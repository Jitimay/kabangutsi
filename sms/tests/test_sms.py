import json
import os
from pathlib import Path

import httpx
import pytest

from app.gateway import UNAVAILABLE, Gateway
from app.modem import Modem
from app.pdu import decode_deliver, encode_submit, gsm7_septets, pack_septets, unpack_septets, decode_gsm7
from tests.fake_modem import FakeSim800, build_deliver

ROOT = Path(__file__).resolve().parents[2]


# ---------------------------------------------------------------- PDU codec ----
def test_gsm7_packing_known_vector():
    assert pack_septets(gsm7_septets("hellohello")).hex().upper() == "E8329BFD4697D9EC37"
    packed = bytes.fromhex("E8329BFD4697D9EC37")
    assert decode_gsm7(unpack_septets(packed, 10)) == "hellohello"


def test_decode_reference_deliver_pdu():
    # Classic example from the GSM 03.40 tutorials: "How are you?" from +31641600986
    d = decode_deliver("07911326040000F0040B911346610089F60000208062917314080CC8F71D14969741F977FD07")
    assert d.sender == "+31641600986" and d.numeric and d.text == "How are you?" and d.concat is None


def test_submit_gsm7_and_ucs2():
    pdu, n = encode_submit("+25779000101", "Crédit à 16 %")
    assert pdu.startswith("0001000B915277090001F100000D")  # SUBMIT, +25779000101, GSM-7, 13 septets
    assert n == len(bytes.fromhex(pdu)) - 1
    pdu2, _ = encode_submit("+25779000101", "Fenêtre")       # ê not in GSM-7 -> UCS-2 (DCS 08)
    assert pdu2[2:].startswith("0100") and "0008" in pdu2
    with pytest.raises(ValueError):
        encode_submit("+25779000101", "x" * 161)


@pytest.mark.parametrize("text,ucs2", [("Ishami rya Ngozi ryugurura ryari?", False),
                                       ("Prêt à 16 % ? «merci»", True)])
def test_deliver_round_trip(text, ucs2):
    d = decode_deliver(build_deliver("+25779000101", text, ucs2=ucs2))
    assert (d.sender, d.text, d.ts) == ("+25779000101", text, "2026-11-02T06:15:30Z")


def test_deliver_concat_header_gsm7():
    d = decode_deliver(build_deliver("+25779000101", "partie deux", concat=(42, 2, 2)))
    assert d.concat == (42, 2, 2) and d.text == "partie deux"


def test_alphanumeric_sender():
    d = decode_deliver(build_deliver("LUMITEL", "Promo", alnum=True))
    assert not d.numeric and d.sender.startswith("LUMITEL")


def test_vendored_text_module_is_identical():
    a = (ROOT / "backend/channels/text.py").read_text().splitlines()[1:]
    b = (ROOT / "sms/app/text.py").read_text().splitlines()[1:]
    if not a:
        pytest.skip("backend/channels not in this checkout")
    assert a == b, "sms/app/text.py drifted from backend/channels/text.py"


# ---------------------------------------------------------------- gateway -------
class FakeBackend:
    def __init__(self, fail=False):
        self.got: list[dict] = []
        self.fail = fail

    def handler(self, request: httpx.Request) -> httpx.Response:
        assert request.url.path == "/v1/channels/sms/inbound"
        msg = json.loads(request.content)
        self.got.append(msg)
        if self.fail:
            return httpx.Response(503, json={"code": "unavailable"})
        return httpx.Response(200, json={"text": "long", "short_text": f"Réponse: {msg['text'][:40]} — fenêtre"})


@pytest.fixture()
def rig():
    fake = FakeSim800()
    modem = Modem(fake.device, 9600, timeout=0.05)
    modem.open()
    backend = FakeBackend()
    gw = Gateway(modem, "http://backend:8000", client=httpx.Client(transport=httpx.MockTransport(backend.handler)))
    yield fake, modem, backend, gw
    modem.close()
    fake.close()


def _decode_submit_text(pdu_hex: str) -> tuple[str, str]:
    b = bytes.fromhex(pdu_hex)[1:]   # skip empty SMSC
    ndig = b[2]
    nb = (ndig + 1) // 2
    h = b[4:4 + nb].hex().upper()
    to = "+" + "".join(h[i + 1] + h[i] for i in range(0, len(h), 2))[:ndig]
    i = 4 + nb
    dcs, udl, ud = b[i + 1], b[i + 2], b[i + 3:]
    text = ud.decode("utf-16-be") if dcs == 8 else decode_gsm7(unpack_septets(ud, udl))
    return to, text


def test_modem_init_uses_pdu_mode(rig):
    fake, modem, _, _ = rig
    assert "AT+CMGF=0" in fake.commands and modem.model == "SIMCOM_SIM800A"
    assert modem.registered() and modem.signal() == 18


def test_inbound_sms_to_backend_and_reply(rig, contract_inbound):
    fake, _, backend, gw = rig
    fake.store(build_deliver("+25779000101", "Ishami rya Ngozi ryugurura ryari?"))
    gw.poll_once()
    assert len(backend.got) == 1
    msg = backend.got[0]
    contract_inbound(msg)
    assert msg["phone"] == msg["session_id"] == "+25779000101" and msg["channel"] == "sms"
    to, text = _decode_submit_text(fake.sent[0])
    assert to == "+25779000101" and text == "Réponse: Ishami rya Ngozi ryugurura ryari? - fenetre"
    assert fake.stored == {}


def test_multipart_sms_reassembled(rig):
    fake, _, backend, gw = rig
    fake.store(build_deliver("+25779000101", "Bonjour, je voudrais ", concat=(7, 2, 1)))
    gw.poll_once()
    assert backend.got == []          # waiting for part 2
    fake.store(build_deliver("+25779000101", "bloquer ma carte.", concat=(7, 2, 2)))
    gw.poll_once()
    assert backend.got[0]["text"] == "Bonjour, je voudrais bloquer ma carte." and fake.stored == {}


def test_ignores_promo_and_foreign_numbers(rig):
    fake, _, backend, gw = rig
    fake.store(build_deliver("LUMITEL", "Promo", alnum=True))
    fake.store(build_deliver("+33612345678", "hello"))
    gw.poll_once()
    assert backend.got == [] and fake.sent == [] and fake.stored == {}


def test_backend_down_keeps_sms_and_apologizes_once(rig):
    fake, _, backend, gw = rig
    backend.fail = True
    fake.store(build_deliver("+25779000101", "Allo?"))
    gw.poll_once()
    gw.poll_once()
    assert len(backend.got) == 2 and backend.got[0]["id"] == backend.got[1]["id"]  # same id: idempotent
    assert len(fake.sent) == 1 and _decode_submit_text(fake.sent[0])[1] == UNAVAILABLE
    assert len(fake.stored) == 1                                                       # kept for retry
    backend.fail = False
    gw.poll_once()
    assert fake.stored == {} and len(fake.sent) == 2


def test_rate_limit(rig):
    fake, _, backend, gw = rig
    for i in range(7):
        fake.store(build_deliver("+25779000101", f"msg {i}"))
    gw.poll_once()
    assert len(backend.got) == 7 and len(fake.sent) == 5


# ---------------------------------------------------------------- HTTP API ------
@pytest.fixture()
def client(rig):
    os.environ["SMS_DISABLE_LOOP"] = "1"
    from fastapi.testclient import TestClient

    from app.main import app
    app.state.gateway = rig[3]
    with TestClient(app) as c:
        yield c, rig[0]
    app.state.gateway = None


REPLY = {"id": "6c7d8e9f-0a1b-4c2d-8e3f-4a5b6c7d8e9f", "conversation_id": "3c4d5e6f-7a8b-4c9d-8e1f-2a3b4c5d6e7f",
         "in_reply_to": None, "channel": "sms", "phone": "+25779000105", "session_id": "+25779000105",
         "lang": "fr", "text": "Un agent vous répond : votre carte est bloquée.",
         "short_text": "Agent: votre carte est bloquée.", "speaker": "agent", "intent": None, "actions": [],
         "attachments": [], "expected_input": "none", "handoff": False, "end_session": False,
         "model_used": None, "model_notice": None, "ts": "2026-11-02T10:05:12Z"}


def test_health(client):
    c, _ = client
    r = c.get("/health").json()
    assert r["status"] == "ok" and r["connected"] is True and "SIM800A" in r["detail"] and "18/31" in r["detail"]


def test_send(client):
    c, fake = client
    r = c.post("/send", json=REPLY)
    assert r.status_code == 202 and r.json() == {"status": "sent", "message_id": REPLY["id"]}
    assert _decode_submit_text(fake.sent[0]) == ("+25779000105", "Agent: votre carte est bloquée.")


def test_send_null_phone_422(client):
    c, _ = client
    assert c.post("/send", json=REPLY | {"phone": None}).status_code == 422
    assert c.post("/send", json={"id": "x"}).status_code == 422


def test_send_without_modem_503(client):
    c, _ = client
    from app.main import app
    app.state.gateway.modem.close()
    assert c.post("/send", json=REPLY).status_code == 503
    assert c.get("/health").json()["status"] == "degraded"
