"""SMS formatting rules (used by the backend; the sms-gateway service applies the same rules).

- Inbound: one SMS (or the re-assembled parts of a long one) from a +257 number.
  session_id = phone, so the backend reuses the open conversation for that number.
- Outbound: one SMS of at most 160 GSM-7 characters, built from `short_text`.
  Characters outside GSM-7 (ê, ô, typographic quotes…) are converted, because a single one
  would switch the SMS to UCS-2 and cut it to 70 characters.
"""

from __future__ import annotations

from typing import Any, TypedDict

from .base import ChannelAdapter
from .schema import InboundMessage, Lang, OutgoingReply
from .text import fit_gsm7, normalize_phone


class SmsIn(TypedDict, total=False):
    sender: str          # any common phone format
    text: str
    received_at: str     # ISO 8601 UTC, optional
    lang: Lang | None


class SmsOut(TypedDict):
    to: str              # +257XXXXXXXX
    text: str            # GSM-7, <= 160 septets


class SmsAdapter(ChannelAdapter):
    channel = "sms"

    def parse_inbound(self, raw: SmsIn | dict[str, Any]) -> InboundMessage:
        phone = normalize_phone(raw.get("sender"))
        if phone is None:
            raise ValueError("sender is not a +257 phone number")
        kw: dict[str, Any] = {}
        if raw.get("received_at"):
            kw["ts"] = raw["received_at"]
        return InboundMessage(
            channel="sms", phone=phone, session_id=phone, lang=raw.get("lang"),
            text=(raw.get("text") or "").strip()[:4000], attachments=[], **kw,
        )

    def format_outbound(self, reply: OutgoingReply) -> SmsOut:
        if reply.phone is None:
            raise ValueError("reply has no phone number")
        return SmsOut(to=reply.phone, text=fit_gsm7(reply.short_text or reply.text, 160))
