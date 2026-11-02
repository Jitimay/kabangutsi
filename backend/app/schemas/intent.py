"""Pydantic mirror of contracts/intent.schema.json (extra keys forbidden, so a model cannot return a PIN field)."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

IntentName = Literal[
    "product_info", "account_opening", "card_block", "loan_info", "complaint", "branch_info", "handoff", "other"
]
Lang = Literal["fr", "en", "rn"]
Urgency = Literal["low", "medium", "high", "critical"]
CardIssue = Literal["lost", "stolen", "blocked", "damaged", "swallowed_by_atm", "fraud_suspected"]
ComplaintCategory = Literal["fees", "card", "loan", "account", "service_quality", "mobile_banking", "atm", "other"]


class Entities(BaseModel):
    model_config = ConfigDict(extra="forbid")

    province: str | None = None
    town: str | None = None
    branch_name: str | None = None
    product: str | None = None
    loan_amount: int | None = Field(default=None, ge=0)
    term_months: int | None = Field(default=None, ge=1, le=360)
    card_last4: str | None = Field(default=None, pattern=r"^[0-9]{4}$")
    card_issue: CardIssue | None = None
    complaint_category: ComplaintCategory | None = None
    ticket_number: str | None = Field(default=None, pattern=r"^TCK-[0-9]{4}-[0-9]{5}$")
    urgency: Urgency | None = None
    topic: str | None = Field(default=None, max_length=120)

    def compact(self) -> dict:
        """Contract form: omit keys that are not mentioned."""
        return self.model_dump(exclude_none=True)


class Intent(BaseModel):
    model_config = ConfigDict(extra="forbid")

    intent: IntentName
    lang: Lang
    entities: Entities
    confidence: float = Field(ge=0, le=1)
    frustration: float = Field(ge=0, le=1)

    def as_contract(self) -> dict:
        return {
            "intent": self.intent,
            "lang": self.lang,
            "entities": self.entities.compact(),
            "confidence": self.confidence,
            "frustration": self.frustration,
        }


def llm_format_schema() -> dict:
    """JSON schema given to Ollama `format` (structured output). Entities as plain optional fields."""
    return {
        "type": "object",
        "required": ["intent", "lang", "entities", "confidence", "frustration"],
        "properties": {
            "intent": {"type": "string", "enum": list(IntentName.__args__)},
            "lang": {"type": "string", "enum": ["fr", "en", "rn"]},
            "entities": {
                "type": "object",
                "properties": {
                    "province": {"type": "string"},
                    "town": {"type": "string"},
                    "branch_name": {"type": "string"},
                    "product": {"type": "string"},
                    "loan_amount": {"type": "integer"},
                    "term_months": {"type": "integer"},
                    "card_last4": {"type": "string"},
                    "card_issue": {"type": "string", "enum": list(CardIssue.__args__)},
                    "complaint_category": {"type": "string", "enum": list(ComplaintCategory.__args__)},
                    "ticket_number": {"type": "string"},
                    "urgency": {"type": "string", "enum": list(Urgency.__args__)},
                    "topic": {"type": "string"},
                },
            },
            "confidence": {"type": "number", "minimum": 0, "maximum": 1},
            "frustration": {"type": "number", "minimum": 0, "maximum": 1},
        },
    }
