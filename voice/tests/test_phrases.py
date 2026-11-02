"""Phrase cache: disk persistence and sync with the backend's reply templates."""
import importlib.util
import json
from pathlib import Path

import pytest

from app.tts import PhraseCache
from tests.conftest import FakeTts

ROOT = Path(__file__).resolve().parents[2]
PHRASES = ROOT / "voice" / "phrases" / "phrases.json"


def test_disk_cache_survives_restart(tmp_path):
    phrases = tmp_path / "p.json"
    phrases.write_text(json.dumps({"hi": {"en": "Hello.", "rn": "Amahoro."}}))
    voices = {"en": [FakeTts("en_US-lessac-medium", "en")], "rn": [FakeTts("mms-tts-run", "rn", "mms", 16000)]}
    first = PhraseCache()
    first.load(phrases, tmp_path / "rec", voices, tmp_path / "cache", warm=False)
    assert len(first.pending) == 2 and first.get("en", "hello") is None
    assert first.warm(voices) == 2 and first.get("en", "hello") is not None
    assert len(list((tmp_path / "cache").rglob("*.wav"))) == 2

    calls = voices["en"][0].calls
    second = PhraseCache()  # "restart": everything comes from disk, nothing is synthesised
    second.load(phrases, tmp_path / "rec", voices, tmp_path / "cache", warm=False)
    assert second.pending == [] and second.get("rn", "Amahoro") is not None
    assert voices["en"][0].calls == calls


def test_recording_overrides_generated(tmp_path):
    from app.audio import to_wav
    import numpy as np

    phrases = tmp_path / "p.json"
    phrases.write_text(json.dumps({"hi": {"rn": "Amahoro."}}))
    (tmp_path / "rec" / "rn").mkdir(parents=True)
    (tmp_path / "rec" / "rn" / "hi.wav").write_bytes(to_wav(np.zeros(800, dtype=np.int16), 16000))
    pc = PhraseCache()
    pc.load(phrases, tmp_path / "rec", {"rn": [FakeTts("mms-tts-run", "rn", "mms", 16000)]}, None)
    assert pc.get("rn", "amahoro")[2] == "prerecorded/rn/hi"


@pytest.mark.skipif(not (ROOT / "backend" / "app" / "core" / "responses.py").exists(), reason="no backend checkout")
def test_phrases_match_backend_templates():
    """Fails when T1 changes a reply template: run `python voice/scripts/sync_phrases.py` and commit."""
    spec = importlib.util.spec_from_file_location("sync_phrases", ROOT / "voice" / "scripts" / "sync_phrases.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    assert json.loads(PHRASES.read_text(encoding="utf-8")) == mod.build(mod.load_templates(mod.SRC))
