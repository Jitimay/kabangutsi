"""Shared types between the orchestrator and the intent handlers."""

from __future__ import annotations

from collections.abc import AsyncIterator, Callable
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy.ext.asyncio import AsyncSession

from app.schemas.intent import Intent


@dataclass
class TurnContext:
    db: AsyncSession
    call: dict[str, Any]  # contract Call (ws_events.json#/$defs/Call)
    state: str  # sessions.state before this turn ("idle", "card_block.awaiting_pin", ...)
    context: dict[str, Any]  # sessions.context_json (never contains a PIN or date of birth)
    text: str  # customer text for this turn (raw; only handlers that own a state get PIN/DOB turns)
    lang: str  # reply language
    intent: Intent | None  # None when the turn bypassed NLU (state owned by a handler)
    model: str | None  # LLM routed for this turn; None = no LLM available / non-LLM path
    customer_turn_id: str

    @property
    def call_id(self) -> str:
        return self.call["id"]

    @property
    def channel(self) -> str:
        return self.call["channel"]

    @property
    def phone(self) -> str | None:
        return self.call["phone"]


@dataclass
class HandlerResult:
    text: str
    short_text: str | None = None  # None → derived from text (≤160)
    actions: list[dict[str, Any]] = field(default_factory=list)  # message.schema.json#/$defs/Action
    attachments: list[dict[str, Any]] = field(default_factory=list)
    expected_input: str = "text"  # text|pin|date_of_birth|account_number|confirmation|menu_choice|none
    state: str = "idle"  # next sessions.state
    context: dict[str, Any] | None = None  # replaces sessions.context_json when not None
    handoff_reason: str | None = None  # set → orchestrator queues the call (agents.handoff.request_handoff)
    end_session: bool = False
    model_used: str | None = None
    # Streaming LLM answers (RAG): orchestrator forwards tokens; each finished sentence passes sentence_ok
    # (grounding check) or is dropped; if nothing survives, fallback_text is used.
    stream: AsyncIterator[str] | None = None
    sentence_ok: Callable[[str], bool] | None = None
    fallback_text: str | None = None
    intent_override: str | None = None  # e.g. continuing a flow: report this intent on the reply
