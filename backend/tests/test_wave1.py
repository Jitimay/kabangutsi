"""Wave 1: models (F19), router (F20, F21), language (F2), intent (F3), RAG (F4), branches (F8), SSE."""

from __future__ import annotations

import io
import json

import pytest

from app.core import keywords, nlu
from app.core.lang import choose_lang
from app.core.model_router import route
from app.rag.answer import numbers_ok
from tests.helpers import intent_json, new_conv, parse_sse, say

# ---------------------------------------------------------------- F19 / F20 / F21


async def test_models_endpoint_reads_ollama(client, contract, fake_llm):
    r = await client.get("/v1/models")
    assert r.status_code == 200
    body = r.json()
    contract.validate(body, "openapi.yaml#/components/schemas/ModelList")
    names = {m["name"]: m for m in body["models"]}
    assert names["gemma4:e4b"]["capabilities"] == ["completion", "vision", "audio", "tools", "thinking"]
    assert names["nomic-embed-text:latest"]["selectable"] is False
    assert body["default_model"] == "gemma:2b"
    # a newly pulled model appears with ?refresh=true (no restart)
    fake_llm.models.append({"name": "llama3.2:latest", "size": 1, "caps": ["completion", "tools"], "family": "llama"})
    r = await client.get("/v1/models", params={"refresh": "true"})
    assert "llama3.2:latest" in {m["name"] for m in r.json()["models"]}


async def test_models_503_when_ollama_down(client, fake_llm):
    fake_llm.fail = True
    r = await client.get("/v1/models", params={"refresh": "true"})
    assert r.status_code == 503 and r.json()["code"] == "service_unavailable"


async def test_router_switches_on_missing_capability(fake_llm):
    r = await route("gemma:2b", "vision", "en")
    assert r.model == "gemma4:e4b" and r.reason == "capability_missing"
    assert "gemma4:e4b" in r.notice and "gemma:2b" in r.notice
    assert (await route("gemma:2b", "completion", "fr")).switched is False


async def test_router_fallback_paths_when_no_model_fits(fake_llm):
    fake_llm.models = [m for m in fake_llm.models if m["name"] == "gemma:2b"]
    r = await route("gemma:2b", "vision", "fr")
    assert r.model is None and r.fallback_path == "ocr" and r.reason == "no_capable_model"
    r = await route("gemma:2b", "audio", "rn")
    assert r.model is None and r.fallback_path == "stt"


PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde\x00\x00"
    b"\x00\x0cIDATx\x9cc\xf8\x0f\x00\x00\x01\x01\x00\x05\x18\xd8N\x00\x00\x00\x00IEND\xaeB`\x82"
)


async def test_image_with_text_model_switches_and_logs(client, contract, fake_llm):
    conv = await new_conv(client, "en", model="gemma:2b")
    fake_llm.answer = "A photo of an ATM screen showing 'card retained'."
    fake_llm.intent_replies = [intent_json("card_block", "en", card_issue="swallowed_by_atm")]
    r = await client.post(
        f"/v1/conversations/{conv['id']}/messages",
        data={"text": "what does this mean?"},
        files={"image": ("atm.png", io.BytesIO(PNG), "image/png")},
    )
    assert r.status_code == 200, r.text
    reply = r.json()
    contract.validate(reply, "message.schema.json#/$defs/OutgoingReply")
    assert reply["model_notice"] and "gemma4:e4b" in reply["model_notice"]
    assert reply["model_used"] == "gemma4:e4b"
    assert reply["text"].startswith("On your image: A photo of an ATM screen")
    vision_calls = [c for c in fake_llm.calls if c.get("messages") and c["messages"][-1].get("images")]
    assert vision_calls and vision_calls[0]["model"] == "gemma4:e4b"
    detail = (await client.get(f"/v1/conversations/{conv['id']}")).json()
    contract.validate(detail, "openapi.yaml#/components/schemas/CallDetail")
    ev = detail["model_events"][0]
    assert (
        ev["requested_model"] == "gemma:2b" and ev["used_model"] == "gemma4:e4b" and ev["capability_needed"] == "vision"
    )


async def test_image_with_only_text_models_uses_ocr_fallback(client, fake_llm, monkeypatch):
    from app.clients import services

    fake_llm.models = [m for m in fake_llm.models if m["name"] != "gemma4:e4b"]

    async def fake_ocr(image, mime, doc_type=None, lang=None):
        return {
            "doc_type": "complaint_photo",
            "doc_type_confidence": 0.9,
            "fields": [],
            "needs_review": False,
            "route_to": "complaint",
            "raw_text": "ERREUR CARTE RETENUE",
            "processing_ms": 10,
            "engine": "paddleocr",
        }

    monkeypatch.setattr(services, "ocr_extract", fake_ocr)
    conv = await new_conv(client, "fr", model="gemma:2b")
    r = await client.post(
        f"/v1/conversations/{conv['id']}/messages", files={"image": ("x.png", io.BytesIO(PNG), "image/png")}
    )
    assert r.status_code == 200, r.text
    reply = r.json()
    assert "OCR" in reply["model_notice"]
    detail = (await client.get(f"/v1/conversations/{conv['id']}")).json()
    ev = detail["model_events"][0]
    assert ev["used_model"] is None and ev["fallback_path"] == "ocr" and ev["reason"] == "no_capable_model"


async def test_upload_rejects_bad_type_and_size(client):
    conv = await new_conv(client)
    r = await client.post(
        f"/v1/conversations/{conv['id']}/messages", files={"image": ("x.gif", b"GIF89a", "image/gif")}
    )
    assert r.status_code == 415 and r.json()["code"] == "unsupported_media_type"
    r = await client.post("/v1/files", files={"file": ("big.png", b"0" * (10 * 1024 * 1024 + 1), "image/png")})
    assert r.status_code == 413


async def test_file_roundtrip(client, contract):
    r = await client.post("/v1/files", files={"file": ("a.png", PNG, "image/png")})
    assert r.status_code == 201
    ref = r.json()
    contract.validate(ref, "openapi.yaml#/components/schemas/FileRef")
    got = await client.get(ref["url"])
    assert got.status_code == 200 and got.content == PNG and got.headers["content-type"] == "image/png"


# ---------------------------------------------------------------- F2 language


@pytest.mark.parametrize(
    "text,lang",
    [
        ("Ishami rya Ngozi ryugurura ryari?", "rn"),
        ("Quelles sont les heures d'ouverture de l'agence de Ngozi ?", "fr"),
        ("What time does the Ngozi branch open?", "en"),
        ("Natakaje ikarata yanje", "rn"),
    ],
)
def test_language_detection(text, lang):
    assert choose_lang(text, None, None) == lang


async def test_reply_language_follows_caller_and_switches(client, fake_llm):
    conv = await new_conv(client, "fr")
    a = await say(client, conv["id"], "Quelles sont les heures de l'agence de Ngozi ?")
    b = await say(client, conv["id"], "Ishami rya Ngozi ryugurura ryari?")
    c = await say(client, conv["id"], "What are the opening hours of the Gitega branch?")
    assert (a["lang"], b["lang"], c["lang"]) == ("fr", "rn", "en")
    assert "Ngozi" in a["text"] and "Ngozi" in b["text"] and "Gitega" in c["text"]


# ---------------------------------------------------------------- F3 intent


async def test_invalid_model_json_never_crashes(fake_llm):
    fake_llm.intent_replies = ["not json at all", '{"intent": "steal_money", "lang": "fr"}']
    res = await nlu.understand("Mon truc ne marche plus du tout depuis hier", "gemma:2b")
    assert res.source == "keyword"
    assert res.attempts == ["invalid_json:gemma:2b", "invalid_json:gemma4:e4b"]


async def test_extra_keys_from_model_are_rejected(fake_llm):
    bad = '{"intent": "card_block", "lang": "en", "entities": {"pin": "1234"}, "confidence": 0.9, "frustration": 0}'
    fake_llm.intent_replies = [bad, bad]
    res = await nlu.understand("I lost my card", "gemma:2b")
    assert res.source == "keyword" and "pin" not in res.intent.entities.compact()


async def test_valid_model_json_is_used(fake_llm):
    fake_llm.intent_replies = [intent_json("loan_info", "fr", 0.88, product="business_loan", loan_amount=5000000)]
    res = await nlu.understand("J'aimerais financer le stock de ma boutique", "gemma:2b")
    assert res.source == "llm" and res.intent.intent == "loan_info" and res.intent.entities.loan_amount == 5000000


async def test_trusted_keywords_skip_the_model(fake_llm):
    res = await nlu.understand("Je voudrais un crédit commerce de 5 millions sur 24 mois", "gemma:2b")
    assert res.intent.intent == "loan_info" and res.attempts == [] and fake_llm.calls == []


async def test_turn_works_when_ollama_is_down(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.fail = True
    from app.core.model_router import registry

    registry.invalidate()
    registry._models = []
    r = await say(client, conv["id"], "Quels documents pour ouvrir un compte ?")
    assert "CNI" in r["text"] or "carte nationale" in r["text"]


# ---------------------------------------------------------------- F4 RAG


async def test_kb_search_hybrid(client, contract):
    r = await client.get("/v1/kb/search", params={"q": "documents pour ouvrir un compte", "lang": "fr"})
    assert r.status_code == 200
    items = r.json()["items"]
    for it in items:
        contract.validate(it, "openapi.yaml#/components/schemas/KbHit")
    assert items[0]["article_id"].startswith("kb-account-opening")


def test_numbers_must_come_from_sources():
    src = ["Le dépôt minimum est de 10 000 FBu. La carte est prête en 5 jours ouvrables."]
    assert numbers_ok("Il faut 10 000 FBu pour ouvrir le compte.", src)
    assert numbers_ok("Il faut 10,000 FBu.", src)
    assert not numbers_ok("Il faut 25 000 FBu pour ouvrir le compte.", src)
    assert not numbers_ok("La carte est prête en 3 jours.", src)


async def test_invented_facts_are_dropped(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("account_opening", "fr", topic="ouvrir un compte")]
    fake_llm.answer = "Il faut un dépôt de 99 999 FBu. Le compte est ouvert en 42 jours."
    r = await say(client, conv["id"], "Que faut-il pour ouvrir un compte ?")
    assert "99" not in r["text"] and "42" not in r["text"]
    assert "10 000" in r["text"] or "CNI" in r["text"]


async def test_grounded_llm_answer_is_kept(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("account_opening", "fr")]
    fake_llm.answer = "Présentez votre CNI et deux photos. Le dépôt minimum est de 10 000 FBu."
    r = await say(client, conv["id"], "Que faut-il pour ouvrir un compte courant ?")
    assert r["text"] == fake_llm.answer and r["model_used"] == "gemma:2b"


async def test_unknown_topic_says_dont_know_and_offers_handoff(client, fake_llm):
    conv = await new_conv(client, "en")
    fake_llm.intent_replies = [intent_json("product_info", "en", 0.9)]
    r = await say(client, conv["id"], "Do you sell bitcoin futures on the Tokyo exchange?")
    assert "do not have that information" in r["text"]
    r2 = await say(client, conv["id"], "yes")
    assert r2["handoff"] is True
    call = (await client.get(f"/v1/calls/{conv['id']}")).json()["call"]
    assert call["status"] == "queued" and call["handoff_reason"] == "no_answer"


# ---------------------------------------------------------------- F8 branches


@pytest.mark.parametrize(
    "lang,text,expect",
    [
        ("fr", "Quels sont les horaires de l'agence de Ngozi ?", "Lundi"),
        ("en", "Ngozi branch hours?", "Monday"),
        ("rn", "Ishami rya Ngozi ryugurura ryari?", "wa mbere"),
    ],
)
async def test_branch_hours_three_languages(client, fake_llm, lang, text, expect):
    conv = await new_conv(client, lang)
    r = await say(client, conv["id"], text)
    assert r["lang"] == lang and "Ngozi" in r["text"] and expect in r["text"] and "+257" in r["text"]
    assert len(r["short_text"]) <= 160


async def test_branches_endpoint_typo_and_contract(client, contract):
    r = await client.get("/v1/branches", params={"province": "ngozy", "lang": "en"})
    items = r.json()["items"]
    assert [b["id"] for b in items] == ["br-ngozi"]
    contract.validate(items[0], "openapi.yaml#/components/schemas/Branch")
    r = await client.get("/v1/branches", params={"q": "Kamenge"})
    assert r.json()["items"][0]["id"] == "br-bujumbura-kamenge"


# ---------------------------------------------------------------- SSE


async def test_sse_stream_order_and_grounding(client, contract, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("account_opening", "fr")]
    fake_llm.answer = "Présentez votre CNI et deux photos. Le dépôt minimum est de 10 000 FBu. Il faut aussi 777 FBu."
    async with client.stream(
        "POST",
        f"/v1/conversations/{conv['id']}/messages",
        json={"text": "Ouvrir un compte ?"},
        headers={"Accept": "text/event-stream"},
    ) as r:
        assert r.headers["content-type"].startswith("text/event-stream")
        body = "".join([chunk async for chunk in r.aiter_text()])
    events = parse_sse(body)
    names = [n for n, _ in events]
    assert names[0] == "turn" and names[-1] == "done"
    assert names.index("token") < names.index("done")
    contract.validate(events[0][1], "ws_events.json#/$defs/Turn")
    done = events[-1][1]
    contract.validate(done, "message.schema.json#/$defs/OutgoingReply")
    assert "777" not in done["text"] and "10 000" in done["text"]
    sentences = [d for n, d in events if n == "sentence"]
    assert [s["index"] for s in sentences] == list(range(len(sentences)))


def test_keyword_amounts():
    assert keywords.parse_amount("5 millions") == 5_000_000
    assert keywords.parse_amount("5 000 000 FBu") == 5_000_000
    assert keywords.parse_term_months("sur 24 mois") == 24
    assert keywords.parse_term_months("imyaka 2") == 24


async def test_model_no_answer_becomes_dont_know(client, fake_llm):
    conv = await new_conv(client, "fr")
    fake_llm.intent_replies = [intent_json("product_info", "fr")]
    fake_llm.answer = "NO_ANSWER"
    r = await say(client, conv["id"], "Je veux acheter une voiture d'occasion")
    assert r["text"] == "Je n'ai pas cette information. Voulez-vous parler à un conseiller ?"
    assert r["expected_input"] == "confirmation"


@pytest.mark.parametrize(
    "text,intent",
    [
        ("Quels sont les frais de tenue de compte courant ?", "product_info"),
        ("Is the youth account free?", "product_info"),
        ("Konti y'urwaruka ni ubuntu?", "product_info"),
        ("What loans do you offer?", "loan_info"),
        ("Nzoriha angahe ku kwezi ku mamiliyoni 2 mu mezi 12?", "loan_info"),
        ("What will the weather be like tomorrow in Bujumbura?", "other"),
        ("I was charged fees twice this month", "complaint"),
        ("Nkeneye impapuro izihe kugira nugurure konti?", "account_opening"),
        ("Ishami rya Ngozi ryugurura ryari?", "branch_info"),
        ("Quels documents pour ouvrir un compte ?", "account_opening"),
    ],
)
def test_keyword_rules_from_live_eval(text, intent):
    assert keywords.keyword_intent(text)["intent"] == intent


async def test_make_room_unloads_other_chat_models(monkeypatch):
    """One chat model at a time; the embedding model stays loaded."""
    import httpx

    from app.clients.ollama import OllamaClient

    unloaded: list[str] = []

    def handler(req: httpx.Request) -> httpx.Response:
        if req.url.path == "/api/ps":
            return httpx.Response(
                200,
                json={"models": [{"name": "gemma:2b"}, {"name": "nomic-embed-text:latest"}, {"name": "gemma4:e2b"}]},
            )
        if req.url.path == "/api/generate":
            unloaded.append(json.loads(req.content)["model"])
            return httpx.Response(200, json={})
        return httpx.Response(404)

    c = OllamaClient(base_url="http://ollama")
    monkeypatch.setattr(
        c,
        "_client",
        lambda timeout=None: httpx.AsyncClient(base_url="http://ollama", transport=httpx.MockTransport(handler)),
    )
    await c.make_room("gemma4:e2b")
    assert unloaded == ["gemma:2b"]


@pytest.mark.parametrize(
    "lang,text,expect",
    [
        ("en", "who are you", "I am Kabangutsi"),
        ("fr", "Qui êtes-vous ?", "Je suis Kabangutsi"),
        ("rn", "Uri nde?", "Ndi Kabangutsi"),
    ("rn", "Muri nde?", "Ndi Kabangutsi"),
    ],
)
async def test_who_are_you(client, fake_llm, lang, text, expect):
    conv = await new_conv(client, lang)
    r = await say(client, conv["id"], text)
    assert r["text"].startswith(expect) and r["lang"] == lang
    assert not [c for c in fake_llm.calls if c.get("format")]  # answered without a model call
