# T3 — Voice service (STT + TTS): Wave 3

Read `CLAUDE.md` and `contracts/voice_api.yaml` first. Start only after **G0**.

- Branch / worktree: `t3-voice` → `../kabangutsi-t3`
- You own: `voice/` and `status/T3.md`
- Your service is called **only by the backend** over HTTP (port 8001, internal). It is the highest-risk
  part of the project: report findings early in your status file.

## Step 1 — De-risk (first, before building anything)
Test on this machine (CPU only, 8 cores, 16 GB RAM) and record results in `status/T3.md`:

| Test | Candidates | Record |
|---|---|---|
| STT French + English | faster-whisper (small / base, int8) | word accuracy on 10 sample sentences, latency per 5 s of audio |
| STT Kirundi | Meta MMS ASR (check that a Kirundi `run` adapter exists) | same |
| TTS French + English | Piper voices | quality (1–5), time to first audio |
| TTS Kirundi | Meta MMS-TTS (check a Kirundi model exists) | quality (1–5), latency |
| Gemma 4 audio input via Ollama | `ollama show` capabilities, one test | works / doesn't |

Decide with the inspector: if Kirundi voice is below 3/5, the fallback is Kirundi text on screen +
pre-recorded Kirundi phrases for the most common answers (greeting, "please wait", "transferring you").

## Step 2 — Build the service (FastAPI, Python 3.12, own Dockerfile)
| Endpoint | Behavior |
|---|---|
| `GET /health` | 200 + loaded models |
| `GET /voices` | available voices per language |
| `POST /stt` | audio (wav/webm/ogg/m4a) + optional `lang` hint → `{text, lang, confidence, duration_ms}`; auto-detect language when no hint |
| `POST /tts` | `{text, lang, voice?}` → `audio/wav`; supports short sentences for streaming |
| `POST /tts/stream` (if in contract) | sentence-by-sentence audio chunks |

Requirements:
- All models downloaded **at image build time** (or into the `voice-models` volume by a script); no
  download at runtime. Test with Wi-Fi off.
- Load models once at startup; keep them in memory.
- Pre-recorded / pre-generated phrase cache for frequent replies in fr, en, rn (instant playback).
- `voice/requirements.txt` pinned; `voice/tests/` with a sample audio per language.
- Time to first audio after the caller stops: target under 3 s total including the LLM — so aim for STT
  under 1 s on 5 s of audio and TTS first sentence under 0.7 s.

## Step 3 — Call wiring (after G1, together with T1 and T2)
- Agree with T1 on the call flow (audio in → STT → orchestrator → reply sentences → TTS → audio out).
- Help T2 with audio formats the Flutter `record` / `just_audio` packages produce and play
  (Android + web).
- Request any backend or Flutter changes through `status/T3.md`; don't edit their folders.

## Done when (Wave 3 exit)
- [ ] Full voice call in French and English through the app, first spoken word under 3 s
- [ ] Kirundi voice working, or the agreed fallback in place
- [ ] Service starts offline from `docker compose up`
