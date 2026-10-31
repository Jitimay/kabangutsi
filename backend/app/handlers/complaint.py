"""F7 Complaints: ticket with category, urgency and summary; the ticket number is read back.
Ticket follow-up ("TCK-2026-00042?") reads the status from the database."""

from __future__ import annotations

import json
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core import keywords
from app.core.lang import tokens
from app.core.nlu import is_number_only, redact_for_llm
from app.core.responses import t
from app.core.types import HandlerResult, TurnContext
from app.db import repo
from app.realtime.events import emit
from app.util import new_id, now

URGENCY_RANK = {"low": 0, "medium": 1, "high": 2, "critical": 3}


def max_urgency(*vals: str | None) -> str:
    return max((v for v in vals if v), key=lambda v: URGENCY_RANK[v], default="low")


def urgency_from_frustration(f: float) -> str:
    s = get_settings()
    if f >= 0.9:
        return "critical"
    if f >= s.frustration_threshold:
        return "high"
    if f >= 0.4:
        return "medium"
    return "low"


def summarize(description: str, category: str) -> str:
    """Code summary (no model): category label + the customer's words, redacted and shortened."""
    d = " ".join(redact_for_llm(description).split())
    if len(d) > 220:
        d = d[:219].rstrip() + "…"
    return f"[{category}] {d}"


async def create_ticket(
    db: AsyncSession,
    *,
    category: str,
    urgency: str,
    description: str,
    lang: str,
    call_id: str | None = None,
    phone: str | None = None,
    attachments: list[dict[str, Any]] | None = None,
) -> dict[str, Any]:
    """Inserts the ticket and emits ticket.created (delivered on commit)."""
    customer_id = None
    if call_id:
        row = (await db.execute(text("SELECT phone, customer_id FROM calls WHERE id = :id"), {"id": call_id})).first()
        if row:
            phone = phone or row.phone
            customer_id = row.customer_id
    if customer_id is None and phone:
        customer_id = await db.scalar(text("SELECT id FROM customers WHERE phone = :p"), {"p": phone})
    seq = await db.scalar(text("SELECT nextval('ticket_number_seq')"))
    year = now().year
    number = f"TCK-{year}-{int(seq):05d}"
    # skip numbers already used by seeded demo tickets
    while await db.scalar(text("SELECT 1 FROM tickets WHERE number = :n"), {"n": number}):
        seq = await db.scalar(text("SELECT nextval('ticket_number_seq')"))
        number = f"TCK-{year}-{int(seq):05d}"
    tid = new_id()
    await db.execute(
        text("""INSERT INTO tickets (id, number, call_id, customer_id, phone, category, urgency, summary, description,
                                     lang, attachments)
                VALUES (:id, :n, :call, :cu, :ph, :cat, :urg, :sum, :desc, :lang, CAST(:att AS jsonb))"""),
        {
            "id": tid,
            "n": number,
            "call": call_id,
            "cu": customer_id,
            "ph": phone,
            "cat": category,
            "urg": urgency,
            "sum": summarize(description, category),
            "desc": description,
            "lang": lang,
            "att": json.dumps(attachments or []),
        },
    )
    ticket = await repo.get_ticket(db, tid)
    await emit(db, "ticket.created", ticket)
    return ticket


async def update_ticket(db: AsyncSession, ticket_id: str, changes: dict[str, Any]) -> dict[str, Any] | None:
    cur = await repo.get_ticket(db, ticket_id)
    if cur is None:
        return None
    sets, params = [], {"id": cur["id"]}
    for k in ("status", "urgency", "assigned_to"):
        if k in changes:
            sets.append(f"{k} = :{k}")
            params[k] = changes[k]
    if sets:
        await db.execute(text(f"UPDATE tickets SET {', '.join(sets)}, updated_at = now() WHERE id = :id"), params)  # noqa: S608
    ticket = await repo.get_ticket(db, cur["id"])
    await emit(db, "ticket.updated", ticket)
    return ticket


_TRIGGER_ONLY = 6  # fewer meaningful words than this → ask for details first


async def handle(ctx: TurnContext) -> HandlerResult:
    lang = ctx.lang
    ents = ctx.intent.entities if ctx.intent else None
    number = (ents.ticket_number if ents else None) or keywords.extract_entities(ctx.text).get("ticket_number")
    if number and ctx.state != "complaint.awaiting_details":
        tk = await repo.get_ticket(ctx.db, number)
        if tk is None:
            return HandlerResult(text=t("ticket_not_found", lang, number=number) + " " + t("ok_else", lang))
        return HandlerResult(
            text=t("ticket_status", lang, number=tk["number"], status=t(f"status_{tk['status']}", lang))
        )

    if ctx.state == "complaint.awaiting_details" and is_number_only(ctx.text):
        return HandlerResult(text=t("ask_complaint_details", lang), state=ctx.state, context=ctx.context)
    if ctx.state == "complaint.awaiting_details":
        description = f"{ctx.context.get('first', '')} {ctx.text}".strip()
        category = (
            ctx.context.get("category") or keywords.extract_entities(ctx.text).get("complaint_category") or "other"
        )
        urgency = max_urgency(
            ctx.context.get("urgency"), urgency_from_frustration(ctx.intent.frustration if ctx.intent else 0)
        )
    else:
        description = ctx.text
        category = (ents.complaint_category if ents else None) or "other"
        frus = ctx.intent.frustration if ctx.intent else 0.0
        urgency = max_urgency(ents.urgency if ents else None, urgency_from_frustration(frus))
        if len(tokens(ctx.text)) < _TRIGGER_ONLY:
            return HandlerResult(
                text=t("ask_complaint_details", lang),
                state="complaint.awaiting_details",
                context={"first": ctx.text, "category": None if category == "other" else category, "urgency": urgency},
            )
    tk = await create_ticket(
        ctx.db,
        category=category,
        urgency=urgency,
        description=description,
        lang=lang,
        call_id=ctx.call_id,
        phone=ctx.phone,
    )
    delay = t("delay_urgent" if URGENCY_RANK[urgency] >= 2 else "delay_normal", lang)
    return HandlerResult(
        text=t("ticket_created", lang, number=tk["number"], delay=delay),
        short_text=t("ticket_created_short", lang, number=tk["number"]),
        actions=[
            {
                "type": "ticket_created",
                "status": "done",
                "reference": tk["number"],
                "data": {"ticket_id": tk["id"], "category": category, "urgency": urgency},
            }
        ],
        state="idle",
        context={},
    )
