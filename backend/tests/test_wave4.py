"""Wave 4: handoff + summary (F9), queue claim locking (F10), agent assist (F11), stats (F12), frustration (F13),
channel inbound (adapters), WebSocket."""

from __future__ import annotations

import asyncio
import json
import time

import asyncpg
import pytest

from app.agents import assist
from tests.conftest import TEST_URL
from tests.helpers import inbound, intent_json, new_conv, say


async def _queued(client, fake_llm, lang="fr", text="Je veux parler à un conseiller") -> dict:
    conv = await new_conv(client, lang)
    await say(client, conv["id"], "Quels sont les horaires de l'agence de Gitega ?")
    r = await say(client, conv["id"], text)
    assert r["handoff"] is True, r
    return conv


class Listener:
    def __init__(self) -> None:
        self.events: list[dict] = []
        self.conn = None

    async def __aenter__(self) -> Listener:
        self.conn = await asyncpg.connect(TEST_URL.replace("+asyncpg", ""))
        await self.conn.add_listener("kabangutsi_events", lambda *a: self.events.append(json.loads(a[3])))
        return self

    async def __aexit__(self, *exc) -> None:
        await asyncio.sleep(0.15)
        await self.conn.close()

    def of(self, type_: str) -> list[dict]:
        return [e for e in self.events if e["type"] == type_]


# ---------------------------------------------------------------- F9 handoff


async def test_handoff_on_request_with_summary_and_transcript(client, contract, fake_llm):
    fake_llm.answer = "Le client demande les horaires de Gitega puis veut parler à un conseiller."
    async with Listener() as ev:
        conv = await _queued(client, fake_llm)
    hand = ev.of("call.handoff_requested")
    assert hand, [e["type"] for e in ev.events]
    contract.event(hand[0])
    d = hand[0]["data"]
    assert d["reason"] == "customer_request" and d["summary"].startswith("Motif : le client demande un conseiller")
    # the AI summary replaces the code summary on the call once the model answers
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["summary"] == fake_llm.answer
    assert [x["speaker"] for x in d["transcript"]][:2] == ["ai", "customer"]
    for e in ev.events:
        contract.event(e)
    q = (await client.get("/v1/calls/queue")).json()["items"]
    assert conv["id"] in [c["id"] for c in q]


async def test_handoff_summary_falls_back_to_code_when_model_down(client, fake_llm):
    conv = await new_conv(client, "en")
    await say(client, conv["id"], "What documents do I need to open an account?")
    fake_llm.fail = True
    r = await client.post(f"/v1/conversations/{conv['id']}/handoff", json={"reason": "customer_request"})
    assert r.status_code == 200 and r.json()["handoff"] is True
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["summary"].startswith("Motif : le client demande un conseiller")
    r = await client.post(f"/v1/conversations/{conv['id']}/handoff", json={})
    assert r.status_code == 409


async def test_summary_never_contains_account_number(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("card_block", "fr")]
    await say(client, conv["id"], "Bloquez ma carte")
    await say(client, conv["id"], "40012345678")
    await say(client, conv["id"], "Je veux parler à un conseiller")
    prompts = json.dumps([c for c in fake_llm.calls if not c.get("format")], ensure_ascii=False)
    assert "40012345678" not in prompts
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert "40012345678" not in (call["summary"] or "")


@pytest.mark.parametrize(
    "lang,text",
    [
        ("fr", "C'est inadmissible, vous êtes des voleurs, j'en ai assez !!"),
        ("en", "This is unacceptable, you are thieves, I am furious!!"),
        ("rn", "Ndarakaye cane, mwanyibye amafaranga!!"),
    ],
)
async def test_angry_caller_is_handed_over_with_high_urgency(client, fake_llm, lang, text):
    conv = await new_conv(client, lang)
    r = await say(client, conv["id"], text)
    assert r["handoff"] is True and r["lang"] == lang
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["handoff_reason"] == "frustration" and call["urgency"] in ("high", "critical")
    assert call["frustration"] >= 0.7


async def test_two_low_confidence_turns_hand_over(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("other", "fr", 0.2)] * 4
    r1 = await say(client, conv["id"], "euh je sais pas trop comment dire ça")
    assert r1["handoff"] is False
    r2 = await say(client, conv["id"], "bon enfin vous voyez ce que je veux dire")
    assert r2["handoff"] is True
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["handoff_reason"] == "low_confidence"


# ---------------------------------------------------------------- F10 queue


async def test_concurrent_claims_never_both_win(client, contract, fake_llm):
    for _ in range(5):
        conv = await _queued(client, fake_llm)
        r1, r2 = await asyncio.gather(
            client.post(f"/v1/calls/{conv['id']}/claim", json={"agent_id": "agent-01"}),
            client.post(f"/v1/calls/{conv['id']}/claim", json={"agent_id": "agent-02"}),
        )
        codes = sorted([r1.status_code, r2.status_code])
        assert codes == [200, 409], (r1.text, r2.text)
        win = r1 if r1.status_code == 200 else r2
        contract.validate(win.json(), "openapi.yaml#/components/schemas/CallDetail")
        lose = r2 if win is r1 else r1
        assert lose.json()["code"] == "already_claimed"


async def test_queue_order_urgency_then_time(client, fake_llm):
    calm = await _queued(client, fake_llm)
    angry = await new_conv(client, "en")
    await say(client, angry["id"], "This is unacceptable, you are thieves, I am furious!!")
    ids = [c["id"] for c in (await client.get("/v1/calls/queue")).json()["items"]]
    assert ids.index(angry["id"]) < ids.index(calm["id"])


async def test_agent_conversation_end_to_end(client, contract, fake_llm):
    conv = await _queued(client, fake_llm)
    r = await client.post(f"/v1/calls/{conv['id']}/claim", json={"agent_id": "agent-03"})
    assert r.status_code == 200
    # customer writes while with the agent: stored, system reply, 409 for the app API
    r = await client.post(
        f"/v1/conversations/{conv['id']}/messages", json={"text": "Quels documents pour ouvrir un compte ?"}
    )
    assert r.status_code == 409
    sys_reply = r.json()["details"]["reply"]
    contract.validate(sys_reply, "message.schema.json#/$defs/OutgoingReply")
    assert sys_reply["speaker"] == "system"
    # agent replies; another agent cannot
    r = await client.post(f"/v1/calls/{conv['id']}/messages", json={"agent_id": "agent-01", "text": "Bonjour"})
    assert r.status_code == 403
    r = await client.post(
        f"/v1/calls/{conv['id']}/messages", json={"agent_id": "agent-03", "text": "Bonjour, je regarde."}
    )
    assert r.status_code == 201 and r.json()["speaker"] == "agent"
    contract.validate(r.json(), "message.schema.json#/$defs/OutgoingReply")
    # end by the agent
    r = await client.post(f"/v1/calls/{conv['id']}/end", json={"agent_id": "agent-03", "note": "ok"})
    assert r.status_code == 200 and r.json()["resolved_by"] == "agent" and r.json()["status"] == "ended"
    contract.validate(r.json(), "ws_events.json#/$defs/Call")
    r = await client.post(f"/v1/conversations/{conv['id']}/messages", json={"text": "allo ?"})
    assert r.status_code == 409


async def test_customer_hangs_up_while_queued_is_abandoned(client, fake_llm):
    conv = await _queued(client, fake_llm)
    r = await client.post(f"/v1/conversations/{conv['id']}/end")
    assert r.json()["resolved_by"] == "abandoned"
    conv2 = await new_conv(client)
    r = await client.post(f"/v1/conversations/{conv2['id']}/end")
    assert r.json()["resolved_by"] == "ai"


# ---------------------------------------------------------------- F11 agent assist


async def test_agent_suggestion_within_3_seconds(contract, fake_llm, client):
    conv = await _queued(client, fake_llm)
    await client.post(f"/v1/calls/{conv['id']}/claim", json={"agent_id": "agent-01"})
    async with Listener() as ev:
        t0 = time.monotonic()
        await client.post(
            f"/v1/conversations/{conv['id']}/messages", json={"text": "Quels documents pour ouvrir un compte ?"}
        )
        await assist.drain()
        took = time.monotonic() - t0
    sug = ev.of("agent.suggestion")
    assert sug and took < 3
    contract.event(sug[0])
    d = sug[0]["data"]
    assert 1 <= len(d["suggestions"]) <= 3 and d["suggestions"][0]["source_ids"]
    assert d["suggestions"][0]["lang"] == "fr"


# ---------------------------------------------------------------- F12 stats


async def test_stats_shape_and_live_update(client, contract, fake_llm):
    before = (await client.get("/v1/stats")).json()
    contract.validate(before, "ws_events.json#/$defs/Stats")
    conv = await new_conv(client, "rn", channel="phone")
    async with Listener() as ev:
        await client.post(f"/v1/conversations/{conv['id']}/end")
    after = (await client.get("/v1/stats")).json()
    assert after["total_calls"] == before["total_calls"] + 1
    assert after["resolved_by_ai"] == before["resolved_by_ai"] + 1
    assert after["by_lang"]["rn"] == before["by_lang"]["rn"] + 1
    st = ev.of("stats.updated")
    assert st and st[-1]["data"]["resolved_by_ai"] == after["resolved_by_ai"]
    contract.event(st[-1])


# ---------------------------------------------------------------- adapters


async def test_channel_inbound_sms_session_and_idempotency(client, contract, fake_llm):
    msg = inbound("sms", "+25779000101", "Ishami rya Ngozi ryugurura ryari?", phone="+25779000101")
    r1 = await client.post("/v1/channels/sms/inbound", json=msg)
    assert r1.status_code == 200, r1.text
    rep = r1.json()
    contract.validate(rep, "message.schema.json#/$defs/OutgoingReply")
    assert rep["lang"] == "rn" and rep["session_id"] == "+25779000101" and len(rep["short_text"]) <= 160
    r2 = await client.post("/v1/channels/sms/inbound", json=msg)  # retry with the same id
    assert r2.json() == rep
    msg2 = inbound("sms", "+25779000101", "Murakoze", phone="+25779000101")
    r3 = await client.post("/v1/channels/sms/inbound", json=msg2)
    assert r3.json()["conversation_id"] == rep["conversation_id"]  # same open conversation reused
    bad = {**inbound("whatsapp", "+25779000101", "x", phone="+25779000101")}
    r = await client.post("/v1/channels/sms/inbound", json=bad)
    assert r.status_code == 422


async def test_channel_inbound_with_agent_returns_200(client, fake_llm):
    msg = inbound("whatsapp", "+25779000103", "I want to talk to an agent", phone="+25779000103")
    r = await client.post("/v1/channels/whatsapp/inbound", json=msg)
    assert r.json()["handoff"] is True
    r = await client.post(
        "/v1/channels/whatsapp/inbound", json=inbound("whatsapp", "+25779000103", "hello?", phone="+25779000103")
    )
    assert r.status_code == 200 and r.json()["speaker"] == "system" and r.json()["handoff"] is True


async def test_eval_runner_shape_web_inbound(client, fake_llm):
    """T0's eval runner posts web InboundMessages with a free session id and lang=null."""
    sid = "eval-session-1"
    r = await client.post(
        "/v1/channels/web/inbound", json=inbound("web", sid, "Quels sont les frais de la carte Visa ?")
    )
    assert r.status_code == 200 and r.json()["intent"] == "product_info"


# ---------------------------------------------------------------- WebSocket


def test_websocket_agent_gets_stats_first(fake_llm, monkeypatch):
    from starlette.testclient import TestClient

    from app.db import session
    from app.main import app

    # TestClient runs the app on its own event loop: give it its own engine, then a fresh one for later tests
    monkeypatch.setattr(session, "_engine", None)
    monkeypatch.setattr(session, "_factory", None)

    with TestClient(app) as tc:
        with tc.websocket_connect("/v1/ws?role=agent&agent_id=agent-01") as ws:
            ev = ws.receive_json()
            assert ev["type"] == "stats.updated" and "queue_length" in ev["data"]
        with tc.websocket_connect("/v1/ws?role=customer&conversation_id=1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d") as ws:
            pass
        r = tc.get("/v1/health")
        assert r.status_code == 200
    session._engine, session._factory = None, None


async def test_ussd_through_t4_adapter(client, contract, fake_llm):
    """Runs only when T4's backend/channels package is importable (after the G1/G2 merge, or with
    PYTHONPATH=../../kabangutsi-t4/backend)."""
    pytest.importorskip("channels.ussd")
    sid = "ussd-sess-1"
    r = await client.post("/v1/channels/ussd/inbound", json=inbound("ussd", sid, "", phone="+25779000105"))
    assert r.status_code == 200, r.text
    menu = r.json()
    contract.validate(menu, "message.schema.json#/$defs/OutgoingReply")
    assert menu["speaker"] == "system" and "1" in menu["text"]
    r = await client.post("/v1/channels/ussd/inbound", json=inbound("ussd", sid, "5", phone="+25779000105"))
    contract.validate(r.json(), "message.schema.json#/$defs/OutgoingReply")


async def test_code_summary_has_the_intent(client, fake_llm):
    fake_llm.fail = True  # no AI summary: the code summary stays
    conv = await new_conv(client, "fr")
    await say(client, conv["id"], "Je veux parler à un conseiller")
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert "Demande : parler à un conseiller" in call["summary"]


async def test_handoff_event_does_not_wait_for_the_model(client, fake_llm, monkeypatch):
    """G1 check finding: a cold gemma4:e4b delayed call.handoff_requested by 55 s."""
    from app.agents import handoff

    async def slow_summary(*a, **k):
        await asyncio.sleep(30)

    monkeypatch.setattr(handoff, "ai_summary", slow_summary)
    monkeypatch.setattr(handoff.get_settings(), "summary_in_background", True)
    conv = await new_conv(client, "en")
    async with Listener() as ev:
        t0 = time.monotonic()
        r = await client.post(f"/v1/conversations/{conv['id']}/handoff", json={})
        assert r.status_code == 200
        await asyncio.sleep(0.3)
    assert ev.of("call.handoff_requested") and time.monotonic() - t0 < 3
    for t in list(handoff._tasks):
        t.cancel()
