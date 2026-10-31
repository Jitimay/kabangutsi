import json
from pathlib import Path

import pytest

CONTRACTS = Path(__file__).resolve().parents[3] / "contracts"


@pytest.fixture(scope="session")
def contract():
    """validate(def_name, instance): checks an instance against message.schema.json#/$defs/<def>."""
    if not (CONTRACTS / "message.schema.json").exists():
        pytest.skip("contracts/ not available")
    from jsonschema import Draft202012Validator
    from referencing import Registry, Resource

    schema = json.loads((CONTRACTS / "message.schema.json").read_text())
    registry = Registry().with_resource(schema["$id"], Resource.from_contents(schema))

    def validate(def_name: str, instance: dict) -> None:
        v = Draft202012Validator({"$ref": f"{schema['$id']}#/$defs/{def_name}"}, registry=registry,
                                 format_checker=Draft202012Validator.FORMAT_CHECKER)
        errors = sorted(v.iter_errors(instance), key=str)
        assert not errors, "\n".join(e.message for e in errors)

    return validate
