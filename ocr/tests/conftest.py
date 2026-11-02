import json
import os
import sys
from pathlib import Path

import pytest
import yaml

OCR = Path(__file__).resolve().parents[1]
CONTRACTS = OCR.parent / "contracts"
SAMPLES = OCR / "samples"
BASE = "https://kabangutsi.local/contracts/"

sys.path.insert(0, str(OCR))
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")



@pytest.fixture(scope="session")
def contract():
    """contract(file, pointer, instance): validate against a contracts/ schema, refs resolved."""
    if not CONTRACTS.exists():
        pytest.skip("contracts/ not available")
    from jsonschema import Draft202012Validator
    from referencing import Registry, Resource
    from referencing.jsonschema import DRAFT202012

    reg = Registry()
    for f in ("message.schema.json", "ws_events.json", "openapi.yaml", "ocr_api.yaml"):
        text = (CONTRACTS / f).read_text()
        doc = json.loads(text) if f.endswith(".json") else yaml.safe_load(text)
        reg = reg.with_resource(BASE + f, Resource.from_contents(doc, default_specification=DRAFT202012))

    def validate(file: str, pointer: str, instance) -> None:
        v = Draft202012Validator({"$ref": f"{BASE}{file}#{pointer}"}, registry=reg)
        errors = sorted(v.iter_errors(instance), key=str)
        assert not errors, "\n".join(f"{list(e.path)}: {e.message}" for e in errors)

    return validate


@pytest.fixture(scope="session")
def contract_doc():
    def load(f: str):
        text = (CONTRACTS / f).read_text()
        return json.loads(text) if f.endswith(".json") else yaml.safe_load(text)
    return load
