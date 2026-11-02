"""GET /v1/health (and /health for the compose health check)."""

from __future__ import annotations

import asyncio

import httpx
from fastapi import APIRouter
from sqlalchemy import text

from app.config import VERSION, get_settings
from app.db.session import db_session
from app.util import iso, now

router = APIRouter()


async def _pg() -> str:
    try:
        async with db_session() as db:
            await asyncio.wait_for(db.execute(text("SELECT 1")), 3)
        return "ok"
    except Exception:  # noqa: BLE001
        return "down"


async def _http(url: str) -> str:
    try:
        async with httpx.AsyncClient(timeout=2) as c:
            r = await c.get(url)
        return "ok" if r.status_code == 200 else "down"
    except httpx.HTTPError:
        return "down"


@router.get("/health", include_in_schema=False)
@router.get("/v1/health", tags=["system"])
async def health() -> dict:
    s = get_settings()
    pg, ol, vo, oc = await asyncio.gather(
        _pg(), _http(f"{s.ollama_url}/api/tags"), _http(f"{s.voice_url}/health"), _http(f"{s.ocr_url}/health")
    )
    deps = {"postgres": pg, "ollama": ol, "voice": vo, "ocr": oc}
    return {
        "status": "ok" if pg == ol == "ok" else "degraded",
        "version": VERSION,
        "dependencies": deps,
        "ts": iso(now()),
    }
