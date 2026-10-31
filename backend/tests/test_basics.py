from pathlib import Path

from app.core import responses
from app.util import short_text, split_sentences


def test_migration_sql_is_the_contract():
    here = Path(__file__).resolve().parents[1] / "app/db/alembic/versions/0001_initial.sql"
    contract = Path(__file__).resolve().parents[2] / "contracts/db_schema.sql"
    assert here.read_text() == contract.read_text()


def test_every_template_has_three_languages():
    for key, entry in responses.T.items():
        assert set(entry) == {"fr", "en", "rn"}, key
        assert all(entry[lg].strip() for lg in entry), key


def test_short_text_limit():
    long = "Une phrase. " * 40
    assert len(short_text(long)) <= 160
    assert len(short_text("x" * 400)) <= 160


def test_split_sentences():
    assert split_sentences("Bonjour. Comment allez-vous ? Bien.") == ["Bonjour.", "Comment allez-vous ?", "Bien."]


def test_hours_text_matches_contract_example():
    std = {d: {"open": "08:00", "close": "17:00"} for d in ["mon", "tue", "wed", "thu", "fri"]}
    std["sat"] = {"open": "08:00", "close": "12:00"}
    std["sun"] = None
    assert responses.hours_text(std, "fr") == "Lundi–vendredi 08:00–17:00, samedi 08:00–12:00, fermé le dimanche"


async def test_health(client, contract):
    r = await client.get("/v1/health")
    assert r.status_code == 200
    contract.validate(r.json(), "openapi.yaml#/components/schemas/Health")
