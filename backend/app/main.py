"""Kabangutsi backend (FastAPI). REST under /v1, WebSocket /v1/ws — contracts/openapi.yaml.

Routers are auto-included: every module in app/api/ that defines `router` is mounted.
"""

from __future__ import annotations

import asyncio
import contextlib
import importlib
import logging
import pkgutil
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app import api, errors
from app.config import VERSION, get_settings
from app.db.session import dispose

log = logging.getLogger("kabangutsi")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    s = get_settings()
    tasks: list[asyncio.Task] = []
    if s.realtime_enabled:
        from app.realtime.hub import hub

        await hub.start()
    if s.embed_on_startup:
        with contextlib.suppress(ImportError):
            from app.rag.embed import fill_missing_embeddings_background

            tasks.append(asyncio.create_task(fill_missing_embeddings_background()))
    yield
    for t in tasks:
        t.cancel()
    if s.realtime_enabled:
        from app.realtime.hub import hub

        await hub.stop()
    await dispose()


def create_app() -> FastAPI:
    s = get_settings()
    app = FastAPI(title="Kabangutsi backend", version=VERSION, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware, allow_origins=s.cors_origins, allow_credentials=False, allow_methods=["*"], allow_headers=["*"]
    )
    errors.install(app)
    for mod in sorted(pkgutil.iter_modules(api.__path__), key=lambda m: m.name):
        m = importlib.import_module(f"app.api.{mod.name}")
        if hasattr(m, "router"):
            app.include_router(m.router)
    return app


app = create_app()
