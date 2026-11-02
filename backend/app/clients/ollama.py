"""Ollama HTTP client (REST /api/*). Thin on purpose so tests can swap it for a fake.

All calls go to the local Ollama container; nothing leaves the machine.
"""

from __future__ import annotations

import json
from collections.abc import AsyncIterator
from typing import Any

import httpx

from app.config import get_settings


class LLMError(Exception):
    pass


class OllamaClient:
    def __init__(self, base_url: str | None = None, timeout: float | None = None) -> None:
        s = get_settings()
        self.base_url = (base_url or s.ollama_url).rstrip("/")
        self.timeout = timeout or s.llm_timeout_seconds
        self.keep_alive = s.ollama_keep_alive

    def _client(self, timeout: float | None = None) -> httpx.AsyncClient:
        return httpx.AsyncClient(base_url=self.base_url, timeout=timeout or self.timeout)

    async def tags(self) -> list[dict[str, Any]]:
        async with self._client(10) as c:
            r = await c.get("/api/tags")
            r.raise_for_status()
            return r.json().get("models", [])

    async def make_room(self, model: str) -> None:
        """OLLAMA_EXCLUSIVE: unload every other loaded chat model before using `model` (the embedding model
        stays). On this 16 GB CPU machine two chat models do not fit next to a desktop: the G1 check saw the
        kernel OOM killer stop gemma4:e2b while gemma:2b was loaded, and 3/3 successes once it was unloaded.
        Best effort: any error is ignored and the call goes ahead."""
        s = get_settings()
        if not s.ollama_exclusive:
            return

        def norm(x: str) -> str:
            return x if ":" in x else f"{x}:latest"

        try:
            async with self._client(10) as c:
                r = await c.get("/api/ps")
                r.raise_for_status()
                for m in r.json().get("models", []):
                    name = m.get("name") or m.get("model") or ""
                    if norm(name) in (norm(model), norm(s.embed_model)):
                        continue
                    await c.post("/api/generate", json={"model": name, "keep_alive": 0})
        except (httpx.HTTPError, ValueError):
            pass

    async def show(self, name: str) -> dict[str, Any]:
        async with self._client(10) as c:
            r = await c.post("/api/show", json={"model": name})
            r.raise_for_status()
            return r.json()

    def _body(
        self,
        model: str,
        messages: list[dict[str, Any]],
        *,
        stream: bool,
        format: dict | str | None,
        temperature: float,
        num_predict: int | None,
        think: bool | None,
    ) -> dict[str, Any]:
        body: dict[str, Any] = {
            "model": model,
            "messages": messages,
            "stream": stream,
            "keep_alive": self.keep_alive,
            "options": {"temperature": temperature},
        }
        if num_predict:
            body["options"]["num_predict"] = num_predict
        if format is not None:
            body["format"] = format
        if think is not None:
            body["think"] = think
        return body

    async def chat(
        self,
        model: str,
        messages: list[dict[str, Any]],
        *,
        format: dict | str | None = None,
        temperature: float = 0.2,
        num_predict: int | None = None,
        think: bool | None = None,
        timeout: float | None = None,
    ) -> str:
        body = self._body(
            model, messages, stream=False, format=format, temperature=temperature, num_predict=num_predict, think=think
        )
        await self.make_room(model)
        try:
            async with self._client(timeout) as c:
                r = await c.post("/api/chat", json=body)
                if r.status_code == 400 and think is not None:
                    # Models without thinking support reject the flag: retry without it
                    body.pop("think", None)
                    r = await c.post("/api/chat", json=body)
                r.raise_for_status()
                return r.json().get("message", {}).get("content", "")
        except httpx.HTTPError as e:
            raise LLMError(f"ollama chat failed: {e!r}") from e

    async def chat_stream(
        self,
        model: str,
        messages: list[dict[str, Any]],
        *,
        temperature: float = 0.2,
        num_predict: int | None = None,
        think: bool | None = None,
        timeout: float | None = None,
    ) -> AsyncIterator[str]:
        body = self._body(
            model, messages, stream=True, format=None, temperature=temperature, num_predict=num_predict, think=think
        )
        await self.make_room(model)
        try:
            async with self._client(timeout) as c:
                async with c.stream("POST", "/api/chat", json=body) as r:
                    if r.status_code >= 400:
                        await r.aread()
                        raise LLMError(f"ollama chat {r.status_code}: {r.text[:200]}")
                    async for line in r.aiter_lines():
                        if not line.strip():
                            continue
                        d = json.loads(line)
                        if d.get("error"):
                            raise LLMError(d["error"])
                        delta = d.get("message", {}).get("content", "")
                        if delta:
                            yield delta
                        if d.get("done"):
                            break
        except httpx.HTTPError as e:
            raise LLMError(f"ollama stream failed: {e!r}") from e

    async def embed(self, model: str, inputs: list[str], timeout: float | None = None) -> list[list[float]]:
        try:
            async with self._client(timeout or 60) as c:
                r = await c.post("/api/embed", json={"model": model, "input": inputs, "keep_alive": self.keep_alive})
                r.raise_for_status()
                return r.json()["embeddings"]
        except (httpx.HTTPError, KeyError) as e:
            raise LLMError(f"ollama embed failed: {e!r}") from e


_client: OllamaClient | None = None


def get_llm() -> OllamaClient:
    global _client
    if _client is None:
        _client = OllamaClient()
    return _client


def set_llm(client: Any) -> None:
    """Tests inject a fake client."""
    global _client
    _client = client
