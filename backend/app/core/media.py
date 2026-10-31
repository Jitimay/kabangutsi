"""Attachments of a customer turn → text the NLU can read (F20, F21).

- Image: capability `vision`. The session model if it can see, else the first capable model of MODEL_PREFERENCE
  (logged in model_events, `model.switched` emitted, notice shown), else the OCR service (fallback_path ocr).
- Audio: capability `audio`, same switching, else the voice service STT (fallback_path stt). On live phone calls
  (STT_FIRST_CHANNELS) STT is used first for latency; that is not a model switch.
"""

from __future__ import annotations

import base64
import logging
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.clients import services
from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core.model_router import Route, route
from app.files import load_file
from app.realtime.events import emit
from app.util import iso, new_id, now

log = logging.getLogger(__name__)
Sink = Callable[[str, dict[str, Any]], Awaitable[None]]


@dataclass
class MediaResult:
    transcript: str | None = None  # audio → text (becomes the customer's words)
    image_text: str | None = None  # what the image shows (context for NLU / handlers)
    stt_lang: str | None = None
    notices: list[str] = field(default_factory=list)
    model_used: str | None = None
    problem: str | None = None  # template key when the media could not be used (audio_unclear, image_unreadable)
    ocr: dict[str, Any] | None = None


async def log_switch(db: AsyncSession, call_id: str, r: Route, lang: str, sink: Sink | None) -> dict[str, Any]:
    ev = {
        "id": new_id(),
        "call_id": call_id,
        "requested_model": r.requested,
        "used_model": r.model,
        "capability_needed": r.capability,
        "reason": r.reason,
        "fallback_path": r.fallback_path,
        "notice": r.notice or "",
        "lang": lang,
        "ts": iso(now()),
    }
    await db.execute(
        text("""INSERT INTO model_events (id, call_id, requested_model, used_model, capability_needed, reason,
                              fallback_path, notice, lang) VALUES (:id, :call_id, :requested_model, :used_model,
                              :capability_needed, :reason, :fallback_path, :notice, :lang)"""),
        ev,
    )
    await emit(db, "model.switched", ev)
    if sink:
        await sink("model.switched", ev)
    return ev


async def _llm_transcribe(model: str, audio: bytes) -> str:
    s = get_settings()
    msgs = [
        {
            "role": "user",
            "content": "Transcribe this audio exactly, in its own language. Reply with the transcript only.",
            "images": [base64.b64encode(audio).decode()],
        }
    ]
    out = await get_llm().chat(model, msgs, temperature=0, num_predict=200, think=False, timeout=s.audio_llm_timeout)
    return " ".join(out.split())


async def _llm_describe(model: str, image: bytes, question: str, lang: str) -> str:
    s = get_settings()
    lang_name = {"fr": "French", "en": "English", "rn": "Kirundi"}[lang]
    msgs = [
        {
            "role": "user",
            "content": (
                "A bank customer sent this image" + (f' with the message: "{question}"' if question else "") + ". "
                f"In {lang_name}, in at most 2 sentences, say what the image shows (document type, card, screen, receipt, ATM...) "
                "and copy any visible error message or amount. Do not copy ID numbers, account numbers or PINs."
            ),
            "images": [base64.b64encode(image).decode()],
        }
    ]
    out = await get_llm().chat(model, msgs, temperature=0.1, num_predict=160, think=False, timeout=s.vision_timeout)
    return " ".join(out.split())


async def _stt(audio: bytes, mime: str, lang: str | None, res: MediaResult) -> bool:
    try:
        r = await services.stt(audio, mime, lang)
    except services.ServiceError as e:
        log.warning("STT failed: %s", e)
        return False
    if not (r.get("text") or "").strip() or float(r.get("confidence", 1)) < 0.4:
        res.problem = "audio_unclear"
        return True
    res.transcript = r["text"].strip()
    res.stt_lang = r.get("lang")
    return True


async def process(
    db: AsyncSession,
    *,
    call: dict[str, Any],
    attachments: list[dict[str, Any]],
    text_: str,
    lang: str,
    requested_model: str | None,
    sink: Sink | None,
) -> MediaResult:
    s = get_settings()
    res = MediaResult()
    audios, images = [], []
    for a in attachments:
        loaded = await load_file(db, a["url"]) if a.get("url", "").startswith("/v1/files/") else None
        if loaded is None:
            continue
        (audios if a["type"] == "audio" else images if a["type"] == "image" else []).append(loaded)

    if audios:
        data, mime = audios[0]
        hint = call["lang"] if call.get("lang") else None
        done = False
        if call["channel"] in s.stt_first_channels:
            done = await _stt(data, mime, hint, res)
        if not done:
            r = await route(requested_model, "audio", lang)
            if r.switched:
                await log_switch(db, call["id"], r, lang, sink)
                if r.notice:
                    res.notices.append(r.notice)
            if r.model:
                try:
                    res.transcript = await _llm_transcribe(r.model, data)
                    res.model_used = r.model
                    done = bool(res.transcript)
                except LLMError as e:
                    log.warning("audio model failed (%s): STT fallback", e)
            if not done:
                done = await _stt(data, mime, hint, res)
        if not done:
            res.problem = "audio_unclear"

    if images:
        data, mime = images[0]
        r = await route(requested_model, "vision", lang)
        if r.switched:
            await log_switch(db, call["id"], r, lang, sink)
            if r.notice:
                res.notices.append(r.notice)
        if r.model:
            try:
                res.image_text = await _llm_describe(r.model, data, text_ or (res.transcript or ""), lang)
                res.model_used = r.model
            except LLMError as e:
                log.warning("vision model failed (%s): OCR fallback", e)
        if not res.image_text:
            try:
                ocr = await services.ocr_extract(data, mime, lang=lang)
                res.ocr = ocr
                raw = " ".join((ocr.get("raw_text") or "").split())[:400]
                res.image_text = f"{ocr.get('doc_type', '')}: {raw}".strip(": ") or None
            except services.ServiceError as e:
                log.warning("OCR fallback failed: %s", e)
        if not res.image_text and not (text_ or res.transcript):
            res.problem = "image_unreadable"
    return res
