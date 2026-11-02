# WhatsApp bridge (T4, F16)

The bridge connects WhatsApp to the Kabangutsi backend. It listens on port 8004 and implements
`contracts/adapter_api.yaml`.

> ⚠️ **This is the only part of Kabangutsi that needs the internet.** WhatsApp messages travel
> through WhatsApp's servers. Every other service runs offline.

## Tool used and its risks

- **[Baileys](https://github.com/WhiskeySockets/Baileys) `@whiskeysockets/baileys@7.0.0-rc14`**
  links to WhatsApp as a "linked device" over WebSocket, like WhatsApp Web. It runs without a browser
  or Chromium.
- It is **unofficial**: it is not the WhatsApp Business API, and WhatsApp can **ban the number** it uses.
  - **Only use a dedicated test SIM/number. Never link a personal number.**
  - Keep the volume low (demo traffic only), don't bulk-message, and only message people who wrote first.

## Message flow

**Customer → backend.** For each customer message:
1. Ignore the message if it is our own, a group message, a status/broadcast, or from a non-`+257` number.
2. Mark the message as read and show "typing…".
3. Text comes from a plain message, an extended text or an image caption.
4. Images and voice notes are downloaded, then uploaded with `POST {BACKEND_URL}/v1/files`. They
   become attachments with `/v1/files/{id}` URLs (max 10 MB).
5. The message becomes an `InboundMessage` with `channel: whatsapp`, `session_id` set to the phone
   and `lang: null`. It is posted to `POST {BACKEND_URL}/v1/channels/whatsapp/inbound`.
6. The bridge sends back the reply's `text` (max 4096 characters; any `model_notice` is appended
   in _italics_). It then fetches each attachment from the backend and sends it:
   - PDF as a document
   - image as an image
   - audio as an audio file (as a voice note only when the audio is ogg/opus)
7. If the backend fails, the customer gets a short "service unavailable" message in fr/en/rn
   (the Kirundi text is a draft that needs review).

**Backend → customer.** `POST /send` takes an `OutgoingReply` (for example, an agent reply) and delivers it:
- `202 {status: "sent", message_id}` when delivered
- `422` when `phone` is null or the body is invalid
- `503` when WhatsApp is not connected

`GET /health` returns `{status: ok|degraded, connected, detail}`.

The same formatting rules are in `backend/channels/whatsapp.py`.

**Privacy:** message text is never logged, because it may contain a PIN. Logs show only ids and
masked phone numbers (`+2577900**01`).

## Linking the test number

1. `docker compose --profile whatsapp up -d whatsapp-bridge`
2. `docker compose logs -f whatsapp-bridge`: a QR code is printed.
3. On the **dedicated test phone**, open WhatsApp → *Linked devices* → *Link a device* and scan the
   QR code. The QR code refreshes about every 20 s, so scan the newest one.
4. The `whatsapp-session` volume keeps the session. If the logs say *logged out*, remove that volume
   and scan again.

## Limits

- No official API, so no service guarantee. WhatsApp protocol changes can break Baileys until it is
  updated (rebuild the image with a newer pinned version).
- The phone must come online at least every ~14 days, or the linked device is logged out.
- Rate limits and ban heuristics are unknown and not public, so keep traffic low.
- Media handled: images and voice notes in, and PDF/image/audio out. Stickers, videos, documents
  sent by customers, locations and contacts are ignored. Inbound media is limited to 10 MB.
- WhatsApp may identify a sender by a LID (`…@lid`) instead of a phone number. The bridge then reads
  the phone number from `remoteJidAlt`. If WhatsApp gives no phone number at all, the message is ignored.

## Environment

| Variable | Default | Meaning |
|---|---|---|
| `PORT` | `8004` | HTTP port |
| `BACKEND_URL` | `http://backend:8000` | Backend base URL (internal network) |
| `SESSION_DIR` | `/session` | Baileys auth files (Docker volume `whatsapp-session`) |
| `LOG_LEVEL` | `info` | pino log level |

## Development

```
npm ci
npm test          # node:test, no network: fake socket + fake backend; validates against contracts/
npm start         # needs a reachable backend; prints a QR (only with the dedicated test number!)
```
