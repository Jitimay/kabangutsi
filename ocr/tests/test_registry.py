import shutil

import pytest

from app import config
from app.registry import load_registry


def test_registry_matches_contract_example(contract_doc, contract):
    """ids, names, field names/types/required and route_to equal the /doc-types contract example."""
    reg = load_registry(config.DOC_TYPES_DIR)
    spec = contract_doc("ocr_api.yaml")["paths"]["/doc-types"]["get"]["responses"]["200"]["content"]["application/json"]
    expected = {d["id"]: d for d in spec["example"]["items"]}
    assert set(reg) == set(expected)
    for dt_id, dt in reg.items():
        pub = dt.public()
        contract("ocr_api.yaml", "/components/schemas/DocType", pub)
        assert pub["name"] == expected[dt_id]["name"]
        assert pub["route_to"] == expected[dt_id]["route_to"]
        assert pub["fields"] == expected[dt_id]["fields"]


def test_new_yaml_adds_type_without_code(tmp_path):
    for f in config.DOC_TYPES_DIR.glob("*.yaml"):
        shutil.copy(f, tmp_path)
    (tmp_path / "bank_statement.yaml").write_text(
        "id: bank_statement\n"
        "name: {fr: Relevé, en: Statement, rn: Icegeranyo}\n"
        "route_to: other\n"
        "detect: {keywords: [releve de compte]}\n"
        "fields:\n"
        "  - {name: account_number, type: string, required: true, labels: [No de compte]}\n")
    reg = load_registry(tmp_path)
    assert "bank_statement" in reg and len(reg) == 5


def test_registry_rejects_bad_yaml(tmp_path):
    (tmp_path / "bad.yaml").write_text("id: x\nname: {fr: a, en: b}\nroute_to: other\nfields: []\n")
    with pytest.raises(Exception):
        load_registry(tmp_path)
