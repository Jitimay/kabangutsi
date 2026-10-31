"""Kabangutsi backend — PLACEHOLDER written by T0 for G0.

T1 owns this file after G0 and replaces it with the real app (contracts/openapi.yaml).
It only shows that the stack starts and can reach PostgreSQL and Ollama.
"""

from __future__ import annotations

import asyncio
import os
from datetime import UTC, datetime
from urllib.parse import urlparse

import httpx
from fastapi import FastAPI

app = FastAPI(title="Kabangutsi backend (placeholder)", version="0.0.1")

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+asyncpg://kabangutsi:kabangutsi_dev@postgres:5432/kabangutsi")


async def _postgres_ok() -> str:
    u = urlparse(DATABASE_URL.replace("+asyncpg", ""))
    try:
        _, writer = await asyncio.wait_for(asyncio.open_connection(u.hostname, u.port or 5432), timeout=2)
        writer.close()
        await writer.wait_closed()
        return "ok"
    except (OSError, TimeoutError):
        return "down"


async def _ollama_ok() -> str:
    try:
        async with httpx.AsyncClient(timeout=2) as client:
            r = await client.get(f"{OLLAMA_URL}/api/tags")
        return "ok" if r.status_code == 200 else "down"
    except httpx.HTTPError:
        return "down"


@app.get("/health")
@app.get("/v1/health")
async def health() -> dict:
    pg, ol = await asyncio.gather(_postgres_ok(), _ollama_ok())
    deps = {"postgres": pg, "ollama": ol, "voice": "disabled", "ocr": "disabled"}
    return {
        "status": "ok" if pg == ol == "ok" else "degraded",
        "version": "0.0.1-placeholder",
        "dependencies": deps,
        "ts": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }
