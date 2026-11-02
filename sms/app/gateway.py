"""Inbound loop: modem SIM storage -> InboundMessage -> backend -> reply SMS (F15).

- Polls the SIM (AT+CMGL) every POLL_INTERVAL_S; works with no internet at all.
- Multi-part SMS are re-assembled by (sender, reference) before posting.
- An SMS is deleted from the SIM only after the backend answered; on failure it is retried
  with the same InboundMessage id (the backend treats a duplicate id idempotently).
- Alphanumeric senders (operator promos) and non +257 numbers are ignored and deleted.
- Per-number reply rate limit, so an auto-responder cannot start an endless SMS loop.
- Message text is never logged (it can be a PIN or a date of birth).
"""

from __future__ import annotations

import logging
import threading
import time
import uuid
from collections import defaultdict, deque
from dataclasses import dataclass, field

import httpx

from .modem import Modem, ModemError, StoredSms
from .text import fit_gsm7, normalize_phone

log = logging.getLogger("sms.gateway")

UNAVAILABLE = "Service indisponible, réessayez plus tard. Service unavailable. Serivisi ntiboneka ubu."
PART_TIMEOUT_S = 120


def mask(phone: str) -> str:
    return phone[:6] + "***" + phone[-2:]


@dataclass
class _Pending:
    msg_id: str
    indexes: list[int]
    parts: dict[int, str]
    total: int
    first_seen: float = field(default_factory=time.monotonic)
    ts: str = ""


class RateLimiter:
    def __init__(self, per_minute: int):
        self.per_minute = per_minute
        self.sent: dict[str, deque[float]] = defaultdict(deque)

    def allow(self, phone: str) -> bool:
        now = time.monotonic()
        q = self.sent[phone]
        while q and now - q[0] > 60:
            q.popleft()
        if len(q) >= self.per_minute:
            return False
        q.append(now)
        return True


class Gateway:
    def __init__(self, modem: Modem, backend_url: str, poll_s: float = 3.0,
                 replies_per_minute: int = 5, client: httpx.Client | None = None):
        self.modem = modem
        self.backend_url = backend_url.rstrip("/")
        self.poll_s = poll_s
        self.client = client or httpx.Client(timeout=120)
        self.limiter = RateLimiter(replies_per_minute)
        self.ids: dict[tuple, str] = {}          # stable InboundMessage id per SMS (for retries)
        self.pending: dict[tuple, _Pending] = {}
        self.apologized: set[str] = set()         # msg ids already told "unavailable"
        self.stop = threading.Event()
        self.connected = False
        self.last_error = ""
        self.stats = {"received": 0, "replied": 0, "failed": 0}

    # ---- loop ----------------------------------------------------------------------
    def run_forever(self) -> None:
        while not self.stop.is_set():
            try:
                if self.modem.port is None:
                    self.modem.open()
                    log.info("modem %s open on %s", self.modem.model, self.modem.device)
                self.poll_once()
                self.connected = True
                self.last_error = ""
            except (ModemError, OSError) as e:
                self.connected = False
                self.last_error = str(e)
                log.warning("modem: %s", e)
                self.modem.close()
                self.stop.wait(10)
                continue
            self.stop.wait(self.poll_s)

    def poll_once(self) -> None:
        for s in self.modem.list_all():
            self._take(s)
        self._flush_ready()

    # ---- assembling ----------------------------------------------------------------
    def _take(self, s: StoredSms) -> None:
        sms = s.sms
        if sms is None or not sms.numeric or normalize_phone(sms.sender) is None:
            log.info("ignoring SMS #%d (undecodable, alphanumeric or non +257 sender)", s.index)
            self.modem.delete(s.index)
            return
        phone = normalize_phone(sms.sender)
        assert phone
        if sms.concat:
            ref, total, part = sms.concat
            key = (phone, "c", ref)
        else:
            total, part = 1, 1
            key = (phone, "s", s.index, s.pdu[-16:])
        p = self.pending.get(key)
        if p is None:
            p = self.pending[key] = _Pending(self.ids.setdefault(key, str(uuid.uuid4())), [], {}, total, ts=sms.ts)
        if s.index not in p.indexes:
            p.indexes.append(s.index)
        p.parts[part] = sms.text

    def _flush_ready(self) -> None:
        now = time.monotonic()
        for key, p in list(self.pending.items()):
            complete = len(p.parts) >= p.total
            if not complete and now - p.first_seen < PART_TIMEOUT_S:
                continue
            text = "".join(p.parts[i] for i in sorted(p.parts))
            if self._handle(key[0], p.msg_id, text, p.ts):
                for idx in p.indexes:
                    self.modem.delete(idx)
                del self.pending[key]
                self.ids.pop(key, None)

    # ---- backend -------------------------------------------------------------------
    def _handle(self, phone: str, msg_id: str, text: str, ts: str) -> bool:
        """Post to the backend and send the reply. True when the SMS can be deleted."""
        msg = {"id": msg_id, "channel": "sms", "phone": phone, "session_id": phone, "lang": None,
               "text": text.strip()[:4000], "attachments": [], "ts": ts}
        self.stats["received"] += 1
        try:
            r = self.client.post(f"{self.backend_url}/v1/channels/sms/inbound", json=msg)
            r.raise_for_status()
            reply = r.json()
        except (httpx.HTTPError, ValueError) as e:
            self.stats["failed"] += 1
            log.warning("backend failed for %s: %s", mask(phone), type(e).__name__)
            if isinstance(e, httpx.HTTPStatusError) and e.response.status_code == 422:
                return True  # will never be accepted: drop it
            if msg_id not in self.apologized:
                self.apologized.add(msg_id)
                self._reply(phone, UNAVAILABLE)
            return False
        self.apologized.discard(msg_id)
        out = reply.get("short_text") or reply.get("text") or ""
        if out:
            self._reply(phone, out)
        return True

    def _reply(self, phone: str, text: str) -> None:
        if not self.limiter.allow(phone):
            log.warning("rate limit: not replying to %s", mask(phone))
            return
        try:
            self.modem.send(phone, fit_gsm7(text, 160))
            self.stats["replied"] += 1
            log.info("replied to %s", mask(phone))
        except ModemError as e:
            log.warning("send to %s failed: %s", mask(phone), e)

    def send_outgoing(self, phone: str, text: str) -> int:
        """Backend-pushed message (POST /send). Not rate limited: an agent wrote it."""
        return self.modem.send(phone, fit_gsm7(text, 160))
