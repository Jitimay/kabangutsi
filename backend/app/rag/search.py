"""Hybrid knowledge-base search (F4): pgvector cosine + full-text (`simple` config) + pg_trgm.

score = 0.5·vector + 0.3·fts + 0.2·trigram (+0.1 when the article's intent matches the detected intent), for ranking.
Without embeddings (Ollama down, or not filled yet) the vector part is 0 and the weights are rescaled.

`relevant` (used for "I don't know"): lexical score (0.6·fts + 0.4·trigram) ≥ RAG_MIN_SCORE, or cosine
similarity ≥ RAG_MIN_VECTOR. Measured on the seed KB without vectors: on-topic questions score ≥ 0.31 in
fr/en/rn, off-topic ones (weather, football, bitcoin) ≤ 0.21.
"""

from __future__ import annotations

import logging
import re
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core.keywords import fold

log = logging.getLogger(__name__)

STOP = {
    "fr": set(
        "le la les de des du un une et ou je j vous votre vos mon ma mes est pour que qui quoi quel quelle quels "
        "quelles comment a au aux en dans sur il elle ce c ca pas ne se sont voudrais veux faut faire avez ai "
        "bonjour s d l y etes es suis nom appelles appelez tu toi moi quand pourquoi dites dis".split()
    ),
    "en": set(
        "the a an and or i you your my is are to of for what which how in on do does can it me would like want "
        "need please hello be who whom whose when where why name this that there here am was were have has with "
        "about tell".split()
    ),
    "rn": set(
        "ni na ku mu kuri iki ico canke nka ndashaka nshaka mwaramutse amahoro murakoze ubu uyu ngo uri muri "
        "nde izina witwa mwitwa".split()
    ),
}


def query_terms(q: str, lang: str) -> list[str]:
    # letters and digits only (unicode, accents kept: the tsv column is not unaccented): safe in to_tsquery
    toks = re.findall(r"[^\W_]+", q.lower())
    stop = STOP.get(lang, set()) | STOP["fr"] | STOP["en"]
    return [w for w in toks if fold(w) not in stop and len(w) > 1][:12]


def vec_literal(v: list[float]) -> str:
    return "[" + ",".join(f"{x:.6f}" for x in v) + "]"


async def embed_query(q: str) -> list[float] | None:
    s = get_settings()
    try:
        return (await get_llm().embed(s.embed_model, [f"search_query: {q}"], timeout=10))[0]
    except (LLMError, IndexError, Exception) as e:  # noqa: BLE001 — search still works without vectors
        log.info("query embedding unavailable: %s", e)
        return None


async def search(
    db: AsyncSession, q: str, lang: str | None, k: int = 5, intent: str | None = None, use_vectors: bool = True
) -> list[dict[str, Any]]:
    s = get_settings()
    terms = query_terms(q, lang or "fr")
    tsq = " | ".join(terms) if terms else ""
    has_emb = bool(await db.scalar(text("SELECT EXISTS (SELECT 1 FROM kb_chunks WHERE embedding IS NOT NULL)")))
    qv = await embed_query(q) if (use_vectors and has_emb) else None
    w_vec, w_fts, w_trg = (0.5, 0.3, 0.2) if qv else (0.0, 0.6, 0.4)
    vec_expr = "(1 - (c.embedding <=> CAST(:qv AS vector)))" if qv else "0"
    # to_tsquery on terms joined by '|' (OR); terms are letters/digits only (no tsquery operators except '|')
    fts_expr = (
        "ts_rank(c.tsv, to_tsquery('simple', :tsq)) / (ts_rank(c.tsv, to_tsquery('simple', :tsq)) + 0.05)"
        if tsq
        else "0"
    )
    sql = f"""
        SELECT c.id, c.article_id, c.lang, a.title, c.text, a.intent, a.topic,
               COALESCE({vec_expr}, 0) AS s_vec,
               {fts_expr} AS s_fts,
               word_similarity(lower(unaccent(:q)), lower(unaccent(c.text))) AS s_trg
        FROM kb_chunks c JOIN kb_articles a ON a.id = c.article_id
        WHERE (CAST(:lang AS text) IS NULL OR c.lang = :lang)
    """  # noqa: S608 (fixed fragments; values are bound)
    params: dict[str, Any] = {"q": q[:500], "lang": lang, "tsq": tsq}
    if qv:
        params["qv"] = vec_literal(qv)
    rows = list(await db.execute(text(sql), params))
    hits = []
    for r in rows:
        vec, fts, trg = float(r.s_vec or 0), float(r.s_fts or 0), float(r.s_trg or 0)
        score = w_vec * vec + w_fts * fts + w_trg * trg
        if intent and r.intent == intent:
            score += 0.1
        lexical = 0.6 * fts + 0.4 * trg
        relevant = lexical >= s.rag_min_score or (qv is not None and vec >= s.rag_min_vector)
        hits.append(
            {
                "id": r.id,
                "article_id": r.article_id,
                "lang": r.lang,
                "title": r.title,
                "text": r.text,
                "score": round(score, 4),
                "relevant": relevant,
                "intent": r.intent,
                "topic": r.topic,
            }
        )
    hits.sort(key=lambda h: h["score"], reverse=True)
    return hits[:k]


def kb_hit_out(h: dict[str, Any]) -> dict[str, Any]:
    return {k: h[k] for k in ("id", "article_id", "lang", "title", "text", "score")}
