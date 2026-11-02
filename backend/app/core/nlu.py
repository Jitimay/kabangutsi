"""Intent detection (F3) and language choice (F2).

Pipeline per customer turn:
  1. Text is redacted for the LLM (account numbers, dates, long digit runs) — PIN/DOB turns never get here.
  2. LLM returns JSON (Ollama structured output) → validated by Pydantic (`Intent`, extra keys forbidden).
  3. Invalid JSON → one retry on HARD_TASK_MODEL → keyword fallback. Never raises.
  4. Result merged with the keyword NLU: small models are weak in Kirundi, so a confident keyword match wins
     over a disagreeing low-confidence LLM answer. Numbers parsed in code win over model-parsed numbers.
"""

from __future__ import annotations

import asyncio
import json
import logging
import re
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Any

from pydantic import ValidationError

from app.clients.ollama import LLMError, get_llm
from app.config import get_settings
from app.core import keywords
from app.core.lang import choose_lang, detect
from app.schemas.intent import Entities, Intent, llm_format_schema

log = logging.getLogger(__name__)
PROMPTS = Path(__file__).parent / "prompts"


@dataclass
class NluResult:
    intent: Intent
    source: str  # llm | llm_retry | keyword | merged
    model_used: str | None
    attempts: list[str] = field(default_factory=list)  # e.g. ["invalid_json:gemma:2b", "ok:gemma4:e4b"]


@lru_cache
def _system_prompt() -> str:
    return (PROMPTS / "intent_system.txt").read_text(encoding="utf-8")


@lru_cache
def _examples(lang: str) -> list[dict[str, Any]]:
    return json.loads((PROMPTS / f"intent_examples_{lang}.json").read_text(encoding="utf-8"))


def is_number_only(text: str) -> bool:
    t = text.strip()
    return bool(t) and re.fullmatch(r"[\d\s.,+\-/]+", t) is not None


def redact_for_llm(text: str) -> str:
    """Belt and braces: the LLM never sees account numbers, dates or long digit runs."""
    text = re.sub(r"\b\d{4}[-/.]\d{1,2}[-/.]\d{1,2}\b", "[date]", text)
    text = re.sub(r"\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b", "[date]", text)
    text = re.sub(r"\b\d{9,}\b", "[number]", text)
    return text


def build_messages(text: str, lang_guess: str) -> list[dict[str, str]]:
    msgs = [{"role": "system", "content": _system_prompt()}]
    shots = _examples(lang_guess)[:4] + [e for lg in ("fr", "en", "rn") if lg != lang_guess for e in _examples(lg)[:2]]
    for ex in shots:
        msgs.append({"role": "user", "content": ex["text"]})
        msgs.append({"role": "assistant", "content": json.dumps(ex["output"], ensure_ascii=False)})
    msgs.append({"role": "user", "content": redact_for_llm(text)})
    return msgs


def parse_intent(raw: str) -> Intent:
    """Raises ValueError / ValidationError on anything that is not a valid intent JSON."""
    raw = raw.strip()
    m = re.search(r"\{.*\}", raw, re.S)
    if not m:
        raise ValueError("no JSON object")
    data = json.loads(m.group(0))
    if not isinstance(data, dict):
        raise ValueError("not an object")
    # Models often return 95 for 0.95: normalise percentages, otherwise validation fails as it should.
    for k in ("confidence", "frustration"):
        v = data.get(k)
        if isinstance(v, (int, float)) and 1 < v <= 100:
            data[k] = v / 100
    ents = data.get("entities")
    if isinstance(ents, dict):
        data["entities"] = {k: v for k, v in ents.items() if v not in (None, "", [])}
    return Intent.model_validate(data)


async def _ask(model: str, text: str, lang_guess: str, timeout: float | None) -> Intent:
    raw = await get_llm().chat(
        model,
        build_messages(text, lang_guess),
        format=llm_format_schema(),
        temperature=0,
        num_predict=200,
        think=False,
        timeout=timeout,
    )
    return parse_intent(raw)


async def llm_intent(
    text: str, model: str, lang_guess: str, allow_retry: bool = True
) -> tuple[Intent | None, str | None, list[str]]:
    s = get_settings()
    attempts: list[str] = []
    try:
        it = await _ask(model, text, lang_guess, None)
        attempts.append(f"ok:{model}")
        if it.confidence >= s.confidence_threshold or s.hard_task_model == model:
            return it, model, attempts
        attempts[-1] = f"low_confidence:{model}"
        first: Intent | None = it
    except (ValueError, ValidationError, json.JSONDecodeError) as e:
        attempts.append(f"invalid_json:{model}")
        log.info("intent JSON invalid from %s: %s", model, str(e)[:200])
        first = None
    except LLMError as e:
        attempts.append(f"llm_error:{model}")
        log.warning("intent LLM error: %s", e)
        first = None
    # One retry on the hard-task model (internal choice, no model.switched event)
    retry = s.hard_task_model
    if allow_retry and retry and retry != model:
        try:
            it = await asyncio.wait_for(_ask(retry, text, lang_guess, s.intent_retry_timeout), s.intent_retry_timeout)
            attempts.append(f"ok:{retry}")
            return it, retry, attempts
        except (ValueError, ValidationError, json.JSONDecodeError):
            attempts.append(f"invalid_json:{retry}")
        except (LLMError, TimeoutError):
            attempts.append(f"llm_error:{retry}")
    return first, (model if first else None), attempts


def merge(
    llm: Intent | None, kw: dict[str, Any], text: str, hint: str | None, previous: str | None
) -> tuple[Intent, str]:
    s = get_settings()
    kw_int = Intent.model_validate(kw)
    if llm is None:
        src = "keyword"
        base = kw_int
    else:
        kw_confident = kw_int.intent != "other" and kw_int.confidence >= 0.6
        kw_trusted = kw_int.confidence >= s.keyword_trust
        # Small models report high confidence for wrong intents (live test: gemma:2b said account_opening 0.9
        # for "I lost my card, please block it"), so strong keyword evidence wins whatever the model's confidence.
        if kw_trusted and kw_int.intent != llm.intent:
            base, src = kw_int, "merged"
        elif kw_confident and kw_int.intent != llm.intent and llm.confidence < 0.85:
            base, src = kw_int, "merged"
        elif llm.intent == "other" and kw_int.intent != "other":
            base, src = kw_int, "merged"
        else:
            base, src = llm, "llm"
    ents = {}
    if llm is not None:
        ents.update(llm.entities.compact())
    ents.update(kw_int.entities.compact())  # numbers and places parsed in code win
    if base.intent != "card_block":
        ents.pop("card_issue", None)
    try:
        entities = Entities.model_validate(ents)
    except ValidationError:
        entities = kw_int.entities
    frustration = max(kw_int.frustration, llm.frustration if llm else 0.0)
    if llm is not None and llm.intent == base.intent:
        confidence = max(llm.confidence, kw_int.confidence)
    else:
        confidence = base.confidence
    lang = choose_lang(text, hint, previous, llm.lang if llm else None, s.default_lang)
    return Intent(
        intent=base.intent,
        lang=lang,
        entities=entities,
        confidence=round(confidence, 3),
        frustration=round(frustration, 3),
    ), src


async def understand(
    text: str, model: str | None, hint: str | None = None, previous: str | None = None, use_llm: bool = True
) -> NluResult:
    """Never raises: any model failure ends in the keyword fallback.

    The LLM is skipped when it cannot add anything: greetings / thanks / goodbyes, number-only turns, and turns
    where the keyword evidence is strong (KEYWORD_TRUST). That keeps those turns under a second on CPU. The
    hard-task retry is only used when the keywords are unsure too.
    """
    s = get_settings()
    kw = keywords.keyword_intent(text)
    lang_guess = detect(text)[0] or hint or previous or "fr"
    llm_it: Intent | None = None
    used: str | None = None
    attempts: list[str] = []
    casual = (
        keywords.is_greeting(text)
        or keywords.is_thanks(text)
        or keywords.is_goodbye(text)
        or keywords.is_who_are_you(text)
    )
    trusted = kw["confidence"] >= s.keyword_trust  # "other" is only that sure for explicit off-topic
    if casual or is_number_only(text) or (trusted and s.skip_llm_when_trusted):
        use_llm = False
    if use_llm and model:
        unsure = kw["intent"] == "other" or kw["confidence"] < 0.6
        llm_it, used, attempts = await llm_intent(text, model, lang_guess, allow_retry=unsure)
    intent, src = merge(llm_it, kw, text, hint, previous)
    if src == "llm" and attempts and attempts[-1].startswith("ok:") and len(attempts) > 1:
        src = "llm_retry"
    return NluResult(intent=intent, source=src, model_used=used, attempts=attempts)
