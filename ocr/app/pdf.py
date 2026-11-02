"""PDF generation (F18): Jinja2 HTML templates in fr/en/rn rendered by WeasyPrint, offline."""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Literal

from jinja2 import Environment, FileSystemLoader, select_autoescape
from pydantic import BaseModel, ConfigDict, Field
from weasyprint import HTML
from weasyprint.urls import URLFetcher

from .pdf_strings import CATEGORY, STATUS, T, URGENCY

TEMPLATES_DIR = Path(__file__).parent / "templates"
Lang = Literal["fr", "en", "rn"]
UUID_RE = r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"
TS_RE = r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$"
PHONE_RE = r"^\+257[0-9]{8}$"
CAT = timezone(timedelta(hours=2), "CAT")  # Africa/Bujumbura, no DST


# ---------------------------------------------------------------- data models (contracts)
class FileRef(BaseModel):
    """openapi.yaml#/components/schemas/FileRef"""
    id: str = Field(pattern=UUID_RE)
    url: str
    type: Literal["image", "audio", "pdf"]
    mime: str
    size_bytes: int
    created_at: str = Field(pattern=TS_RE)


class LoanSimulation(BaseModel):
    """openapi.yaml#/components/schemas/LoanSimulation"""
    product_id: str
    product_name: str
    amount: int
    term_months: int
    annual_rate_pct: float
    monthly_payment: int
    total_payment: int
    total_interest: int
    explanation: str
    lang: Lang
    pdf: FileRef | None


class Attachment(BaseModel):
    model_config = ConfigDict(extra="forbid")
    type: Literal["image", "audio", "pdf"]
    url: str
    mime: str
    name: str | None = None
    size_bytes: int | None = Field(default=None, ge=0)
    duration_ms: int | None = Field(default=None, ge=0)


class Ticket(BaseModel):
    """ws_events.json#/$defs/Ticket"""
    model_config = ConfigDict(extra="forbid")
    id: str = Field(pattern=UUID_RE)
    number: str = Field(pattern=r"^TCK-[0-9]{4}-[0-9]{5}$")
    call_id: str | None = Field(pattern=UUID_RE)
    phone: str | None = Field(pattern=PHONE_RE)
    customer_name: str | None = None
    category: Literal["fees", "card", "loan", "account", "service_quality", "mobile_banking", "atm", "other"]
    urgency: Literal["low", "medium", "high", "critical"]
    summary: str
    status: Literal["open", "in_progress", "resolved", "closed"]
    lang: Lang
    assigned_to: str | None = None
    attachments: list[Attachment] = Field(default_factory=list)
    created_at: str = Field(pattern=TS_RE)
    updated_at: str = Field(pattern=TS_RE)


TEMPLATES: dict[str, type[BaseModel]] = {"loan_simulation": LoanSimulation, "ticket_receipt": Ticket}


# ---------------------------------------------------------------- formatting
def fbu(n: int) -> str:
    """5000000 -> '5 000 000 FBu' (non-breaking spaces)."""
    return f"{n:,}".replace(",", " ") + " FBu"


def pct(x: float, lang: str) -> str:
    s = f"{x:.1f}"
    return (s if lang == "en" else s.replace(".", ",")) + " %"


def local_time(ts: str) -> str:
    dt = datetime.strptime(ts[:19], "%Y-%m-%dT%H:%M:%S").replace(tzinfo=timezone.utc).astimezone(CAT)
    return dt.strftime("%d/%m/%Y %H:%M") + " (CAT)"


def mask_phone(phone: str | None) -> str:
    return "—" if not phone else phone[:6] + "•••" + phone[-2:]


_env = Environment(loader=FileSystemLoader(TEMPLATES_DIR), autoescape=select_autoescape(["html"]))
_env.filters.update(fbu=fbu, local_time=local_time, mask_phone=mask_phone)
_fetcher = URLFetcher(allowed_protocols={"file", "data"})  # no http(s): offline by construction


def render(template: str, lang: str, data: BaseModel) -> bytes:
    ctx: dict[str, Any] = {"lang": lang, "t": T[lang], "d": data,
                           "generated": datetime.now(CAT).strftime("%d/%m/%Y %H:%M") + " (CAT)"}
    if template == "loan_simulation":
        ctx["rate"] = pct(data.annual_rate_pct, lang)  # type: ignore[attr-defined]
    else:
        ctx.update(category=CATEGORY[lang][data.category],  # type: ignore[attr-defined]
                   urgency=URGENCY[lang][data.urgency],      # type: ignore[attr-defined]
                   status=STATUS[lang][data.status])         # type: ignore[attr-defined]
    html = _env.get_template(f"{template}.html").render(**ctx)
    return HTML(string=html, base_url=str(TEMPLATES_DIR), url_fetcher=_fetcher).write_pdf()
