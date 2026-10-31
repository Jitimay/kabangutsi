"""sms-gateway service (port 8003): GET /health, POST /send (contracts/adapter_api.yaml).

Env: BACKEND_URL (http://backend:8000), MODEM_DEVICE (/dev/ttyUSB0), MODEM_BAUD (9600, the
Arduino Nano passthrough speed; USB dongles ignore it), POLL_INTERVAL_S (3),
REPLIES_PER_MINUTE (5), SMS_DISABLE_LOOP (1 = do not start the modem loop, for tests).
"""

from __future__ import annotations

import logging
import os
import threading
from contextlib import asynccontextmanager
from typing import Any

from fastapi import FastAPI
from fastapi.concurrency import run_in_threadpool
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field

from .gateway import Gateway
from .modem import Modem, ModemError

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"),
                    format="%(asctime)s %(levelname)s %(name)s %(message)s")


class OutgoingReplyIn(BaseModel):
    """The fields /send needs from an OutgoingReply (full schema: contracts/message.schema.json)."""
    model_config = ConfigDict(extra="allow")
    id: str
    phone: str | None = Field(pattern=r"^\+257[0-9]{8}$")
    text: str
    short_text: str = Field(max_length=160)


def build_gateway() -> Gateway:
    modem = Modem(os.environ.get("MODEM_DEVICE", "/dev/ttyUSB0"), int(os.environ.get("MODEM_BAUD", "9600")))
    return Gateway(modem, os.environ.get("BACKEND_URL", "http://backend:8000"),
                   poll_s=float(os.environ.get("POLL_INTERVAL_S", "3")),
                   replies_per_minute=int(os.environ.get("REPLIES_PER_MINUTE", "5")))


@asynccontextmanager
async def lifespan(app: FastAPI):
    gw: Gateway = getattr(app.state, "gateway", None) or build_gateway()
    app.state.gateway = gw
    t = None
    if os.environ.get("SMS_DISABLE_LOOP") != "1":
        t = threading.Thread(target=gw.run_forever, name="sms-loop", daemon=True)
        t.start()
    yield
    gw.stop.set()
    if t:
        t.join(timeout=5)
    gw.modem.close()


app = FastAPI(title="Kabangutsi sms-gateway", version="1.0.0", lifespan=lifespan)


@app.exception_handler(RequestValidationError)
async def _invalid(_req, exc: RequestValidationError):
    return JSONResponse(status_code=422, content={"code": "validation_error", "message": "invalid body",
                                                  "details": {"errors": [e["loc"] for e in exc.errors()]}})


@app.get("/health")
def health() -> dict[str, Any]:
    gw: Gateway = app.state.gateway
    detail = f"Modem {gw.modem.model} on {gw.modem.device}"
    connected = False
    if gw.modem.port is not None:
        try:
            connected = gw.modem.registered()
            sig = gw.modem.signal()
            detail += f", signal {sig}/31" if sig is not None else ", no signal"
            if not connected:
                detail += ", not registered on the network"
        except ModemError as e:
            detail += f", error: {e}"
    else:
        detail += f": not open ({gw.last_error or 'starting'})"
    return {"status": "ok" if connected else "degraded", "connected": connected, "detail": detail}


@app.post("/send", status_code=202)
async def send(reply: OutgoingReplyIn):
    gw: Gateway = app.state.gateway
    if reply.phone is None:
        return JSONResponse(status_code=422, content={"code": "validation_error", "message": "phone is null"})
    if gw.modem.port is None:
        return JSONResponse(status_code=503, content={"code": "unavailable", "message": "modem not available"})
    try:
        await run_in_threadpool(gw.send_outgoing, reply.phone, reply.short_text or reply.text)
    except ModemError as e:
        return JSONResponse(status_code=503, content={"code": "unavailable", "message": str(e)})
    return {"status": "sent", "message_id": reply.id}
