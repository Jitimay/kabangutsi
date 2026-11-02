"""USSD adapter: *123# session with numbered menus in fr / en / rn (F14).

Menus: 1 Products, 2 Card, 3 Loans, 4 Complaint, 5 Branches, 6 Language.
Pure menu screens are built here (no LLM, model_used = null). When a choice needs an
answer, the adapter turns it into a customer question and calls `ask` (the backend
orchestrator); the reply is then fitted to one USSD screen (182 characters).

How the backend uses it (T1, in the /v1/channels/ussd/inbound handler):

    from channels.ussd import UssdAdapter
    ussd = UssdAdapter()                       # one instance per process (holds sessions)

    if channel == "ussd":
        reply = await ussd.handle(msg, ask=orchestrator_handle, conversation_id=conv_id)

`ask(InboundMessage) -> OutgoingReply` must run the normal conversation pipeline (not this
endpoint again). Session state is kept in memory (USSD sessions are short-lived); the
adapter never touches the database and never logs customer input (it can be a PIN).
"""

from __future__ import annotations

import re
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field
from typing import Any

from .base import ChannelAdapter
from .schema import InboundMessage, Lang, OutgoingReply
from .text import fit_gsm7, normalize_phone, truncate
from .ussd_strings import Q, S

SCREEN_MAX = 182
SESSION_TTL_S = 300
DEFAULT_LANG: Lang = "fr"
# while the orchestrator waits for these, "0" is a real answer, not "back to menu"
_RAW_INPUTS = {"pin", "date_of_birth", "account_number", "confirmation"}

Ask = Callable[[InboundMessage], Awaitable[OutgoingReply]]


@dataclass
class UssdSession:
    lang: Lang
    state: str = "main"
    data: dict[str, Any] = field(default_factory=dict)
    expected_input: str = "menu_choice"
    touched: float = field(default_factory=time.monotonic)


@dataclass
class _Screen:
    text: str
    end: bool = False
    expected_input: str = "menu_choice"


@dataclass
class _Forward:
    question: str


def _parse_amount(s: str) -> int | None:
    digits = re.sub(r"[\s.,_']", "", s)
    if not digits.isdigit():
        return None
    v = int(digits)
    return v if 0 < v <= 10_000_000_000 else None


class UssdAdapter(ChannelAdapter):
    channel = "ussd"

    def __init__(self, default_lang: Lang = DEFAULT_LANG, ttl_s: int = SESSION_TTL_S):
        self.default_lang = default_lang
        self.ttl_s = ttl_s
        self.sessions: dict[str, UssdSession] = {}

    # ---- ChannelAdapter -------------------------------------------------------------
    def parse_inbound(self, raw: dict[str, Any]) -> InboundMessage:
        """Gateway-style payload {sessionId, phoneNumber, text, lang?} -> InboundMessage.

        The Flutter simulator posts InboundMessage directly; this is for a real USSD
        gateway. Cumulative inputs like '3*2*500000' keep only the last step.
        """
        text = (raw.get("text") or "").split("*")[-1].strip()
        return InboundMessage(channel="ussd", phone=normalize_phone(raw.get("phoneNumber")),
                              session_id=str(raw["sessionId"]), lang=raw.get("lang"), text=text)

    def format_outbound(self, reply: OutgoingReply) -> dict[str, Any]:
        """OutgoingReply -> gateway response: 'CON <screen>' or 'END <screen>'."""
        return {"response": ("END " if reply.end_session else "CON ") + reply.text,
                "end": reply.end_session}

    # ---- session flow ---------------------------------------------------------------
    async def handle(self, msg: InboundMessage, ask: Ask, conversation_id: str) -> OutgoingReply:
        self._expire()
        text = msg.text.strip()
        sess = self.sessions.get(msg.session_id)
        if sess is None or text == "":
            sess = UssdSession(lang=msg.lang or self.default_lang)
            self.sessions[msg.session_id] = sess
            return self._menu_reply(msg, sess, conversation_id, _Screen(S["main"][sess.lang]))
        sess.touched = time.monotonic()

        step = self._step(sess, text)
        if isinstance(step, _Screen):
            if step.end:
                self.sessions.pop(msg.session_id, None)
            return self._menu_reply(msg, sess, conversation_id, step)

        fwd = msg.model_copy(update={"text": step.question, "lang": sess.lang, "attachments": []})
        try:
            reply = await ask(fwd)
        except Exception:  # backend pipeline failure: end cleanly instead of hanging the session
            self.sessions.pop(msg.session_id, None)
            return self._menu_reply(msg, sess, conversation_id,
                                    _Screen(S["unavailable"][sess.lang], end=True, expected_input="none"))
        sess.state = "conversation"
        sess.expected_input = reply.expected_input
        if reply.end_session:
            self.sessions.pop(msg.session_id, None)
        return self._fit_reply(reply, sess)

    def _step(self, sess: UssdSession, t: str) -> _Screen | _Forward:
        L = sess.lang

        def go(state: str, key: str | None = None, expected: str = "menu_choice") -> _Screen:
            sess.state = state
            return _Screen(S[key or state][L], expected_input=expected)

        def invalid(key: str) -> _Screen:
            return _Screen(S["invalid"][L] + "\n" + S[key][L])

        waiting_raw = sess.state == "conversation" and sess.expected_input in _RAW_INPUTS
        if t == "00" and not waiting_raw:
            return _Screen(S["bye"][L], end=True, expected_input="none")
        st = sess.state

        if st == "main":
            nxt = {"1": "products", "2": "card", "3": "loans", "6": "lang"}
            if t in nxt:
                return go(nxt[t])
            if t == "4":
                return go("complaint", "ask_complaint", "text")
            if t == "5":
                return go("branch", "ask_branch", "text")
            return invalid("main")

        if t == "0" and st in {"products", "card", "loans", "lang", "free",
                               "complaint", "branch", "loan_amount", "loan_term"}:
            return go("main")

        if st == "products":
            if t == "1":
                return _Forward(Q["product_list"][L])
            if t == "2":
                return _Forward(Q["open_account"][L])
            if t == "3":
                return go("free", "ask_free", "text")
            return invalid("products")

        if st == "card":
            if t == "1":
                return _Forward(Q["block_card"][L])
            if t == "2":
                return go("free", "ask_free", "text")
            return invalid("card")

        if st == "loans":
            if t == "1":
                return _Forward(Q["loan_types"][L])
            if t == "2":
                return go("loan_amount", "ask_amount", "text")
            if t == "3":
                return go("free", "ask_free", "text")
            return invalid("loans")

        if st == "loan_amount":
            amount = _parse_amount(t)
            if amount is None:
                return invalid("ask_amount")
            sess.data["amount"] = amount
            return go("loan_term", "ask_term", "text")

        if st == "loan_term":
            if not t.isdigit() or not 1 <= int(t) <= 360:
                return invalid("ask_term")
            amount = f"{sess.data.pop('amount'):,}".replace(",", " ")
            return _Forward(Q["loan_sim"][L].format(amount=amount, months=int(t)))

        if st == "lang":
            new = {"1": "fr", "2": "en", "3": "rn"}.get(t)
            if new is None:
                return invalid("lang")
            sess.lang = new  # type: ignore[assignment]
            L = sess.lang
            return go("main")

        if st == "complaint":
            return _Forward(Q["complaint"][L].format(x=t))
        if st == "branch":
            return _Forward(Q["branch"][L].format(x=t))
        if st == "free":
            return _Forward(t)

        # conversation: after an orchestrator answer
        if t == "0" and sess.expected_input not in _RAW_INPUTS:
            return go("main")
        return _Forward(t)

    # ---- reply building -------------------------------------------------------------
    def _menu_reply(self, msg: InboundMessage, sess: UssdSession, conversation_id: str,
                    screen: _Screen) -> OutgoingReply:
        sess.expected_input = screen.expected_input
        return OutgoingReply(
            conversation_id=conversation_id, in_reply_to=msg.id, channel="ussd",
            phone=msg.phone, session_id=msg.session_id, lang=sess.lang,
            text=screen.text, short_text=fit_gsm7(screen.text, 160), speaker="system",
            intent=None, actions=[], attachments=[],
            expected_input=screen.expected_input,  # type: ignore[arg-type]
            handoff=False, end_session=screen.end, model_used=None, model_notice=None,
        )

    def _fit_reply(self, reply: OutgoingReply, sess: UssdSession) -> OutgoingReply:
        if reply.end_session:
            body = reply.text if len(reply.text) <= SCREEN_MAX else reply.short_text
            screen = truncate(body, SCREEN_MAX)
        else:
            footer = "" if sess.expected_input in _RAW_INPUTS else "\n" + S["footer"][reply.lang]
            room = SCREEN_MAX - len(footer)
            body = reply.text if len(reply.text) <= room else reply.short_text
            screen = truncate(body, room) + footer
        return reply.model_copy(update={"text": screen})

    def _expire(self) -> None:
        cutoff = time.monotonic() - self.ttl_s
        for sid in [s for s, v in self.sessions.items() if v.touched < cutoff]:
            del self.sessions[sid]
