"""Test fixtures.

- A dedicated database `kabangutsi_t1test` on the local Postgres (TEST_DATABASE_URL to override) is
  re-created once per session: `alembic upgrade head` + the demo seed (scripts/reset_demo.sql).
- `fake_llm` replaces Ollama with a scripted fake (no model calls in unit tests).
- `contract` validates payloads against the JSON schemas in ../contracts.
"""

from __future__ import annotations

import asyncio
import json
import os
import subprocess
import sys
from collections.abc import AsyncIterator
from pathlib import Path
from typing import Any

import asyncpg
import pytest

ROOT = Path(__file__).resolve().parents[2]
BACKEND = ROOT / "backend"
TEST_DB = "kabangutsi_t1test"
ADMIN_URL = os.environ.get("TEST_ADMIN_URL", "postgresql://kabangutsi:kabangutsi_dev@localhost:5432/kabangutsi")
TEST_URL = os.environ.get(
    "TEST_DATABASE_URL", f"postgresql+asyncpg://kabangutsi:kabangutsi_dev@localhost:5432/{TEST_DB}"
)

os.environ["DATABASE_URL"] = TEST_URL
os.environ["REALTIME_ENABLED"] = "false"
os.environ["EMBED_ON_STARTUP"] = "false"
os.environ["SUMMARY_IN_BACKGROUND"] = "false"
os.environ["RAG_LLM_LANGS"] = "fr,en"  # exercise the LLM answer path + grounding check
os.environ["FILES_DIR"] = str(BACKEND / ".test-files")
os.environ["OLLAMA_URL"] = "http://127.0.0.1:9"  # nothing listens: any real call fails fast
os.environ["VOICE_URL"] = "http://127.0.0.1:9"
os.environ["OCR_URL"] = "http://127.0.0.1:9"
os.environ["SMS_GATEWAY_URL"] = "http://127.0.0.1:9"
os.environ["WHATSAPP_BRIDGE_URL"] = "http://127.0.0.1:9"


def _reset_db() -> None:
    async def go() -> None:
        conn = await asyncpg.connect(ADMIN_URL)
        try:
            await conn.execute(
                f"SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '{TEST_DB}' AND pid <> pg_backend_pid()"  # noqa: S608
            )
            await conn.execute(f"DROP DATABASE IF EXISTS {TEST_DB}")
            await conn.execute(f"CREATE DATABASE {TEST_DB}")
        finally:
            await conn.close()

    asyncio.run(go())
    subprocess.run(
        [sys.executable, "-m", "alembic", "upgrade", "head"],
        cwd=BACKEND,
        check=True,
        env={**os.environ, "DATABASE_URL": TEST_URL},
    )

    from app.db.seed import load_seed

    asyncio.run(load_seed(url=TEST_URL))


def pytest_sessionstart(session: pytest.Session) -> None:
    _reset_db()


# ---------------------------------------------------------------- fake LLM


class FakeLLM:
    """Scripted Ollama stand-in. `intent_replies` are returned in order for format= (JSON) calls;
    `answer` is streamed for free-text calls. Records every message list it receives."""

    def __init__(self) -> None:
        self.models = [
            {"name": "gemma:2b", "size": 1678456656, "caps": ["completion"], "family": "gemma"},
            {
                "name": "gemma4:e4b",
                "size": 9608350718,
                "caps": ["completion", "vision", "audio", "tools", "thinking"],
                "family": "gemma4",
            },
            {"name": "nomic-embed-text:latest", "size": 274302450, "caps": ["embedding"], "family": "nomic-bert"},
        ]
        self.intent_replies: list[str] = []
        self.answer = "Je n'ai pas cette information."
        self.calls: list[dict[str, Any]] = []
        self.fail = False

    def seen_text(self) -> str:
        return json.dumps(self.calls, ensure_ascii=False)

    async def tags(self) -> list[dict[str, Any]]:
        if self.fail:
            from app.clients.ollama import LLMError

            raise LLMError("down")
        return [{"name": m["name"], "size": m["size"], "details": {"family": m["family"]}} for m in self.models]

    async def show(self, name: str) -> dict[str, Any]:
        for m in self.models:
            if m["name"] == name:
                return {
                    "capabilities": m["caps"],
                    "details": {"family": m["family"], "parameter_size": "x", "quantization_level": "q"},
                }
        raise KeyError(name)

    async def chat(self, model: str, messages: list[dict[str, Any]], **kw: Any) -> str:
        self.calls.append({"model": model, "messages": messages, "format": kw.get("format") is not None})
        if self.fail:
            from app.clients.ollama import LLMError

            raise LLMError("down")
        if kw.get("format") is not None:
            return self.intent_replies.pop(0) if self.intent_replies else "not json"
        return self.answer

    async def chat_stream(self, model: str, messages: list[dict[str, Any]], **kw: Any) -> AsyncIterator[str]:
        self.calls.append({"model": model, "messages": messages, "format": False})
        if self.fail:
            from app.clients.ollama import LLMError

            raise LLMError("down")
        for w in self.answer.split(" "):
            yield w + " "

    async def embed(self, model: str, inputs: list[str], timeout: float | None = None) -> list[list[float]]:
        self.calls.append({"model": model, "embed": inputs})
        # deterministic bag-of-letters vector, 768 dims
        out = []
        for s in inputs:
            v = [0.0] * 768
            for i, ch in enumerate(s.lower()):
                v[(ord(ch) * 7 + i % 3) % 768] += 1.0
            out.append(v)
        return out


@pytest.fixture
def fake_llm() -> FakeLLM:
    from app.clients.ollama import set_llm
    from app.core.model_router import registry

    f = FakeLLM()
    set_llm(f)
    registry.invalidate()
    registry._models = []
    yield f
    set_llm(None)
    registry.invalidate()
    registry._models = []


# ---------------------------------------------------------------- app + db


@pytest.fixture
async def client(fake_llm: FakeLLM) -> AsyncIterator[Any]:
    import httpx

    from app.main import app

    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as c:
        yield c


@pytest.fixture
async def db() -> AsyncIterator[Any]:
    from app.db.session import db_session

    async with db_session() as s:
        yield s


# ---------------------------------------------------------------- contracts


class Contract:
    def __init__(self) -> None:
        import yaml
        from referencing import Registry, Resource
        from referencing.jsonschema import DRAFT202012

        cdir = ROOT / "contracts"
        self.docs: dict[str, Any] = {}
        resources = []
        for name in ("message.schema.json", "ws_events.json", "intent.schema.json"):
            d = json.loads((cdir / name).read_text())
            self.docs[name] = d
            resources.append((name, Resource.from_contents(d, default_specification=DRAFT202012)))
        for name in ("openapi.yaml", "ocr_api.yaml"):
            d = yaml.safe_load((cdir / name).read_text())
            self.docs[name] = d
            resources.append((name, Resource.from_contents(d, default_specification=DRAFT202012)))
        self.registry = Registry().with_resources(resources)

    def validate(self, instance: Any, ref: str) -> None:
        """ref like 'ws_events.json#/$defs/Call' or 'openapi.yaml#/components/schemas/LoanSimulation'."""
        from jsonschema import Draft202012Validator

        file, _, pointer = ref.partition("#")
        schema = {"$ref": ref}
        v = Draft202012Validator(schema, registry=self.registry, format_checker=Draft202012Validator.FORMAT_CHECKER)
        errs = sorted(v.iter_errors(instance), key=lambda e: e.path)
        assert not errs, f"{ref}: " + "; ".join(f"{list(e.path)}: {e.message}" for e in errs[:5])

    def event(self, ev: dict[str, Any]) -> None:
        self.validate(ev, "ws_events.json")


@pytest.fixture(scope="session")
def contract() -> Contract:
    return Contract()
