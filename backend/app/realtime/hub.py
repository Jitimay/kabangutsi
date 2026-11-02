"""WebSocket hub fed by Postgres LISTEN kabangutsi_events (works across processes and workers)."""

from __future__ import annotations

import asyncio
import contextlib
import json
import logging
from dataclasses import dataclass
from typing import Any

import asyncpg
from fastapi import WebSocket

from app.config import get_settings
from app.db.seed import plain_dsn
from app.realtime.events import CHANNEL, CUSTOMER_EVENTS, event_call_id

log = logging.getLogger(__name__)


@dataclass(eq=False)
class Client:
    ws: WebSocket
    role: str
    agent_id: str | None = None
    conversation_id: str | None = None
    queue: asyncio.Queue | None = None

    def wants(self, ev: dict[str, Any]) -> bool:
        if self.role == "agent":
            return True
        return ev.get("type") in CUSTOMER_EVENTS and event_call_id(ev) == self.conversation_id


class Hub:
    def __init__(self) -> None:
        self.clients: set[Client] = set()
        self._task: asyncio.Task | None = None
        self._conn: asyncpg.Connection | None = None
        self._incoming: asyncio.Queue[str] = asyncio.Queue()

    async def start(self) -> None:
        self._task = asyncio.create_task(self._run(), name="ws-hub")

    async def stop(self) -> None:
        if self._task:
            self._task.cancel()
            with contextlib.suppress(asyncio.CancelledError, Exception):
                await self._task
        if self._conn:
            with contextlib.suppress(Exception):
                await self._conn.close()

    def _on_notify(self, _conn: Any, _pid: int, _channel: str, payload: str) -> None:
        self._incoming.put_nowait(payload)

    async def _run(self) -> None:
        dsn = plain_dsn(get_settings().database_url)
        while True:
            try:
                self._conn = await asyncpg.connect(dsn)
                await self._conn.add_listener(CHANNEL, self._on_notify)
                log.info("hub listening on %s", CHANNEL)
                while not self._conn.is_closed():
                    try:
                        payload = await asyncio.wait_for(self._incoming.get(), timeout=5)
                    except TimeoutError:
                        continue
                    await self._dispatch(payload)
            except asyncio.CancelledError:
                raise
            except Exception as e:  # noqa: BLE001 — reconnect forever
                log.warning("hub connection lost: %s", e)
                await asyncio.sleep(2)

    async def _dispatch(self, payload: str) -> None:
        try:
            ev = json.loads(payload)
        except json.JSONDecodeError:
            return
        if "ref" in ev and "data" not in ev:
            from app.realtime.rebuild import rebuild

            ev = await rebuild(ev)
            if ev is None:
                return
        await self.broadcast(ev)

    async def broadcast(self, ev: dict[str, Any]) -> None:
        for c in list(self.clients):
            if c.wants(ev) and c.queue is not None:
                c.queue.put_nowait(ev)

    def add(self, c: Client) -> None:
        c.queue = asyncio.Queue()
        self.clients.add(c)

    def remove(self, c: Client) -> None:
        self.clients.discard(c)


hub = Hub()
