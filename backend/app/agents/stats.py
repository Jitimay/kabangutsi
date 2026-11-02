"""F12 Supervisor stats for the current day (Africa/Bujumbura midnight → now)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.handlers.branch_info import local_now
from app.realtime.events import emit
from app.util import iso, now


async def compute(db: AsyncSession) -> dict[str, Any]:
    start = local_now().replace(hour=0, minute=0, second=0, microsecond=0)
    p = {"start": start}
    r = (
        await db.execute(
            text("""
        SELECT count(*) AS total,
               count(*) FILTER (WHERE resolved_by = 'ai') AS by_ai,
               count(*) FILTER (WHERE resolved_by = 'agent') AS by_agent,
               count(*) FILTER (WHERE status = 'active') AS active,
               COALESCE(avg(EXTRACT(EPOCH FROM (COALESCE(claimed_at, now()) - queued_at)))
                        FILTER (WHERE queued_at IS NOT NULL), 0) AS avg_wait
        FROM calls WHERE started_at >= :start"""),
            p,
        )
    ).first()
    queue_len = await db.scalar(text("SELECT count(*) FROM calls WHERE status = 'queued'"))
    open_tickets = await db.scalar(text("SELECT count(*) FROM tickets WHERE status IN ('open', 'in_progress')"))
    intents = await db.execute(
        text("""
        SELECT t.intent, count(*) AS n FROM call_turns t JOIN calls c ON c.id = t.call_id
        WHERE c.started_at >= :start AND t.speaker = 'customer' AND t.intent IS NOT NULL
        GROUP BY t.intent ORDER BY n DESC, t.intent LIMIT 8"""),
        p,
    )
    by_channel = {k: 0 for k in ("phone", "web", "ussd", "sms", "whatsapp")}
    for x in await db.execute(
        text("SELECT channel, count(*) AS n FROM calls WHERE started_at >= :start GROUP BY channel"), p
    ):
        by_channel[x.channel] = int(x.n)
    by_lang = {k: 0 for k in ("fr", "en", "rn")}
    for x in await db.execute(
        text("SELECT language, count(*) AS n FROM calls WHERE started_at >= :start GROUP BY language"), p
    ):
        by_lang[x.language] = int(x.n)
    ai, ag = int(r.by_ai), int(r.by_agent)
    return {
        "period_start": iso(start),
        "total_calls": int(r.total),
        "resolved_by_ai": ai,
        "resolved_by_agent": ag,
        "ai_resolution_rate": round(ai / (ai + ag), 4) if ai + ag else 0.0,
        "avg_wait_seconds": round(max(0.0, float(r.avg_wait)), 1),
        "queue_length": int(queue_len),
        "active_calls": int(r.active),
        "open_tickets": int(open_tickets),
        "top_intents": [{"intent": x.intent, "count": int(x.n)} for x in intents],
        "by_channel": by_channel,
        "by_lang": by_lang,
        "updated_at": iso(now()),
    }


async def emit_stats(db: AsyncSession) -> dict[str, Any]:
    st = await compute(db)
    await emit(db, "stats.updated", st)
    return st
