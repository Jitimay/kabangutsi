"""F4 Product info, account opening and any other knowledge-base question (RAG).

Answers only from retrieved chunks. Nothing relevant → "I don't know" + handoff offer (state offer_handoff;
a "yes" next turn hands over with reason no_answer).
"""

from __future__ import annotations

from collections.abc import AsyncIterator

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core.responses import t
from app.core.types import HandlerResult, TurnContext
from app.rag.answer import answer_messages, extractive, numbers_ok
from app.rag.search import search


def _no_answer(res: HandlerResult, lang: str, question: str) -> None:
    res.fallback_text = t("dont_know", lang)
    res.state, res.expected_input, res.context = "offer_handoff", "confirmation", {"no_answer_q": question[:200]}


async def _guarded(stream: AsyncIterator[str], res: HandlerResult, lang: str, question: str) -> AsyncIterator[str]:
    """Swallows a NO_ANSWER reply (the passages do not answer the question): the result is switched to
    "I don't know" + handoff offer. Read by the orchestrator after the stream ends."""
    head: str | None = ""
    async for d in stream:
        if head is None:
            yield d
            continue
        head += d
        h = head.lstrip()
        if len(h) < 9 and "NO_ANSWER".startswith(h):
            continue  # could still become NO_ANSWER
        if h.startswith("NO_ANSWER"):
            _no_answer(res, lang, question)
            return
        out, head = head, None
        yield out


async def handle(ctx: TurnContext) -> HandlerResult:
    s = get_settings()
    lang = ctx.lang
    question = ctx.text
    topic = ctx.intent.entities.topic if ctx.intent and ctx.intent.entities.topic else None
    q = f"{question} {topic}" if topic and topic.lower() not in question.lower() else question
    intent = ctx.intent.intent if ctx.intent else None
    hits = await search(ctx.db, q, lang, k=s.rag_k, intent=intent)
    if not hits or not hits[0]["relevant"]:
        return HandlerResult(
            text=t("dont_know", lang),
            state="offer_handoff",
            expected_input="confirmation",
            context={"no_answer_q": question[:200]},
        )
    top = [h for h in hits if h["relevant"] and h["score"] >= hits[0]["score"] * 0.6][:3]
    sources = [h["text"] for h in top]
    fallback = extractive(question, top)
    data = {"sources": [h["id"] for h in top]}
    if ctx.model is None or lang not in s.rag_llm_langs:
        return HandlerResult(text=fallback, actions=[], context=data)
    try:
        stream = get_llm().chat_stream(
            ctx.model,
            answer_messages(question, top, lang),
            temperature=0.1,
            num_predict=180,
            think=False,
            timeout=s.llm_timeout_seconds,
        )
    except LLMError:
        return HandlerResult(text=fallback, context=data)
    res = HandlerResult(
        text="",
        sentence_ok=lambda sent: numbers_ok(sent, sources),
        fallback_text=fallback,
        model_used=ctx.model,
        context=data,
    )
    res.stream = _guarded(stream, res, lang, question)
    return res
