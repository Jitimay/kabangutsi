"""End-to-end voice call through the real stack (backend → voice → Ollama → voice), as the app does it.

For each language: create a phone conversation, send a recorded customer turn (16 kHz mono WAV, like
the Flutter call screen) with voice=true over SSE, and time each stage from the moment the upload is
complete:
  stt_s          `turn` event (backend got the transcript from POST /stt)
  first_sentence `sentence` event with audio_url (LLM sentence + POST /tts done)
  first_audio_s  first sentence's WAV downloaded = when the app can start playing ("first spoken word")
Target (docs/terminals/T3-voice.md): first spoken word < 3 s after the caller stops.

    .venv/bin/python call_e2e.py [http://localhost:8000] [--rounds 2]   → results/call_e2e.json
"""
import argparse
import json
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

from common import machine_state, save_json

AUDIO = Path(__file__).resolve().parents[1] / "tests" / "audio"
PHONE = {"fr": "+25779000201", "en": "+25779000202", "rn": "+25779000203"}  # synthetic


def post_json(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def multipart(fields: dict, files: dict) -> tuple[bytes, str]:
    b = "----" + uuid.uuid4().hex
    out = b""
    for k, v in fields.items():
        out += f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    for k, (name, data, mime) in files.items():
        out += (f'--{b}\r\nContent-Disposition: form-data; name="{k}"; filename="{name}"\r\n'
                f"Content-Type: {mime}\r\n\r\n").encode() + data + b"\r\n"
    return out + f"--{b}--\r\n".encode(), f"multipart/form-data; boundary={b}"


def call_turn(api: str, lang: str) -> dict:
    conv = post_json(f"{api}/v1/conversations", {"channel": "phone", "phone": PHONE[lang], "lang": lang, "model": None})
    body, ctype = multipart({"voice": "true", "lang": lang},
                            {"audio": ("turn.wav", (AUDIO / f"{lang}.wav").read_bytes(), "audio/wav")})
    req = urllib.request.Request(f"{api}/v1/conversations/{conv['id']}/messages", data=body,
                                 headers={"Content-Type": ctype, "Accept": "text/event-stream"})
    t0 = time.perf_counter()
    res = {"lang": lang, "conversation_id": conv["id"], "sentences": []}
    event = None
    with urllib.request.urlopen(req, timeout=300) as r:
        for raw in r:
            line = raw.decode("utf-8").rstrip("\r\n")
            if line.startswith("event:"):
                event = line[6:].strip()
            elif line.startswith("data:") and event:
                data = json.loads(line[5:])
                t = round(time.perf_counter() - t0, 3)
                if event == "turn":
                    res["stt_s"], res["transcript"] = t, data.get("text")
                elif event == "model.switched":
                    res["model_switched"] = data
                elif event == "sentence":
                    res["sentences"].append({"t": t, "text": data["text"], "audio_url": data.get("audio_url")})
                    if "first_sentence_s" not in res and data.get("audio_url"):
                        res["first_sentence_s"] = t
                        res["first_audio_url"] = data["audio_url"]
                        try:  # what the app does: fetch as soon as the sentence arrives
                            u = data["audio_url"]
                            with urllib.request.urlopen(u if u.startswith("http") else api + u, timeout=30) as a:
                                a.read()
                            res["playable_at_sentence"] = True
                            res["first_audio_s"] = round(time.perf_counter() - t0, 3)
                        except urllib.error.HTTPError as e:
                            res["playable_at_sentence"] = False
                            res["http_at_sentence"] = e.code
                elif event == "done":
                    res["done_s"] = t
                    # read the rest of the stream in the background is not needed: done is last
                    res["intent"] = (data.get("intent") or {}).get("name") if isinstance(data.get("intent"), dict) else data.get("intent")
                    res["model_used"] = data.get("model_used")
                elif event == "error":
                    res["error"] = data
                event = None
    if res.get("first_audio_url") and not res.get("playable_at_sentence"):
        res.update(fetch_audio(api, res["first_audio_url"], t0))
    return res


def fetch_audio(api: str, url: str, t0: float) -> dict:
    """Poll the sentence audio like a player would: 404 means 'not committed yet' (T1 bug, status/T3.md)."""
    url = url if url.startswith("http") else api + url
    while time.perf_counter() - t0 < 120:
        try:
            with urllib.request.urlopen(url, timeout=30) as a:
                wav = a.read()
            return {"first_audio_s": round(time.perf_counter() - t0, 3), "first_audio_bytes": len(wav),
                    "first_audio_type": a.headers.get("Content-Type")}
        except urllib.error.HTTPError as e:
            if e.code != 404:
                raise
            time.sleep(0.05)
    return {"first_audio_s": None}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("api", nargs="?", default="http://localhost:8000")
    ap.add_argument("--rounds", type=int, default=2, help="round 1 warms the models; later rounds are warm")
    a = ap.parse_args()
    out = {"machine_before": machine_state(), "runs": []}
    for rnd in range(1, a.rounds + 1):
        for lang in ("fr", "en", "rn"):
            r = call_turn(a.api, lang)
            r["round"] = rnd
            out["runs"].append(r)
            print(f"round {rnd} {lang}: stt {r.get('stt_s')}s, first audio {r.get('first_audio_s')}s, "
                  f"playable at sentence {r.get('playable_at_sentence')}, first sentence {r.get('first_sentence_s')}s, done {r.get('done_s')}s, sentences {len(r['sentences'])}, model {r.get('model_used')}, "
                  f"intent {r.get('intent')}{', ERROR ' + str(r['error']) if 'error' in r else ''}\n"
                  f"   heard: {r.get('transcript')!r}\n   said:  {r['sentences'][0]['text'] if r['sentences'] else None!r}")
    out["machine_after"] = machine_state()
    save_json("call_e2e.json", out)


if __name__ == "__main__":
    main()
