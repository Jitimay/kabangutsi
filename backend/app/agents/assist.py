"""F11 Agent assist: up to 3 suggested replies per customer turn during a human call (`agent.suggestion`).

Grounded on knowledge-base chunks. The LLM gets SUGGESTION_TIMEOUT (target: suggestion within 3 s); when it is
slower or down, the suggestions are the best KB sentences (extractive), which are always ready in time.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
import time
from typing import Any

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core.nlu import redact_for_llm
from app.core.responses import t
from app.db.session import db_session
from app.rag.answer import LANG_NAME, extractive, numbers_ok
from app.rag.search import search
from app.realtime.events import emit

log = logging.getLogger(__name__)
_tasks: set[asyncio.Task] = set()


async def _llm_suggestions(question: str, hits: list[dict[str, Any]], lang: str, model: str) -> list[dict[str, Any]]:
    s = get_settings()
    ctx = "\n".join(f"[{h['id']}] {h['text']}" for h in hits)
    msgs = [
        {
            "role": "system",
            "content": (
                f"Suggest up to 3 short replies (1-2 sentences each, in {LANG_NAME[lang]}) a bank agent could send to the "
                'customer. Use only facts from the PASSAGES. Return JSON: {"suggestions": [{"text": "...", "source": "<passage id>"}]}'
            ),
        },
        {"role": "user", "content": f"PASSAGES:\n{ctx}\n\nCUSTOMER: {redact_for_llm(question)}"},
    ]
    raw = await asyncio.wait_for(
        get_llm().chat(
            model, msgs, format="json", temperature=0.2, num_predict=200, think=False, timeout=s.suggestion_timeout
        ),
        s.suggestion_timeout,
    )
    data = json.loads(re.search(r"\{.*\}", raw, re.S).group(0))
    ids = {h["id"] for h in hits}
    sources = [h["text"] for h in hits]
    out = []
    for x in data.get("suggestions", [])[:3]:
        txt = str(x.get("text", "")).strip()
        if txt and numbers_ok(txt, sources):
            src = [x["source"]] if x.get("source") in ids else [hits[0]["id"]]
            out.append({"text": txt[:500], "lang": lang, "source_ids": src})
    return out


async def suggestions(call_id: str, turn_id: str, question: str, lang: str, model: str | None) -> dict[str, Any]:
    t0 = time.monotonic()
    async with db_session() as db:
        hits = await search(db, question, lang, k=3)
    hits = [h for h in hits if h["relevant"]]
    out: list[dict[str, Any]] = []
    if hits and model:
        try:
            out = await _llm_suggestions(question, hits, lang, model)
        except (LLMError, TimeoutError, ValueError, AttributeError, KeyError) as e:
            log.info("assist LLM unavailable (%s): extractive suggestions", e)
    if not out:
        seen = set()
        for h in hits:
            if h["article_id"] in seen:
                continue
            seen.add(h["article_id"])
            out.append(
                {
                    "text": extractive(question, [h], max_sentences=2, max_chars=280),
                    "lang": lang,
                    "source_ids": [h["id"]],
                }
            )
    if not out:
        out = [{"text": t("dont_know", lang), "lang": lang, "source_ids": []}]
    return {
        "call_id": call_id,
        "turn_id": turn_id,
        "suggestions": out[:3],
        "generated_ms": int((time.monotonic() - t0) * 1000),
    }


async def suggest_and_emit(call_id: str, turn_id: str, question: str, lang: str, model: str | None) -> None:
    try:
        sug = await suggestions(call_id, turn_id, question, lang, model)
        async with db_session() as db:
            await emit(db, "agent.suggestion", sug)
            await db.commit()
    except Exception:  # noqa: BLE001 — assist must never break the call
        log.exception("agent suggestion failed")


def schedule(call_id: str, turn_id: str, question: str, lang: str, model: str | None) -> None:
    task = asyncio.create_task(suggest_and_emit(call_id, turn_id, question, lang, model))
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)


async def drain() -> None:
    while _tasks:
        await asyncio.gather(*list(_tasks), return_exceptions=True)
