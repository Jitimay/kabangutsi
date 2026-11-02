"""Request bodies (openapi.yaml components). additionalProperties: false → extra="forbid"."""

from __future__ import annotations

from datetime import date
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, model_validator

Lang = Literal["fr", "en", "rn"]
Channel = Literal["phone", "ussd", "sms", "whatsapp", "web"]
Urgency = Literal["low", "medium", "high", "critical"]
TicketCategory = Literal["fees", "card", "loan", "account", "service_quality", "mobile_banking", "atm", "other"]
TicketStatus = Literal["open", "in_progress", "resolved", "closed"]
HandoffReason = Literal[
    "customer_request", "frustration", "low_confidence", "no_answer", "identity_failed", "agent_review", "other"
]
PHONE = r"^\+257[0-9]{8}$"
UUID4 = r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Attachment(Strict):
    type: Literal["image", "audio", "pdf"]
    url: str
    mime: str
    name: str | None = None
    size_bytes: int | None = Field(default=None, ge=0)
    duration_ms: int | None = Field(default=None, ge=0)

    def dump(self) -> dict:
        return self.model_dump(exclude_none=True)


class ConversationCreate(Strict):
    channel: Literal["phone", "web"]
    phone: str | None = Field(default=None, pattern=PHONE)
    lang: Lang | None = None
    model: str | None = None


class ConversationUpdate(Strict):
    model: str | None = None
    lang: Lang | None = None

    @model_validator(mode="after")
    def _one(self) -> ConversationUpdate:
        if self.model is None and self.lang is None:
            raise ValueError("model or lang is required")
        return self


class MessageJson(Strict):
    text: str | None = Field(default=None, max_length=4000)
    lang: Lang | None = None
    model: str | None = None
    voice: bool = False
    attachments: list[Attachment] = Field(default_factory=list, max_length=5)


class HandoffBody(Strict):
    reason: HandoffReason = "customer_request"


class InboundMessage(Strict):
    id: str = Field(pattern=UUID4)
    channel: Channel
    phone: str | None = Field(pattern=PHONE)
    session_id: str = Field(min_length=1, max_length=128)
    lang: Lang | None
    text: str = Field(max_length=4000)
    attachments: list[Attachment] = Field(max_length=5)
    ts: str


class CardBlockRequest(Strict):
    conversation_id: str | None = Field(default=None, pattern=UUID4)
    account_number: str = Field(pattern=r"^[0-9]{11}$")
    pin: str | None = Field(default=None, pattern=r"^[0-9]{4}$", repr=False)
    date_of_birth: date | None = Field(default=None, repr=False)
    card_last4: str | None = Field(default=None, pattern=r"^[0-9]{4}$")
    reason: Literal["lost", "stolen", "blocked", "damaged", "swallowed_by_atm", "fraud_suspected"]
    lang: Lang

    @model_validator(mode="after")
    def _exactly_one(self) -> CardBlockRequest:
        if (self.pin is None) == (self.date_of_birth is None):
            raise ValueError("exactly one of pin or date_of_birth is required")
        return self


class LoanSimulationRequest(Strict):
    product_id: str
    amount: int = Field(ge=1)
    term_months: int = Field(ge=1, le=360)
    lang: Lang
    pdf: bool = False
    conversation_id: str | None = Field(default=None, pattern=UUID4)


class TicketCreate(Strict):
    conversation_id: str | None = Field(default=None, pattern=UUID4)
    phone: str | None = Field(default=None, pattern=PHONE)
    category: TicketCategory
    urgency: Urgency
    description: str = Field(min_length=3, max_length=4000)
    lang: Lang
    attachments: list[Attachment] = Field(default_factory=list)


class TicketUpdate(Strict):
    status: TicketStatus | None = None
    urgency: Urgency | None = None
    assigned_to: str | None = None

    @model_validator(mode="after")
    def _one(self) -> TicketUpdate:
        if not self.model_fields_set:
            raise ValueError("at least one field is required")
        return self


class AgentRef(Strict):
    agent_id: str


class AgentMessage(Strict):
    agent_id: str
    text: str = Field(min_length=1, max_length=2000)
    voice: bool = False


class EndCall(Strict):
    agent_id: str
    note: str | None = Field(default=None, max_length=2000)
