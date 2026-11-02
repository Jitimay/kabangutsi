"""Agent side: calls, queue, claim, agent messages, end (F9, F10), agents, stats (F12)."""

from __future__ import annotations

from fastapi import APIRouter, Query, Request
from sqlalchemy import text

from app.agents import queue, stats
from app.api.conversations import _body
from app.api.deps import require_uuid
from app.core import orchestrator
from app.db import repo
from app.db.session import db_session
from app.errors import ApiError
from app.schemas.api import AgentMessage, AgentRef, Channel, EndCall

router = APIRouter(prefix="/v1")


@router.get("/calls", tags=["calls"])
async def list_calls(
    status: str | None = Query(None, pattern="^(active|queued|with_agent|ended)$"),
    channel: Channel | None = None,
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> dict:
    conds, p = [], {"limit": limit, "offset": offset}
    if status:
        conds.append("c.status = :status")
        p["status"] = status
    if channel:
        conds.append("c.channel = :channel")
        p["channel"] = channel
    where = " WHERE " + " AND ".join(conds) if conds else ""
    async with db_session() as db:
        total = await db.scalar(text(f"SELECT count(*) FROM calls c{where}"), p)  # noqa: S608
        rows = await db.execute(
            text(
                f"SELECT {repo.CALL_COLS} FROM {repo.CALL_FROM}{where} "  # noqa: S608
                "ORDER BY c.started_at DESC LIMIT :limit OFFSET :offset"
            ),
            p,
        )
        return {"items": [repo.call_out(r) for r in rows], "total": int(total)}


@router.get("/calls/queue", tags=["calls"])
async def get_queue() -> dict:
    async with db_session() as db:
        return {"items": await queue.list_queue(db)}


@router.get("/calls/{call_id}", tags=["calls"])
async def get_call(call_id: str) -> dict:
    require_uuid(call_id, "Call")
    async with db_session() as db:
        d = await repo.call_detail(db, call_id)
    if d is None:
        raise ApiError(404, "not_found", "Call not found")
    return d


@router.post("/calls/{call_id}/claim", tags=["calls"])
async def claim_call(call_id: str, request: Request) -> dict:
    require_uuid(call_id, "Call")
    b = await _body(request, AgentRef)
    async with db_session() as db:
        d = await queue.claim(db, call_id, b.agent_id)
        await db.commit()
    return d


@router.post("/calls/{call_id}/messages", status_code=201, tags=["calls"])
async def send_agent_message(call_id: str, request: Request) -> dict:
    require_uuid(call_id, "Call")
    b = await _body(request, AgentMessage)
    return await orchestrator.agent_message(call_id, b.agent_id, b.text, b.voice)


@router.post("/calls/{call_id}/end", tags=["calls"])
async def end_call(call_id: str, request: Request) -> dict:
    require_uuid(call_id, "Call")
    b = await _body(request, EndCall)
    async with db_session() as db:
        call = await queue.end_call(db, call_id, resolved_by="agent", agent_id=b.agent_id, note=b.note)
        await db.commit()
    return call


@router.get("/agents", tags=["agents"])
async def list_agents() -> dict:
    async with db_session() as db:
        rows = await db.execute(text("SELECT id, name, languages, role FROM agents ORDER BY role, id"))
        return {"items": [{"id": r.id, "name": r.name, "languages": list(r.languages), "role": r.role} for r in rows]}


@router.get("/stats", tags=["stats"])
async def get_stats() -> dict:
    async with db_session() as db:
        return await stats.compute(db)
