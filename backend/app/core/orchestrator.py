"""Conversation orchestrator: one customer turn in, one OutgoingReply out (message.schema.json).

Per turn:
  1. Idempotency (InboundMessage.id already answered → stored reply) and per-call serialisation (asyncio lock).
  2. Call status: ended → 409; queued / with agent → message stored, forwarded (agent assist), system reply.
  3. Attachments → text (media.py: vision / audio models with auto-switch, OCR / STT fallback).
  4. Session state owned by a flow (card block: account, PIN, confirmation) → that handler, NO model sees the text.
     A turn answering expected_input=pin / date_of_birth is stored as '••••'.
  5. Otherwise NLU (LLM intent JSON + keyword fallback) → policy (code only: handoff on request, frustration,
     2× low confidence) → intent handler.
  6. Streaming answers: each sentence passes the grounding check before it is sent (SSE `token` / `sentence`).
  7. Reply stored with the turn (reply_json, for idempotent replay); events emitted (delivered on commit).
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession

from app.agents import assist, handoff
from app.agents.queue import end_call
from app.clients import services
from app.config import get_settings
from app.core import keywords, media
from app.core.lang import choose_lang, tokens
from app.core.model_router import registry, route
from app.core.nlu import understand
from app.core.responses import t
from app.core.types import HandlerResult, TurnContext
from app.db import repo
from app.db.session import db_session
from app.errors import ApiError
from app.files import attachment_of, store_file
from app.handlers import branch_info, card_block, complaint, knowledge, loan_info
from app.realtime.events import emit
from app.schemas.intent import Intent
from app.util import MASK, SentenceBuffer, is_uuid, iso, new_id, now, short_text, split_sentences

log = logging.getLogger(__name__)
Sink = Callable[[str, dict[str, Any]], Awaitable[None]]

_locks: dict[str, asyncio.Lock] = {}


def _lock(key: str) -> asyncio.Lock:
    lk = _locks.get(key)
    if lk is None:
        if len(_locks) > 5000:
            for k in [k for k, v in _locks.items() if not v.locked()][:2500]:
                _locks.pop(k, None)
        lk = _locks[key] = asyncio.Lock()
    return lk


@dataclass
class TurnInput:
    text: str = ""
    lang_hint: str | None = None
    model_override: str | None = None
    voice: bool = False
    attachments: list[dict[str, Any]] = field(default_factory=list)
    message_id: str | None = None  # InboundMessage.id (idempotency); None for app turns
    via_channel_api: bool = False  # /v1/channels/{channel}/inbound: always 200, never 409


@dataclass
class TurnOutcome:
    reply: dict[str, Any]
    status: int = 200  # 409 when the conversation is ended or with an agent (app API only)
    conflict_message: str | None = None


# ---------------------------------------------------------------- replies


def build_reply(
    call: dict[str, Any],
    *,
    text_: str,
    lang: str,
    session_id: str,
    in_reply_to: str | None = None,
    speaker: str = "ai",
    intent: str | None = None,
    actions: list | None = None,
    attachments: list | None = None,
    expected_input: str = "text",
    handoff_: bool = False,
    end_session: bool = False,
    model_used: str | None = None,
    model_notice: str | None = None,
    short: str | None = None,
    reply_id: str | None = None,
) -> dict[str, Any]:
    return {
        "id": reply_id or new_id(),
        "conversation_id": call["id"],
        "in_reply_to": in_reply_to,
        "channel": call["channel"],
        "phone": call["phone"],
        "session_id": session_id,
        "lang": lang,
        "text": text_,
        "short_text": short_text(short or text_),
        "speaker": speaker,
        "intent": intent,
        "actions": actions or [],
        "attachments": attachments or [],
        "expected_input": expected_input,
        "handoff": handoff_,
        "end_session": end_session,
        "model_used": model_used,
        "model_notice": model_notice,
        "ts": iso(now()),
    }


async def _tts_attachment(db: AsyncSession, sentence: str, lang: str, call_id: str) -> dict[str, Any] | None:
    try:
        wav = await services.tts(sentence, lang)
        ref = await store_file(db, wav, "audio/wav", call_id)
        return attachment_of(ref)
    except (services.ServiceError, ValueError, OverflowError) as e:
        log.info("TTS unavailable: %s", e)
        return None


def clean_sentence(s: str) -> str:
    """LLM output for voice/SMS: no markdown bullets, bold or headings; one line."""
    s = re.sub(r"(^|\n)\s*(?:[-*•]|\d+[.)])\s+", r"\1", s)
    s = re.sub(r"[*_#`]{1,3}", "", s)
    s = re.sub(r"\s*\n+\s*", "; ", s.strip())
    return re.sub(r"\s+", " ", s).strip(" ;")


# ---------------------------------------------------------------- sessions


def session_key(channel: str, key: str) -> str:
    return f"{channel}:{key}"


async def load_session(
    db: AsyncSession, call: dict[str, Any], key: str | None = None
) -> tuple[str, str, dict[str, Any]]:
    row = (
        await db.execute(
            text("SELECT * FROM sessions WHERE call_id = :c ORDER BY updated_at DESC LIMIT 1"), {"c": call["id"]}
        )
    ).first()
    if row is not None:
        ctx = row.context_json if isinstance(row.context_json, dict) else json.loads(row.context_json or "{}")
        return row.session_key, row.state, ctx
    k = key or session_key(call["channel"], call["id"])
    await db.execute(
        text("""INSERT INTO sessions (session_key, call_id, phone, state, context_json)
                              VALUES (:k, :c, :p, 'idle', '{}') ON CONFLICT (session_key) DO UPDATE
                              SET call_id = :c, phone = :p, state = 'idle', context_json = '{}', updated_at = now()"""),
        {"k": k, "c": call["id"], "p": call["phone"]},
    )
    return k, "idle", {}


async def save_session(db: AsyncSession, key: str, state: str, ctx: dict[str, Any]) -> None:
    for banned in ("pin", "date_of_birth", "dob"):
        ctx.pop(banned, None)
    await db.execute(
        text(
            "UPDATE sessions SET state = :s, context_json = CAST(:c AS jsonb), updated_at = now() "
            "WHERE session_key = :k"
        ),
        {"s": state, "c": json.dumps(ctx, default=str), "k": key},
    )


# ---------------------------------------------------------------- conversations


async def check_model(name: str | None) -> str | None:
    """422 when the model is not installed or not selectable (Ollama down → accepted as is)."""
    if not name:
        return None
    try:
        info = await registry.get(name)
        if info is None:
            await registry.list(refresh=True)
            info = await registry.get(name)
    except Exception:  # noqa: BLE001
        return name
    if info is None or not info.selectable:
        raise ApiError(422, "validation_error", f"Model {name} is not installed or cannot chat", {"field": "model"})
    return info.name


async def open_call(
    db: AsyncSession, *, channel: str, phone: str | None, lang: str | None, model: str | None, key: str | None
) -> dict[str, Any]:
    s = get_settings()
    cid = new_id()
    try:
        default = await registry.default_model()
    except Exception:  # noqa: BLE001
        default = s.default_model
    await db.execute(
        text("""INSERT INTO calls (id, phone, channel, session_key, language, model)
                              VALUES (:id, :p, :ch, :k, :l, :m)"""),
        {"id": cid, "p": phone, "ch": channel, "k": key or cid, "l": lang or s.default_lang, "m": model or default},
    )
    call = await repo.get_call(db, cid)
    await load_session(db, call, session_key(channel, key or cid))
    await emit(db, "call.started", call)
    return call


async def create_conversation(channel: str, phone: str | None, lang: str | None, model: str | None) -> dict[str, Any]:
    model = await check_model(model)
    async with db_session() as db:
        call = await open_call(db, channel=channel, phone=phone, lang=lang, model=model, key=None)
        lg = call["lang"]
        reply = build_reply(
            call, text_=t("greeting", lg), short=t("greeting_short", lg), lang=lg, session_id=call["id"]
        )
        turn = await repo.insert_turn(
            db, call_id=call["id"], speaker="ai", text_=reply["text"], lang=lg, message_id=reply["id"], reply_json=reply
        )
        await emit(db, "call.turn", turn)
        await db.commit()
    return {
        "id": call["id"],
        "channel": call["channel"],
        "phone": call["phone"],
        "lang": lg,
        "model": call["model"],
        "status": call["status"],
        "started_at": call["started_at"],
        "greeting": reply,
    }


def conversation_out(call: dict[str, Any]) -> dict[str, Any]:
    return {k: call[k] for k in ("id", "channel", "phone", "lang", "model", "status", "started_at")}


async def update_conversation(call_id: str, model: str | None, lang: str | None) -> dict[str, Any]:
    model = await check_model(model)
    async with db_session() as db:
        call = await repo.get_call(db, call_id)
        if call is None:
            raise ApiError(404, "not_found", "Conversation not found")
        if model:
            await db.execute(text("UPDATE calls SET model = :m WHERE id = :id"), {"m": model, "id": call_id})
        if lang:
            await db.execute(text("UPDATE calls SET language = :l WHERE id = :id"), {"l": lang, "id": call_id})
        call = await repo.get_call(db, call_id)
        await db.commit()
    return conversation_out(call)


async def find_call_for_inbound(db: AsyncSession, msg: dict[str, Any]) -> dict[str, Any]:
    """Web/phone: session_id is the conversation id. SMS/WhatsApp/USSD: reuse the open conversation for that
    session key (recently active, or waiting for / with an agent), else open one."""
    s = get_settings()
    ch, sid = msg["channel"], msg["session_id"]
    if ch in ("web", "phone") and is_uuid(sid):
        call = await repo.get_call(db, sid)
        if call is not None and call["channel"] == ch:
            return call
    row = (
        await db.execute(
            text("""
        SELECT c.id FROM calls c WHERE c.channel = :ch AND c.session_key = :k AND c.status <> 'ended'
          AND (c.status IN ('queued', 'with_agent')
               OR COALESCE((SELECT max(ts) FROM call_turns WHERE call_id = c.id), c.started_at)
                  > now() - make_interval(mins => :mins))
        ORDER BY c.started_at DESC LIMIT 1"""),
            {"ch": ch, "k": sid, "mins": s.session_reuse_minutes},
        )
    ).first()
    if row is not None:
        return await repo.get_call(db, str(row.id))
    # stale open sessions for this key are closed first
    for old in await db.execute(
        text("SELECT id FROM calls WHERE channel = :ch AND session_key = :k AND status = 'active'"),
        {"ch": ch, "k": sid},
    ):
        await end_call(db, str(old.id))
    return await open_call(db, channel=ch, phone=msg.get("phone"), lang=msg.get("lang"), model=None, key=sid)


async def stored_reply(db: AsyncSession, message_id: str) -> dict[str, Any] | None:
    r = await db.scalar(
        text(
            "SELECT reply_json FROM call_turns WHERE reply_json IS NOT NULL AND reply_json->>'in_reply_to' = :m LIMIT 1"
        ),
        {"m": message_id},
    )
    if r is None:
        return None
    return r if isinstance(r, dict) else json.loads(r)


async def handle_inbound(msg: dict[str, Any], sink: Sink | None = None) -> dict[str, Any]:
    """POST /v1/channels/{channel}/inbound: always answers with an OutgoingReply."""
    async with _lock(f"in:{msg['channel']}:{msg['session_id']}"):
        async with db_session() as db:
            dup = await stored_reply(db, msg["id"])
            if dup is not None:
                return dup
            call = await find_call_for_inbound(db, msg)
            await db.commit()
        inp = TurnInput(
            text=msg.get("text") or "",
            lang_hint=msg.get("lang"),
            attachments=msg.get("attachments") or [],
            message_id=msg["id"],
            via_channel_api=True,
        )
        out = await handle_turn(call["id"], inp, sink, session_id=msg["session_id"])
        return out.reply


# ---------------------------------------------------------------- the turn


STRONG_STATES = ("card_block.",)  # flows that own every turn (no NLU, no model)


def _handler_for(intent: Intent, txt: str) -> Callable[[TurnContext], Awaitable[HandlerResult]] | None:
    return {
        "product_info": knowledge.handle,
        "account_opening": knowledge.handle,
        "card_block": card_block.handle,
        "loan_info": loan_info.handle,
        "complaint": complaint.handle,
        "branch_info": branch_info.handle,
    }.get(intent.intent)


async def _other(ctx: TurnContext) -> HandlerResult:
    lang, txt = ctx.lang, ctx.text
    if keywords.is_greeting(txt):
        return HandlerResult(text=t("hello", lang))
    if keywords.is_thanks(txt):
        return HandlerResult(text=t("thanks", lang))
    if keywords.is_goodbye(txt):
        return HandlerResult(text=t("goodbye", lang), end_session=ctx.channel == "phone", expected_input="none")
    if len(tokens(txt)) >= 3:
        res = await knowledge.handle(ctx)
        if res.state != "offer_handoff":
            return res
    return HandlerResult(text=t("other", lang))


async def handle_turn(
    call_id: str, inp: TurnInput, sink: Sink | None = None, session_id: str | None = None
) -> TurnOutcome:
    async with _lock(f"call:{call_id}"):
        async with db_session() as db:
            try:
                return await _turn(db, call_id, inp, sink, session_id)
            except ApiError:
                raise
            except Exception:
                log.exception("turn failed for call %s", call_id)
                await db.rollback()
                return await _error_reply(db, call_id, inp, session_id)


async def _error_reply(db: AsyncSession, call_id: str, inp: TurnInput, session_id: str | None) -> TurnOutcome:
    call = await repo.get_call(db, call_id)
    lang = inp.lang_hint or call["lang"]
    reply = build_reply(
        call, text_=t("error", lang), lang=lang, session_id=session_id or call["id"], in_reply_to=inp.message_id
    )
    turn = await repo.insert_turn(
        db, call_id=call_id, speaker="ai", text_=reply["text"], lang=lang, message_id=reply["id"], reply_json=reply
    )
    await emit(db, "call.turn", turn)
    await db.commit()
    return TurnOutcome(reply)


async def _turn(
    db: AsyncSession, call_id: str, inp: TurnInput, sink: Sink | None, session_id: str | None
) -> TurnOutcome:
    s = get_settings()
    if inp.message_id:
        dup = await stored_reply(db, inp.message_id)
        if dup is not None:
            return TurnOutcome(dup)
    call = await repo.get_call(db, call_id)
    if call is None:
        raise ApiError(404, "not_found", "Conversation not found")
    sid = session_id or (call["id"] if call["channel"] in ("web", "phone") else call["phone"] or call["id"])
    skey, state, sctx = await load_session(db, call)
    expected = sctx.get("_expected", "text")
    masked = expected in ("pin", "date_of_birth")
    # A lone 4-digit message outside the flows that expect digits is treated as a possible PIN typed by
    # mistake: stored masked, never sent to a model, never used as ticket text.
    lone4 = re.fullmatch(r"\s*\d{4}\s*", inp.text or "") is not None and not inp.attachments
    in_card_flow = state.startswith("card_block.")
    stray_pin = lone4 and not masked and not in_card_flow
    # inside the card flow (except when choosing a card by its last 4 digits) the handler answers, but the
    # transcript is masked all the same
    masked = masked or stray_pin or (lone4 and in_card_flow and state != "card_block.awaiting_card")
    hint = inp.lang_hint
    base_lang = hint or call["lang"]
    in_reply_to = inp.message_id or new_id()  # app turns: the customer turn id

    # ---------- not with the AI any more
    if call["status"] == "ended":
        reply = build_reply(
            call,
            text_=t("conversation_ended", base_lang),
            lang=base_lang,
            session_id=sid,
            in_reply_to=in_reply_to,
            speaker="system",
            expected_input="none",
            end_session=True,
        )
        return TurnOutcome(reply, 200 if inp.via_channel_api else 409, "Conversation ended")
    if call["status"] in ("queued", "with_agent"):
        cust = await repo.insert_turn(
            db,
            call_id=call_id,
            speaker="customer",
            text_=MASK if masked else inp.text,
            lang=base_lang,
            message_id=in_reply_to,
            attachments=inp.attachments,
        )
        await emit(db, "call.turn", cust)
        if sink:
            await sink("turn", cust)
        key = "with_agent_wait" if call["status"] == "with_agent" else "queued_wait"
        reply = build_reply(
            call,
            text_=t(key, base_lang),
            lang=base_lang,
            session_id=sid,
            in_reply_to=in_reply_to,
            speaker="system",
            handoff_=True,
        )
        st = await repo.insert_turn(
            db,
            call_id=call_id,
            speaker="system",
            text_=reply["text"],
            lang=base_lang,
            message_id=reply["id"],
            reply_json=reply,
        )
        await emit(db, "call.turn", st)
        await db.commit()
        if call["status"] == "with_agent" and not masked and inp.text.strip():
            assist.schedule(call_id, cust["id"], inp.text, base_lang, s.hard_task_model)
        msg = (
            "Conversation is with an agent"
            if call["status"] == "with_agent"
            else "Conversation is waiting for an agent"
        )
        return TurnOutcome(reply, 200 if inp.via_channel_api else 409, msg)

    # ---------- media (switch events are sent after the `turn` event, as the SSE contract orders them)
    pending: list[tuple[str, dict[str, Any]]] = []

    async def buffer(name: str, data: dict[str, Any]) -> None:
        pending.append((name, data))

    requested = inp.model_override or call["model"]
    med = media.MediaResult()
    if inp.attachments and not masked:
        med = await media.process(
            db,
            call=call,
            attachments=inp.attachments,
            text_=inp.text,
            lang=base_lang,
            requested_model=requested,
            sink=buffer if sink else None,
        )
    txt = " ".join(x for x in (inp.text.strip(), med.transcript or "") if x)
    if med.stt_lang and not hint:
        hint = med.stt_lang
    notices = list(med.notices)

    # ---------- understand (never for flow-owned / masked turns)
    owned = state.startswith(STRONG_STATES) or (masked and not stray_pin)
    intent: Intent | None = None
    nlu_model: str | None = None
    llm_for_turn: str | None = None
    if owned:
        lang = call["lang"]
    else:
        r = await route(requested, "completion", base_lang)
        if r.switched and r.model:
            await media.log_switch(db, call_id, r, base_lang, buffer if sink else None)
            if r.notice:
                notices.append(r.notice)
        llm_for_turn = r.model
        if med.model_used:
            # The model that read the image / audio also handles this turn: it can chat, it is loaded, and
            # swapping back to the session model mid-turn would reload it (one chat model fits in memory).
            llm_for_turn = med.model_used
        nlu_text = txt + (f"\n[image: {med.image_text}]" if med.image_text else "")
        if nlu_text.strip():
            nlu = await understand(nlu_text, llm_for_turn, hint=hint, previous=call["lang"])
            intent, nlu_model = nlu.intent, nlu.model_used
            lang = intent.lang
        else:
            lang = choose_lang(txt, hint, call["lang"], None, s.default_lang)

    # ---------- store the customer turn
    cust = await repo.insert_turn(
        db,
        call_id=call_id,
        speaker="customer",
        text_=MASK if masked else txt,
        lang=lang,
        message_id=in_reply_to,
        intent=intent.intent if intent else None,
        confidence=intent.confidence if intent else None,
        frustration=intent.frustration if intent else None,
        attachments=inp.attachments,
        model_used=nlu_model or med.model_used,
    )
    await emit(db, "call.turn", cust)
    await db.commit()
    if sink:
        await sink("turn", cust)
        for name, data in pending:
            await sink(name, data)

    ctx = TurnContext(
        db=db,
        call=call,
        state=state,
        context={k: v for k, v in sctx.items() if not k.startswith("_")},
        # handlers also see what the image shows (KB search, complaint text); flows never get images
        text=f"{txt} {med.image_text}".strip() if med.image_text and not owned else txt,
        lang=lang,
        intent=intent,
        model=llm_for_turn,
        customer_turn_id=cust["id"],
    )
    low_conf = int(sctx.get("_low_conf", 0))

    # ---------- policy (code only) → handler
    res: HandlerResult
    if stray_pin:
        res = HandlerResult(text=t("stray_digits", lang), state="idle", context={})
    elif med.problem and not txt and not med.image_text:
        res = HandlerResult(text=t(med.problem, lang), state=state, context=ctx.context, expected_input=expected)
    elif not masked and (keywords.wants_agent(txt) or (intent and intent.intent == "handoff")):
        res = HandlerResult(
            text=t("handoff_queued", lang),
            handoff_reason="customer_request",
            state="idle",
            context={},
            expected_input="none",
        )
    elif intent and intent.frustration >= s.frustration_threshold:
        res = HandlerResult(
            text=t("handoff_frustration", lang),
            handoff_reason="frustration",
            state="idle",
            context={},
            expected_input="none",
        )
    elif owned:
        res = await card_block.handle(ctx)
    elif state == "complaint.awaiting_details" and not keywords.wants_cancel(txt):
        res = await complaint.handle(ctx)
    elif state == "offer_handoff" and len(tokens(txt)) <= 4 and keywords.yes_no(txt) is not None:
        if keywords.yes_no(txt):
            res = HandlerResult(
                text=t("handoff_queued", lang),
                handoff_reason="no_answer",
                state="idle",
                context={},
                expected_input="none",
            )
        else:
            res = HandlerResult(text=t("ok_else", lang), state="idle", context={})
    else:
        assert intent is not None or not txt
        if intent is None:  # attachment only, nothing readable
            res = HandlerResult(text=t("image_unreadable", lang))
        else:
            casual = keywords.is_greeting(txt) or keywords.is_thanks(txt) or keywords.is_goodbye(txt)
            low_conf = 0 if (casual or intent.confidence >= s.confidence_threshold) else low_conf + 1
            soft = None
            if (
                state == "loan.collecting"
                and intent.intent in ("other", "loan_info")
                and (
                    intent.entities.loan_amount
                    or intent.entities.term_months
                    or keywords.parse_amount(txt)
                    or keywords.parse_term_months(txt)
                    or keywords.find_product(txt, loans_only=True)
                )
            ):
                soft = loan_info.handle
            elif (
                state == "branch.awaiting_place"
                and intent.intent in ("other", "branch_info")
                and keywords.find_place(txt)
            ):
                soft = branch_info.handle
            if low_conf >= 2 and soft is None:
                res = HandlerResult(
                    text=t("handoff_queued", lang),
                    handoff_reason="low_confidence",
                    state="idle",
                    context={},
                    expected_input="none",
                )
                low_conf = 0
            else:
                h = soft or _handler_for(intent, txt) or _other
                res = await h(ctx)
    if med.ocr and med.ocr.get("needs_review") and not res.handoff_reason:
        res.text = f"{res.text} {t('doc_review', lang)}".strip()
        res.handoff_reason = "agent_review"

    # ---------- reply text (streamed answers pass the grounding check sentence by sentence)
    reply_id = new_id()
    attachments: list[dict[str, Any]] = list(res.attachments)
    sentences: list[str] = []

    async def send_sentence(sent: str) -> None:
        sent = clean_sentence(sent)
        if not sent:
            return
        idx = len(sentences)
        sentences.append(sent)
        audio = await _tts_attachment(db, sent, lang, call_id) if inp.voice else None
        if audio:
            attachments.append(audio)
        if sink:
            await sink("token", {"delta": (" " if idx else "") + sent})
            await sink("sentence", {"index": idx, "text": sent, "audio_url": audio["url"] if audio else None})

    # The customer sent an image: first say what was seen on it (their own image, not a bank fact)
    if med.image_text and not owned:
        await send_sentence(t("image_seen", lang, desc=med.image_text.rstrip(". ")))
    pre = len(sentences)
    limit = s.max_answer_sentences + pre

    if res.stream is not None:
        buf = SentenceBuffer()
        try:
            async for delta in res.stream:
                for sent in buf.feed(delta):
                    if len(sentences) < limit and (res.sentence_ok is None or res.sentence_ok(sent)):
                        await send_sentence(sent)
                if len(sentences) >= limit:
                    break
            for sent in buf.flush():
                if len(sentences) < limit and (res.sentence_ok is None or res.sentence_ok(sent)):
                    await send_sentence(sent)
        except Exception as e:  # noqa: BLE001 — model failed mid-answer: grounded fallback below
            log.warning("answer stream failed: %s", e)
        if len(sentences) == pre:  # nothing grounded survived
            res.model_used = None
            for sent in split_sentences(res.fallback_text or t("dont_know", lang)):
                await send_sentence(sent)
    else:
        for sent in split_sentences(res.text):
            await send_sentence(sent)
    reply_text = " ".join(sentences)

    # ---------- call row first (the handoff summary reads language, intent and frustration from it)
    upd = {
        "id": call_id,
        "l": lang,
        "i": intent.intent if intent else call["last_intent"],
        "f": max(call["frustration"], intent.frustration if intent else 0.0),
    }
    await db.execute(
        text(
            "UPDATE calls SET language = :l, last_intent = :i, frustration = GREATEST(frustration, :f) WHERE id = :id"
        ),
        upd,
    )

    # ---------- actions with side effects owned by the orchestrator
    actions = list(res.actions)
    handed = False
    end_session = res.end_session
    if res.handoff_reason:
        try:
            await handoff.queue_call(db, call_id, res.handoff_reason, intent.frustration if intent else None)
            handed = True
            actions.append(
                {"type": "handoff", "status": "done", "reference": None, "data": {"reason": res.handoff_reason}}
            )
        except handoff.HandoffConflict:
            reply_text = t("already_queued", lang)
    model_used = res.model_used or med.model_used or nlu_model
    reply = build_reply(
        call,
        text_=reply_text,
        short=res.short_text,
        lang=lang,
        session_id=sid,
        in_reply_to=in_reply_to,
        intent=res.intent_override or (intent.intent if intent else None),
        actions=actions,
        attachments=attachments,
        expected_input=res.expected_input,
        handoff_=handed,
        end_session=end_session,
        model_used=model_used,
        model_notice=" ".join(dict.fromkeys(notices)) or None,
        reply_id=reply_id,
    )

    # ---------- persist
    new_ctx = dict(res.context if res.context is not None else ctx.context)
    new_ctx["_expected"] = res.expected_input
    new_ctx["_low_conf"] = low_conf
    await save_session(db, skey, res.state, new_ctx)
    ai = await repo.insert_turn(
        db,
        call_id=call_id,
        speaker="ai",
        text_=reply_text,
        lang=lang,
        message_id=reply_id,
        intent=reply["intent"],
        attachments=attachments,
        model_used=model_used,
        reply_json=reply,
    )
    await emit(db, "call.turn", ai)
    if end_session and not handed:
        await end_call(db, call_id)
    await db.commit()
    if handed:
        task = handoff.after_commit(call_id, res.handoff_reason)
        if not s.summary_in_background and task is not None:
            await task
    if sink:
        await sink("done", reply)
    return TurnOutcome(reply)


# ---------------------------------------------------------------- explicit handoff / end / agent messages


async def request_handoff(call_id: str, reason: str) -> dict[str, Any]:
    s = get_settings()
    async with _lock(f"call:{call_id}"):
        async with db_session() as db:
            call = await repo.get_call(db, call_id)
            if call is None:
                raise ApiError(404, "not_found", "Conversation not found")
            try:
                await handoff.queue_call(db, call_id, reason)
            except handoff.HandoffConflict as e:
                raise ApiError(409, "conflict", f"Conversation is {e.status}", {"status": e.status}) from e
            lang = call["lang"]
            skey, _, sctx = await load_session(db, call)
            await save_session(db, skey, "idle", {"_expected": "none"})
            reply = build_reply(
                call,
                text_=t("handoff_queued", lang),
                lang=lang,
                session_id=call["id"],
                handoff_=True,
                intent="handoff",
                expected_input="none",
                actions=[{"type": "handoff", "status": "done", "reference": None, "data": {"reason": reason}}],
            )
            turn = await repo.insert_turn(
                db,
                call_id=call_id,
                speaker="ai",
                text_=reply["text"],
                lang=lang,
                message_id=reply["id"],
                reply_json=reply,
                intent="handoff",
            )
            await emit(db, "call.turn", turn)
            await db.commit()
    task = handoff.after_commit(call_id, reason)
    if not s.summary_in_background and task is not None:
        await task
    return reply


async def agent_message(call_id: str, agent_id: str, text_: str, voice: bool) -> dict[str, Any]:
    async with db_session() as db:
        call = await repo.get_call(db, call_id)
        if call is None:
            raise ApiError(404, "not_found", "Call not found")
        if call["status"] != "with_agent" or call["claimed_by"] != agent_id:
            raise ApiError(403, "forbidden", "Call not claimed by this agent")
        lang = call["lang"]
        atts = []
        if voice:
            a = await _tts_attachment(db, text_, lang, call_id)
            if a:
                atts.append(a)
        sid = (
            call["id"]
            if call["channel"] in ("web", "phone")
            else (await db.scalar(text("SELECT session_key FROM calls WHERE id = :id"), {"id": call_id}) or call["id"])
        )
        reply = build_reply(call, text_=text_, lang=lang, session_id=sid, speaker="agent", attachments=atts)
        turn = await repo.insert_turn(
            db,
            call_id=call_id,
            speaker="agent",
            agent_id=agent_id,
            text_=text_,
            lang=lang,
            message_id=reply["id"],
            attachments=atts,
            reply_json=reply,
        )
        await emit(db, "call.turn", turn)
        await db.commit()
    if call["channel"] in ("sms", "whatsapp"):
        asyncio.create_task(services.adapter_send(call["channel"], reply))  # noqa: RUF006 — best effort push
    return reply
