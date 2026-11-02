import asyncio

import pytest

from channels.schema import InboundMessage, OutgoingReply
from channels.ussd import SCREEN_MAX, UssdAdapter
from channels.ussd_strings import Q, S

CONV = "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d"


class FakeOrchestrator:
    """Stands in for the backend pipeline: records questions, answers with a canned reply."""

    def __init__(self, text="Réponse de la base de connaissances.", expected="text", end=False):
        self.questions: list[InboundMessage] = []
        self.text, self.expected, self.end = text, expected, end

    async def __call__(self, msg: InboundMessage) -> OutgoingReply:
        self.questions.append(msg)
        return OutgoingReply(conversation_id=CONV, in_reply_to=msg.id, channel="ussd", phone=msg.phone,
                             session_id=msg.session_id, lang=msg.lang or "fr", text=self.text,
                             short_text=self.text[:160], speaker="ai", intent="other",
                             expected_input=self.expected, end_session=self.end, model_used="gemma:2b")


def dial(adapter, ask, inputs, lang="fr", session="ussd-1"):
    """Send inputs ('' = dial *123#) and return the list of replies."""
    async def run():
        out = []
        for t in inputs:
            msg = InboundMessage(channel="ussd", phone="+25779000103", session_id=session, lang=lang, text=t)
            out.append(await adapter.handle(msg, ask=ask, conversation_id=CONV))
        return out
    return asyncio.run(run())


@pytest.mark.parametrize("lang", ["fr", "en", "rn"])
def test_dial_shows_main_menu(lang, contract):
    r = dial(UssdAdapter(), FakeOrchestrator(), [""], lang=lang)[0]
    assert r.text == S["main"][lang] and r.model_used is None and not r.end_session
    assert r.speaker == "system" and r.expected_input == "menu_choice"
    contract("OutgoingReply", r.dump())


# The 6 request types: products, account opening, card block, loans, complaint, branch hours
CASES = [
    (["", "1", "1"], "product_list", {}),
    (["", "1", "2"], "open_account", {}),
    (["", "2", "1"], "block_card", {}),
    (["", "3", "1"], "loan_types", {}),
    (["", "3", "2", "5 000 000", "24"], "loan_sim", {"amount": "5 000 000", "months": 24}),
    (["", "4", "Frais prélevés deux fois"], "complaint", {"x": "Frais prélevés deux fois"}),
    (["", "5", "Ngozi"], "branch", {"x": "Ngozi"}),
]


@pytest.mark.parametrize("lang", ["fr", "en", "rn"])
@pytest.mark.parametrize("inputs,qkey,fmt", CASES)
def test_each_request_type_reaches_orchestrator(lang, inputs, qkey, fmt, contract):
    ask = FakeOrchestrator()
    replies = dial(UssdAdapter(), ask, inputs, lang=lang)
    assert len(ask.questions) == 1
    q = ask.questions[0]
    assert q.text == Q[qkey][lang].format(**fmt) and q.lang == lang and q.channel == "ussd"
    last = replies[-1]
    assert last.text.endswith(S["footer"][lang]) and len(last.text) <= SCREEN_MAX
    for r in replies:
        contract("OutgoingReply", r.dump())


def test_free_question_is_forwarded_raw():
    ask = FakeOrchestrator()
    dial(UssdAdapter(), ask, ["", "1", "3", "Frais du compte épargne ?"])
    assert ask.questions[0].text == "Frais du compte épargne ?"


def test_language_switch_to_kirundi():
    r = dial(UssdAdapter(), FakeOrchestrator(), ["", "6", "3"], lang="fr")
    assert r[-1].text == S["main"]["rn"] and r[-1].lang == "rn"


def test_invalid_choice_and_back():
    a, ask = UssdAdapter(), FakeOrchestrator()
    r = dial(a, ask, ["", "9", "2", "0"])
    assert r[1].text.startswith(S["invalid"]["fr"])
    assert r[2].text == S["card"]["fr"]
    assert r[3].text == S["main"]["fr"]
    assert ask.questions == []


def test_bad_amount_reprompts():
    ask = FakeOrchestrator()
    r = dial(UssdAdapter(), ask, ["", "3", "2", "beaucoup", "0"])
    assert r[3].text.startswith(S["invalid"]["fr"]) and S["ask_amount"]["fr"] in r[3].text
    assert r[4].text == S["main"]["fr"] and ask.questions == []


def test_exit_ends_session():
    a = UssdAdapter()
    r = dial(a, FakeOrchestrator(), ["", "00"])
    assert r[1].end_session and r[1].text == S["bye"]["fr"]
    assert "ussd-1" not in a.sessions


def test_pin_flow_zero_is_forwarded_not_menu():
    """While the backend waits for a PIN, every input (even '0') goes to the orchestrator, no footer."""
    a, ask = UssdAdapter(), FakeOrchestrator(text="Entrez votre code PIN à 4 chiffres.", expected="pin")
    r = dial(a, ask, ["", "2", "1"])
    assert r[-1].text == "Entrez votre code PIN à 4 chiffres."  # no footer
    dial(a, ask, ["0"], session="ussd-1")
    assert [q.text for q in ask.questions] == [Q["block_card"]["fr"], "0"]


def test_after_answer_zero_returns_to_menu():
    a, ask = UssdAdapter(), FakeOrchestrator()
    dial(a, ask, ["", "1", "1"])
    r = dial(a, ask, ["0"])
    assert r[0].text == S["main"]["fr"]


def test_long_answer_uses_short_text_and_fits():
    ask = FakeOrchestrator(text="Très longue réponse. " * 30)
    r = dial(UssdAdapter(), ask, ["", "1", "1"])[-1]
    assert len(r.text) <= SCREEN_MAX


def test_end_session_from_backend():
    a = UssdAdapter()
    r = dial(a, FakeOrchestrator(text="Ticket TCK-2026-00042 créé.", end=True), ["", "4", "Carte avalée"])
    assert r[-1].end_session and "ussd-1" not in a.sessions


def test_orchestrator_failure_ends_cleanly():
    async def broken(_msg):
        raise RuntimeError("ollama down")
    r = dial(UssdAdapter(), broken, ["", "1", "1"])[-1]
    assert r.end_session and r.text == S["unavailable"]["fr"]


def test_session_expiry():
    a = UssdAdapter(ttl_s=0)
    dial(a, FakeOrchestrator(), ["", "1"])
    a._expire()
    assert a.sessions == {}


def test_all_strings_exist_in_three_languages():
    for table in (S, Q):
        for key, tr in table.items():
            assert set(tr) == {"fr", "en", "rn"}, key
            assert all(v.strip() for v in tr.values()), key
    for key in ("main", "products", "card", "loans", "lang"):
        for lang in ("fr", "en", "rn"):
            assert len(S[key][lang]) <= SCREEN_MAX


def test_gateway_payload_round_trip():
    a = UssdAdapter()
    msg = a.parse_inbound({"sessionId": "AT-123", "phoneNumber": "+25779000103", "text": "3*2*500000"})
    assert msg.text == "500000" and msg.session_id == "AT-123"
    r = dial(a, FakeOrchestrator(), [""], session="AT-123")[0]
    assert a.format_outbound(r)["response"].startswith("CON Kabangutsi")
