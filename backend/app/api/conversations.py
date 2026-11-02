"""Customer side: /v1/conversations (+ SSE streaming), /v1/files, /v1/models."""

from __future__ import annotations

import asyncio
import json
import logging
from collections.abc import AsyncIterator
from typing import Any

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse, Response, StreamingResponse
from pydantic import ValidationError
from starlette.datastructures import UploadFile

from app.api.deps import require_uuid
from app.config import get_settings
from app.core import orchestrator
from app.core.model_router import registry
from app.db import repo
from app.db.session import db_session
from app.errors import ApiError, error_body
from app.files import MAX_BYTES, attachment_of, kind_of, load_file, store_file
from app.schemas.api import ConversationCreate, ConversationUpdate, HandoffBody, MessageJson

log = logging.getLogger(__name__)
router = APIRouter(prefix="/v1")


def _validation(e: ValidationError) -> ApiError:
    err = e.errors()[0]
    return ApiError(422, "validation_error", err["msg"], {"field": ".".join(str(x) for x in err["loc"])})


async def _body(request: Request, model: Any, default: dict | None = None) -> Any:
    try:
        raw = await request.body()
        data = json.loads(raw) if raw else (default if default is not None else {})
    except json.JSONDecodeError as e:
        raise ApiError(422, "validation_error", "Body is not valid JSON") from e
    try:
        return model.model_validate(data)
    except ValidationError as e:
        raise _validation(e) from e


# ---------------------------------------------------------------- models


@router.get("/models", tags=["models"])
async def list_models(refresh: bool = False) -> dict:
    s = get_settings()
    try:
        models = await registry.list(refresh=refresh)
        default = await registry.default_model()
    except Exception as e:  # noqa: BLE001
        raise ApiError(503, "service_unavailable", "Ollama is not reachable") from e
    return {
        "default_model": default,
        "preference_order": s.model_preference,
        "models": [m.to_api(default) for m in sorted(models, key=lambda m: m.name)],
    }


# ---------------------------------------------------------------- conversations


@router.post("/conversations", status_code=201, tags=["conversations"])
async def create_conversation(request: Request) -> dict:
    b = await _body(request, ConversationCreate)
    return await orchestrator.create_conversation(b.channel, b.phone, b.lang, b.model)


@router.get("/conversations/{conversation_id}", tags=["conversations"])
async def get_conversation(conversation_id: str) -> dict:
    require_uuid(conversation_id, "Conversation")
    async with db_session() as db:
        d = await repo.call_detail(db, conversation_id)
    if d is None:
        raise ApiError(404, "not_found", "Conversation not found")
    return d


@router.patch("/conversations/{conversation_id}", tags=["conversations"])
async def update_conversation(conversation_id: str, request: Request) -> dict:
    require_uuid(conversation_id, "Conversation")
    b = await _body(request, ConversationUpdate)
    return await orchestrator.update_conversation(conversation_id, b.model, b.lang)


async def _upload(db: Any, f: UploadFile, expect: str, call_id: str) -> dict[str, Any]:
    mime = (f.content_type or "").split(";")[0].strip().lower()
    kind = kind_of(mime)
    if kind != expect:
        raise ApiError(415, "unsupported_media_type", f"Unsupported {expect} type: {mime or 'unknown'}")
    data = await f.read(MAX_BYTES[kind] + 1)
    if len(data) > MAX_BYTES[kind]:
        raise ApiError(413, "too_large", f"{expect} larger than {MAX_BYTES[kind] // (1024 * 1024)} MB")
    ref = await store_file(db, data, mime, call_id)
    return attachment_of(ref, name=f.filename or None)


@router.post("/conversations/{conversation_id}/messages", tags=["conversations"], response_model=None)
async def send_message(conversation_id: str, request: Request) -> Response | dict:
    require_uuid(conversation_id, "Conversation")
    async with db_session() as db:
        call = await repo.get_call(db, conversation_id)
        if call is None:
            raise ApiError(404, "not_found", "Conversation not found")
        ctype = request.headers.get("content-type", "")
        if ctype.startswith("multipart/form-data"):
            form = await request.form()
            atts = []
            for field, kind in (("image", "image"), ("audio", "audio")):
                f = form.get(field)
                if isinstance(f, UploadFile):
                    atts.append(await _upload(db, f, kind, conversation_id))
            text_ = form.get("text")
            lang = form.get("lang") or None
            if lang not in (None, "fr", "en", "rn"):
                raise ApiError(422, "validation_error", "lang must be fr, en or rn", {"field": "lang"})
            if isinstance(text_, str) and len(text_) > 4000:
                raise ApiError(422, "validation_error", "text is too long", {"field": "text"})
            inp = orchestrator.TurnInput(
                text=text_ if isinstance(text_, str) else "",
                lang_hint=lang,
                model_override=(form.get("model") or None),
                voice=str(form.get("voice", "false")).lower() in ("1", "true", "yes", "on"),
                attachments=atts,
            )
            await db.commit()
        else:
            b = await _body(request, MessageJson)
            inp = orchestrator.TurnInput(
                text=b.text or "",
                lang_hint=b.lang,
                model_override=b.model,
                voice=b.voice,
                attachments=[a.dump() for a in b.attachments],
            )
    if not inp.text.strip() and not inp.attachments:
        raise ApiError(422, "validation_error", "text, image, audio or attachments is required", {"field": "text"})
    if inp.model_override:
        inp.model_override = await orchestrator.check_model(inp.model_override)

    if "text/event-stream" in request.headers.get("accept", ""):
        return StreamingResponse(
            _sse(conversation_id, inp),
            media_type="text/event-stream",
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )
    out = await orchestrator.handle_turn(conversation_id, inp)
    if out.status == 409:
        return JSONResponse(error_body("conflict", out.conflict_message or "Conflict", {"reply": out.reply}), 409)
    return out.reply


def _sse_line(name: str, data: Any) -> bytes:
    return f"event: {name}\ndata: {json.dumps(data, ensure_ascii=False, separators=(',', ':'))}\n\n".encode()


async def _sse(conversation_id: str, inp: orchestrator.TurnInput) -> AsyncIterator[bytes]:
    q: asyncio.Queue[tuple[str, Any] | None] = asyncio.Queue()

    async def sink(name: str, data: dict[str, Any]) -> None:
        await q.put((name, data))

    async def run() -> None:
        try:
            out = await orchestrator.handle_turn(conversation_id, inp, sink)
            if out.status == 409:
                await q.put(("error", error_body("conflict", out.conflict_message or "Conflict", {"reply": out.reply})))
        except ApiError as e:
            await q.put(("error", error_body(e.code, e.message, e.details)))
        except Exception:  # noqa: BLE001
            log.exception("stream failed")
            await q.put(("error", error_body("internal_error", "Internal error")))
        finally:
            await q.put(None)

    task = asyncio.create_task(run())
    try:
        while True:
            item = await q.get()
            if item is None:
                break
            yield _sse_line(*item)
    finally:
        if not task.done():
            # client went away: let the turn finish (it is stored and replayed), just stop streaming
            pass


@router.post("/conversations/{conversation_id}/handoff", tags=["conversations"])
async def request_handoff(conversation_id: str, request: Request) -> dict:
    require_uuid(conversation_id, "Conversation")
    b = await _body(request, HandoffBody, default={})
    return await orchestrator.request_handoff(conversation_id, b.reason)


@router.post("/conversations/{conversation_id}/end", tags=["conversations"])
async def end_conversation(conversation_id: str) -> dict:
    from app.agents.queue import end_call

    require_uuid(conversation_id, "Conversation")
    async with db_session() as db:
        call = await end_call(db, conversation_id)
        await db.commit()
    return call


# ---------------------------------------------------------------- files


@router.post("/files", status_code=201, tags=["files"])
async def upload_file(request: Request) -> dict:
    if not request.headers.get("content-type", "").startswith("multipart/form-data"):
        raise ApiError(
            422, "validation_error", "multipart/form-data with a `file` field is required", {"field": "file"}
        )
    form = await request.form()
    f = form.get("file")
    if not isinstance(f, UploadFile):
        raise ApiError(422, "validation_error", "file is required", {"field": "file"})
    mime = (f.content_type or "").split(";")[0].strip().lower()
    kind = kind_of(mime)
    if kind is None:
        raise ApiError(415, "unsupported_media_type", f"Unsupported type: {mime or 'unknown'}")
    data = await f.read(MAX_BYTES[kind] + 1)
    if len(data) > MAX_BYTES[kind]:
        raise ApiError(413, "too_large", "File too large")
    async with db_session() as db:
        ref = await store_file(db, data, mime)
        await db.commit()
    return ref


@router.get("/files/{file_id}", tags=["files"])
async def get_file(file_id: str) -> Response:
    require_uuid(file_id, "File")
    async with db_session() as db:
        got = await load_file(db, file_id)
    if got is None:
        raise ApiError(404, "not_found", "File not found")
    data, mime = got
    return Response(content=data, media_type=mime)
