"""Text-to-speech: Piper (fr, en) and Meta MMS-TTS (rn), plus a phrase cache for frequent replies."""
import hashlib
import json
import re
import threading
import unicodedata
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from .audio import read_wav, to_wav

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
    """Frequent replies, kept in memory as int16 audio (phrases.json = the backend's fixed sentences).

    Source per phrase, first match wins:
      1. pre-recorded human voice: <prerecorded_dir>/<lang>/<id>.wav
      2. generated earlier: <cache_dir>/<lang>/<hash of voice + text>.wav (in the models volume)
      3. generated now with the default voice of the language, then written to <cache_dir>
    `load` does 1 and 2 (fast) and returns what is still missing; `warm` generates those (~65 s for all
    phrases on first start), meant to run in a background thread so the service is up immediately.
    """

    def __init__(self):
        self.items: dict[tuple[str, str], tuple[np.ndarray, int, str]] = {}
        self.pending: list[tuple[str, str]] = []
        self.cache_dir: Path | None = None

    def load(self, phrases_file: Path, prerecorded_dir: Path, voices: dict[str, list],
             cache_dir: Path | None = None, warm: bool = True) -> None:
        self.cache_dir = cache_dir
        if not phrases_file.exists():
            return
        data = json.loads(phrases_file.read_text(encoding="utf-8"))
        for pid, by_lang in data.items():
            for lang, text in by_lang.items():
                rec = prerecorded_dir / lang / f"{pid}.wav"
                if rec.exists():
                    audio, sr = read_wav(rec)
                    self.items[(lang, phrase_key(text))] = (audio, sr, f"prerecorded/{lang}/{pid}")
                    continue
                if not voices.get(lang):
                    continue
                cached = self._cache_path(lang, text, voices[lang][0].voice.id)
                if cached is not None and cached.exists():
                    try:
                        audio, sr = read_wav(cached)
                        self.items[(lang, phrase_key(text))] = (audio, sr, voices[lang][0].voice.id)
                        continue
                    except (ValueError, EOFError, OSError):
                        pass  # corrupt file: regenerate
                self.pending.append((lang, text))
        if warm:
            self.warm(voices)

    def warm(self, voices: dict[str, list]) -> int:
        """Generate the pending phrases (and store them on disk when possible). Returns how many."""
        done = 0
        while self.pending:
            lang, text = self.pending.pop(0)
            eng = voices[lang][0]
            audio = eng.synth(text, 1.0)
            self.items[(lang, phrase_key(text))] = (audio, eng.voice.sample_rate, eng.voice.id)
            path = self._cache_path(lang, text, eng.voice.id)
            if path is not None:
                try:
                    path.parent.mkdir(parents=True, exist_ok=True)
                    tmp = path.with_suffix(".tmp")
                    tmp.write_bytes(to_wav(audio, eng.voice.sample_rate))
                    tmp.replace(path)
                except OSError:
                    self.cache_dir = None  # read-only volume: keep in memory only
            done += 1
        return done

    def _cache_path(self, lang: str, text: str, voice_id: str) -> Path | None:
        if self.cache_dir is None:
            return None
        h = hashlib.sha1(f"{voice_id}\n{phrase_key(text)}".encode()).hexdigest()[:20]
        return self.cache_dir / lang / f"{h}.wav"

    def get(self, lang: str, text: str):
        return self.items.get((lang, phrase_key(text)))
