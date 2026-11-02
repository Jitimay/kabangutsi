"""Speech-to-text: faster-whisper for fr/en, Meta MMS-1b-all + `run` adapter for Kirundi.

Language auto-detect: Whisper has no Kirundi. whisper-small gives Kirundi audio P(fr)+P(en) ≤ 0.21 and
fr/en audio ≥ 0.96; whisper-base (the fast default) mostly too, but 2 of 100 test clips land in between
(fr 0.49, rn 0.55). So: P(fr)+P(en) ≥ threshold → the more likely of fr/en (Whisper), otherwise rn (MMS);
when base's score is in the ambiguous band, whisper-small (the `referee`) decides the language only
(one extra encoder pass, rare). MMS's CTC confidence is ~0.96 even on French, so it cannot arbitrate.
"""
import math
import threading
from dataclasses import dataclass

import numpy as np

SR = 16000
INT8_FILE = "run-int8.pt"  # same name as scripts/quantize_mms.py OUT_NAME


@dataclass
class SttResult:
    text: str
    lang: str
    confidence: float
    model: str


class WhisperStt:
    def __init__(self, models_dir, size: str, threads: int):
        from faster_whisper import WhisperModel

        self.name = f"faster-whisper-{size}-int8"
        self.model = WhisperModel(str(models_dir / f"faster-whisper-{size}"), device="cpu",
                                  compute_type="int8", cpu_threads=threads)
        self.lock = threading.Lock()
        self.referee: "WhisperStt | None" = None  # bigger model, language ID only in the ambiguous band
        self.ambiguous = (0.3, 0.7)

    def lang_probs(self, audio: np.ndarray) -> dict[str, float]:
        with self.lock:
            return dict(self.model.detect_language(audio)[2])

    def _run(self, audio: np.ndarray, lang: str | None):
        return self.model.transcribe(audio, language=lang, beam_size=1, vad_filter=False,
                                     condition_on_previous_text=False, without_timestamps=True)

    def transcribe(self, audio: np.ndarray, lang: str) -> SttResult:
        with self.lock:
            segments, _ = self._run(audio, lang)
            return self._result(list(segments), lang)

    def transcribe_auto(self, audio: np.ndarray, rn_threshold: float) -> SttResult | None:
        """Detect fr/en and transcribe in one encoder pass. Returns None when the audio looks like Kirundi.

        faster-whisper detects the language before decoding and decodes lazily, so Kirundi audio
        costs only the detection (no slow hallucinated decoding).
        """
        with self.lock:
            segments, info = self._run(audio, None)
            p = dict(info.all_language_probs or [])
            fr, en = p.get("fr", 0.0), p.get("en", 0.0)
            low, high = self.ambiguous
            if self.referee is not None and self.referee is not self and low <= fr + en <= high:
                p = self.referee.lang_probs(audio)
                fr, en = p.get("fr", 0.0), p.get("en", 0.0)
            if fr + en < rn_threshold:
                return None
            lang = "fr" if fr >= en else "en"
            if info.language != lang:  # Whisper preferred a third language: force fr/en
                segments, _ = self._run(audio, lang)
            return self._result(list(segments), lang)

    def _result(self, segments, lang: str) -> SttResult:
        text = " ".join(s.text.strip() for s in segments).strip()
        conf = float(np.mean([math.exp(s.avg_logprob) for s in segments])) if segments else 0.0
        return SttResult(text, lang, round(min(max(conf, 0.0), 1.0), 3), self.name)


class MmsStt:
    name = "mms-1b-all/run"

    def __init__(self, models_dir, threads: int, dtype: str = "fp32"):
        import torch
        from transformers import AutoProcessor, Wav2Vec2ForCTC

        torch.set_num_threads(threads)
        path = models_dir / "mms-1b-all"
        self.processor = AutoProcessor.from_pretrained(path, target_lang="run")
        if dtype == "int8":
            # Built once by scripts/quantize_mms.py (image build): ~2.6 GB RSS instead of ~4 GB for fp32,
            # 3 WER points worse, ~2 s per 3 s utterance on this CPU (voice/experiments).
            pt = path / INT8_FILE
            if not pt.exists():
                raise FileNotFoundError(f"{pt} missing: run scripts/quantize_mms.py {models_dir}")
            model = torch.load(pt, weights_only=False).eval()
            self.name = "mms-1b-all/run-int8"
        else:
            model = Wav2Vec2ForCTC.from_pretrained(path, target_lang="run", ignore_mismatched_sizes=True,
                                                   use_safetensors=True).eval()
        self.model = model
        self.blank = self.processor.tokenizer.pad_token_id
        self.lock = threading.Lock()
        self._torch = torch

    def transcribe(self, audio: np.ndarray) -> SttResult:
        inputs = self.processor(audio, sampling_rate=SR, return_tensors="pt")
        with self.lock, self._torch.inference_mode():
            logits = self.model(inputs.input_values).logits[0]
        probs = logits.softmax(-1)
        best_p, ids = probs.max(-1)
        speech = ids != self.blank
        conf = float(best_p[speech].mean()) if bool(speech.any()) else 0.0
        text = self.processor.decode(ids)
        return SttResult(text.strip(), "rn", round(conf, 3), self.name)
