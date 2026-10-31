# Contracts (frozen at G0)

These files let T1–T4 work in parallel without talking to each other. **Code must match them exactly.**
To change them, see `CHANGELOG.md`.

| File | What | Implemented by | Used by |
|---|---|---|---|
| `openapi.yaml` | Backend REST API `/v1` (OpenAPI 3.1), SSE stream format | T1 | T2 (app), T4 (adapters → `/v1/channels/{channel}/inbound`) |
| `ws_events.json` | WebSocket events on `/v1/ws`, plus the shared shapes `Call`, `Turn`, `Ticket`, `Stats`, `ModelSwitch`, `Suggestion` | T1 | T2 |
| `message.schema.json` | Standard `InboundMessage` and `OutgoingReply` (`short_text` ≤ 160), `Attachment`, `Lang`, `Channel`, `Phone` | T1, T4 | T2, T3 |
| `intent.schema.json` | JSON the LLM must return per customer turn | T1 | — |
| `voice_api.yaml` | Voice service `/stt`, `/tts`, `/voices`, `/health` (port 8001) | T3 | T1 |
| `ocr_api.yaml` | OCR + PDF service `/ocr/extract`, `/doc-types`, `/pdf/render`, `/health` (port 8002) | T4 | T1 |
| `adapter_api.yaml` | `/send` + `/health` on sms-gateway (8003) and whatsapp-bridge (8004), for messages pushed by the backend | T4 | T1 |
| `db_schema.sql` / `db_schema.md` | PostgreSQL schema → T1's first Alembic migration | T1 | everyone (read only) |
| `CHANGELOG.md` | Change log and change process | T0 | everyone |

## How the files reference each other

JSON Schema 2020-12 `$ref`s with relative paths:

- `openapi.yaml` → `message.schema.json#/$defs/…` and `ws_events.json#/$defs/…`
- `ws_events.json` → `message.schema.json#/$defs/…`
- `ocr_api.yaml` → `openapi.yaml#/components/schemas/LoanSimulation`, `ws_events.json#/$defs/Ticket`

Load them from the `contracts/` directory so the relative refs resolve. Check them with:

```
scripts/validate_contracts.py     # validates every file and every embedded example
```

## Key decisions

- **Conversation = call.** One id. Customer endpoints use `/v1/conversations/{id}`, agent endpoints `/v1/calls/{id}`.
- **Streaming:** `POST /v1/conversations/{id}/messages` with `Accept: text/event-stream` → SSE events
  `turn`, `model.switched`, `token`, `sentence` (with TTS `audio_url` when `voice=true`), `done`, `error`.
  Voice calls play the `sentence` audio in order. That is the sentence-by-sentence TTS pipeline.
- **Security:** PIN and date of birth go only to `POST /v1/cards/block`, or as a chat message when the previous
  reply had `expected_input: "pin" | "date_of_birth"`. The orchestrator then handles that message in code
  and never passes it to NLU. `intent.schema.json` forbids extra entity keys, so a model cannot return a PIN field.
- **Model capabilities** are read from Ollama `/api/show` at runtime (`GET /v1/models`). Never hard-coded.
- **All example data is fictional.**
