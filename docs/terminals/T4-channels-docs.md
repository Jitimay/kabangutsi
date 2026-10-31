# T4 — Channels (USSD, SMS, WhatsApp) + Documents (OCR, PDF): Waves 5, 6

Read `CLAUDE.md` first.

## Before G0 — start now (tests only, no adapter code)
Record every result in `status/T4.md`; keep scripts in `sms/experiments/`, `whatsapp/experiments/`,
`ocr/experiments/`.
- **GSM modem:** plug it in, find the device (`/dev/ttyUSB*`), send and receive one SMS with gammu or AT
  commands. Note the modem model, SIM operator, any permission fix (`dialout` group).
- **WhatsApp bridge:** on the team hardware with a dedicated test SIM, receive and send one text and one
  image. Note the tool used and its limits.
- **OCR:** install PaddleOCR (and Tesseract as a backup), run it on 3 fictional documents (fake CNI,
  loan form, coffee receipt); record accuracy and time per image on this CPU. Make sure models can be
  downloaded ahead of time (no download at runtime).
- **PDF:** render one HTML template to PDF with WeasyPrint.

## After G0
Run `git merge main` in your worktree, read `contracts/message.schema.json`, `contracts/openapi.yaml`
(channel inbound) and `contracts/ocr_api.yaml`, then start Wave 5.

- Branch / worktree: `t4-channels` → `../kabangutsi-t4`
- You own: `backend/channels/`, `sms/`, `whatsapp/`, `ocr/` and `status/T4.md`
- Every adapter converts its channel to the **standard message** and posts it to the backend
  (`POST /v1/channels/{channel}/inbound`). Adapters **never** touch the database.

## Wave 5 — Channels

### `backend/channels/` (Python, imported by the backend app)
- `base.py`: `ChannelAdapter` interface — `parse_inbound(raw) -> Message`, `format_outbound(reply) -> raw`.
- `ussd.py`: session-based numbered menus (`*123#`): 1 Products, 2 Card, 3 Loans, 4 Complaint,
  5 Branches, 6 Language; free text where needed. Used by the Flutter USSD simulator (T2).
- `sms.py`, `whatsapp.py`: formatting rules (SMS replies ≤ 160 chars using `short_text`; WhatsApp can send
  images and PDFs).
- Coordinate with T1 on how the router mounts these (T1 owns `main.py`): request it in your status file.

| ID | Task | Done when |
|---|---|---|
| F14 | USSD adapter + menus in fr/en/rn | Simulator in the app answers all 6 request types |
| F15 | `sms/` service: GSM modem gateway (gammu-smsd or AT commands via pyserial), receives SMS → standard message → backend; sends replies | Real SMS from a phone gets a reply, with no internet |
| F16 | `whatsapp/` service: bridge on the team's hardware/number, text + image in, text + PDF out | Same question answered on WhatsApp |

Notes:
- The modem is passed into the container (`/dev/ttyUSB0`, Compose profile `hardware`). Test on day one;
  add the host user to the `dialout` group if needed.
- WhatsApp is the **only** part of the project that needs internet; say so in the README. Unofficial
  bridges can get a number banned: use a dedicated test SIM, never a personal number.
- Phone numbers normalised to `+257XXXXXXXX`.

## Wave 6 — Documents (`ocr/` service, FastAPI, port 8002, own Dockerfile)
| ID | Task | Done when |
|---|---|---|
| F17 | OCR pipeline: OpenCV preprocessing (crop, deskew, contrast) → PaddleOCR (or Tesseract `fra`/`eng`) → field extraction (regex + LLM via backend-agreed call or local rules) → validation | Photo → JSON fields with per-field confidence; below 0.8 flagged for agent review |
| F17 | Document registry: one YAML per type in `ocr/doc_types/` (fields, regex, validation, route_to). Start with `cni.yaml`, `loan_application.yaml`, `coffee_receipt.yaml`, `complaint_photo.yaml` | New type added without code changes |
| F18 | PDF generation (WeasyPrint, HTML templates in fr/en/rn): loan simulation, ticket receipt | PDF in the caller's language; sent on WhatsApp |
| — | Fake sample documents (clearly fictional) for each type in `ocr/samples/` for tests and the demo | |

Requirements:
- All OCR models downloaded at build time (PaddleOCR downloads on first run by default — prevent it).
- `ocr/tests/`: one sample per document type with expected fields.

## Done when
- [ ] Same question answered on phone (app), USSD, SMS and WhatsApp
- [ ] CNI / loan paper photo → fields with confidence; low confidence goes to agent review
- [ ] Loan simulation PDF generated in fr, en, rn and delivered by WhatsApp
- [ ] `ocr` and `sms-gateway` start offline from `docker compose up`
