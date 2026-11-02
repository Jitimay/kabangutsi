"""Grounded answers from retrieved chunks (F4, "no invented bank facts").

- `numbers_ok`: a sentence may only contain numbers (amounts, rates, days, hours) that appear in the chunks.
- `extractive`: best 2–3 sentences of the top chunk, used when no LLM is available, for Kirundi by default
  (small models write poor Kirundi; the KB text was written for it), or when every LLM sentence failed the check.
"""

from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path
from typing import Any

from app.core.keywords import fold
from app.rag.search import query_terms
from app.util import split_sentences

PROMPTS = Path(__file__).resolve().parents[1] / "core" / "prompts"
LANG_NAME = {"fr": "French", "en": "English", "rn": "Kirundi"}

_NUM = re.compile(r"\d{1,3}(?:[  \xa0.,]\d{3})+|\d+(?:[.,]\d+)?")


def numbers_in(s: str) -> set[str]:
    out = set()
    for m in _NUM.finditer(s):
        raw = m.group(0)
        if re.fullmatch(r"\d{1,3}(?:[  \xa0.,]\d{3})+", raw):
            out.add(re.sub(r"\D", "", raw))
        else:
            out.add(raw.replace(",", ".").rstrip("0").rstrip(".") if "." in raw.replace(",", ".") else raw)
    return out


def numbers_ok(sentence: str, sources: list[str]) -> bool:
    allowed: set[str] = set()
    for s in sources:
        allowed |= numbers_in(s)
    return numbers_in(sentence) <= allowed


@lru_cache
def _prompt(name: str) -> str:
    return (PROMPTS / name).read_text(encoding="utf-8")


def answer_messages(question: str, hits: list[dict[str, Any]], lang: str) -> list[dict[str, str]]:
    ctx = "\n\n".join(f"[{h['id']}] {h['title']}\n{h['text']}" for h in hits)
    system = _prompt("answer_system.txt").format(lang_name=LANG_NAME[lang])
    return [
        {"role": "system", "content": system},
        {"role": "user", "content": f"PASSAGES:\n{ctx}\n\nQUESTION: {question}"},
    ]


def extractive(question: str, hits: list[dict[str, Any]], max_sentences: int = 3, max_chars: int = 420) -> str:
    """Highest-overlap sentences of the top chunk, kept in their original order."""
    if not hits:
        return ""
    top = hits[0]
    sents = split_sentences(top["text"])
    terms = {fold(w) for w in query_terms(question, top["lang"])}

    def score(i: int, s: str) -> float:
        words = {fold(w) for w in re.findall(r"[^\W_]+", s.lower())}
        return len(words & terms) + (0.5 if i == 0 else 0)

    ranked = sorted(range(len(sents)), key=lambda i: score(i, sents[i]), reverse=True)
    keep: list[int] = []
    total = 0
    for i in ranked:
        if len(keep) >= max_sentences or total + len(sents[i]) > max_chars:
            continue
        keep.append(i)
        total += len(sents[i]) + 1
    if not keep and sents:
        keep = [0]
    return " ".join(sents[i] for i in sorted(keep))
