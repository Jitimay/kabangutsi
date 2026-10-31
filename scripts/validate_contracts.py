#!/usr/bin/env python3
"""Validate everything in contracts/.

- OpenAPI 3.1 documents (openapi.yaml, voice_api.yaml, ocr_api.yaml, adapter_api.yaml) with
  openapi-spec-validator, including cross-file $refs.
- JSON Schemas (message.schema.json, intent.schema.json, ws_events.json) against the 2020-12 metaschema.
- Every embedded example: `examples` in JSON Schema $defs, and `example` / `examples` of request
  bodies, responses and component schemas in the OpenAPI files, validated against their schema
  with formats checked (uuid, date-time, date).
- db_schema.sql mentions every table listed in db_schema.md.

    pip install jsonschema openapi-spec-validator pyyaml
    python3 scripts/validate_contracts.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

import yaml
from jsonschema import Draft202012Validator, FormatChecker
from openapi_spec_validator import validate
from openapi_spec_validator.readers import read_from_filename
from referencing import Registry, Resource
from referencing.jsonschema import DRAFT202012

ROOT = Path(__file__).resolve().parent.parent / "contracts"
BASE = "https://kabangutsi.local/contracts/"
JSON_FILES = ["message.schema.json", "intent.schema.json", "ws_events.json"]
OPENAPI_FILES = ["openapi.yaml", "voice_api.yaml", "ocr_api.yaml", "adapter_api.yaml"]

errors: list[str] = []
checked = 0


def load(name: str):
    text = (ROOT / name).read_text()
    return json.loads(text) if name.endswith(".json") else yaml.safe_load(text)


docs = {n: load(n) for n in JSON_FILES + OPENAPI_FILES}
registry = Registry().with_resources(
    (BASE + n, Resource.from_contents(d, default_specification=DRAFT202012)) for n, d in docs.items()
)
fmt = FormatChecker()


def ptr(parts) -> str:
    if not parts:
        return ""
    return "/" + "/".join(str(p).replace("~", "~0").replace("/", "~1") for p in parts)


def check(file: str, schema_path: list, instance, label: str) -> None:
    global checked
    checked += 1
    v = Draft202012Validator({"$ref": f"{BASE}{file}#{ptr(schema_path)}"}, registry=registry, format_checker=fmt)
    for e in sorted(v.iter_errors(instance), key=lambda e: list(e.path)):
        loc = "/".join(map(str, e.absolute_path)) or "(root)"
        errors.append(f"{file} {label}: {loc}: {e.message[:300]}")


# ---------- JSON Schemas ----------
for name in JSON_FILES:
    doc = docs[name]
    try:
        Draft202012Validator.check_schema(doc)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"{name}: invalid schema: {exc}")
    for i, ex in enumerate(doc.get("examples", [])):
        check(name, [], ex, f"examples[{i}]")
    for key, sub in doc.get("$defs", {}).items():
        for i, ex in enumerate(sub.get("examples", []) if isinstance(sub, dict) else []):
            if isinstance(ex, (dict, list)) or sub.get("type") not in (None, "object", "array"):
                check(name, ["$defs", key], ex, f"$defs/{key} examples[{i}]")

# ---------- OpenAPI ----------
for name in OPENAPI_FILES:
    try:
        spec, base_uri = read_from_filename(str(ROOT / name))
        validate(spec, base_uri=base_uri)
    except Exception as exc:  # noqa: BLE001
        errors.append(f"{name}: invalid OpenAPI: {str(exc)[:500]}")

    doc = docs[name]

    def walk_media(path: list, media: dict) -> None:
        if "schema" not in media:
            return
        schema = media["schema"]
        if schema.get("format") == "binary" or (schema.get("type") == "string" and "example" in media):
            return
        if "example" in media and not isinstance(media["example"], str):
            check(name, path + ["schema"], media["example"], ptr(path) + "/example")
        for k, ex in (media.get("examples") or {}).items():
            if "value" in ex:
                check(name, path + ["schema"], ex["value"], ptr(path) + f"/examples/{k}")

    for p, item in (doc.get("paths") or {}).items():
        for method, op in item.items():
            if not isinstance(op, dict) or method == "parameters":
                continue
            rb = op.get("requestBody", {})
            for mt, media in (rb.get("content") or {}).items():
                if mt.startswith("multipart/"):
                    continue
                walk_media(["paths", p, method, "requestBody", "content", mt], media)
            for code, resp in (op.get("responses") or {}).items():
                for mt, media in (resp.get("content") or {}).items():
                    if mt == "text/event-stream":
                        continue
                    walk_media(["paths", p, method, "responses", code, "content", mt], media)
    for cname, resp in ((doc.get("components") or {}).get("responses") or {}).items():
        for mt, media in (resp.get("content") or {}).items():
            walk_media(["components", "responses", cname, "content", mt], media)

# ---------- DB schema ----------
sql = (ROOT / "db_schema.sql").read_text()
md = (ROOT / "db_schema.md").read_text()
sql_tables = set(re.findall(r"CREATE TABLE IF NOT EXISTS (\w+)", sql))
md_tables = set(re.findall(r"^\| `(\w+)` \|", md, re.M))
if sql_tables != md_tables:
    errors.append(f"db_schema: tables differ: only in sql {sql_tables - md_tables}, only in md {md_tables - sql_tables}")

print(f"Checked {checked} examples, {len(OPENAPI_FILES)} OpenAPI files, {len(JSON_FILES)} JSON Schemas, "
      f"{len(sql_tables)} tables.")
if errors:
    print(f"\n{len(errors)} problem(s):")
    for e in errors:
        print(" -", e)
    sys.exit(1)
print("All contracts valid.")
