"""Text-to-speech: Piper (fr, en) and Meta MMS-TTS (rn), plus a phrase cache for frequent replies."""
import json
import re
import threading
import unicodedata
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from .audio import read_wav

SENTENCE_END = re.compile(r"(?<=[.!?…])\s+")


@dataclass
class Voice:
    id: str
    lang: str
    engine: str
    gender: str | None
    default: bool
    sample_rate: int

    def public(self) -> dict:
        return {"id": self.id, "lang": self.lang, "engine": self.engine, "gender": self.gender,
                "default": self.default, "sample_rate": self.sample_rate}


class PiperTts:
    def __init__(self, voice_id: str, lang: str, path: Path, gender, default: bool):
        from piper import PiperVoice

        self.piper = PiperVoice.load(str(path))
        self.voice = Voice(voice_id, lang, "piper", gender, default, self.piper.config.sample_rate)
        self.lock = threading.Lock()

    def synth(self, text: str, speed: float) -> np.ndarray:
        from piper import SynthesisConfig

        cfg = SynthesisConfig(length_scale=self.piper.config.length_scale / speed)
        with self.lock:
            chunks = [np.frombuffer(c.audio_int16_bytes, dtype=np.int16)
                      for c in self.piper.synthesize(text, syn_config=cfg)]
        return np.concatenate(chunks) if chunks else np.zeros(0, dtype=np.int16)


class MmsTts:
    """VITS, not streaming: long text is split into sentences (keeps each call short and stable)."""

    def __init__(self, models_dir: Path, threads: int):
        import torch
        from transformers import AutoTokenizer, VitsModel

        torch.set_num_threads(threads)
        path = models_dir / "mms-tts-run"
        self.model = VitsModel.from_pretrained(path).eval()
        self.tok = AutoTokenizer.from_pretrained(path)
        sr = self.model.config.sampling_rate
        self.voice = Voice("mms-tts-run", "rn", "mms", "male", True, sr)
        self.lock = threading.Lock()
        self._torch = torch

    def synth(self, text: str, speed: float) -> np.ndarray:
        torch = self._torch
        pause = np.zeros(int(0.2 * self.voice.sample_rate), dtype=np.float32)
        parts = []
        for sentence in [s for s in SENTENCE_END.split(text.strip()) if s]:
            inputs = self.tok(sentence, return_tensors="pt")
            if inputs.input_ids.shape[1] == 0:
                continue
            with self.lock, torch.inference_mode():
                self.model.speaking_rate = speed
                torch.manual_seed(0)  # VITS samples noise: fixed seed = same audio for same text
                wav = self.model(**inputs).waveform[0].numpy()
            parts += [wav, pause]
        if not parts:
            return np.zeros(0, dtype=np.int16)
        return (np.clip(np.concatenate(parts[:-1]), -1, 1) * 32767).astype(np.int16)


def phrase_key(text: str) -> str:
    """Exact-match key: case, accents, apostrophes and spaces normalised; final punctuation ignored."""
    t = unicodedata.normalize("NFC", text).replace("’", "'").lower()
    return re.sub(r"\s+", " ", t).strip().rstrip(".!?… ")


class PhraseCache:
    """Frequent replies, kept in memory as int16 audio.

    Source per phrase: a pre-recorded WAV (<prerecorded_dir>/<lang>/<id>.wav, human voice) if present,
    otherwise generated once at startup with the default voice of that language.
    """

    def __init__(self):
        self.items: dict[tuple[str, str], tuple[np.ndarray, int, str]] = {}

    def load(self, phrases_file: Path, prerecorded_dir: Path, voices: dict[str, list]) -> None:
        if not phrases_file.exists():
            return
        data = json.loads(phrases_file.read_text(encoding="utf-8"))
        for pid, by_lang in data.items():
            for lang, text in by_lang.items():
                rec = prerecorded_dir / lang / f"{pid}.wav"
                if rec.exists():
                    audio, sr = read_wav(rec)
                    self.items[(lang, phrase_key(text))] = (audio, sr, f"prerecorded/{lang}/{pid}")
                elif voices.get(lang):
                    eng = voices[lang][0]
                    self.items[(lang, phrase_key(text))] = (eng.synth(text, 1.0), eng.voice.sample_rate,
                                                            eng.voice.id)

    def get(self, lang: str, text: str):
        return self.items.get((lang, phrase_key(text)))
