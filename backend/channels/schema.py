"""Pydantic v2 models for contracts/message.schema.json (v1.0.0).

Mirrors the contract exactly (extra fields forbidden). If T1 defines its own models in
backend/app, both must stay identical to the contract; tests in backend/channels/tests
validate these models' output against the JSON Schema itself.
"""

from __future__ import annotations

import uuid
from datetime import UTC, datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field

Lang = Literal["fr", "en", "rn"]
Channel = Literal["phone", "ussd", "sms", "whatsapp", "web"]
IntentName = Literal[
    "product_info", "account_opening", "card_block", "loan_info",
    "complaint", "branch_info", "handoff", "other",
]
ExpectedInput = Literal[
    "text", "pin", "date_of_birth", "account_number", "confirmation", "menu_choice", "none",
]
LANGS: tuple[Lang, ...] = ("fr", "en", "rn")
PHONE_PATTERN = r"^\+257[0-9]{8}$"


def new_id() -> str:
    return str(uuid.uuid4())


def now_ts() -> str:
    return datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Attachment(_Strict):
    type: Literal["image", "audio", "pdf"]
    url: str
    mime: str
    name: str | None = None
    size_bytes: int | None = Field(default=None, ge=0)
    duration_ms: int | None = Field(default=None, ge=0)

    def dump(self) -> dict[str, Any]:
        # optional keys are omitted rather than sent as null (schema types them as non-null)
        return self.model_dump(exclude_none=True)


class InboundMessage(_Strict):
    id: str = Field(default_factory=new_id)
    channel: Channel
    phone: str | None = Field(pattern=PHONE_PATTERN)
    session_id: str = Field(min_length=1, max_length=128)
    lang: Lang | None = None
    text: str = Field(default="", max_length=4000)
    attachments: list[Attachment] = Field(default_factory=list, max_length=5)
    ts: str = Field(default_factory=now_ts)

    def dump(self) -> dict[str, Any]:
        d = self.model_dump()
        d["attachments"] = [a.dump() for a in self.attachments]
        return d


class Action(_Strict):
    type: Literal[
        "card_block", "loan_simulation", "ticket_created", "handoff",
        "document_extracted", "pdf_generated", "identity_check",
    ]
    status: Literal["pending", "done", "failed"]
    reference: str | None = None
    data: dict[str, Any] | None = None


class OutgoingReply(_Strict):
    id: str = Field(default_factory=new_id)
    conversation_id: str
    in_reply_to: str | None
    channel: Channel
    phone: str | None = Field(pattern=PHONE_PATTERN)
    session_id: str
    lang: Lang
    text: str
    short_text: str = Field(max_length=160)
    speaker: Literal["ai", "agent", "system"]
    intent: IntentName | None
    actions: list[Action] = Field(default_factory=list)
    attachments: list[Attachment] = Field(default_factory=list)
    expected_input: ExpectedInput
    handoff: bool = False
    end_session: bool = False
    model_used: str | None = None
    model_notice: str | None = None
    ts: str = Field(default_factory=now_ts)

    def dump(self) -> dict[str, Any]:
        d = self.model_dump()
        d["attachments"] = [a.dump() for a in self.attachments]
        d["actions"] = [a.model_dump(exclude_none=True) | {"reference": a.reference}
                        for a in self.actions]
        return d
