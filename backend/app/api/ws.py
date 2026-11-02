"""GET /v1/ws — live events (ws_events.json). Agents get everything (first a stats.updated); customers only the
events of their conversation."""

from __future__ import annotations

import asyncio
import contextlib

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from fastapi.responses import JSONResponse

from app.agents import stats
from app.db.session import db_session
from app.errors import error_body
from app.realtime.events import make_event
from app.realtime.hub import Client, hub
from app.util import is_uuid

router = APIRouter()


async def _deny(ws: WebSocket, message: str) -> None:
    try:
        await ws.send_denial_response(JSONResponse(error_body("validation_error", message), status_code=400))
    except Exception:  # noqa: BLE001 — server without the denial extension
        await ws.close(code=1008, reason=message)


@router.websocket("/v1/ws")
async def websocket(ws: WebSocket) -> None:
    role = ws.query_params.get("role")
    agent_id = ws.query_params.get("agent_id")
    conv = ws.query_params.get("conversation_id")
    if role not in ("agent", "customer"):
        return await _deny(ws, "role must be agent or customer")
    if role == "agent" and not agent_id:
        return await _deny(ws, "agent_id is required for role=agent")
    if role == "customer" and not (conv and is_uuid(conv)):
        return await _deny(ws, "conversation_id is required for role=customer")
    await ws.accept()
    client = Client(ws=ws, role=role, agent_id=agent_id, conversation_id=conv)
    hub.add(client)
    try:
        if role == "agent":
            async with db_session() as db:
                await ws.send_json(make_event("stats.updated", await stats.compute(db)))

        async def pump() -> None:
            assert client.queue is not None
            while True:
                await ws.send_json(await client.queue.get())

        async def drain_incoming() -> None:
            while True:
                await ws.receive_text()  # pings / ignored; raises on disconnect

        tasks = [asyncio.create_task(pump()), asyncio.create_task(drain_incoming())]
        done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        for tk in pending:
            tk.cancel()
        for tk in done:
            if not tk.cancelled():
                tk.exception()  # disconnects end a task with WebSocketDisconnect: expected, mark it retrieved
    except WebSocketDisconnect:
        pass
    finally:
        hub.remove(client)
        with contextlib.suppress(Exception):
            await ws.close()
