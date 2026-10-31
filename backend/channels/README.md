# backend/channels (T4)

Channel adapters imported by the backend. Pure Python + Pydantic: no database, no network.

| Module | What |
|---|---|
| `schema.py` | Pydantic models for `contracts/message.schema.json` (`InboundMessage`, `OutgoingReply`, `Attachment`, `Action`) |
| `base.py` | `ChannelAdapter`: `parse_inbound(raw) -> InboundMessage`, `format_outbound(reply) -> raw` |
| `ussd.py` | `UssdAdapter`: `*123#` session menus (1 Products, 2 Card, 3 Loans, 4 Complaint, 5 Branches, 6 Language) in fr/en/rn |
| `sms.py` | SMS rules: session = phone, reply = `short_text` as ≤160 GSM-7 chars |
| `whatsapp.py` | WhatsApp rules: full `text` + attachments (PDF → document) |
| `text.py` | `normalize_phone` (+257XXXXXXXX), GSM-7 conversion, truncation |

## How T1 mounts the USSD adapter

The Flutter simulator (T2) posts an `InboundMessage` (`channel: "ussd"`, `text` = raw menu input,
`""` for the first dial) to `POST /v1/channels/ussd/inbound`. In that handler:

```python
from channels import UssdAdapter

ussd = UssdAdapter()  # one per process: holds the in-memory USSD sessions (TTL 5 min)

async def channel_inbound(channel, msg):
    if channel == "ussd":
        conv_id = ...  # conversation for msg.session_id (open one if needed)
        return await ussd.handle(msg, ask=orchestrator.handle, conversation_id=conv_id)
    return await orchestrator.handle(msg)
```

- `ask` is the normal conversation pipeline (`InboundMessage -> OutgoingReply`), **not** this endpoint.
- Menu screens are built here (`speaker: "system"`, `model_used: null`). Menu choices that need an
  answer become a plain customer question in the session language (e.g. 5 → "Ngozi" →
  "Ishami rya Ngozi ryugurura ryari?") so the orchestrator answers from the knowledge base.
  No bank facts are hard-coded.
- While the reply's `expected_input` is `pin`, `date_of_birth`, `account_number` or `confirmation`,
  every input (even `0`) is forwarded raw; the adapter never logs input.
- Replies are fitted to one 182-character screen (`text`, else `short_text`), with a `0:Menu 00:Exit` footer.

SMS and WhatsApp traffic arrives from the `sms-gateway` and `whatsapp-bridge` services, which
apply the same rules as `sms.py` / `whatsapp.py` before posting `InboundMessage`s.

## Tests

```
cd backend && pytest channels/tests      # needs jsonschema + referencing (dev only)
```

Every reply is validated against `contracts/message.schema.json`. Kirundi strings in
`ussd_strings.py` are a draft: they need review by a native speaker.
