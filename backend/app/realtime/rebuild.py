"""Rebuild a full event from a {"type","id","ref"} NOTIFY payload (payload was too large for NOTIFY)."""

from __future__ import annotations

from typing import Any

from sqlalchemy import text

from app.db import repo
from app.db.session import db_session


async def rebuild(small: dict[str, Any]) -> dict[str, Any] | None:
    table, _, rid = small["ref"].partition(":")
    t = small["type"]
    async with db_session() as db:
        data: dict[str, Any] | None = None
        if t == "call.handoff_requested":
            call = await repo.get_call(db, rid)
            if call:
                data = {
                    "call": call,
                    "reason": small.get("reason") or call["handoff_reason"] or "other",
                    "summary": call["summary"] or "",
                    "transcript": await repo.get_transcript(db, rid),
                }
        elif t == "call.claimed":
            call = await repo.get_call(db, rid)
            if call:
                data = {"call": call, "agent_id": small.get("agent_id"), "agent_name": small.get("agent_name")}
        elif table == "calls":
            data = await repo.get_call(db, rid)
        elif table == "call_turns" and t == "call.turn":
            data = await repo.get_turn(db, rid)
        elif table == "tickets":
            data = await repo.get_ticket(db, rid)
        elif table == "model_events":
            r = (await db.execute(text("SELECT * FROM model_events WHERE id = :id"), {"id": rid})).first()
            data = repo.model_event_out(r) if r else None
    if data is None:
        return None
    return {"type": t, "id": small["id"], "ts": small["ts"], "data": data}
