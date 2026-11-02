"""Model list and capability-based routing (F19, F20, F21).

Capabilities are read from Ollama /api/show at runtime — never hard-coded. The list is cached at most
MODELS_CACHE_SECONDS; `refresh=True` forces a re-read so a newly pulled model appears without a restart.
"""

from __future__ import annotations

import asyncio
import time
from dataclasses import dataclass
from typing import Any

from app.clients.ollama import get_llm
from app.config import get_settings
from app.core.responses import t


@dataclass
class ModelInfo:
    name: str
    family: str | None
    parameter_size: str | None
    quantization: str | None
    size_bytes: int | None
    capabilities: list[str]

    @property
    def selectable(self) -> bool:
        return "completion" in self.capabilities

    def to_api(self, default: str) -> dict[str, Any]:
        return {
            "name": self.name,
            "family": self.family,
            "parameter_size": self.parameter_size,
            "quantization": self.quantization,
            "size_bytes": self.size_bytes,
            "capabilities": self.capabilities,
            "selectable": self.selectable,
            "is_default": self.name == default,
        }


def same_model(a: str, b: str) -> bool:
    """'nomic-embed-text' == 'nomic-embed-text:latest'."""

    def norm(x: str) -> str:
        return x if ":" in x else f"{x}:latest"

    return norm(a) == norm(b)


class ModelRegistry:
    def __init__(self) -> None:
        self._models: list[ModelInfo] = []
        self._at = 0.0
        self._lock = asyncio.Lock()

    async def list(self, refresh: bool = False) -> list[ModelInfo]:
        ttl = get_settings().models_cache_seconds
        if not refresh and self._models and time.monotonic() - self._at < ttl:
            return self._models
        async with self._lock:
            if not refresh and self._models and time.monotonic() - self._at < ttl:
                return self._models
            llm = get_llm()
            tags = await llm.tags()

            async def info(tag: dict[str, Any]) -> ModelInfo:
                name = tag.get("name") or tag.get("model")
                try:
                    show = await llm.show(name)
                except Exception:  # noqa: BLE001 — a broken model must not hide the others
                    show = {}
                det = show.get("details") or tag.get("details") or {}
                caps = list(show.get("capabilities") or [])
                return ModelInfo(
                    name=name,
                    family=det.get("family"),
                    parameter_size=det.get("parameter_size"),
                    quantization=det.get("quantization_level"),
                    size_bytes=tag.get("size"),
                    capabilities=caps,
                )

            self._models = list(await asyncio.gather(*(info(tg) for tg in tags)))
            self._at = time.monotonic()
            return self._models

    async def get(self, name: str) -> ModelInfo | None:
        for m in await self.list():
            if same_model(m.name, name):
                return m
        return None

    async def default_model(self) -> str:
        s = get_settings()
        models = await self.list()
        installed = [m for m in models if m.selectable]
        for cand in [s.default_model, *s.model_preference]:
            for m in installed:
                if same_model(m.name, cand):
                    return m.name
        return installed[0].name if installed else s.default_model

    async def find_capable(self, capability: str) -> str | None:
        """First installed model of MODEL_PREFERENCE with the capability, else any installed one."""
        s = get_settings()
        models = await self.list()
        for cand in s.model_preference:
            for m in models:
                if same_model(m.name, cand) and capability in m.capabilities:
                    return m.name
        for m in models:
            if capability in m.capabilities and m.selectable:
                return m.name
        return None

    def invalidate(self) -> None:
        self._at = 0.0


registry = ModelRegistry()


@dataclass
class Route:
    requested: str
    model: str | None  # None → non-LLM fallback path
    capability: str
    reason: str | None = None  # capability_missing | model_unavailable | no_capable_model
    fallback_path: str | None = None  # ocr | stt
    notice: str | None = None

    @property
    def switched(self) -> bool:
        return self.reason is not None


def needed_capability(has_image: bool, has_audio: bool) -> str:
    if has_image:
        return "vision"
    if has_audio:
        return "audio"
    return "completion"


async def route(requested: str | None, capability: str, lang: str) -> Route:
    """Pick the model for one turn. Emitting the event and logging model_events is the caller's job."""
    try:
        req = requested or await registry.default_model()
        info = await registry.get(req)
        down = False
    except Exception:  # noqa: BLE001 — Ollama down: let the caller fall back
        req, info, down = requested or get_settings().default_model, None, True
    if info is not None and capability in info.capabilities:
        return Route(requested=req, model=info.name, capability=capability)
    if down and capability == "completion":
        # Ollama unreachable: no switch to report; NLU uses the keyword fallback, answers are extractive
        return Route(requested=req, model=None, capability=capability)
    try:
        alt = None if down else await registry.find_capable(capability)
    except Exception:  # noqa: BLE001
        alt = None
    if alt is not None:
        if info is None:
            reason = "model_unavailable"
            notice = t("notice_unavailable", lang, requested=req, used=alt)
        else:
            reason = "capability_missing"
            notice = t("notice_switch", lang, used=alt, requested=req, cap=t(f"cap_{capability}", lang))
        return Route(requested=req, model=alt, capability=capability, reason=reason, notice=notice)

    if capability == "vision":
        return Route(
            requested=req,
            model=None,
            capability=capability,
            reason="no_capable_model",
            fallback_path="ocr",
            notice=t("notice_ocr", lang),
        )
    if capability == "audio":
        return Route(
            requested=req,
            model=None,
            capability=capability,
            reason="no_capable_model",
            fallback_path="stt",
            notice=t("notice_stt", lang),
        )
    return Route(
        requested=req,
        model=None,
        capability=capability,
        reason="model_unavailable",
        notice=t("notice_unavailable", lang, requested=req, used="—"),
    )
