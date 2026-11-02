"""F9 Handoff to a human agent, with an AI summary for the agent.

`queue_call` runs inside the turn's transaction: status → queued, code summary, urgency raised, and emits
`call.handoff_requested` + `stats.updated` (delivered on commit), so agents see the call at once.
`finish_handoff` runs after commit: AI summary on HARD_TASK_MODEL (time-boxed); when it arrives it replaces the
code summary on the call (GET /v1/calls/{id}). The event never waits for a model: in the G1 check a cold
gemma4:e4b on a busy machine delayed it by 55 s.
"""

from __future__ import annotations

import asyncio
import logging
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core.nlu import redact_for_llm
from app.core.responses import t
from app.db import repo
from app.db.session import db_session
from app.handlers.complaint import max_urgency, urgency_from_frustration
from app.realtime.events import emit
from app.util import MASK

log = logging.getLogger(__name__)
_tasks: set[asyncio.Task] = set()

LANG_NAME = {"fr": "French", "en": "English", "rn": "Kirundi"}


class HandoffConflict(Exception):
    def __init__(self, status: str) -> None:
        self.status = status


def code_summary(call: dict[str, Any], transcript: list[dict[str, Any]], reason: str, lang: str) -> str:
    said = [x["text"] for x in transcript if x["speaker"] == "customer" and x["text"] and x["text"] != MASK][-3:]
    words = " / ".join(redact_for_llm(s)[:160] for s in said) or "—"
    intent = t(f"intent_{call['last_intent']}", lang) if call.get("last_intent") else "—"
    return t(
        "summary_code",
        lang,
        reason=t(f"reason_{reason}", lang),
        intent=intent,
        call_lang=call["lang"],
        frustration=f"{call['frustration']:.1f}",
        said=words,
    )


async def ai_summary(transcript: list[dict[str, Any]], reason: str, lang: str) -> str | None:
    s = get_settings()
    lines = []
    for x in transcript[-16:]:
        txt = x["text"] if x["text"] == MASK else redact_for_llm(x["text"])
        lines.append(f"{x['speaker']}: {txt}")
    msgs = [
        {
            "role": "system",
            "content": (
                f"You write handoff notes for a bank call-center agent. In {LANG_NAME[lang]}, in at most 3 short sentences: "
                "what the customer wants, what was already done, what the agent should do next. Facts from the transcript "
                "only. Never write a PIN, a date of birth or an account number."
            ),
        },
        {"role": "user", "content": f"Handoff reason: {reason}\nTranscript:\n" + "\n".join(lines)},
    ]
    try:
        out = await asyncio.wait_for(
            get_llm().chat(
                s.hard_task_model,
                msgs,
                temperature=0.2,
                num_predict=160,
                think=False,
                timeout=s.handoff_summary_timeout,
            ),
            s.handoff_summary_timeout,
        )
    except (LLMError, TimeoutError) as e:
        log.info("AI summary unavailable (%s): code summary kept", e)
        return None
    out = " ".join(out.split())
    return redact_for_llm(out)[:800] or None


async def queue_call(db: AsyncSession, call_id: str, reason: str, frustration: float | None = None) -> dict[str, Any]:
    """Raises HandoffConflict when the call is already queued, with an agent, or ended."""
    row = await repo.get_call_row(db, call_id, lock=True)
    if row is None:
        raise LookupError(call_id)
    call = repo.call_out(row)
    if call["status"] != "active":
        raise HandoffConflict(call["status"])
    s = get_settings()
    urg = call["urgency"]
    f = max(call["frustration"], frustration or 0.0)
    if reason in ("frustration", "identity_failed"):
        urg = max_urgency(urg, "high")
    urg = max_urgency(urg, urgency_from_frustration(f), "medium" if reason == "customer_request" else None)
    transcript = await repo.get_transcript(db, call_id)
    summary = code_summary({**call, "frustration": f}, transcript, reason, s.agent_dashboard_lang)
    await db.execute(
        text("""UPDATE calls SET status = 'queued', queued_at = now(), handoff_reason = :r, urgency = :u,
                              frustration = :f, summary = :s WHERE id = :id"""),
        {"r": reason, "u": urg, "f": f, "s": summary, "id": call_id},
    )
    queued = await repo.get_call(db, call_id)
    await emit(
        db, "call.handoff_requested", {"call": queued, "reason": reason, "summary": summary, "transcript": transcript}
    )
    from app.agents.stats import emit_stats

    await emit_stats(db)
    return queued


async def finish_handoff(call_id: str, reason: str) -> None:
    """Replaces the code summary with the AI summary when the model answers in time (no event)."""
    s = get_settings()
    async with db_session() as db:
        transcript = await repo.get_transcript(db, call_id)
    summary = await ai_summary(transcript, reason, s.agent_dashboard_lang)
    if not summary:
        return
    async with db_session() as db:
        await db.execute(
            text("UPDATE calls SET summary = :s WHERE id = :id AND status IN ('queued', 'with_agent')"),
            {"s": summary, "id": call_id},
        )
        await db.commit()


def after_commit(call_id: str, reason: str) -> asyncio.Task | None:
    """Schedules finish_handoff. In background by default so the customer gets "please wait" at once."""
    task = asyncio.create_task(finish_handoff(call_id, reason))
    _tasks.add(task)
    task.add_done_callback(_tasks.discard)
    return task


async def drain() -> None:
    """Tests: wait for pending background handoffs."""
    while _tasks:
        await asyncio.gather(*list(_tasks), return_exceptions=True)
