"""Small helpers shared by the tests."""

from __future__ import annotations

import json
import uuid
from typing import Any


def intent_json(intent: str, lang: str, conf: float = 0.9, frus: float = 0.0, **entities: Any) -> str:
    return json.dumps({"intent": intent, "lang": lang, "entities": entities, "confidence": conf, "frustration": frus})


async def new_conv(
    client: Any, lang: str = "fr", channel: str = "web", phone: str | None = None, model: str | None = None
) -> dict:
    r = await client.post("/v1/conversations", json={"channel": channel, "phone": phone, "lang": lang, "model": model})
    assert r.status_code == 201, r.text
    return r.json()


async def say(client: Any, conv_id: str, text: str, **kw: Any) -> dict:
    r = await client.post(f"/v1/conversations/{conv_id}/messages", json={"text": text, **kw})
    assert r.status_code == 200, r.text
    return r.json()


def inbound(channel: str, session_id: str, text: str, phone: str | None = None, lang: str | None = None) -> dict:
    return {
        "id": str(uuid.uuid4()),
        "channel": channel,
        "phone": phone,
        "session_id": session_id,
        "lang": lang,
        "text": text,
        "attachments": [],
        "ts": "2026-11-02T08:15:30Z",
    }


def parse_sse(body: str) -> list[tuple[str, Any]]:
    out = []
    for block in body.strip().split("\n\n"):
        name, data = None, None
        for line in block.splitlines():
            if line.startswith("event: "):
                name = line[7:]
            elif line.startswith("data: "):
                data = json.loads(line[6:])
        if name:
            out.append((name, data))
    return out
