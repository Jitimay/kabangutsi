"""Async engine and session factory (SQLAlchemy 2 + asyncpg)."""

from __future__ import annotations

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings

_engine: AsyncEngine | None = None
_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine() -> AsyncEngine:
    global _engine, _factory
    if _engine is None:
        _engine = create_async_engine(get_settings().database_url, pool_size=10, max_overflow=10, pool_pre_ping=True)
        _factory = async_sessionmaker(_engine, expire_on_commit=False)
    return _engine


def session_factory() -> async_sessionmaker[AsyncSession]:
    get_engine()
    assert _factory is not None
    return _factory


@asynccontextmanager
async def db_session() -> AsyncIterator[AsyncSession]:
    async with session_factory()() as s:
        yield s


async def get_db() -> AsyncIterator[AsyncSession]:
    """FastAPI dependency."""
    async with session_factory()() as s:
        yield s


async def dispose() -> None:
    global _engine, _factory
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _factory = None
