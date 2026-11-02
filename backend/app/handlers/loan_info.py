"""F6 Loan products and repayment simulator. Rates and limits come only from `loan_products`; the maths is
pure Python (annuity, integer FBu, rounded half up)."""

from __future__ import annotations

import json
from decimal import ROUND_HALF_UP, Decimal, getcontext
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core import keywords
from app.core.responses import amount, join_list, rate, t
from app.core.types import HandlerResult, TurnContext
from app.errors import ApiError
from app.util import short_text

getcontext().prec = 40


def monthly_payment(principal: int, annual_rate_pct: float, term_months: int) -> int:
    """round(P·r / (1 − (1 + r)^−n)), r = annual_rate_pct / 1200; r = 0 → P / n. Half up."""
    p, n = Decimal(principal), int(term_months)
    r = Decimal(str(annual_rate_pct)) / Decimal(1200)
    v = p / n if r == 0 else p * r / (1 - (1 + r) ** -n)
    return int(v.quantize(Decimal(1), rounding=ROUND_HALF_UP))


def _loc(v: Any, lang: str) -> Any:
    if isinstance(v, str):
        v = json.loads(v)
    return v.get(lang) or v.get("fr")


def product_out(r: Any, lang: str) -> dict[str, Any]:
    m = r._mapping
    return {
        "id": m["id"],
        "name": _loc(m["name"], lang),
        "description": _loc(m["description"], lang),
        "annual_rate_pct": float(m["annual_rate_pct"]),
        "min_amount": int(m["min_amount"]),
        "max_amount": int(m["max_amount"]),
        "min_term_months": int(m["min_term_months"]),
        "max_term_months": int(m["max_term_months"]),
        "requirements": list(_loc(m["requirements"], lang)),
        "fictional": True,
    }


async def list_products(db: AsyncSession, lang: str) -> list[dict[str, Any]]:
    return [product_out(r, lang) for r in await db.execute(text("SELECT * FROM loan_products ORDER BY id"))]


async def get_product(db: AsyncSession, pid: str, lang: str) -> dict[str, Any] | None:
    r = (await db.execute(text("SELECT * FROM loan_products WHERE id = :id"), {"id": pid})).first()
    return product_out(r, lang) if r else None


def check_limits(p: dict[str, Any], amount_: int, term: int, lang: str) -> None:
    if amount_ < p["min_amount"]:
        raise ApiError(
            422,
            "out_of_range",
            t("loan_amount_min", lang, x=amount(p["min_amount"], lang)),
            {"field": "amount", "min": p["min_amount"], "max": p["max_amount"]},
        )
    if amount_ > p["max_amount"]:
        raise ApiError(
            422,
            "out_of_range",
            t("loan_amount_max", lang, x=amount(p["max_amount"], lang)),
            {"field": "amount", "min": p["min_amount"], "max": p["max_amount"]},
        )
    if not p["min_term_months"] <= term <= p["max_term_months"]:
        raise ApiError(
            422,
            "out_of_range",
            t("loan_term_range", lang, a=p["min_term_months"], b=p["max_term_months"]),
            {"field": "term_months", "min": p["min_term_months"], "max": p["max_term_months"]},
        )


def simulate(p: dict[str, Any], amount_: int, term: int, lang: str) -> dict[str, Any]:
    """Contract LoanSimulation (pdf filled by the caller)."""
    check_limits(p, amount_, term, lang)
    m = monthly_payment(amount_, p["annual_rate_pct"], term)
    total = m * term
    interest = total - amount_
    expl = t(
        "loan_sim",
        lang,
        amount=amount(amount_, lang),
        term=term,
        rate=rate(p["annual_rate_pct"], lang),
        monthly=amount(m, lang),
        interest=amount(interest, lang),
    )
    return {
        "product_id": p["id"],
        "product_name": p["name"],
        "amount": amount_,
        "term_months": term,
        "annual_rate_pct": p["annual_rate_pct"],
        "monthly_payment": m,
        "total_payment": total,
        "total_interest": interest,
        "explanation": expl,
        "lang": lang,
        "pdf": None,
    }


_REQ_WORDS = ["document", "pièce", "piece", "condition", "requirement", "need", "faut-il", "ivyangombwa", "bisabwa"]


async def handle(ctx: TurnContext) -> HandlerResult:
    lang = ctx.lang
    prev = ctx.context if ctx.state == "loan.collecting" else {}
    ents = ctx.intent.entities if ctx.intent else None
    pid = (
        (ents.product if ents and ents.product in keywords.LOAN_PRODUCTS else None)
        or keywords.find_product(ctx.text, loans_only=True)
        or prev.get("product")
    )
    amt = (ents.loan_amount if ents else None) or keywords.parse_amount(ctx.text) or prev.get("amount")
    term = (ents.term_months if ents else None) or keywords.parse_term_months(ctx.text) or prev.get("term")
    keep = {"product": pid, "amount": amt, "term": term}

    if not pid:
        names = [p["name"] for p in await list_products(ctx.db, lang)]
        return HandlerResult(
            text=t("loan_list", lang, names=join_list(names, lang)),
            short_text=short_text(t("loan_list", lang, names=", ".join(names))),
            state="loan.collecting",
            context=keep,
        )
    p = await get_product(ctx.db, pid, lang)
    if p is None:  # model invented a product id
        return HandlerResult(
            text=t("loan_list", lang, names=join_list([x["name"] for x in await list_products(ctx.db, lang)], lang)),
            state="loan.collecting",
            context={},
        )
    tf = keywords.fold(ctx.text)
    if any(w in tf for w in _REQ_WORDS) and not (amt and term):
        txt = f"{p['name']}. " + t("loan_requirements", lang, items="; ".join(p["requirements"]))
        return HandlerResult(text=txt, state="loan.collecting", context=keep)
    if not (amt and term):
        txt = (
            t(
                "loan_product",
                lang,
                name=p["name"],
                description=p["description"],
                rate=rate(p["annual_rate_pct"], lang),
                min=amount(p["min_amount"], lang),
                max=amount(p["max_amount"], lang),
                tmin=p["min_term_months"],
                tmax=p["max_term_months"],
            )
            + " "
            + t("loan_ask_amount_term", lang)
        )
        return HandlerResult(text=txt, state="loan.collecting", context=keep)
    try:
        sim = simulate(p, int(amt), int(term), lang)
    except ApiError as e:
        # keep the product, forget the bad value so the next turn can correct it
        bad = e.details.get("field")
        keep["amount" if bad == "amount" else "term"] = None
        return HandlerResult(
            text=f"{e.message} {t('loan_ask_amount_term', lang)}", state="loan.collecting", context=keep
        )
    short = t(
        "loan_sim_short",
        lang,
        name=p["name"],
        amount=amount(sim["amount"], lang),
        term=term,
        rate=rate(p["annual_rate_pct"], lang),
        monthly=amount(sim["monthly_payment"], lang),
    )
    action = {
        "type": "loan_simulation",
        "status": "done",
        "reference": None,
        "data": {k: v for k, v in sim.items() if k not in ("explanation", "pdf")},
    }
    return HandlerResult(
        text=sim["explanation"], short_text=short_text(short), actions=[action], state="loan.collecting", context=keep
    )
