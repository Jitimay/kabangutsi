import pytest

from channels.schema import Attachment, OutgoingReply
from channels.sms import SmsAdapter
from channels.text import fit_gsm7, gsm7_length, normalize_phone, to_gsm7
from channels.whatsapp import WhatsAppAdapter, phone_to_jid


@pytest.mark.parametrize("raw", ["+25779000101", "25779000101", "0025779000101", "79000101",
                                 "79 00 01 01", "25779000101@s.whatsapp.net", "25779000101:12@s.whatsapp.net"])
def test_normalize_phone(raw):
    assert normalize_phone(raw) == "+25779000101"


@pytest.mark.parametrize("raw", [None, "", "+33612345678", "12345", "+2577900010"])
def test_normalize_phone_rejects(raw):
    assert normalize_phone(raw) is None


def test_gsm7_keeps_gsm_accents_and_strips_others():
    assert to_gsm7("Crédit à 16 %") == "Crédit à 16 %"
    assert to_gsm7("Fenêtre ôté «ok» – très") == 'Fenetre oté "ok" - très'
    assert to_gsm7("5 000 000 FBu") == "5 000 000 FBu"


def test_fit_gsm7_limit():
    long = "Mensualité " + "très longue phrase ê " * 20
    out = fit_gsm7(long, 160)
    assert gsm7_length(out) <= 160 and out.endswith("...")
    assert all(ord(c) < 0x2000 for c in out)


def _reply(**kw):
    base = dict(conversation_id="1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d",
                in_reply_to="3b0e7f0c-9a51-4c7e-8d2a-1f6e5b4c3a21", channel="sms",
                phone="+25779000101", session_id="+25779000101", lang="fr",
                text="Texte complet de la réponse.", short_text="Réponse courte, prête pour SMS.",
                speaker="ai", intent="branch_info", expected_input="text")
    base.update(kw)
    return OutgoingReply(**base)


def test_sms_inbound_matches_contract(contract):
    msg = SmsAdapter().parse_inbound({"sender": "79000101", "text": " Ishami rya Ngozi ryugurura ryari? "})
    assert msg.phone == msg.session_id == "+25779000101"
    assert msg.text == "Ishami rya Ngozi ryugurura ryari?"
    contract("InboundMessage", msg.dump())


def test_sms_inbound_rejects_foreign_number():
    with pytest.raises(ValueError):
        SmsAdapter().parse_inbound({"sender": "+33612345678", "text": "hi"})


def test_sms_outbound_uses_short_text(contract):
    r = _reply(short_text="Agence de Gitega : lun-ven 8h-17h. Tél +25779000201 — fenêtre")
    contract("OutgoingReply", r.dump())
    out = SmsAdapter().format_outbound(r)
    assert out["to"] == "+25779000101"
    assert out["text"] == "Agence de Gitega : lun-ven 8h-17h. Tél +25779000201 - fenetre"
    assert gsm7_length(out["text"]) <= 160


def test_whatsapp_inbound_with_image(contract):
    msg = WhatsAppAdapter().parse_inbound({
        "sender": "25779000102@s.whatsapp.net", "text": "Voici ma carte d'identité",
        "attachments": [{"type": "image", "url": "/v1/files/7d1f6a52-3c1e-4f0b-9a7e-2b6f0d4c8e11",
                         "mime": "image/jpeg", "size_bytes": 284311}]})
    assert msg.channel == "whatsapp" and msg.phone == "+25779000102"
    contract("InboundMessage", msg.dump())


def test_whatsapp_image_only_allowed_but_empty_rejected():
    WhatsAppAdapter().parse_inbound({"sender": "+25779000102", "attachments": [
        {"type": "image", "url": "/v1/files/x", "mime": "image/jpeg"}]})
    with pytest.raises(ValueError):
        WhatsAppAdapter().parse_inbound({"sender": "+25779000102", "text": "  "})


def test_whatsapp_outbound_text_and_pdf(contract):
    r = _reply(channel="whatsapp", text="Voici votre simulation.", model_notice="Modèle changé.",
               attachments=[Attachment(type="pdf", url="/v1/files/abc", mime="application/pdf",
                                       name="simulation_pret.pdf")])
    contract("OutgoingReply", r.dump())
    out = WhatsAppAdapter().format_outbound(r)
    assert out["to"] == phone_to_jid("+25779000101") == "25779000101@s.whatsapp.net"
    assert out["text"].startswith("Voici votre simulation.") and "_Modèle changé._" in out["text"]
    assert out["files"] == [{"kind": "document", "url": "/v1/files/abc", "mime": "application/pdf",
                             "name": "simulation_pret.pdf"}]
