"""Contract tests (contracts/voice_api.yaml) with fake engines: fast, no models needed."""
import io
import subprocess
import wave

import numpy as np

from tests.conftest import AUDIO


def wav_bytes(seconds=1.0, amp=0.1, sr=16000):
    t = np.arange(int(sr * seconds)) / sr
    y = (np.sin(2 * np.pi * 220 * t) * amp * 32767).astype(np.int16)
    buf = io.BytesIO()
    with wave.open(buf, "wb") as w:
        w.setnchannels(1), w.setsampwidth(2), w.setframerate(sr), w.writeframes(y.tobytes())
    return buf.getvalue()


def test_health(fake_client):
    r = fake_client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] in ("ok", "degraded") and isinstance(body["models"], dict)


def test_voices(fake_client):
    voices = fake_client.get("/voices").json()["voices"]
    assert {v["lang"] for v in voices} == {"fr", "en", "rn"}
    for v in voices:
        assert set(v) >= {"id", "lang", "engine", "default", "sample_rate"}


def test_stt_with_hint(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(), "audio/wav")}, data={"lang": "en"})
    assert r.status_code == 200
    b = r.json()
    assert b["lang"] == "en" and b["lang_detected"] is False and b["text"] == "hello"
    assert 900 <= b["duration_ms"] <= 1100 and 0 <= b["confidence"] <= 1
    assert set(b) >= {"text", "lang", "confidence", "duration_ms", "processing_ms", "lang_detected", "model"}


def test_stt_auto_detect_fr_and_rn(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(amp=0.1), "audio/wav")})
    assert r.json()["lang"] == "fr" and r.json()["lang_detected"] is True
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(amp=0.9), "audio/wav")})
    assert r.json()["lang"] == "rn" and r.json()["model"] == "fake-mms"


def test_stt_hint_rn_goes_to_mms(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(), "audio/wav")}, data={"lang": "rn"})
    assert r.json()["model"] == "fake-mms"


def test_stt_ogg_webm_m4a_mp3(fake_client, tmp_path):
    """Formats from Flutter `record` (Android m4a/aac, web webm/opus) and WhatsApp (ogg/opus)."""
    for ext, codec, mime in (("ogg", "libopus", "audio/ogg"), ("webm", "libopus", "audio/webm"),
                             ("m4a", "aac", "audio/mp4"), ("mp3", "libmp3lame", "audio/mpeg")):
        out = tmp_path / f"a.{ext}"
        subprocess.run(["ffmpeg", "-loglevel", "error", "-i", str(AUDIO / "fr.wav"), "-c:a", codec, str(out)],
                       check=True)
        r = fake_client.post("/stt", files={"audio": (out.name, out.read_bytes(), mime)}, data={"lang": "fr"})
        assert r.status_code == 200, (ext, r.text)
        assert r.json()["duration_ms"] > 1000


def test_stt_not_audio_415(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.txt", b"hello world" * 100, "text/plain")})
    assert r.status_code == 415 and r.json()["code"] == "unsupported_media_type"


def test_stt_too_long_413(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(seconds=62), "audio/wav")})
    assert r.status_code == 413 and r.json()["code"] == "too_large"


def test_stt_empty_422(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", b"", "audio/wav")})
    assert r.status_code == 422 and r.json()["code"] == "validation_error"


def test_stt_bad_lang_422(fake_client):
    r = fake_client.post("/stt", files={"audio": ("a.wav", wav_bytes(), "audio/wav")}, data={"lang": "sw"})
    assert r.status_code == 422 and r.json()["code"] == "unsupported_language"


def test_tts_wav_and_headers(fake_client):
    r = fake_client.post("/tts", json={"text": "Votre carte est bloquée.", "lang": "fr", "voice": None})
    assert r.status_code == 200 and r.headers["content-type"] == "audio/wav"
    assert r.headers["X-Voice-Id"] == "fr_FR-siwis-medium" and r.headers["X-Voice-Fallback"] == "none"
    assert int(r.headers["X-Duration-Ms"]) == 500 and "X-Processing-Ms" in r.headers
    with wave.open(io.BytesIO(r.content)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == 22050


def test_tts_phrase_cache(fake_client):
    synth = fake_client.engines.tts["rn"][0]
    before = synth.calls
    # first sentence of the backend greeting, case/space/final punctuation ignored
    r = fake_client.post("/tts", json={"text": "murakaza  neza kuri BancoBu", "lang": "rn"})
    assert r.status_code == 200 and r.headers["X-Voice-Fallback"] == "phrase_cache"
    assert synth.calls == before  # served from memory


def test_tts_speed(fake_client):
    r = fake_client.post("/tts", json={"text": "Hello.", "lang": "en", "speed": 2.0})
    assert 248 <= int(r.headers["X-Duration-Ms"]) <= 250


def test_tts_validation(fake_client):
    cases = [({"text": "", "lang": "fr"}, "validation_error"),
             ({"text": "x" * 601, "lang": "fr"}, "validation_error"),
             ({"text": "hi", "lang": "sw"}, "unsupported_language"),
             ({"text": "hi", "lang": "en", "extra": 1}, "validation_error"),
             ({"text": "hi", "lang": "en", "speed": 3}, "validation_error"),
             ({"text": "hi", "lang": "en", "voice": "nope"}, "validation_error"),
             ({"text": "   ", "lang": "en"}, "validation_error")]
    for body, code in cases:
        r = fake_client.post("/tts", json=body)
        assert r.status_code == 422 and r.json()["code"] == code, (body, r.text)
