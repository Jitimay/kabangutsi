"""Stored files (uploads, TTS audio, generated PDFs) in FILES_DIR, metadata in the `files` table."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import get_settings
from app.util import iso, new_id

MAX_BYTES = {"image": 10 * 1024 * 1024, "audio": 20 * 1024 * 1024, "pdf": 20 * 1024 * 1024}
EXT = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "audio/wav": ".wav",
    "audio/x-wav": ".wav",
    "audio/wave": ".wav",
    "audio/webm": ".webm",
    "audio/ogg": ".ogg",
    "audio/mp4": ".m4a",
    "audio/mpeg": ".mp3",
    "audio/aac": ".aac",
    "application/pdf": ".pdf",
}


def kind_of(mime: str) -> str | None:
    mime = (mime or "").split(";")[0].strip().lower()
    if mime not in EXT:
        return None
    if mime.startswith("image/"):
        return "image"
    if mime.startswith("audio/"):
        return "audio"
    return "pdf"


def files_root() -> Path:
    p = Path(get_settings().files_dir)
    p.mkdir(parents=True, exist_ok=True)
    return p


async def store_file(db: AsyncSession, data: bytes, mime: str, call_id: str | None = None) -> dict[str, Any]:
    """Writes bytes + row, returns FileRef (openapi FileRef). Caller checks size/type first (or catches ValueError)."""
    mime = mime.split(";")[0].strip().lower()
    kind = kind_of(mime)
    if kind is None:
        raise ValueError("unsupported_media_type")
    if len(data) > MAX_BYTES[kind]:
        raise OverflowError("too_large")
    fid = new_id()
    rel = f"{fid}{EXT[mime]}"
    (files_root() / rel).write_bytes(data)
    r = await db.execute(
        text(
            "INSERT INTO files (id, kind, mime, size_bytes, path, call_id) VALUES (:id, :k, :m, :s, :p, :c) RETURNING created_at"
        ),
        {"id": fid, "k": kind, "m": mime, "s": len(data), "p": rel, "c": call_id},
    )
    created = r.scalar()
    return {
        "id": fid,
        "url": f"/v1/files/{fid}",
        "type": kind,
        "mime": mime,
        "size_bytes": len(data),
        "created_at": iso(created),
    }


def attachment_of(ref: dict[str, Any], name: str | None = None, duration_ms: int | None = None) -> dict[str, Any]:
    a = {"type": ref["type"], "url": ref["url"], "mime": ref["mime"], "size_bytes": ref["size_bytes"]}
    if name:
        a["name"] = name
    if duration_ms is not None:
        a["duration_ms"] = duration_ms
    return a


async def load_file(db: AsyncSession, file_id_or_url: str) -> tuple[bytes, str] | None:
    fid = file_id_or_url.rsplit("/", 1)[-1]
    r = (
        (await db.execute(text("SELECT mime, path FROM files WHERE id = CAST(:id AS uuid)"), {"id": fid})).first()
        if len(fid) == 36
        else None
    )
    if r is None:
        return None
    p = files_root() / r.path
    if not p.exists():
        return None
    return p.read_bytes(), r.mime
