"""F5 Card block. The identity check is done here, in code: account number + (PIN or date of birth).

- The PIN is compared with the argon2id hash; it is never logged, never stored, never sent to a model.
- PIN / date-of-birth turns are stored as '••••' (the orchestrator masks them before writing the transcript).
- 3 failures for the same account (customers.failed_attempts) or the same conversation → locked, handoff
  (reason identity_failed).
- Success gives a confirmation id valid CARD_BLOCK_CONFIRM_MINUTES; the card is blocked only on confirm.
"""

from __future__ import annotations

import re
from datetime import date, timedelta
from typing import Any

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError
from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core import keywords
from app.core.responses import card_type_name, t
from app.core.types import HandlerResult, TurnContext
from app.errors import ApiError
from app.util import iso, new_id, now

_ph = PasswordHasher()

ACCOUNT_RE = re.compile(r"(?<!\d)(\d[\d \-.]{9,16}\d)(?!\d)")


def parse_account(s: str) -> str | None:
    for m in ACCOUNT_RE.finditer(s):
        digits = re.sub(r"\D", "", m.group(1))
        if len(digits) == 11:
            return digits
    return None


def parse_pin(s: str) -> str | None:
    s = s.strip()
    m = re.fullmatch(r"\s*(\d)\s*(\d)\s*(\d)\s*(\d)\s*[.!]?", s)
    return "".join(m.groups()) if m else None


def parse_dob(s: str) -> date | None:
    s = s.strip()
    m = re.search(r"\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b", s)
    if m:
        y, mo, d = (int(x) for x in m.groups())
    else:
        m = re.search(r"\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{4})\b", s)
        if not m:
            return None
        d, mo, y = (int(x) for x in m.groups())
    try:
        return date(y, mo, d)
    except ValueError:
        return None


def verify_pin(pin_hash: str, pin: str) -> bool:
    try:
        return _ph.verify(pin_hash, pin)
    except (VerificationError, InvalidHashError):
        return False


def card_info(r: Any) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    return {"last4": m["last4"], "type": m["card_type"], "status": m["status"]}


class IdentityError(Exception):
    def __init__(self, attempts_left: int, locked: bool) -> None:
        self.attempts_left, self.locked = attempts_left, locked


async def _conversation_failures(db: AsyncSession, call_id: str | None, add: int = 0) -> int:
    if not call_id:
        return 0
    key = await db.scalar(
        text("SELECT session_key FROM sessions WHERE call_id = :c ORDER BY updated_at DESC LIMIT 1"), {"c": call_id}
    )
    if key is None:
        return 0
    if add:
        await db.execute(
            text("""UPDATE sessions SET context_json = jsonb_set(context_json, '{id_fail}',
                                   to_jsonb(COALESCE((context_json->>'id_fail')::int, 0) + :a)), updated_at = now()
                                 WHERE session_key = :k"""),
            {"a": add, "k": key},
        )
    return int(
        await db.scalar(
            text("SELECT COALESCE((context_json->>'id_fail')::int, 0) FROM sessions WHERE session_key = :k"), {"k": key}
        )
        or 0
    )


async def verify_identity(
    db: AsyncSession, account_number: str, *, pin: str | None, dob: date | None, call_id: str | None
) -> Any:
    """Returns the customer row. Raises IdentityError (wrong / locked) or ApiError 404 (unknown account,
    reported exactly like a wrong PIN to avoid account enumeration — still counts as a failure)."""
    s = get_settings()
    cust = (
        await db.execute(text("SELECT * FROM customers WHERE account_number = :a FOR UPDATE"), {"a": account_number})
    ).first()
    conv_fail = await _conversation_failures(db, call_id)
    if cust is not None and cust.locked_until is not None and cust.locked_until > now():
        raise IdentityError(0, True)
    if conv_fail >= s.max_identity_attempts:
        raise IdentityError(0, True)
    ok = False
    if cust is not None:
        if pin is not None:
            ok = verify_pin(cust.pin_hash, pin)
        elif dob is not None:
            ok = cust.date_of_birth == dob
    if ok:
        await db.execute(
            text("UPDATE customers SET failed_attempts = 0, locked_until = NULL WHERE id = :id"), {"id": cust.id}
        )
        if call_id:
            await db.execute(text("UPDATE calls SET customer_id = :cu WHERE id = :c"), {"cu": cust.id, "c": call_id})
        return cust
    conv_fail = await _conversation_failures(db, call_id, add=1)
    acc_fail = 0
    if cust is not None:
        acc_fail = int(
            await db.scalar(
                text(
                    "UPDATE customers SET failed_attempts = failed_attempts + 1 WHERE id = :id "
                    "RETURNING failed_attempts"
                ),
                {"id": cust.id},
            )
        )
    fails = max(acc_fail, conv_fail)
    if fails >= s.max_identity_attempts:
        if cust is not None:
            await db.execute(
                text("UPDATE customers SET locked_until = :u WHERE id = :id"),
                {"u": now() + timedelta(minutes=s.identity_lock_minutes), "id": cust.id},
            )
        raise IdentityError(0, True)
    raise IdentityError(s.max_identity_attempts - fails, False)


async def active_cards(db: AsyncSession, customer_id: Any) -> list[Any]:
    return list(
        await db.execute(
            text("SELECT * FROM cards WHERE customer_id = :c AND status = 'active' ORDER BY last4"), {"c": customer_id}
        )
    )


async def create_request(db: AsyncSession, card: Any, call_id: str | None, reason: str, lang: str) -> dict[str, Any]:
    cid = new_id()
    exp = now() + timedelta(minutes=get_settings().card_block_confirm_minutes)
    await db.execute(
        text(
            "INSERT INTO card_block_requests (id, card_id, call_id, reason, expires_at) "
            "VALUES (:id, :card, :call, :r, :e)"
        ),
        {"id": cid, "card": card.id, "call": call_id, "r": reason, "e": exp},
    )
    msg = t("confirm_block", lang, type=card_type_name(card.card_type, lang), last4=card.last4)
    return {"confirmation_id": cid, "expires_at": iso(exp), "card": card_info(card), "message": msg}


async def confirm(db: AsyncSession, confirmation_id: str, lang: str) -> dict[str, Any]:
    """Blocks the card. 404 unknown, 410 expired. Re-confirming a done request returns the same result."""
    req = (
        await db.execute(text("SELECT * FROM card_block_requests WHERE id = :id FOR UPDATE"), {"id": confirmation_id})
    ).first()
    if req is None:
        raise ApiError(404, "not_found", "Confirmation not found")
    card = (await db.execute(text("SELECT * FROM cards WHERE id = :id FOR UPDATE"), {"id": req.card_id})).first()
    if req.confirmed_at is not None and card.block_reference:
        ref = card.block_reference
        return {
            "reference": ref,
            "card": card_info(card),
            "blocked_at": iso(card.blocked_at),
            "message": t("card_blocked", lang, last4=card.last4, ref=ref),
        }
    if req.expires_at < now():
        raise ApiError(410, "expired", t("confirm_expired", lang))
    year = now().year
    seq = await db.scalar(text("SELECT nextval('card_block_ref_seq')"))
    ref = f"BLK-{year}-{int(seq):05d}"
    r = (
        await db.execute(
            text("""UPDATE cards SET status = 'blocked', blocked_at = now(), block_reason = :reason,
                                   block_reference = :ref WHERE id = :id RETURNING *"""),
            {"reason": req.reason, "ref": ref, "id": card.id},
        )
    ).first()
    await db.execute(
        text("UPDATE card_block_requests SET confirmed_at = now() WHERE id = :id"), {"id": confirmation_id}
    )
    return {
        "reference": ref,
        "card": card_info(r),
        "blocked_at": iso(r.blocked_at),
        "message": t("card_blocked", lang, last4=r.last4, ref=ref),
    }


# ---------------------------------------------------------------- conversation flow


def _act(type_: str, status: str, reference: str | None = None, data: dict | None = None) -> dict[str, Any]:
    return {"type": type_, "status": status, "reference": reference, "data": data or {}}


async def handle(ctx: TurnContext) -> HandlerResult:
    """States: card_block.awaiting_account → awaiting_pin (or awaiting_dob) → [awaiting_card] →
    awaiting_confirmation → idle. Context keeps account number (needed for the check), reason, last4,
    confirmation id — never a PIN or date of birth."""
    lang, st, c = ctx.lang, ctx.state, dict(ctx.context)
    txt = ctx.text

    if st.startswith("card_block.") and keywords.wants_cancel(txt) and st != "card_block.awaiting_confirmation":
        return HandlerResult(text=t("block_cancelled", lang), state="idle", context={})

    if not st.startswith("card_block."):
        ents = ctx.intent.entities if ctx.intent else None
        c = {"reason": (ents.card_issue if ents else None) or "lost", "last4": ents.card_last4 if ents else None}
        acc = parse_account(txt)
        if acc is None:
            return HandlerResult(
                text=t("ask_account", lang),
                expected_input="account_number",
                state="card_block.awaiting_account",
                context=c,
            )
        st, c["account"] = "card_block.awaiting_account", acc

    if st == "card_block.awaiting_account":
        acc = c.get("account") or parse_account(txt)
        if acc is None:
            return HandlerResult(
                text=t("bad_account", lang),
                expected_input="account_number",
                state="card_block.awaiting_account",
                context=c,
            )
        c["account"] = acc
        return HandlerResult(text=t("ask_pin", lang), expected_input="pin", state="card_block.awaiting_pin", context=c)

    if st in ("card_block.awaiting_pin", "card_block.awaiting_dob"):
        if st == "card_block.awaiting_pin" and keywords.forgot_pin(txt) and parse_dob(txt) is None:
            return HandlerResult(
                text=t("ask_dob", lang), expected_input="date_of_birth", state="card_block.awaiting_dob", context=c
            )
        pin = parse_pin(txt) if st == "card_block.awaiting_pin" else None
        dob = None if pin else parse_dob(txt)
        if pin is None and dob is None:
            exp = "pin" if st == "card_block.awaiting_pin" else "date_of_birth"
            return HandlerResult(text=t("pin_format", lang), expected_input=exp, state=st, context=c)
        try:
            cust = await verify_identity(ctx.db, c["account"], pin=pin, dob=dob, call_id=ctx.call_id)
        except IdentityError as e:
            if e.locked:
                return HandlerResult(
                    text=t("identity_locked", lang),
                    state="idle",
                    context={},
                    actions=[_act("identity_check", "failed", data={"attempts_left": 0})],
                    handoff_reason="identity_failed",
                    expected_input="none",
                )
            return HandlerResult(
                text=t("identity_failed", lang, left=e.attempts_left) + " " + t("ask_pin", lang).split(". ", 1)[-1],
                expected_input="pin",
                state="card_block.awaiting_pin",
                context=c,
                actions=[_act("identity_check", "failed", data={"attempts_left": e.attempts_left})],
            )
        cards = await active_cards(ctx.db, cust.id)
        ok_act = _act("identity_check", "done")
        if not cards:
            return HandlerResult(
                text=t("no_active_card", lang) + " " + t("ok_else", lang), state="idle", context={}, actions=[ok_act]
            )
        chosen = [x for x in cards if x.last4 == c.get("last4")] if c.get("last4") else []
        if not chosen and len(cards) == 1:
            chosen = cards
        if not chosen:
            c["cards"] = [x.last4 for x in cards]
            c["customer_id"] = str(cust.id)
            return HandlerResult(
                text=t("choose_card", lang, cards=", ".join(c["cards"])),
                expected_input="text",
                state="card_block.awaiting_card",
                context=c,
                actions=[ok_act],
            )
        pend = await create_request(ctx.db, chosen[0], ctx.call_id, c["reason"], lang)
        c = {"confirmation_id": pend["confirmation_id"], "last4": chosen[0].last4}
        return HandlerResult(
            text=pend["message"],
            expected_input="confirmation",
            state="card_block.awaiting_confirmation",
            context=c,
            actions=[
                ok_act,
                _act("card_block", "pending", data={"card": pend["card"], "expires_at": pend["expires_at"]}),
            ],
        )

    if st == "card_block.awaiting_card":
        m = re.search(r"\b(\d{4})\b", txt)
        if not m or m.group(1) not in c.get("cards", []):
            return HandlerResult(text=t("choose_card", lang, cards=", ".join(c.get("cards", []))), state=st, context=c)
        card = (
            await ctx.db.execute(
                text("SELECT * FROM cards WHERE customer_id = :cu AND last4 = :l AND status = 'active'"),
                {"cu": c["customer_id"], "l": m.group(1)},
            )
        ).first()
        pend = await create_request(ctx.db, card, ctx.call_id, c.get("reason") or "lost", lang)
        c = {"confirmation_id": pend["confirmation_id"], "last4": card.last4}
        return HandlerResult(
            text=pend["message"],
            expected_input="confirmation",
            state="card_block.awaiting_confirmation",
            context=c,
            actions=[_act("card_block", "pending", data={"card": pend["card"], "expires_at": pend["expires_at"]})],
        )

    if st == "card_block.awaiting_confirmation":
        yn = keywords.yes_no(txt)
        if yn is None:
            return HandlerResult(text=t("yes_no", lang), expected_input="confirmation", state=st, context=c)
        if yn is False:
            return HandlerResult(
                text=t("block_cancelled", lang),
                state="idle",
                context={},
                actions=[_act("card_block", "failed", data={"cancelled": True})],
            )
        try:
            res = await confirm(ctx.db, c["confirmation_id"], lang)
        except ApiError as e:
            if e.status == 410:
                return HandlerResult(
                    text=t("confirm_expired", lang),
                    state="idle",
                    context={},
                    actions=[_act("card_block", "failed", data={"expired": True})],
                )
            raise
        return HandlerResult(
            text=res["message"],
            short_text=t("card_blocked_short", lang, last4=res["card"]["last4"], ref=res["reference"]),
            state="idle",
            context={},
            actions=[
                _act("card_block", "done", res["reference"], {"card": res["card"], "blocked_at": res["blocked_at"]})
            ],
        )

    return HandlerResult(text=t("ok_else", lang), state="idle", context={})
