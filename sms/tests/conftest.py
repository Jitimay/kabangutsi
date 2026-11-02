import json
from pathlib import Path

import pytest

CONTRACTS = Path(__file__).resolve().parents[2] / "contracts"


@pytest.fixture(scope="session")
def contract_inbound():
    if not (CONTRACTS / "message.schema.json").exists():
        pytest.skip("contracts/ not available")
    from jsonschema import Draft202012Validator
    from referencing import Registry, Resource

    schema = json.loads((CONTRACTS / "message.schema.json").read_text())
    reg = Registry().with_resource(schema["$id"], Resource.from_contents(schema))
    v = Draft202012Validator({"$ref": f"{schema['$id']}#/$defs/InboundMessage"}, registry=reg,
                             format_checker=Draft202012Validator.FORMAT_CHECKER)

    def check(instance):
        errs = list(v.iter_errors(instance))
        assert not errs, [e.message for e in errs]
    return check
