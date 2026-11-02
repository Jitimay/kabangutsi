"""Auto-detect routing in WhisperStt.transcribe_auto (fake Whisper models, no real weights)."""
import threading
from types import SimpleNamespace

import numpy as np

from app.stt import WhisperStt


class FakeModel:
    def __init__(self, probs):
        self.probs = probs  # what this model "hears"
        self.detect_calls = 0

    def transcribe(self, audio, language=None, **_):
        info = SimpleNamespace(language=language or max(self.probs, key=self.probs.get),
                               all_language_probs=sorted(self.probs.items(), key=lambda kv: -kv[1]))
        return iter([SimpleNamespace(text="texte", avg_logprob=-0.1)]), info

    def detect_language(self, audio):
        self.detect_calls += 1
        return None, None, list(self.probs.items())


def stt(probs, referee_probs=None):
    w = object.__new__(WhisperStt)  # skip loading a real model
    w.name, w.model, w.lock, w.ambiguous = "fake", FakeModel(probs), threading.Lock(), (0.3, 0.7)
    w.referee = stt(referee_probs) if referee_probs else None
    return w


AUDIO = np.zeros(16000, dtype=np.float32)


def test_clear_fr_and_clear_rn_skip_referee():
    w = stt({"fr": 0.95, "en": 0.03, "sw": 0.02}, referee_probs={"sw": 1.0})
    assert w.transcribe_auto(AUDIO, 0.5).lang == "fr"
    w = stt({"sw": 0.9, "fr": 0.05, "en": 0.05}, referee_probs={"fr": 1.0})
    assert w.transcribe_auto(AUDIO, 0.5) is None  # → Kirundi
    assert w.referee.model.detect_calls == 0


def test_ambiguous_kirundi_resolved_by_referee():
    # base says 55 % French on Kirundi audio (seen in voice/experiments); small says Swahili
    w = stt({"fr": 0.55, "sw": 0.45}, referee_probs={"sw": 0.8, "fr": 0.1, "en": 0.1})
    assert w.transcribe_auto(AUDIO, 0.5) is None
    assert w.referee.model.detect_calls == 1


def test_ambiguous_french_resolved_by_referee():
    w = stt({"fr": 0.49, "it": 0.51}, referee_probs={"fr": 0.97, "en": 0.01, "it": 0.02})
    r = w.transcribe_auto(AUDIO, 0.5)
    assert r is not None and r.lang == "fr"


def test_no_referee_uses_threshold():
    assert stt({"fr": 0.49, "it": 0.51}).transcribe_auto(AUDIO, 0.5) is None
