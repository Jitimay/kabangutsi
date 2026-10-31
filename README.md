# Kabangutsi

Kabangutsi is an AI call center assistant for BancoBu (Burundi), built for a hackathon prototype. It answers in French,
English and Kirundi by voice and text, and hands calls to a human agent with a summary when needed.
It runs **100% locally**: the only part that needs the internet is the WhatsApp bridge.

> All customers, accounts, cards, branches, products, fees and rates in this repository are **fictional**.

## Quick start

```bash
cp .env.example .env
docker compose build                 # online: builds images, installs packages
scripts/pull_models.sh               # online: pulls gemma4:e2b, gemma4:e4b, gemma:2b, nomic-embed-text
scripts/start_demo.sh --reset        # works offline from here on
scripts/offline_check.sh             # images and models present, no container calls out
```

- Backend API: http://localhost:8000/v1/health (OpenAPI UI at `/docs`)
- Web app (customer + agent dashboard): http://localhost:8080, once `frontend/Dockerfile` exists
- SMS gateway with a USB modem: `scripts/start_demo.sh --hardware`

## Layout

| Path | What | Owner |
|---|---|---|
| `contracts/` | Frozen API, event, message, intent and DB contracts (see `contracts/README.md`) | T0 |
| `scripts/` | Model pull, start, reset, offline check, contract validation, seed data | T0 |
| `backend/` | FastAPI orchestrator, model router, handlers, WebSocket | T1 |
| `backend/channels/` | USSD / SMS / WhatsApp adapters (Python side) | T4 |
| `frontend/` | Flutter customer app + agent dashboard (BLoC) | T2 |
| `voice/` | STT + TTS service | T3 |
| `ocr/`, `sms/`, `whatsapp/` | OCR + PDF service, GSM modem gateway, WhatsApp bridge | T4 |

Rules for contributors: `CLAUDE.md`. Product requirements: the PRD linked there.
