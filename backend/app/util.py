"""Small shared helpers: time, ids, text shaping."""

from __future__ import annotations

import re
import uuid
from datetime import UTC, datetime

LANGS = ("fr", "en", "rn")
MASK = "••••"


def now() -> datetime:
    return datetime.now(UTC)


def iso(dt: datetime | None) -> str | None:
    """ISO 8601 UTC with Z suffix (contract Timestamp)."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=UTC)
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def new_id() -> str:
    return str(uuid.uuid4())


def is_uuid(v: str) -> bool:
    try:
        return str(uuid.UUID(v)) == v.lower()
    except (ValueError, AttributeError, TypeError):
        return False


_SENT_END = re.compile(r"(?<=[.!?…])\s+(?=[A-ZÀ-ÖØ-Þ0-9«\"'(])")


def split_sentences(text: str) -> list[str]:
    text = " ".join(text.split())
    if not text:
        return []
    return [s.strip() for s in _SENT_END.split(text) if s.strip()]


def short_text(text: str, limit: int = 160) -> str:
    """SMS-safe version: whole sentences while they fit, else a hard cut with an ellipsis."""
    text = " ".join(text.split())
    if len(text) <= limit:
        return text
    out = ""
    for s in split_sentences(text):
        cand = f"{out} {s}".strip()
        if len(cand) > limit:
            break
        out = cand
    if out:
        return out
    return text[: limit - 1].rstrip() + "…"


def fmt_amount(n: int, lang: str) -> str:
    """5000000 → '5 000 000' (fr/rn) or '5,000,000' (en)."""
    s = f"{int(n):,}"
    return s if lang == "en" else s.replace(",", " ")


class SentenceBuffer:
    """Accumulates streamed tokens and yields finished sentences."""

    def __init__(self) -> None:
        self.buf = ""

    def feed(self, delta: str) -> list[str]:
        self.buf += delta
        parts = _SENT_END.split(self.buf)
        if len(parts) <= 1:
            return []
        done, self.buf = parts[:-1], parts[-1]
        return [p.strip() for p in done if p.strip()]

    def flush(self) -> list[str]:
        rest, self.buf = self.buf.strip(), ""
        return [rest] if rest else []
