"""F8 Branch hours, address and phone. Facts come only from the `branches` table (never from a model)."""

from __future__ import annotations

import json
from datetime import UTC, datetime, timedelta, timezone
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.core import keywords
from app.core.responses import DAY_KEYS, hours_text, join_list, t
from app.core.types import HandlerResult, TurnContext
from app.util import short_text


def local_now() -> datetime:
    try:
        from zoneinfo import ZoneInfo

        tz: Any = ZoneInfo(get_settings().tz_local)
    except Exception:  # noqa: BLE001 — no tzdata in the image: Bujumbura is UTC+2 all year
        tz = timezone(timedelta(hours=2))
    return datetime.now(UTC).astimezone(tz)


def is_open(hours: dict[str, Any], at: datetime | None = None) -> bool:
    at = at or local_now()
    h = hours.get(DAY_KEYS[at.weekday()])
    if not h:
        return False
    hm = at.strftime("%H:%M")
    return h["open"] <= hm < h["close"]


def branch_out(r: Any, lang: str) -> dict[str, Any]:
    m = r._mapping if hasattr(r, "_mapping") else r
    hours = m["hours"] if isinstance(m["hours"], dict) else json.loads(m["hours"])
    return {
        "id": m["id"],
        "name": m["name"],
        "province": m["province"],
        "town": m["town"],
        "address": m["address"],
        "phone": m["phone"],
        "hours": {k: hours.get(k) for k in DAY_KEYS},
        "hours_text": hours_text(hours, lang),
        "services": list(m["services"] or []),
        "is_open_now": is_open(hours),
        "fictional": True,
    }


async def search_branches(
    db: AsyncSession, *, province: str | None = None, town: str | None = None, q: str | None = None, lang: str = "fr"
) -> list[dict[str, Any]]:
    """Accent- and case-insensitive; trigram match tolerates typos ('ngozy' → Ngozi)."""
    conds, params = [], {}
    for name, val in (("province", province), ("town", town)):
        if val:
            conds.append(
                f"(lower(unaccent({name})) = lower(unaccent(:{name})) "
                f"OR similarity(lower(unaccent({name})), lower(unaccent(:{name}))) > 0.45)"
            )
            params[name] = val
    if q:
        conds.append(
            "(word_similarity(lower(unaccent(:q)), lower(unaccent(name || ' ' || town || ' ' || province "
            "|| ' ' || address))) > 0.5)"
        )
        params["q"] = q
    where = " AND ".join(conds) if conds else "true"
    order = "word_similarity(lower(unaccent(:q)), lower(unaccent(name || ' ' || address))) DESC, " if q else ""
    sql = f"SELECT * FROM branches WHERE {where} ORDER BY {order}name"  # noqa: S608 (fixed fragments)
    return [branch_out(r, lang) for r in await db.execute(text(sql), params)]


async def handle(ctx: TurnContext) -> HandlerResult:
    lang = ctx.lang
    ents = ctx.intent.entities if ctx.intent else None
    place = (ents.town or ents.province or ents.branch_name) if ents else None
    place = (
        place
        or keywords.find_place(ctx.text)
        or (ctx.context.get("branch_place") if ctx.state == "branch.awaiting_place" else None)
    )
    items: list[dict[str, Any]] = []
    if place:
        items = await search_branches(ctx.db, province=place, lang=lang)
        if not items:
            items = await search_branches(ctx.db, town=place, lang=lang)
        if not items:
            items = await search_branches(ctx.db, q=place, lang=lang)
    if not items:
        towns = sorted({r.town for r in await ctx.db.execute(text("SELECT DISTINCT town FROM branches"))})
        return HandlerResult(
            text=t("branch_ask_town", lang, towns=join_list(towns, lang)),
            short_text=short_text(t("branch_ask_town", lang, towns=", ".join(towns))),
            state="branch.awaiting_place",
        )
    lines, shorts = [], []
    for b in items[:3]:
        status = t("open_now" if b["is_open_now"] else "closed_now", lang)
        lines.append(
            t("branch_line", lang, name=b["name"], address=b["address"], hours=b["hours_text"], phone=b["phone"])
            + f" {status}."
        )
        shorts.append(
            t(
                "branch_line_short",
                lang,
                town=b["name"].replace("Agence ", "").replace(" (fictive)", ""),
                hours=b["hours_text"],
                phone=b["phone"],
            )
        )
    head = t("branch_many", lang, n=len(items), place=place) + " " if len(items) > 1 else ""
    return HandlerResult(text=head + " ".join(lines), short_text=short_text(shorts[0]), actions=[], context={})
