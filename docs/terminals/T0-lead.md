# T0 — Lead: Wave 0 (foundations + contracts)

Read `CLAUDE.md` first. You run **before** everyone else. T1–T4 cannot start until you reach **G0**.

- Branch: `main`
- You own: `docker-compose.yml`, `.env.example`, `contracts/`, `scripts/`, `docs/`, root files, `status/T0.md`
- You also create the empty skeleton folders for the others (they own them after G0).

## Goal
A stack that starts with one command, offline, and a set of frozen contracts that let four terminals work
in parallel without talking to each other.

## Tasks

### 1. Repository
- `git init`, `.gitignore` (Python, Flutter, `.env`, `*.db`, model caches, `node_modules`, `build/`).
- Skeleton folders, each with a short `README.md`: `backend/`, `backend/channels/`, `frontend/`, `voice/`,
  `sms/`, `whatsapp/`, `ocr/`, `contracts/`, `scripts/`, `status/`.
- `backend/requirements.txt` and `backend/requirements-dev.txt` already exist; keep them.

### 2. Contracts (`contracts/`) — the most important deliverable
| File | Content |
|---|---|
| `openapi.yaml` | Backend REST API `/v1`: health, models list (with capabilities), conversations + messages (text, image, audio attachment, chosen model, streamed reply via SSE), card block, loan simulation, tickets, branches, calls queue, claim call, stats, channel inbound `/v1/channels/{channel}/inbound` |
| `ws_events.json` | JSON Schema of every WebSocket event: `call.started`, `call.turn`, `call.handoff_requested`, `call.claimed`, `call.ended`, `ticket.created`, `ticket.updated`, `model.switched`, `stats.updated`, `agent.suggestion` |
| `message.schema.json` | Standard message: `{id, channel (phone/ussd/sms/whatsapp/web), phone, session_id, lang, text, attachments[{type: image/audio/pdf, url, mime}], ts}` and the outgoing reply format (with `short_text` ≤160 chars for SMS) |
| `intent.schema.json` | LLM output: `{intent (product_info/account_opening/card_block/loan_info/complaint/branch_info/handoff/other), lang, entities{...}, confidence, frustration (0–1)}` |
| `voice_api.yaml` | Voice service: `POST /stt` (audio → text, lang, confidence), `POST /tts` (text, lang → audio/wav), `GET /health`, `GET /voices` |
| `ocr_api.yaml` | OCR service: `POST /ocr/extract` (image, doc_type → fields with confidence), `GET /doc-types`, `POST /pdf/render` (template, lang, data → PDF), `GET /health` |
| `db_schema.md` | Tables from the PRD data model + `model_events`; T1 turns it into the first Alembic migration |
| `CHANGELOG.md` | Empty, with the change-entry template |

Include realistic examples in every schema (fr, en, rn). Get the inspector to review before freezing.

### 3. Docker Compose
- Services: `postgres` (`pgvector/pgvector:pg16`), `ollama` (`ollama/ollama`), `backend`, `voice`, `ocr`,
  `frontend` (nginx serving Flutter web build), `sms-gateway`, `whatsapp-bridge`. Ports as in `CLAUDE.md`.
- Placeholder Dockerfiles + a minimal `/health` app for each service so the whole stack starts on day one.
- Named volumes: postgres data, ollama models, voice models, ocr models, whatsapp session.
- Health checks on postgres and ollama; backend `depends_on` them (condition: service_healthy).
- `sms-gateway`: `devices: ["/dev/ttyUSB0:/dev/ttyUSB0"]` behind a Compose profile `hardware` so the
  stack still starts without the modem.
- `.env.example`: DB credentials, default model, model preference order, ports.

### 4. Scripts (`scripts/`)
- `pull_models.sh`: pulls Ollama models (`gemma4:e2b`, `gemma4:e4b` if they exist under those tags —
  verify on ollama.com — plus `gemma:2b`, `nomic-embed-text`) into the ollama volume.
- `start_demo.sh`: `docker compose up -d`, waits for health, prints URLs.
- `reset_demo.sh` + `scripts/reset_demo.sql`: restores the synthetic demo data.
- `offline_check.sh`: starts the stack with the network cut (or checks no container calls out).

### 5. Synthetic data (`scripts/seed/`)
Fictional but realistic Burundian data as JSON/CSV: ~50 customers (names, provinces: Bujumbura, Gitega,
Ngozi, Muyinga, Rumonge…), cards, branches (hours, phones), loan products (rate, min/max, term),
knowledge base articles in fr/en/rn (account opening requirements, card procedures, loan products,
complaint process, fees). Mark everything clearly as fictional.

### 6. Risk checks (record results in `status/T0.md`)
- `ollama show <model>` for each Gemma model: list capabilities (vision? audio?).
- Quick test: Kirundi STT/TTS model availability (Meta MMS) — hand detailed work to T3.

### 7. Worktrees for the other terminals (after G0)
```
git branch t1-backend && git worktree add ../kabangutsi-t1 t1-backend
git branch t2-flutter && git worktree add ../kabangutsi-t2 t2-flutter
git branch t3-voice   && git worktree add ../kabangutsi-t3 t3-voice
git branch t4-channels && git worktree add ../kabangutsi-t4 t4-channels
```

## G0 exit checklist
- [ ] `docker compose up` starts every service; all `/health` return 200 — with Wi-Fi off
- [ ] All contract files present, with examples, reviewed by the inspector
- [ ] Seed data loads into PostgreSQL
- [ ] Model capability results recorded
- [ ] Worktrees created; `status/T1.md` … `status/T4.md` created from the template

## Later: Wave 7 (with everyone)
150-utterance test set (50 fr, 50 en, 50 rn) in `scripts/eval/`, offline rehearsal, backup video, pitch.
