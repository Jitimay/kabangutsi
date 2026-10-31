# Kabangutsi — shared rules for every terminal

Kabangutsi is an AI call center assistant for BancoBu (Burundi), built for a hackathon.
Customers ask about products, account opening, blocked cards, loans, complaints, and branch hours;
the AI answers by voice and text in **French, English and Kirundi (equal priority)**, hands over to a
human agent with a summary when needed, and runs **100% locally**.

- PRD (source of truth): https://claude.ai/artifact/JneUkGctoTKzFiNAUS1gFp
- Challenge brief: `requirements/ai_call_center_assistant_challenge.md`
- Your personal instructions: `docs/terminals/<your terminal>.md`

## Terminals and folder ownership

| Terminal | Branch | Owns (may edit) |
|---|---|---|
| T0 Lead | `main` | `docker-compose.yml`, `.env.example`, `contracts/`, `scripts/`, `docs/`, root files |
| T1 Backend | `t1-backend` | `backend/` except `backend/channels/` |
| T2 Flutter | `t2-flutter` | `frontend/` |
| T3 Voice | `t3-voice` | `voice/` |
| T4 Channels + docs | `t4-channels` | `backend/channels/`, `sms/`, `whatsapp/`, `ocr/` |

Every terminal also owns its own status file: `status/T<n>.md`.

## Hard rules

1. **Edit only the folders you own.** Need something in another folder? Write it in your status file under
   "Requests to other terminals" and stop on that item.
2. **Contracts are law.** Everything in `contracts/` is frozen at gate G0. Code must match it exactly.
   A change needs an entry in `contracts/CHANGELOG.md` (what, why, who is affected) and inspector approval.
3. **Offline at runtime.** No cloud API, no CDN, no runtime downloads. Models, fonts and packages are
   pulled at build time. Only exception: WhatsApp traffic itself goes through the internet.
4. **The LLM never takes security decisions.** PIN, identity checks, card blocking and any action are
   done in code. PINs and identity data are never sent to a model.
5. **No invented bank facts.** Product, fee, branch and hour answers come only from the knowledge base.
6. **Three languages everywhere:** `fr`, `en`, `rn` (Kirundi). Every user-facing string exists in all three.
7. **Synthetic data only.** No real names, IDs, phone or account numbers.
8. **Commits:** small, only your folders, message format `T<n>: <what>` (e.g. `T1: add card block handler`).
   Never commit `.env`, model files or database dumps.

## Shared technical conventions

| Service | Port (host) | Notes |
|---|---|---|
| backend (FastAPI) | 8000 | REST under `/v1`, WebSockets under `/v1/ws` |
| frontend (Flutter web, nginx) | 8080 | |
| voice (STT/TTS) | 8001 | internal |
| ocr (OCR + PDF) | 8002 | internal |
| sms-gateway | 8003 | internal |
| whatsapp-bridge | 8004 | internal |
| postgres (pgvector) | 5432 | internal |
| ollama | 11434 | internal |

- Python 3.12 in Docker; FastAPI + Pydantic v2; SQLAlchemy 2 async + asyncpg; Alembic migrations.
- Flutter with BLoC (`flutter_bloc`), clean layers: UI → BLoC/Cubit → repository → data source.
- Language codes: `fr`, `en`, `rn`. Currency: FBu (integer amounts). Phone format: `+257XXXXXXXX`.
- Timestamps: ISO 8601 UTC. IDs: UUID v4 strings.

## Status file (read by the inspector)

Keep `status/T<n>.md` up to date after every finished task:

```
# T<n> status
Current wave: <n>
## Done
- [x] <feature id> <what> — <how verified>
## In progress
- [ ] ...
## Blocked / requests to other terminals
- <who> — <what you need>
## Contract questions
- ...
```

## Gates

- **G0 Contracts:** T0 finishes Wave 0; `docker compose up` works offline; contracts frozen. Terminals T1–T4 start.
- **G1 Text demo:** T1 + T2 merged; all 6 request types work by chat in fr, en, rn; model auto-switch works.
- **G2 All merged:** voice, handoff, 4 channels, documents work together. Then Wave 7 (everyone).

At each gate the inspector reviews every branch: folder ownership, contract compliance, tests, offline run,
PRD acceptance criteria. Fix findings before moving to the next wave.
