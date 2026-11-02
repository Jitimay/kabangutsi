"""Shared helpers for routers."""

from __future__ import annotations

from app.errors import ApiError
from app.util import is_uuid


def require_uuid(v: str, what: str) -> str:
    if not is_uuid(v):
        raise ApiError(404, "not_found", f"{what} not found")
    return v
