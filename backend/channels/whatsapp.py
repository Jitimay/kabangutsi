"""WhatsApp formatting rules (used by the backend; the whatsapp-bridge applies the same rules).

- Inbound: text and/or media (image, voice note) from a +257 number. The bridge uploads
  media to the backend (POST /v1/files) first, so attachments carry /v1/files/{id} URLs.
- Outbound: the full `text` (WhatsApp has no 160 limit; capped at 4096 to be safe),
  then every attachment (PDF as a document, image as an image, audio as a voice note).
"""

from __future__ import annotations

from typing import Any, TypedDict

from .base import ChannelAdapter
from .schema import Attachment, InboundMessage, Lang, OutgoingReply
from .text import normalize_phone, truncate

MAX_TEXT = 4096


class WaIn(TypedDict, total=False):
    sender: str                       # JID '25779000101@s.whatsapp.net' or phone
    text: str
    attachments: list[dict[str, Any]]  # Attachment dicts with backend URLs
    received_at: str
    lang: Lang | None


class WaFile(TypedDict):
    kind: str          # document | image | audio
    url: str           # backend-relative /v1/files/{id}
    mime: str
    name: str


class WaOut(TypedDict):
    to: str            # JID
    text: str
    files: list[WaFile]


def phone_to_jid(phone: str) -> str:
    return phone.lstrip("+") + "@s.whatsapp.net"


class WhatsAppAdapter(ChannelAdapter):
    channel = "whatsapp"

    def parse_inbound(self, raw: WaIn | dict[str, Any]) -> InboundMessage:
        phone = normalize_phone(raw.get("sender"))
        if phone is None:
            raise ValueError("sender is not a +257 phone number")
        atts = [Attachment(**a) for a in (raw.get("attachments") or [])][:5]
        text = (raw.get("text") or "").strip()[:4000]
        if not text and not atts:
            raise ValueError("empty message")
        kw: dict[str, Any] = {}
        if raw.get("received_at"):
            kw["ts"] = raw["received_at"]
        return InboundMessage(channel="whatsapp", phone=phone, session_id=phone,
                              lang=raw.get("lang"), text=text, attachments=atts, **kw)

    def format_outbound(self, reply: OutgoingReply) -> WaOut:
        if reply.phone is None:
            raise ValueError("reply has no phone number")
        text = reply.text
        if reply.model_notice:
            text = f"{text}\n\n_{reply.model_notice}_"
        files: list[WaFile] = []
        for i, a in enumerate(reply.attachments):
            kind = {"pdf": "document", "image": "image", "audio": "audio"}[a.type]
            ext = {"pdf": "pdf", "image": "jpg", "audio": "wav"}[a.type]
            files.append(WaFile(kind=kind, url=a.url, mime=a.mime,
                                name=a.name or f"kabangutsi_{i + 1}.{ext}"))
        return WaOut(to=phone_to_jid(reply.phone), text=truncate(text, MAX_TEXT), files=files)
