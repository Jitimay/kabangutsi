"""Regenerate voice/phrases/phrases.json from the backend's fixed reply templates.

The backend sends replies to POST /tts one sentence at a time (backend/app/core/orchestrator.py
`send_sentence`, split by backend/app/util.py `split_sentences`). The phrase cache matches exact text,
so it must hold those same sentences. Run this whenever T1 changes backend/app/core/responses.py:

    python voice/scripts/sync_phrases.py            # from the repo root; rewrites voice/phrases/phrases.json

Only reads the backend file (no import, no runtime dependency between the services). Templates with
`{placeholders}` are skipped (their text changes per call); human recordings in phrases/<lang>/<id>.wav
keep working because ids are stable (`<template>` or `<template>.<n>` for the n-th sentence).
"""
import ast
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "backend" / "app" / "core" / "responses.py"
OUT = ROOT / "voice" / "phrases" / "phrases.json"
LANGS = ("fr", "en", "rn")
# Same regex as backend/app/util.py _SENT_END
SENT_END = re.compile(r"(?<=[.!?…])\s+(?=[A-ZÀ-ÖØ-Þ0-9«\"'(])")
# Labels and fragments that are never spoken on their own
SKIP_PREFIXES = ("reason_", "cap_", "card_")
# Phrases the service keeps even if the backend does not use them (yet)
EXTRA = {
    "please_wait": {"fr": "Un instant, s'il vous plaît.", "en": "One moment, please.", "rn": "Mutegereze gato."},
}


def split_sentences(text: str) -> list[str]:
    text = " ".join(text.split())
    return [s.strip() for s in SENT_END.split(text) if s.strip()]


def load_templates(src: Path) -> dict[str, dict[str, str]]:
    for node in ast.parse(src.read_text(encoding="utf-8")).body:
        target = node.targets[0] if isinstance(node, ast.Assign) else getattr(node, "target", None)
        if getattr(target, "id", None) == "T":
            return ast.literal_eval(node.value)
    raise SystemExit(f"no T = {{...}} templates dict in {src}")


def build(templates: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    out: dict[str, dict[str, str]] = {}
    for key, by_lang in templates.items():
        if key.startswith(SKIP_PREFIXES) or not all(isinstance(by_lang.get(lg), str) for lg in LANGS):
            continue
        if any("{" in by_lang[lg] for lg in LANGS):
            continue
        split = {lg: split_sentences(by_lang[lg]) for lg in LANGS}
        if max(len(s) for s in split.values()) == 1:
            out[key] = {lg: split[lg][0] for lg in LANGS if split[lg]}
            continue
        # Multi-sentence: one entry per sentence (languages may split differently; ids stay per language)
        for lg in LANGS:
            for i, sent in enumerate(split[lg], 1):
                out.setdefault(f"{key}.{i}", {})[lg] = sent
    for key, by_lang in EXTRA.items():
        out.setdefault(key, by_lang)
    return out


def main() -> None:
    phrases = build(load_templates(SRC))
    OUT.write_text(json.dumps(phrases, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    n = sum(len(v) for v in phrases.values())
    print(f"wrote {OUT.relative_to(ROOT)}: {len(phrases)} ids, {n} phrases")


if __name__ == "__main__":
    sys.exit(main())
