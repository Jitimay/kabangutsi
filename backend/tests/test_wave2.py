"""Wave 2: card block (F5), loans (F6), complaints (F7), account opening; G1 check: 6 request types × fr/en/rn."""

from __future__ import annotations

import asyncio
import json

import asyncpg
import pytest
from sqlalchemy import text

from app.handlers.loan_info import monthly_payment
from app.util import MASK
from tests.conftest import TEST_URL
from tests.helpers import intent_json, new_conv, say

# Demo personas (scripts/seed/demo_credentials.json; all fictional)
KEVIN = {"account": "40012345678", "pin": "1234", "dob": "1992-07-30", "card": "4821"}  # en, one Visa card
ERIC = {"account": "40012345679", "pin": "1234", "dob": "1988-04-12", "cards": ["7710", "7711"]}  # fr, two cards
CLAUDINE = {"account": "40012345670", "pin": "1234", "dob": "1990-03-14", "card": "1357"}  # rn


async def _card(db, account: str, last4: str) -> tuple[str, str | None]:
    r = (
        await db.execute(
            text(
                "SELECT c.status, c.block_reference FROM cards c JOIN customers cu ON cu.id = c.customer_id "
                "WHERE cu.account_number = :a AND c.last4 = :l"
            ),
            {"a": account, "l": last4},
        )
    ).first()
    return r.status, r.block_reference


async def _reset(db, account: str) -> None:
    await db.execute(
        text(
            "UPDATE cards SET status = 'active', blocked_at = NULL, block_reason = NULL, block_reference = NULL "
            "WHERE customer_id = (SELECT id FROM customers WHERE account_number = :a)"
        ),
        {"a": account},
    )
    await db.execute(
        text("UPDATE customers SET failed_attempts = 0, locked_until = NULL WHERE account_number = :a"), {"a": account}
    )
    await db.commit()


# ---------------------------------------------------------------- F5 card block by chat


async def test_card_block_chat_flow_pin_never_reaches_llm(client, contract, fake_llm, db):
    await _reset(db, KEVIN["account"])
    conv = await new_conv(client, "en")
    fake_llm.intent_replies = [intent_json("card_block", "en", 0.95, card_issue="lost")]
    r1 = await say(client, conv["id"], "I lost my card, please block it")
    assert r1["intent"] == "card_block" and r1["expected_input"] == "account_number"
    r2 = await say(client, conv["id"], f"My account is {KEVIN['account']}")
    assert r2["expected_input"] == "pin"
    r3 = await say(client, conv["id"], KEVIN["pin"])
    assert r3["expected_input"] == "confirmation" and "4821" in r3["text"]
    r4 = await say(client, conv["id"], "yes")
    contract.validate(r4, "message.schema.json#/$defs/OutgoingReply")
    blk = [a for a in r4["actions"] if a["type"] == "card_block"][0]
    assert blk["status"] == "done" and blk["reference"].startswith("BLK-")
    assert blk["reference"] in r4["text"]
    # DB: blocked with that reference
    assert await _card(db, KEVIN["account"], "4821") == ("blocked", blk["reference"])
    # The PIN and the account number never reached a model
    seen = fake_llm.seen_text()
    assert KEVIN["account"] not in seen and f'"{KEVIN["pin"]}"' not in seen and f": {KEVIN['pin']}" not in seen
    assert len([c for c in fake_llm.calls if c.get("format")]) <= 1  # at most the first turn went through NLU
    # Transcript: PIN turn masked
    detail = (await client.get(f"/v1/calls/{conv['id']}")).json()
    texts = [x["text"] for x in detail["transcript"] if x["speaker"] == "customer"]
    assert MASK in texts and KEVIN["pin"] not in texts
    # The PIN is not stored anywhere in the database
    conn = await asyncpg.connect(TEST_URL.replace("+asyncpg", ""))
    try:
        for tbl, col in (
            ("call_turns", "text"),
            ("call_turns", "reply_json::text"),
            ("sessions", "context_json::text"),
        ):
            n = await conn.fetchval(
                f"SELECT count(*) FROM {tbl} WHERE call_id = $1 AND {col} ~ '(^|[^0-9]){KEVIN['pin']}([^0-9]|$)'",  # noqa: S608
                __import__("uuid").UUID(conv["id"]),
            )
            assert n == 0, (tbl, col)
    finally:
        await conn.close()


async def test_card_block_dob_and_two_cards(client, fake_llm, db):
    await _reset(db, ERIC["account"])
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("card_block", "fr", 0.9, card_issue="stolen")]
    await say(client, conv["id"], f"On m'a volé ma carte, mon compte est le {ERIC['account']}")
    r = await say(client, conv["id"], "j'ai oublié mon code")
    assert r["expected_input"] == "date_of_birth"
    r = await say(client, conv["id"], "12/04/1988")
    assert "7710" in r["text"] and "7711" in r["text"]
    r = await say(client, conv["id"], "7711")
    assert r["expected_input"] == "confirmation"
    r = await say(client, conv["id"], "oui")
    assert "BLK-" in r["text"]
    assert (await _card(db, ERIC["account"], "7711"))[0] == "blocked"
    assert (await _card(db, ERIC["account"], "7710"))[0] == "active"


async def test_card_block_cancel_keeps_card(client, fake_llm, db):
    await _reset(db, CLAUDINE["account"])
    conv = await new_conv(client, "rn")
    fake_llm.intent_replies = [intent_json("card_block", "rn", 0.9, card_issue="lost")]
    r = await say(client, conv["id"], "Natakaje ikarata yanje")
    assert r["lang"] == "rn"
    await say(client, conv["id"], CLAUDINE["account"])
    await say(client, conv["id"], CLAUDINE["pin"])
    r = await say(client, conv["id"], "oya")
    assert [a for a in r["actions"] if a["type"] == "card_block"][0]["status"] == "failed"
    assert (await _card(db, CLAUDINE["account"], "1357"))[0] == "active"


async def test_three_wrong_pins_lock_and_hand_over(client, fake_llm, db):
    await _reset(db, KEVIN["account"])
    conv = await new_conv(client, "en")
    fake_llm.intent_replies = [intent_json("card_block", "en", 0.9)]
    await say(client, conv["id"], f"block my card, account {KEVIN['account']}")
    r = await say(client, conv["id"], "0000")
    assert "2" in r["text"] and r["expected_input"] == "pin"
    r = await say(client, conv["id"], "1111")
    r = await say(client, conv["id"], "2222")
    assert r["handoff"] is True
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["status"] == "queued" and call["handoff_reason"] == "identity_failed" and call["urgency"] == "high"
    locked = await db.scalar(
        text("SELECT locked_until IS NOT NULL FROM customers WHERE account_number = :a"), {"a": KEVIN["account"]}
    )
    assert locked
    # still locked through the API
    r = await client.post(
        "/v1/cards/block",
        json={"account_number": KEVIN["account"], "pin": KEVIN["pin"], "reason": "lost", "lang": "en"},
    )
    assert r.status_code == 423 and r.json()["code"] == "locked"
    await _reset(db, KEVIN["account"])


async def test_card_block_api_two_steps(client, contract, db):
    await _reset(db, KEVIN["account"])
    r = await client.post(
        "/v1/cards/block", json={"account_number": KEVIN["account"], "pin": "9999", "reason": "lost", "lang": "en"}
    )
    assert r.status_code == 403 and r.json() == {
        "code": "identity_failed",
        "message": r.json()["message"],
        "details": {"attempts_left": 2},
    }
    r = await client.post(
        "/v1/cards/block",
        json={
            "account_number": KEVIN["account"],
            "pin": None,
            "date_of_birth": KEVIN["dob"],
            "reason": "lost",
            "lang": "en",
        },
    )
    assert r.status_code == 200, r.text
    pend = r.json()
    contract.validate(pend, "openapi.yaml#/components/schemas/CardBlockPending")
    assert (await _card(db, KEVIN["account"], "4821"))[0] == "active"  # nothing blocked yet
    r = await client.post(f"/v1/cards/block/{pend['confirmation_id']}/confirm")
    assert r.status_code == 200
    contract.validate(r.json(), "openapi.yaml#/components/schemas/CardBlockResult")
    assert (await _card(db, KEVIN["account"], "4821")) == ("blocked", r.json()["reference"])
    # both PIN and DOB → 422; the PIN is not echoed back
    r = await client.post(
        "/v1/cards/block",
        json={
            "account_number": KEVIN["account"],
            "pin": "4321",
            "date_of_birth": KEVIN["dob"],
            "reason": "lost",
            "lang": "en",
        },
    )
    assert r.status_code == 422 and "4321" not in r.text
    await _reset(db, KEVIN["account"])


async def test_card_block_confirmation_expires(client, db):
    await _reset(db, KEVIN["account"])
    r = await client.post(
        "/v1/cards/block",
        json={"account_number": KEVIN["account"], "pin": KEVIN["pin"], "reason": "lost", "lang": "fr"},
    )
    cid = r.json()["confirmation_id"]
    await db.execute(
        text("UPDATE card_block_requests SET expires_at = now() - interval '1 minute' WHERE id = :id"), {"id": cid}
    )
    await db.commit()
    r = await client.post(f"/v1/cards/block/{cid}/confirm")
    assert r.status_code == 410 and r.json()["code"] == "expired"
    assert (await _card(db, KEVIN["account"], "4821"))[0] == "active"


# ---------------------------------------------------------------- F6 loans


def test_annuity_matches_hand_computed_example():
    # 5 000 000 FBu, 16 %/year, 24 months: r = 0.01333…, (1+r)^24 = 1.374219…, P·r/(1-(1+r)^-24) = 244 816.47 → 244 816
    assert monthly_payment(5_000_000, 16.0, 24) == 244_816
    assert monthly_payment(1_200_000, 0.0, 12) == 100_000
    assert monthly_payment(1_000_000, 12.0, 12) == 88_849  # 88 848.79 → half up


async def test_simulate_endpoint(client, contract):
    r = await client.post(
        "/v1/loans/simulate", json={"product_id": "business_loan", "amount": 5000000, "term_months": 24, "lang": "fr"}
    )
    assert r.status_code == 200
    sim = r.json()
    contract.validate(sim, "openapi.yaml#/components/schemas/LoanSimulation")
    assert (sim["monthly_payment"], sim["total_payment"], sim["total_interest"]) == (244816, 5875584, 875584)
    assert "244 816 FBu" in sim["explanation"]
    r = await client.post(
        "/v1/loans/simulate",
        json={"product_id": "business_loan", "amount": 99_000_000, "term_months": 24, "lang": "fr"},
    )
    assert r.status_code == 422 and r.json()["code"] == "out_of_range" and r.json()["details"]["field"] == "amount"
    r = await client.post(
        "/v1/loans/simulate", json={"product_id": "nope", "amount": 1, "term_months": 2, "lang": "fr"}
    )
    assert r.status_code == 404


async def test_loan_products_in_three_languages(client, contract):
    for lang in ("fr", "en", "rn"):
        items = (await client.get("/v1/loan-products", params={"lang": lang})).json()["items"]
        assert len(items) == 6
        for p in items:
            contract.validate(p, "openapi.yaml#/components/schemas/LoanProduct")


async def test_loan_by_chat_over_two_turns(client, fake_llm):
    conv = await new_conv(client, "fr")
    r = await say(client, conv["id"], "Je voudrais un crédit commerce")
    assert "Crédit commerce" in r["text"] and "16" in r["text"]
    r = await say(client, conv["id"], "5 millions sur 24 mois")
    assert "244 816" in r["text"]
    act = [a for a in r["actions"] if a["type"] == "loan_simulation"][0]
    assert act["data"]["monthly_payment"] == 244816


# ---------------------------------------------------------------- F7 complaints


async def test_complaint_creates_ticket_with_event(client, contract, fake_llm):
    conv = await new_conv(client, "fr", phone="+25779000102")
    conn = await asyncpg.connect(TEST_URL.replace("+asyncpg", ""))
    got: list[dict] = []
    await conn.add_listener("kabangutsi_events", lambda *a: got.append(json.loads(a[3])))
    try:
        fake_llm.intent_replies = [intent_json("complaint", "fr", 0.9, complaint_category="atm")]
        r = await say(
            client,
            conv["id"],
            "Je veux faire une réclamation : le guichet automatique de Gitega a avalé ma carte hier soir",
        )
        await asyncio.sleep(0.2)
    finally:
        await conn.close()
    act = [a for a in r["actions"] if a["type"] == "ticket_created"][0]
    assert act["reference"] in r["text"]
    created = [e for e in got if e["type"] == "ticket.created"]
    assert created and created[0]["data"]["number"] == act["reference"]
    contract.event(created[0])
    for e in got:
        contract.event(e)
    tk = (await client.get(f"/v1/tickets/{act['reference']}")).json()
    contract.validate(tk, "ws_events.json#/$defs/Ticket")
    assert tk["category"] == "atm" and tk["phone"] == "+25779000102" and tk["customer_name"] == "Jean-Bosco Ndikumana"


async def test_short_complaint_asks_details_then_creates(client, fake_llm):
    conv = await new_conv(client, "en")
    fake_llm.intent_replies = [intent_json("complaint", "en", 0.9)]
    r = await say(client, conv["id"], "I want to complain")
    assert r["actions"] == []
    r = await say(client, conv["id"], "You charged me fees twice this month on my account")
    assert r["actions"][0]["type"] == "ticket_created"


async def test_ticket_status_follow_up_and_patch(client, contract):
    r = await client.post(
        "/v1/tickets",
        json={
            "phone": "+25779000110",
            "category": "atm",
            "urgency": "medium",
            "description": "Le guichet automatique de Gitega a avalé ma carte.",
            "lang": "fr",
        },
    )
    assert r.status_code == 201
    tk = r.json()
    contract.validate(tk, "ws_events.json#/$defs/Ticket")
    r = await client.patch(f"/v1/tickets/{tk['id']}", json={"status": "in_progress", "assigned_to": "agent-01"})
    assert r.json()["status"] == "in_progress" and r.json()["assigned_to"] == "agent-01"
    conv = await new_conv(client, "fr")
    r = await say(client, conv["id"], f"Où en est mon ticket {tk['number']} ?")
    assert tk["number"] in r["text"] and "en cours" in r["text"]
    lst = (await client.get("/v1/tickets", params={"status": "in_progress"})).json()
    assert tk["id"] in [x["id"] for x in lst["items"]]


# ---------------------------------------------------------------- G1: the 6 request types by chat, fr / en / rn

CASES = {
    "product_info": {
        "fr": "Quels sont les frais de la carte Visa ?",
        "en": "What are the fees for the Visa debit card?",
        "rn": "Amafaranga yo gukoresha ikarata ya Visa ni angahe?",
    },
    "account_opening": {
        "fr": "Quels documents faut-il pour ouvrir un compte ?",
        "en": "What documents do I need to open an account?",
        "rn": "Ivyangombwa bisabwa kwugurura konti ni ibihe?",
    },
    "card_block": {
        "fr": "J'ai perdu ma carte, il faut la bloquer",
        "en": "I lost my card, please block it",
        "rn": "Natakaje ikarata yanje, nimuyihagarike",
    },
    "loan_info": {
        "fr": "Je voudrais un crédit commerce de 5 millions sur 24 mois",
        "en": "I want a business loan of 5 million over 24 months",
        "rn": "Ndashaka ingurane y'ubudandaji ya miliyoni 5 mu mezi 24",
    },
    "complaint": {
        "fr": "Je veux faire une réclamation, on m'a prélevé des frais deux fois ce mois",
        "en": "I want to make a complaint, you charged me fees twice this month",
        "rn": "Ndashaka gutanga ikirego, bankuyeko amafaranga kabiri uku kwezi",
    },
    "branch_info": {
        "fr": "Quels sont les horaires de l'agence de Ngozi ?",
        "en": "What are the Ngozi branch opening hours?",
        "rn": "Ishami rya Ngozi ryugurura ryari?",
    },
}


@pytest.mark.parametrize("lang", ["fr", "en", "rn"])
@pytest.mark.parametrize("intent", list(CASES))
async def test_six_request_types_keyword_only(client, contract, fake_llm, intent, lang):
    """Model returns garbage: the keyword NLU alone must still serve all 6 request types in all 3 languages."""
    conv = await new_conv(client, lang)
    r = await say(client, conv["id"], CASES[intent][lang])
    contract.validate(r, "message.schema.json#/$defs/OutgoingReply")
    assert r["intent"] == intent, r
    assert r["lang"] == lang, r
    assert r["text"] and len(r["short_text"]) <= 160
    if intent == "loan_info":
        assert "244" in r["text"]
    if intent == "complaint":
        assert "TCK-" in r["text"]
    if intent == "card_block":
        assert r["expected_input"] == "account_number"


async def test_stray_pin_is_masked_and_never_sent_to_a_model(client, fake_llm):
    conv = await new_conv(client, "en")
    n_before = len(fake_llm.calls)
    r = await say(client, conv["id"], "4821")
    assert "never send your PIN" in r["text"]
    assert len(fake_llm.calls) == n_before
    detail = (await client.get(f"/v1/calls/{conv['id']}")).json()
    assert [x["text"] for x in detail["transcript"] if x["speaker"] == "customer"] == [MASK]


async def test_strong_keywords_beat_a_wrong_confident_model(client, fake_llm):
    """Live finding: gemma:2b returned account_opening 0.9 for 'I lost my card, please block it'."""
    conv = await new_conv(client, "en")
    fake_llm.intent_replies = [intent_json("account_opening", "en", 0.95)]
    r = await say(client, conv["id"], "I lost my card, please block it")
    assert r["intent"] == "card_block" and r["expected_input"] == "account_number"
