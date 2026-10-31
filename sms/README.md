# sms-gateway (T4, F15)

GSM modem ↔ backend. **Works with no internet**: SMS go over the GSM network only.

```
customer SMS → modem SIM → AT+CMGL (PDU) → InboundMessage → POST /v1/channels/sms/inbound
             ← AT+CMGS (PDU) ← short_text (≤160 GSM-7) ←────────────── OutgoingReply
backend push (agent reply) → POST /send (contracts/adapter_api.yaml) → SMS
```

## Hardware
SIM800A + Arduino Nano running `experiments/sim800_passthrough/` (USB serial, 9600 baud),
or any USB GSM dongle with AT commands. The Samsung phone cannot be used: its modem port
refuses AT commands (see `status/T4.md`). SIM800A is 2G only and needs its own 2 A supply.

## Behaviour
- PDU mode (not text mode): accents and multi-part SMS are handled in `app/pdu.py`, not by the modem.
- Multi-part SMS are re-assembled before posting (incomplete ones are posted after 2 min).
- An SMS is deleted from the SIM only once the backend answered. If the backend is down it is retried
  with the **same message id** (the backend deduplicates), and the customer gets one short trilingual
  "service unavailable" SMS.
- Operator/promo (alphanumeric) senders and non +257 numbers are ignored.
- At most `REPLIES_PER_MINUTE` replies per number (prevents loops with auto-responders).
- Message text is never logged; phone numbers are masked in logs.
- Replies use `short_text`, converted to GSM-7 (`ê`→`e`, `«»`→`"`) so one SMS holds 160 characters
  instead of 70. Rules shared with `backend/channels/sms.py` (`app/text.py` is a checked copy).

## Env
| Var | Default |
|---|---|
| `BACKEND_URL` | `http://backend:8000` |
| `MODEM_DEVICE` | `/dev/ttyUSB0` |
| `MODEM_BAUD` | `9600` (Nano passthrough; USB dongles ignore it) |
| `POLL_INTERVAL_S` | `3` |
| `REPLIES_PER_MINUTE` | `5` |

## Run / test
```
docker compose --profile hardware up -d sms-gateway
pip install -r requirements-dev.txt && pytest tests     # from sms/; uses a fake SIM800 on a pty
python experiments/at_probe.py /dev/ttyUSB0 --baud 9600  # check the real modem first
```
