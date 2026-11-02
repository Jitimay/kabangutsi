#!/usr/bin/env python3
"""Merge lib/core/l10n/fragments/<feature>_<lang>.json into lib/core/l10n/arb/app_<lang>.arb.

Each feature owns its own fragment files, so parallel work never edits the same file.
Fails if a key is defined twice or if fr/en/rn do not have exactly the same keys (hard rule 6).
Run from frontend/:  python3 tool/merge_arb.py && flutter gen-l10n
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib" / "core" / "l10n"
LANGS = ["en", "fr", "rn"]
merged = {}
for lang in LANGS:
    out = {"@@locale": lang}
    for f in sorted((ROOT / "fragments").glob(f"*_{lang}.json")):
        for k, v in json.loads(f.read_text(encoding="utf-8")).items():
            if k in out:
                sys.exit(f"duplicate key {k!r} in {f.name}")
            out[k] = v
    merged[lang] = out
keys = {lang: set(merged[lang]) - {"@@locale"} for lang in LANGS}
for lang in LANGS:
    if keys[lang] != keys["en"]:
        sys.exit(f"{lang} keys differ from en: missing {sorted(keys['en'] - keys[lang])}, extra {sorted(keys[lang] - keys['en'])}")
for lang in LANGS:
    (ROOT / "arb" / f"app_{lang}.arb").write_text(json.dumps(merged[lang], ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"merged {len(keys['en'])} keys x {len(LANGS)} languages")
