"""Fills kb_chunks.embedding (nomic-embed-text, 768 dims). The seed leaves it NULL; the backend fills it at
start-up in the background, retrying until Ollama answers. Search works without it (full-text + trigram)."""

from __future__ import annotations

import asyncio
import logging

from sqlalchemy import text

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.db.session import db_session
from app.rag.search import vec_literal

log = logging.getLogger(__name__)


async def fill_missing_embeddings(batch: int = 16) -> int:
    s = get_settings()
    done = 0
    while True:
        async with db_session() as db:
            rows = list(
                await db.execute(
                    text(
                        "SELECT c.id, a.title, c.text FROM kb_chunks c JOIN kb_articles a ON a.id = c.article_id "
                        "WHERE c.embedding IS NULL ORDER BY c.id LIMIT :n"
                    ),
                    {"n": batch},
                )
            )
            if not rows:
                return done
            vecs = await get_llm().embed(
                s.embed_model, [f"search_document: {r.title}. {r.text}" for r in rows], timeout=120
            )
            for r, v in zip(rows, vecs, strict=True):
                if len(v) != 768:
                    raise LLMError(f"embedding size {len(v)} != 768 (model {s.embed_model})")
                await db.execute(
                    text("UPDATE kb_chunks SET embedding = CAST(:v AS vector) WHERE id = :id"),
                    {"v": vec_literal(v), "id": r.id},
                )
            await db.commit()
            done += len(rows)


async def fill_missing_embeddings_background() -> None:
    delay = 5.0
    while True:
        try:
            n = await fill_missing_embeddings()
            if n:
                log.info("embedded %d knowledge-base chunks", n)
            return
        except asyncio.CancelledError:
            raise
        except Exception as e:  # noqa: BLE001 — Ollama or DB not ready yet: retry
            log.info("embedding not possible yet (%s); retry in %.0fs", e, delay)
            await asyncio.sleep(delay)
            delay = min(delay * 2, 120)
