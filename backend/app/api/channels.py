"""POST /v1/channels/{channel}/inbound (adapters → backend) and POST /v1/documents/extract (F17)."""

from __future__ import annotations

import logging
from typing import Any

from fastapi import APIRouter, Request
from starlette.datastructures import UploadFile

from app.agents import handoff
from app.api.conversations import _body
from app.clients import services
from app.core import orchestrator
from app.db import repo
from app.db.session import db_session
from app.errors import ApiError
from app.files import MAX_BYTES, kind_of
from app.schemas.api import InboundMessage

log = logging.getLogger(__name__)
router = APIRouter(prefix="/v1")
CHANNELS = ("phone", "ussd", "sms", "whatsapp", "web")

_ussd: Any = None


def ussd_adapter() -> Any:
    """T4's USSD menus (backend/channels). None when the package is not present (branch not merged yet)."""
    global _ussd
    if _ussd is None:
        try:
            from channels import UssdAdapter  # type: ignore[import-not-found]
        except ImportError:
            return None
        _ussd = UssdAdapter()
    return _ussd


async def _ask(m: Any) -> Any:
    """`ask` callable for the USSD adapter: InboundMessage (T4 Pydantic) → OutgoingReply (T4 Pydantic)."""
    from channels import OutgoingReply  # type: ignore[import-not-found]

    reply = await orchestrator.handle_inbound(m.dump())
    return OutgoingReply.model_validate(reply)


@router.post("/channels/{channel}/inbound", tags=["channels"])
async def channel_inbound(channel: str, request: Request) -> dict:
    if channel not in CHANNELS:
        raise ApiError(422, "validation_error", f"Unknown channel {channel}", {"field": "channel"})
    msg = await _body(request, InboundMessage)
    if msg.channel != channel:
        raise ApiError(422, "validation_error", "channel in the path and in the body differ", {"field": "channel"})
    data = msg.model_dump()
    data["attachments"] = [a.dump() for a in msg.attachments]
    if channel == "ussd" and (adapter := ussd_adapter()) is not None:
        from channels import InboundMessage as T4Inbound  # type: ignore[import-not-found]

        async with db_session() as db:
            call = await orchestrator.find_call_for_inbound(db, data)
            await db.commit()
        out = await adapter.handle(T4Inbound.model_validate(data), ask=_ask, conversation_id=call["id"])
        return out.model_dump() if hasattr(out, "model_dump") else out
    return await orchestrator.handle_inbound(data)


@router.post("/documents/extract", tags=["documents"])
async def extract_document(request: Request) -> dict:
    if not request.headers.get("content-type", "").startswith("multipart/form-data"):
        raise ApiError(
            422, "validation_error", "multipart/form-data with an `image` field is required", {"field": "image"}
        )
    form = await request.form()
    f = form.get("image")
    if not isinstance(f, UploadFile):
        raise ApiError(422, "validation_error", "image is required", {"field": "image"})
    mime = (f.content_type or "").split(";")[0].strip().lower()
    if kind_of(mime) != "image":
        raise ApiError(415, "unsupported_media_type", f"Unsupported image type: {mime or 'unknown'}")
    data = await f.read(MAX_BYTES["image"] + 1)
    if len(data) > MAX_BYTES["image"]:
        raise ApiError(413, "too_large", "Image larger than 10 MB")
    conv = form.get("conversation_id") or None
    lang = form.get("lang") or None
    try:
        res = await services.ocr_extract(data, mime, doc_type=form.get("doc_type") or None, lang=lang)
    except services.ServiceError as e:
        raise ApiError(503, "service_unavailable", "OCR service unavailable") from e
    if res.get("needs_review") and isinstance(conv, str):
        async with db_session() as db:
            if await repo.get_call(db, conv) is not None:
                try:
                    await handoff.queue_call(db, conv, "agent_review")
                    await db.commit()
                    handoff.after_commit(conv, "agent_review")
                except handoff.HandoffConflict:
                    pass
    return res
