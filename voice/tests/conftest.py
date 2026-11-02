import os
from pathlib import Path

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import Engines, create_app
from app.stt import SttResult
from app.tts import Voice

AUDIO = Path(__file__).parent / "audio"
MODELS = Path(os.environ.get("VOICE_MODELS_DIR", Path(__file__).resolve().parents[1] / "models"))


class FakeTts:
    def __init__(self, vid, lang, engine="piper", sr=22050):
        self.voice = Voice(vid, lang, engine, None, True, sr)
        self.calls = 0

    def synth(self, text, speed):
        self.calls += 1
        return np.zeros(int(self.voice.sample_rate * 0.5 / speed), dtype=np.int16)


class FakeWhisper:
    name = "fake-whisper"

    def transcribe(self, audio, lang):
        return SttResult("bonjour" if lang == "fr" else "hello", lang, 0.9, self.name)

    def transcribe_auto(self, audio, threshold):
        # loud audio = Kirundi in this fake
        return None if float(np.abs(audio).max()) > 0.5 else self.transcribe(audio, "fr")


class FakeMms:
    name = "fake-mms"

    def transcribe(self, audio):
        return SttResult("amahoro", "rn", 0.8, self.name)


@pytest.fixture
def fake_client(tmp_path):
    s = Settings(models_dir=tmp_path, engines=())
    e = Engines(s)
    e.whisper, e.mms_stt = FakeWhisper(), FakeMms()
    e.tts = {"fr": [FakeTts("fr_FR-siwis-medium", "fr")], "en": [FakeTts("en_US-lessac-medium", "en")],
             "rn": [FakeTts("mms-tts-run", "rn", "mms", 16000)]}
    e.phrases.load(s.phrases_file, tmp_path / "none", e.tts)
    with TestClient(create_app(e)) as c:
        c.engines = e
        yield c


@pytest.fixture(scope="session")
def real_client():
    if not (MODELS / "faster-whisper-small").exists():
        pytest.skip(f"models not found in {MODELS} (run scripts/download_models.sh)")
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
    e = Engines(Settings(models_dir=MODELS)).load()
    with TestClient(create_app(e)) as c:
        yield c
