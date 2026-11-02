"""F10 Agent queue: list, claim (SELECT … FOR UPDATE SKIP LOCKED), agent messages, end of call."""

from __future__ import annotations

from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.db import repo
from app.errors import ApiError
from app.realtime.events import emit

URGENCY_ORDER = "CASE c.urgency WHEN 'critical' THEN 0 WHEN 'high' THEN 1 WHEN 'medium' THEN 2 ELSE 3 END"


async def list_queue(db: AsyncSession) -> list[dict[str, Any]]:
    rows = await db.execute(
        text(
            f"SELECT {repo.CALL_COLS} FROM {repo.CALL_FROM} WHERE c.status = 'queued' "  # noqa: S608
            f"ORDER BY {URGENCY_ORDER}, c.queued_at"
        )
    )
    return [repo.call_out(r) for r in rows]


async def claim(db: AsyncSession, call_id: str, agent_id: str) -> dict[str, Any]:
    """Exactly one of two concurrent claims wins: the loser either skips the locked row or sees status
    with_agent after the winner commits. Caller commits."""
    name = await repo.agent_name(db, agent_id)
    if name is None:
        raise ApiError(404, "not_found", "Agent not found")
    got = await db.scalar(
        text("SELECT id FROM calls WHERE id = :id AND status = 'queued' FOR UPDATE SKIP LOCKED"), {"id": call_id}
    )
    if got is None:
        call = await repo.get_call(db, call_id)
        if call is None:
            raise ApiError(404, "not_found", "Call not found")
        if call["status"] == "with_agent" and call["claimed_by"] == agent_id:
            return await repo.call_detail(db, call_id)  # idempotent re-claim by the same agent
        if call["status"] in ("with_agent", "queued"):
            by = call["claimed_by"]
            raise ApiError(
                409,
                "already_claimed",
                f"Call already claimed by {by}" if by else "Call is being claimed",
                {"claimed_by": by},
            )
        raise ApiError(409, "conflict", f"Call is {call['status']}, not queued", {"status": call["status"]})
    await db.execute(
        text("UPDATE calls SET status = 'with_agent', claimed_by = :a, claimed_at = now() WHERE id = :id"),
        {"a": agent_id, "id": call_id},
    )
    detail = await repo.call_detail(db, call_id)
    await emit(db, "call.claimed", {"call": detail["call"], "agent_id": agent_id, "agent_name": name})
    from app.agents.stats import emit_stats

    await emit_stats(db)
    return detail


async def end_call(
    db: AsyncSession,
    call_id: str,
    *,
    resolved_by: str | None = None,
    agent_id: str | None = None,
    note: str | None = None,
) -> dict[str, Any]:
    """resolved_by: agent (agent closes), else derived: ai if never queued, abandoned if hung up while queued,
    agent if a human had the call. Ending an ended call returns it unchanged."""
    row = await repo.get_call_row(db, call_id, lock=True)
    if row is None:
        raise ApiError(404, "not_found", "Call not found")
    call = repo.call_out(row)
    if agent_id is not None and call["claimed_by"] != agent_id:
        raise ApiError(403, "forbidden", "Not this agent's call")
    if call["status"] == "ended":
        return call
    if resolved_by is None:
        resolved_by = {"active": "ai", "queued": "abandoned", "with_agent": "agent"}[call["status"]]
    await db.execute(
        text("""UPDATE calls SET status = 'ended', ended_at = now(), resolved_by = :rb,
                              agent_note = COALESCE(:note, agent_note) WHERE id = :id"""),
        {"rb": resolved_by, "note": note, "id": call_id},
    )
    await db.execute(
        text("UPDATE sessions SET state = 'ended', updated_at = now() WHERE call_id = :id"), {"id": call_id}
    )
    call = await repo.get_call(db, call_id)
    await emit(db, "call.ended", call)
    from app.agents.stats import emit_stats

    await emit_stats(db)
    return call
