"""Integration tests on the real models (skipped if voice/models is missing). Heavy: ~5 GB RAM."""
import pytest

from tests.conftest import AUDIO

pytestmark = pytest.mark.models


@pytest.mark.parametrize("lang,words", [("fr", {"carte", "bloquée"}), ("en", {"card", "blocked"})])
def test_stt_fr_en(real_client, lang, words):
    for hint in (lang, None):
        data = {"lang": hint} if hint else {}
        r = real_client.post("/stt", files={"audio": (f"{lang}.wav", (AUDIO / f"{lang}.wav").read_bytes(),
                                                      "audio/wav")}, data=data)
        b = r.json()
        assert r.status_code == 200 and b["lang"] == lang, b
        assert words <= set(b["text"].lower().replace(".", "").split()), b
        assert b["confidence"] > 0.4


def test_stt_rn_auto(real_client):
    r = real_client.post("/stt", files={"audio": ("rn.wav", (AUDIO / "rn.wav").read_bytes(), "audio/wav")})
    b = r.json()
    assert r.status_code == 200 and b["lang"] == "rn" and b["lang_detected"] is True, b
    assert "ikarata" in b["text"], b


@pytest.mark.parametrize("lang,text", [("fr", "Votre carte est bloquée."), ("en", "Your card is blocked."),
                                       ("rn", "Ikarata yanyu yafunzwe.")])
def test_tts(real_client, lang, text):
    r = real_client.post("/tts", json={"text": text, "lang": lang})
    assert r.status_code == 200 and r.headers["X-Voice-Fallback"] == "none"
    assert int(r.headers["X-Duration-Ms"]) > 500


def test_health_ok(real_client):
    b = real_client.get("/health").json()
    assert b["status"] == "ok", b
