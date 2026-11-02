"""HTTP clients for the other local services (contracts/voice_api.yaml, ocr_api.yaml, adapter_api.yaml).
All failures raise ServiceError; callers fall back (text only, no PDF, ...)."""

from __future__ import annotations

import logging
from typing import Any

import httpx

from app.config import get_settings

log = logging.getLogger(__name__)


class ServiceError(Exception):
    pass


async def _post(url: str, *, timeout: float | None = None, **kw: Any) -> httpx.Response:
    try:
        async with httpx.AsyncClient(timeout=timeout or get_settings().service_timeout) as c:
            r = await c.post(url, **kw)
    except httpx.HTTPError as e:
        raise ServiceError(f"{url}: {e!r}") from e
    if r.status_code >= 400:
        raise ServiceError(f"{url}: HTTP {r.status_code} {r.text[:200]}")
    return r


# ---------------------------------------------------------------- voice (T3)


async def stt(audio: bytes, mime: str, lang: str | None) -> dict[str, Any]:
    """SttResult: {text, lang, confidence, duration_ms, ...}. Sends the session language as hint when known
    (Whisper cannot detect Kirundi; the voice service routes rn to MMS by this hint)."""
    data = {"lang": lang} if lang else {}
    r = await _post(f"{get_settings().voice_url}/stt", files={"audio": ("audio", audio, mime)}, data=data)
    return r.json()


async def tts(text: str, lang: str) -> bytes:
    r = await _post(f"{get_settings().voice_url}/tts", json={"text": text[:600], "lang": lang, "voice": None})
    return r.content


# ---------------------------------------------------------------- ocr + pdf (T4)


async def ocr_extract(image: bytes, mime: str, doc_type: str | None = None, lang: str | None = None) -> dict[str, Any]:
    data = {k: v for k, v in (("doc_type", doc_type), ("lang", lang)) if v}
    r = await _post(
        f"{get_settings().ocr_url}/ocr/extract", files={"image": ("image", image, mime)}, data=data, timeout=60
    )
    return r.json()


async def render_pdf(template: str, lang: str, data: dict[str, Any]) -> bytes:
    r = await _post(f"{get_settings().ocr_url}/pdf/render", json={"template": template, "lang": lang, "data": data})
    if not r.headers.get("content-type", "").startswith("application/pdf"):
        raise ServiceError("pdf service did not return a PDF")
    return r.content


# ---------------------------------------------------------------- channel adapters (T4)


async def adapter_send(channel: str, reply: dict[str, Any]) -> bool:
    """Pushes a message the backend sends later (agent reply) to the SMS gateway / WhatsApp bridge."""
    s = get_settings()
    base = {"sms": s.sms_gateway_url, "whatsapp": s.whatsapp_bridge_url}.get(channel)
    if base is None or not reply.get("phone"):
        return False
    try:
        await _post(f"{base}/send", json=reply, timeout=15)
        return True
    except ServiceError as e:
        log.warning("push to %s failed: %s", channel, e)
        return False
