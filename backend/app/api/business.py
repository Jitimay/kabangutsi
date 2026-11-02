"""Self-service endpoints: cards (F5), loans (F6), tickets (F7), branches (F8), knowledge base search."""

from __future__ import annotations

import logging

from fastapi import APIRouter, Query, Request
from fastapi.responses import JSONResponse, Response
from sqlalchemy import text

from app.agents import handoff
from app.api.conversations import _body
from app.api.deps import require_uuid
from app.clients import services
from app.core.responses import t
from app.db import repo
from app.db.session import db_session
from app.errors import ApiError, error_body
from app.files import store_file
from app.handlers import branch_info, card_block, complaint, loan_info
from app.rag.search import kb_hit_out, search
from app.schemas.api import (
    CardBlockRequest,
    Lang,
    LoanSimulationRequest,
    TicketCategory,
    TicketCreate,
    TicketStatus,
    TicketUpdate,
    Urgency,
)

log = logging.getLogger(__name__)
router = APIRouter(prefix="/v1")


# ---------------------------------------------------------------- cards


@router.post("/cards/block", tags=["cards"], response_model=None)
async def verify_card_block(request: Request) -> dict | JSONResponse:
    b = await _body(request, CardBlockRequest)
    lang = b.lang
    handed = False
    async with db_session() as db:
        if b.conversation_id and await repo.get_call(db, b.conversation_id) is None:
            raise ApiError(404, "not_found", "Conversation not found")
        try:
            cust = await card_block.verify_identity(
                db, b.account_number, pin=b.pin, dob=b.date_of_birth, call_id=b.conversation_id
            )
        except card_block.IdentityError as e:
            if e.locked and b.conversation_id:
                try:
                    await handoff.queue_call(db, b.conversation_id, "identity_failed")
                    handed = True
                except handoff.HandoffConflict:
                    pass
            await db.commit()  # failure counters must persist
            if handed:
                handoff.after_commit(b.conversation_id, "identity_failed")
            if e.locked:
                return JSONResponse(error_body("locked", t("identity_locked", lang), {"handoff": handed}), 423)
            return JSONResponse(
                error_body(
                    "identity_failed",
                    t("identity_failed", lang, left=e.attempts_left),
                    {"attempts_left": e.attempts_left},
                ),
                403,
            )
        cards = await card_block.active_cards(db, cust.id)
        if b.card_last4:
            cards = [c for c in cards if c.last4 == b.card_last4]
        if not cards:
            await db.commit()
            raise ApiError(404, "not_found", t("no_active_card", lang))
        if len(cards) > 1:
            await db.commit()
            raise ApiError(
                422,
                "validation_error",
                t("choose_card", lang, cards=", ".join(c.last4 for c in cards)),
                {"field": "card_last4", "cards": [c.last4 for c in cards]},
            )
        pend = await card_block.create_request(db, cards[0], b.conversation_id, b.reason, lang)
        await db.commit()
    return pend


@router.post("/cards/block/{confirmation_id}/confirm", tags=["cards"])
async def confirm_card_block(confirmation_id: str, lang: Lang | None = None) -> dict:
    require_uuid(confirmation_id, "Confirmation")
    async with db_session() as db:
        if lang is None:  # language of the conversation, else of the customer
            lang = (
                await db.scalar(
                    text("""SELECT COALESCE(ca.language, cu.language) FROM card_block_requests r
                                           JOIN cards c ON c.id = r.card_id JOIN customers cu ON cu.id = c.customer_id
                                           LEFT JOIN calls ca ON ca.id = r.call_id WHERE r.id = :id"""),
                    {"id": confirmation_id},
                )
                or "fr"
            )
        res = await card_block.confirm(db, confirmation_id, lang)
        await db.commit()
    return res


# ---------------------------------------------------------------- loans


@router.get("/loan-products", tags=["loans"])
async def list_loan_products(lang: Lang = "fr") -> dict:
    async with db_session() as db:
        return {"items": await loan_info.list_products(db, lang)}


@router.post("/loans/simulate", tags=["loans"])
async def simulate_loan(request: Request) -> dict:
    b = await _body(request, LoanSimulationRequest)
    async with db_session() as db:
        p = await loan_info.get_product(db, b.product_id, b.lang)
        if p is None:
            raise ApiError(404, "not_found", "Loan product not found")
        sim = loan_info.simulate(p, b.amount, b.term_months, b.lang)
        if b.pdf:
            try:
                pdf = await services.render_pdf("loan_simulation", b.lang, sim)
                sim["pdf"] = await store_file(db, pdf, "application/pdf", b.conversation_id)
                await db.commit()
            except services.ServiceError as e:
                log.warning("loan PDF not rendered: %s", e)
    return sim


# ---------------------------------------------------------------- tickets


@router.get("/tickets", tags=["tickets"])
async def list_tickets(
    status: TicketStatus | None = None,
    urgency: Urgency | None = None,
    category: TicketCategory | None = None,
    phone: str | None = Query(None, pattern=r"^\+257[0-9]{8}$"),
    limit: int = Query(50, ge=1, le=200),
    offset: int = Query(0, ge=0),
) -> dict:
    conds, p = [], {"limit": limit, "offset": offset}
    for k, v in (("status", status), ("urgency", urgency), ("category", category), ("phone", phone)):
        if v is not None:
            conds.append(f"t.{k} = :{k}")
            p[k] = v
    where = " WHERE " + " AND ".join(conds) if conds else ""
    async with db_session() as db:
        total = await db.scalar(text(f"SELECT count(*) FROM tickets t{where}"), p)  # noqa: S608
        rows = await db.execute(
            text(f"{repo.TICKET_SELECT}{where} ORDER BY t.created_at DESC LIMIT :limit OFFSET :offset"), p
        )  # noqa: S608
        return {"items": [repo.ticket_out(r) for r in rows], "total": int(total)}


@router.post("/tickets", status_code=201, tags=["tickets"])
async def create_ticket(request: Request) -> dict:
    b = await _body(request, TicketCreate)
    async with db_session() as db:
        if b.conversation_id and await repo.get_call(db, b.conversation_id) is None:
            raise ApiError(404, "not_found", "Conversation not found")
        tk = await complaint.create_ticket(
            db,
            category=b.category,
            urgency=b.urgency,
            description=b.description,
            lang=b.lang,
            call_id=b.conversation_id,
            phone=b.phone,
            attachments=[a.dump() for a in b.attachments],
        )
        from app.agents.stats import emit_stats

        await emit_stats(db)
        await db.commit()
    return tk


@router.get("/tickets/{ticket_id}", tags=["tickets"])
async def get_ticket(ticket_id: str) -> dict:
    async with db_session() as db:
        tk = await repo.get_ticket(db, ticket_id)
    if tk is None:
        raise ApiError(404, "not_found", "Ticket not found")
    return tk


@router.patch("/tickets/{ticket_id}", tags=["tickets"])
async def update_ticket(ticket_id: str, request: Request) -> dict:
    b = await _body(request, TicketUpdate)
    changes = b.model_dump(exclude_unset=True)
    async with db_session() as db:
        if changes.get("assigned_to") and await repo.agent_name(db, changes["assigned_to"]) is None:
            raise ApiError(422, "validation_error", "Unknown agent", {"field": "assigned_to"})
        tk = await complaint.update_ticket(db, ticket_id, changes)
        if tk is None:
            raise ApiError(404, "not_found", "Ticket not found")
        from app.agents.stats import emit_stats

        await emit_stats(db)
        await db.commit()
    return tk


@router.get("/tickets/{ticket_id}/receipt", tags=["tickets", "documents"])
async def ticket_receipt(ticket_id: str, lang: Lang | None = None) -> Response:
    async with db_session() as db:
        tk = await repo.get_ticket(db, ticket_id)
    if tk is None:
        raise ApiError(404, "not_found", "Ticket not found")
    try:
        pdf = await services.render_pdf("ticket_receipt", lang or tk["lang"], tk)
    except services.ServiceError as e:
        raise ApiError(503, "service_unavailable", "PDF service unavailable") from e
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": f'inline; filename="{tk["number"]}.pdf"'},
    )


# ---------------------------------------------------------------- branches + knowledge base


@router.get("/branches", tags=["branches"])
async def list_branches(
    province: str | None = None, town: str | None = None, q: str | None = None, lang: Lang = "fr"
) -> dict:
    async with db_session() as db:
        return {"items": await branch_info.search_branches(db, province=province, town=town, q=q, lang=lang)}


@router.get("/kb/search", tags=["knowledge"])
async def kb_search(
    q: str = Query(..., min_length=2), lang: Lang | None = None, k: int = Query(5, ge=1, le=20)
) -> dict:
    async with db_session() as db:
        return {"items": [kb_hit_out(h) for h in await search(db, q, lang, k=k)]}
