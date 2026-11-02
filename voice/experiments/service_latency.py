"""End-to-end latency of the running voice service (HTTP, warm), against the contract targets:
STT < 1 s for 5 s of audio, first TTS sentence < 0.7 s.

    uvicorn app.main:app --port 8001          # from voice/, VOICE_MODELS_DIR=voice/models
    .venv/bin/python service_latency.py [http://localhost:8001]   → results/service_latency.json
"""
import json
import statistics
import sys
import time
import urllib.request
import uuid
from pathlib import Path

from common import OUT, machine_state, save_json

URL = sys.argv[1] if len(sys.argv) > 1 else "http://localhost:8001"
INPUT = OUT / "stt_input"
TTS_TEXT = {"fr": "Votre carte se terminant par 4821 est bloquée.",
            "en": "Your card ending in 4821 is now blocked.",
            "rn": "Ikarata yanyu yafunzwe."}
CACHED = {"fr": "Un instant, s'il vous plaît.", "en": "One moment, please.", "rn": "Mutegereze gato."}


def post_stt(path: Path, lang: str | None) -> tuple[dict, float]:
    b = "----" + uuid.uuid4().hex
    parts = []
    if lang:
        parts.append(f'--{b}\r\nContent-Disposition: form-data; name="lang"\r\n\r\n{lang}\r\n'.encode())
    parts.append(f'--{b}\r\nContent-Disposition: form-data; name="audio"; filename="{path.name}"\r\n'
                 f"Content-Type: audio/wav\r\n\r\n".encode() + path.read_bytes() + b"\r\n")
    parts.append(f"--{b}--\r\n".encode())
    req = urllib.request.Request(f"{URL}/stt", data=b"".join(parts),
                                 headers={"Content-Type": f"multipart/form-data; boundary={b}"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=120) as r:
        body = json.loads(r.read())
    return body, time.perf_counter() - t0


def post_tts(text: str, lang: str) -> tuple[dict, float]:
    req = urllib.request.Request(f"{URL}/tts", data=json.dumps({"text": text, "lang": lang}).encode(),
                                 headers={"Content-Type": "application/json"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=120) as r:
        r.read()
        headers = {k.lower(): v for k, v in r.headers.items()}
    return headers, time.perf_counter() - t0


def stats(xs):
    return {"median_s": round(statistics.median(xs), 3), "max_s": round(max(xs), 3), "n": len(xs)}


def main():
    before = machine_state()
    health = json.loads(urllib.request.urlopen(f"{URL}/health").read())
    out = {"url": URL, "machine_before": before, "health": health, "stt": {}, "tts": {}}
    for lang in ("fr", "en", "rn"):
        src = sorted(p for p in (INPUT / lang).iterdir() if p.name != "espeak" and not p.name.endswith("_phone"))[0]
        files = sorted(src.glob("*.wav"))[:5]
        post_stt(files[0], lang)  # warm-up
        for mode in ("hint", "auto"):
            times, per5, langs = [], [], []
            for f in files:
                body, dt = post_stt(f, lang if mode == "hint" else None)
                times.append(dt)
                per5.append(dt / (body["duration_ms"] / 1000) * 5)
                langs.append(body["lang"])
            out["stt"][f"{lang}_{mode}"] = {**stats(times), "per_5s_audio_median_s": round(statistics.median(per5), 3),
                                            "lang_ok": sum(x == lang for x in langs) / len(langs)}
            print(lang, mode, out["stt"][f"{lang}_{mode}"])
    for lang in ("fr", "en", "rn"):
        post_tts(TTS_TEXT[lang], lang)  # warm-up
        times = [post_tts(TTS_TEXT[lang], lang)[1] for _ in range(5)]
        h, dt = post_tts(CACHED[lang], lang)
        out["tts"][lang] = {**stats(times), "phrase_cache_s": round(dt, 3),
                            "phrase_cache_header": h.get("x-voice-fallback")}
        print(lang, "tts", out["tts"][lang])
    out["machine_after"] = machine_state()
    save_json("service_latency.json", out)


if __name__ == "__main__":
    main()
