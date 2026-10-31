# T1 — Backend (FastAPI): Waves 1, 2, 4

Read `CLAUDE.md` and the contracts in `contracts/` first. Start only after **G0**.

- Branch / worktree: `t1-backend` → `../kabangutsi-t1`
- You own: `backend/` **except** `backend/channels/` (T4), plus `status/T1.md`
- You implement exactly `contracts/openapi.yaml`, `ws_events.json`, `intent.schema.json`, `message.schema.json`.

## Target structure
```
backend/app/
  main.py            # FastAPI app, routers, CORS, lifespan
  config.py          # pydantic-settings from .env
  db/                # SQLAlchemy models, session, alembic/
  core/
    orchestrator.py  # call/session state machine per phone/session
    nlu.py           # intent JSON from the LLM + keyword fallback (fr/en/rn)
    model_router.py  # model list, capabilities, auto-switch
    policy.py        # identity checks, confirmations, limits (no LLM)
    responses.py     # reply templates fr/en/rn, short_text for SMS
  rag/               # embeddings, pgvector + pg_trgm/full-text hybrid search
  handlers/          # product_info, account_opening, card_block, loan_info, complaint, branch_info
  agents/            # handoff, queue, agent assist, stats, frustration
  realtime/          # WebSocket hub + Postgres LISTEN/NOTIFY
  clients/           # voice and ocr HTTP clients (httpx)
backend/tests/
```

## Wave 1 — Text assistant core
| ID | Task | Done when |
|---|---|---|
| — | Alembic migration from `contracts/db_schema.md`; seed loader | `alembic upgrade head` + seed work on a fresh DB |
| F19 | `GET /v1/models`: installed Ollama models + capabilities read from Ollama `/api/show` (never hard-coded) | New model pulled → appears without restart (or on refresh) |
| F20 | Model router: detect needed capability (image → vision, audio → audio, else completion); switch if the chosen model lacks it; emit `model.switched` event + notice text; log to `model_events` | Image sent with `gemma:2b` selected → answered by a vision model with a notice |
| F21 | Fallback when no model fits: image → OCR service, audio → voice STT | Works with only `gemma:2b` installed |
| F2 | Language detection fr/en/rn (LLM + keyword heuristics) | Reply language = caller language, switches mid-conversation |
| F3 | Intent detection → JSON validated by Pydantic against `intent.schema.json`; retry once, then keyword fallback | Invalid model JSON never crashes a request |
| F4 | RAG over knowledge base: hybrid search (pgvector + pg_trgm/full-text `simple`); answer only from retrieved chunks; "I don't know" + handoff offer otherwise | No answer contains facts absent from the KB |
| F8 | Branch hours/contacts by town or province | "Ngozi branch hours?" answered in fr/en/rn |
| — | Streaming replies (SSE) for chat | First tokens arrive before the full reply |

## Wave 2 — Self-service actions
| ID | Task | Done when |
|---|---|---|
| F5 | Card block: identity check in code (account number + PIN or date of birth, PIN hashed with argon2), confirmation, block, reference number | PIN never reaches the LLM (test asserts it); card status changes in DB |
| F6 | Loan info + simulator: monthly payment from amount, rate, term (pure Python) | Matches a hand-computed annuity example |
| F7 | Complaint: ticket with category, urgency, summary; ticket number read back; `ticket.created` event | Ticket visible via API and WebSocket |
| — | Account opening requirements via RAG | Answered from KB in 3 languages |

**→ G1 with T2:** all 6 request types work by chat in fr, en, rn.

## Wave 4 — Agent side (API)
| ID | Task | Done when |
|---|---|---|
| F9 | Handoff on request, frustration ≥ threshold, or low confidence; AI summary of the call | Agent receives `call.handoff_requested` with summary + transcript |
| F10 | Queue: `GET /v1/calls/queue`, claim with `SELECT … FOR UPDATE SKIP LOCKED`; events over WebSocket | Two agents claiming at once never get the same call |
| F11 | Agent assist: suggested reply per caller turn during a human call (`agent.suggestion`) | Suggestion within 3 s |
| F12 | Stats: AI resolution rate, average wait, top intents (`stats.updated`) | Numbers update live |
| F13 | Frustration score per turn (in the intent JSON) raises urgency | Angry test utterances trigger handoff |
| — | Voice integration with T3 after G1: `clients/voice.py`, call flow audio → STT → orchestrator → TTS, sentence-by-sentence | Full voice turn works end to end |

## Rules specific to T1
- Only the backend writes to PostgreSQL. Adapters (T4) post to `/v1/channels/{channel}/inbound`.
- Keep prompts in `backend/app/core/prompts/` as files, per language, with few-shot examples.
- Tests in `backend/tests/` for: model router, intent validation fallback, card block security, loan math,
  queue locking. Run `pytest` before each status update.
- Keep answers short (2–3 sentences) for voice.
