"""Test Gemma 4 audio input via Ollama: send a 16 kHz WAV, ask for a transcript.

    python gemma_audio_test.py <wav> [<wav> ...]   (default model gemma4:e4b, OLLAMA_HOST env)
Ollama has no separate audio field: media goes in `images` (base64) and the server sniffs the type.
"""
import base64
import json
import os
import sys
import time
import urllib.request

from common import save_json

HOST = os.environ.get("OLLAMA_HOST", "http://localhost:11434")
MODEL = os.environ.get("GEMMA_MODEL", "gemma4:e4b")
PROMPT = ("Transcribe this audio exactly, in its original language. "
          "Then on a new line write LANG=<fr|en|rn|other>.")


def ask(wav: str) -> dict:
    body = {"model": MODEL, "stream": False, "think": False, "options": {"temperature": 0},
            "messages": [{"role": "user", "content": PROMPT,
                          "images": [base64.b64encode(open(wav, "rb").read()).decode()]}]}
    req = urllib.request.Request(f"{HOST}/api/chat", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            out = json.load(r)
        return {"wav": wav, "ok": True, "seconds": round(time.perf_counter() - t0, 2),
                "reply": out["message"]["content"],
                "load_s": round(out.get("load_duration", 0) / 1e9, 2),
                "prompt_tokens": out.get("prompt_eval_count")}
    except urllib.error.HTTPError as e:
        return {"wav": wav, "ok": False, "error": f"{e.code} {e.read().decode()[:300]}"}


if __name__ == "__main__":
    res = [ask(w) for w in sys.argv[1:]]
    for r in res:
        print(json.dumps(r, ensure_ascii=False))
    save_json("gemma_audio.json", {"model": MODEL, "results": res})
