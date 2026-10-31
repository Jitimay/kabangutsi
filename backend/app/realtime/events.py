"""Event emission: after each write that maps to a WebSocket event, NOTIFY kabangutsi_events '<event json>'.

NOTIFY is transactional: the event is delivered when the surrounding transaction commits, so clients never
see an event for a write that was rolled back. Payloads above 7900 bytes are replaced by
{"type", "id", "ref": "<table>:<id>"} and the hub rebuilds the full event from the database.
"""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.util import iso, new_id, now

CHANNEL = "kabangutsi_events"
MAX_PAYLOAD = 7900


def make_event(type_: str, data: dict[str, Any]) -> dict[str, Any]:
    return {"type": type_, "id": new_id(), "ts": iso(now()), "data": data}


def ref_for(type_: str, data: dict[str, Any]) -> str:
    if type_ in ("call.started", "call.ended"):
        return f"calls:{data['id']}"
    if type_ in ("call.handoff_requested", "call.claimed"):
        return f"calls:{data['call']['id']}"
    if type_ == "call.turn":
        return f"call_turns:{data['id']}"
    if type_ in ("ticket.created", "ticket.updated"):
        return f"tickets:{data['id']}"
    if type_ == "model.switched":
        return f"model_events:{data['id']}"
    if type_ == "agent.suggestion":
        return f"call_turns:{data['turn_id']}"
    return "stats:today"


async def emit(db: AsyncSession, type_: str, data: dict[str, Any]) -> dict[str, Any]:
    ev = make_event(type_, data)
    payload = json.dumps(ev, ensure_ascii=False, separators=(",", ":"))
    if len(payload.encode()) > MAX_PAYLOAD:
        small = {"type": type_, "id": ev["id"], "ts": ev["ts"], "ref": ref_for(type_, data)}
        if type_ == "call.handoff_requested":
            small["reason"] = data.get("reason")
        if type_ == "call.claimed":
            small["agent_id"], small["agent_name"] = data.get("agent_id"), data.get("agent_name")
        payload = json.dumps(small)
    await db.execute(text("SELECT pg_notify(:ch, :p)"), {"ch": CHANNEL, "p": payload})
    return ev


def event_call_id(ev: dict[str, Any]) -> str | None:
    """Conversation the event belongs to (customer sockets only get their own)."""
    t, d = ev.get("type"), ev.get("data") or {}
    if t in ("call.started", "call.ended"):
        return d.get("id")
    if t in ("call.handoff_requested", "call.claimed"):
        return (d.get("call") or {}).get("id")
    if t in ("call.turn", "model.switched", "agent.suggestion"):
        return d.get("call_id")
    return None


CUSTOMER_EVENTS = {"call.turn", "call.handoff_requested", "call.claimed", "call.ended", "model.switched"}
