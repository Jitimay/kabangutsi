"""Row → contract shape (ws_events.json $defs) and the common queries. Plain SQL: the schema is the contract."""

from __future__ import annotations

import json
from datetime import datetime
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.util import iso, new_id, now

CALL_COLS = """
    c.id, c.phone, c.channel, c.session_key, c.language, c.status, c.resolved_by, c.model, c.last_intent,
    c.urgency, c.frustration, c.handoff_reason, c.summary, c.claimed_by, c.started_at, c.queued_at,
    c.claimed_at, c.ended_at, c.customer_id, cu.full_name AS customer_name
"""
CALL_FROM = "calls c LEFT JOIN customers cu ON cu.id = c.customer_id"


def _f(v: Any) -> float:
    return float(v) if v is not None else 0.0


def call_out(r: Any) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    wait = None
    if m["queued_at"] is not None:
        end: datetime = m["claimed_at"] or now()
        wait = max(0, int((end - m["queued_at"]).total_seconds()))
    return {
        "id": str(m["id"]),
        "phone": m["phone"],
        "customer_name": m["customer_name"],
        "channel": m["channel"],
        "lang": m["language"],
        "status": m["status"],
        "resolved_by": m["resolved_by"],
        "model": m["model"],
        "last_intent": m["last_intent"],
        "urgency": m["urgency"],
        "frustration": round(_f(m["frustration"]), 3),
        "handoff_reason": m["handoff_reason"],
        "summary": m["summary"],
        "claimed_by": m["claimed_by"],
        "started_at": iso(m["started_at"]),
        "queued_at": iso(m["queued_at"]),
        "claimed_at": iso(m["claimed_at"]),
        "ended_at": iso(m["ended_at"]),
        "wait_seconds": wait,
    }


def turn_out(r: Any) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    att = m["attachments"]
    if isinstance(att, str):
        att = json.loads(att)
    return {
        "id": str(m["id"]),
        "call_id": str(m["call_id"]),
        "speaker": m["speaker"],
        "agent_id": m["agent_id"],
        "text": m["text"],
        "lang": m["lang"],
        "intent": m["intent"],
        "confidence": None if m["confidence"] is None else round(float(m["confidence"]), 3),
        "frustration": None if m["frustration"] is None else round(float(m["frustration"]), 3),
        "attachments": att or [],
        "model_used": m["model_used"],
        "ts": iso(m["ts"]),
    }


def ticket_out(r: Any) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    att = m["attachments"]
    if isinstance(att, str):
        att = json.loads(att)
    return {
        "id": str(m["id"]),
        "number": m["number"],
        "call_id": str(m["call_id"]) if m["call_id"] else None,
        "phone": m["phone"],
        "customer_name": m["customer_name"],
        "category": m["category"],
        "urgency": m["urgency"],
        "summary": m["summary"],
        "status": m["status"],
        "lang": m["lang"],
        "assigned_to": m["assigned_to"],
        "attachments": att or [],
        "created_at": iso(m["created_at"]),
        "updated_at": iso(m["updated_at"]),
    }


def model_event_out(r: Any) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    return {
        "id": str(m["id"]),
        "call_id": str(m["call_id"]),
        "requested_model": m["requested_model"],
        "used_model": m["used_model"],
        "capability_needed": m["capability_needed"],
        "reason": m["reason"],
        "fallback_path": m["fallback_path"],
        "notice": m["notice"],
        "lang": m["lang"],
        "ts": iso(m["ts"]),
    }


TICKET_SELECT = (
    "SELECT t.*, cu.full_name AS customer_name FROM tickets t LEFT JOIN customers cu ON cu.id = t.customer_id"
)


async def get_call_row(db: AsyncSession, call_id: str, lock: bool = False) -> Any | None:
    if lock:
        # FOR UPDATE cannot apply to the nullable side of an outer join: lock calls only
        await db.execute(text("SELECT id FROM calls WHERE id = :id FOR UPDATE"), {"id": call_id})
    r = await db.execute(text(f"SELECT {CALL_COLS} FROM {CALL_FROM} WHERE c.id = :id"), {"id": call_id})  # noqa: S608 (fixed fragments)
    return r.first()


async def get_call(db: AsyncSession, call_id: str) -> dict[str, Any] | None:
    r = await get_call_row(db, call_id)
    return call_out(r) if r else None


async def get_transcript(db: AsyncSession, call_id: str) -> list[dict[str, Any]]:
    r = await db.execute(text("SELECT * FROM call_turns WHERE call_id = :id ORDER BY ts, id"), {"id": call_id})
    return [turn_out(x) for x in r]


async def get_turn(db: AsyncSession, turn_id: str) -> dict[str, Any] | None:
    r = (await db.execute(text("SELECT * FROM call_turns WHERE id = :id"), {"id": turn_id})).first()
    return turn_out(r) if r else None


async def get_ticket(db: AsyncSession, ticket_id_or_number: str) -> dict[str, Any] | None:
    from app.util import is_uuid

    if is_uuid(ticket_id_or_number):
        r = (await db.execute(text(f"{TICKET_SELECT} WHERE t.id = :v"), {"v": ticket_id_or_number})).first()
    else:
        r = (await db.execute(text(f"{TICKET_SELECT} WHERE t.number = :v"), {"v": ticket_id_or_number.upper()})).first()
    return ticket_out(r) if r else None


async def call_detail(db: AsyncSession, call_id: str) -> dict[str, Any] | None:
    call = await get_call(db, call_id)
    if call is None:
        return None
    tickets = [
        ticket_out(x)
        for x in await db.execute(text(f"{TICKET_SELECT} WHERE t.call_id = :id ORDER BY t.created_at"), {"id": call_id})
    ]
    events = [
        model_event_out(x)
        for x in await db.execute(text("SELECT * FROM model_events WHERE call_id = :id ORDER BY ts"), {"id": call_id})
    ]
    return {"call": call, "transcript": await get_transcript(db, call_id), "tickets": tickets, "model_events": events}


async def insert_turn(
    db: AsyncSession,
    *,
    call_id: str,
    speaker: str,
    text_: str,
    lang: str,
    message_id: str | None = None,
    agent_id: str | None = None,
    intent: str | None = None,
    confidence: float | None = None,
    frustration: float | None = None,
    attachments: list[dict] | None = None,
    model_used: str | None = None,
    reply_json: dict | None = None,
    turn_id: str | None = None,
) -> dict[str, Any]:
    tid = turn_id or new_id()
    r = await db.execute(
        text(
            """INSERT INTO call_turns (id, call_id, message_id, speaker, agent_id, text, lang, intent, confidence,
                   frustration, attachments, model_used, reply_json, ts)
               VALUES (:id, :call_id, :message_id, :speaker, :agent_id, :text, :lang, :intent, :confidence,
                   :frustration, CAST(:attachments AS jsonb), :model_used, CAST(:reply_json AS jsonb), clock_timestamp())
               RETURNING *"""
        ),
        {
            "id": tid,
            "call_id": call_id,
            "message_id": message_id,
            "speaker": speaker,
            "agent_id": agent_id,
            "text": text_,
            "lang": lang,
            "intent": intent,
            "confidence": confidence,
            "frustration": frustration,
            "attachments": json.dumps(attachments or []),
            "model_used": model_used,
            "reply_json": json.dumps(reply_json) if reply_json is not None else None,
        },
    )
    return turn_out(r.first())


async def agent_name(db: AsyncSession, agent_id: str) -> str | None:
    return (await db.execute(text("SELECT name FROM agents WHERE id = :id"), {"id": agent_id})).scalar()
