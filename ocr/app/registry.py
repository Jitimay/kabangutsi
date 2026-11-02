"""Document type registry: one YAML per type in ocr/doc_types/. New file = new type, no code change."""

from __future__ import annotations

from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import BaseModel, ConfigDict, Field

FieldType = Literal["string", "integer", "number", "date"]
Intent = Literal["product_info", "account_opening", "card_block", "loan_info",
                 "complaint", "branch_info", "handoff", "other"]


class LocalizedText(BaseModel):
    model_config = ConfigDict(extra="forbid")
    fr: str
    en: str
    rn: str


class Validation(BaseModel):
    model_config = ConfigDict(extra="forbid")
    regex: str | None = None
    min: float | str | None = None   # number, or ISO date for date fields
    max: float | str | None = None


class LabelGroup(BaseModel):
    model_config = ConfigDict(extra="forbid")
    labels: list[str]


class FieldSpec(BaseModel):
    model_config = ConfigDict(extra="forbid")
    name: str
    type: FieldType
    required: bool
    labels: list[str] = Field(default_factory=list)
    parts: list[LabelGroup] = Field(default_factory=list)   # composite field
    source: Literal["label", "all_text"] = "label"
    pattern: str | None = None      # optional regex; group 1 (or whole match) is the value
    validate_: Validation = Field(default_factory=Validation, alias="validate")


class Detect(BaseModel):
    model_config = ConfigDict(extra="forbid")
    keywords: list[str] = Field(default_factory=list)
    fallback: bool = False


class DocType(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str
    name: LocalizedText
    route_to: Intent
    detect: Detect = Field(default_factory=Detect)
    fields: list[FieldSpec]

    def public(self) -> dict[str, Any]:
        """Shape of contracts/ocr_api.yaml DocType."""
        return {"id": self.id, "name": self.name.model_dump(), "route_to": self.route_to,
                "fields": [{"name": f.name, "type": f.type, "required": f.required} for f in self.fields]}


def load_registry(directory: Path) -> dict[str, DocType]:
    types: dict[str, DocType] = {}
    for path in sorted(directory.glob("*.yaml")):
        dt = DocType.model_validate(yaml.safe_load(path.read_text(encoding="utf-8")))
        if dt.id in types:
            raise ValueError(f"duplicate doc type id {dt.id!r} in {path.name}")
        types[dt.id] = dt
    return types
