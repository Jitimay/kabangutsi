#!/usr/bin/env python3
"""Kabangutsi Wave 7 evaluation: 150 utterances (50 fr, 50 en, 50 rn) against the running backend.

Each utterance is sent as a fresh conversation through the contract endpoint
POST /v1/channels/web/inbound (InboundMessage, lang=null so language detection is tested too),
and the OutgoingReply is scored:

  intent accuracy per language   reply.intent == expected          target >= 85 % (PRD)
  language detection             reply.lang == utterance language
  frustration / handoff          cases with min_frustration, and every `handoff` case, must give reply.handoff=true
  grounding                      every number in the reply must exist in the seed data (KB, branches, loans)
                                 or in the question; replies with a loan simulation, ticket or card block
                                 reference are exempt (computed in code)      target 100 % (PRD)
  latency                        p50 / p95 per reply (no streaming)

Standard library only. Usage:
  python3 scripts/eval/run_eval.py --check                 # validate the test set, no backend needed
  python3 scripts/eval/run_eval.py [--url http://localhost:8000] [--lang rn] [--limit 10]
Results are written to scripts/eval/results/<UTC timestamp>.json (git-ignored).
"""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
import time
import urllib.error
import urllib.request
import uuid
from collections import Counter, defaultdict
from datetime import UTC, datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
SEED = HERE.parent / "seed"
LANGS = ("fr", "en", "rn")
INTENTS = {"product_info", "account_opening", "card_block", "loan_info", "complaint", "branch_info", "handoff", "other"}
ENTITY_KEYS = {"province", "town", "branch_name", "product", "loan_amount", "term_months", "card_last4", "card_issue",
               "complaint_category", "ticket_number", "urgency", "topic"}
TARGET_ACCURACY = 0.85
NUM_RE = re.compile(r"\d+(?:[   .,]\d{3})*(?:[.,]\d+)?")


def load_cases() -> list[dict]:
    return json.loads((HERE / "utterances.json").read_text())["cases"]


def check_set(cases: list[dict]) -> list[str]:
    errs = []
    ids = Counter(c["id"] for c in cases)
    errs += [f"duplicate id {i}" for i, n in ids.items() if n > 1]
    for c in cases:
        if c["intent"] not in INTENTS:
            errs.append(f"{c['id']}: unknown intent {c['intent']}")
        if set(c["entities"]) - ENTITY_KEYS:
            errs.append(f"{c['id']}: unknown entity keys {set(c['entities']) - ENTITY_KEYS}")
        for lang in LANGS:
            if not c.get(lang, "").strip():
                errs.append(f"{c['id']}: missing {lang} text")
    per_lang = {lang: sum(1 for c in cases if c.get(lang)) for lang in LANGS}
    if any(n != 50 for n in per_lang.values()):
        errs.append(f"expected 50 utterances per language, got {per_lang}")
    missing = INTENTS - {c["intent"] for c in cases}
    if missing:
        errs.append(f"intents without test cases: {missing}")
    return errs


def numbers(text: str) -> set[int]:
    out = set()
    for tok in NUM_RE.findall(text):
        tok = re.sub(r"[   ]", "", tok)
        if re.fullmatch(r"\d+([.,]\d{3})+", tok):  # thousands separators
            tok = re.sub(r"[.,]", "", tok)
        tok = tok.replace(",", ".")
        try:
            v = float(tok)
        except ValueError:
            continue
        out.add(int(v)) if v.is_integer() else out.update({int(v), round(v * 100)})
    return out


def allowed_numbers() -> set[int]:
    texts = [(SEED / f).read_text() for f in ("kb_articles.json", "branches.json", "loan_products.json")]
    allowed = set()
    for t in texts:
        allowed |= numbers(t)
    return allowed | set(range(0, 11))  # small counting words ("2 documents", "option 4")


def post(url: str, body: dict, timeout: float) -> tuple[dict, float]:
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json", "Accept": "application/json"})
    t0 = time.perf_counter()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        data = json.loads(r.read())
    return data, time.perf_counter() - t0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--url", default="http://localhost:8000")
    ap.add_argument("--lang", choices=LANGS)
    ap.add_argument("--limit", type=int, help="first N cases per language")
    ap.add_argument("--timeout", type=float, default=60)
    ap.add_argument("--check", action="store_true", help="only validate the test set")
    args = ap.parse_args()

    cases = load_cases()
    errs = check_set(cases)
    if errs:
        print("Test set problems:\n - " + "\n - ".join(errs))
        return 2
    by_intent = Counter(c["intent"] for c in cases)
    print(f"Test set OK: {len(cases)} cases x {len(LANGS)} languages = {len(cases) * len(LANGS)} utterances; "
          f"per intent: {dict(by_intent)}")
    if args.check:
        return 0

    allowed = allowed_numbers()
    endpoint = args.url.rstrip("/") + "/v1/channels/web/inbound"
    langs = [args.lang] if args.lang else list(LANGS)
    rows = []
    for lang in langs:
        for c in cases[: args.limit] if args.limit else cases:
            text = c[lang]
            sid = str(uuid.uuid4())
            msg = {"id": str(uuid.uuid4()), "channel": "web", "phone": None, "session_id": sid, "lang": None,
                   "text": text, "attachments": [], "ts": datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")}
            row = {"id": c["id"], "lang": lang, "text": text, "expected_intent": c["intent"]}
            try:
                reply, dt = post(endpoint, msg, args.timeout)
            except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
                row.update(error=str(exc))
                rows.append(row)
                print(f"  ERR  {lang} {c['id']}: {exc}")
                continue
            actions = {a.get("type") for a in reply.get("actions", [])}
            exempt = bool(actions & {"loan_simulation", "ticket_created", "card_block"})
            ungrounded = sorted(numbers(reply.get("text", "")) - allowed - numbers(text)) if not exempt else []
            must_handoff = c["intent"] == "handoff" or "min_frustration" in c
            row.update(
                got_intent=reply.get("intent"), got_lang=reply.get("lang"), handoff=reply.get("handoff"),
                latency_s=round(dt, 3), reply=reply.get("text"), model=reply.get("model_used"),
                intent_ok=reply.get("intent") == c["intent"], lang_ok=reply.get("lang") == lang,
                handoff_ok=(reply.get("handoff") is True) if must_handoff else None,
                ungrounded_numbers=ungrounded,
            )
            rows.append(row)
            mark = "ok " if row["intent_ok"] else "BAD"
            print(f"  {mark} {lang} {c['id']:8} {row['got_intent']!s:16} {dt:5.1f}s  {text[:60]}")

    # ---------- report ----------
    print("\n=== Results ===")
    failed = False
    per = defaultdict(list)
    for r in rows:
        per[r["lang"]].append(r)
    for lang in langs:
        rs = per[lang]
        done = [r for r in rs if "error" not in r]
        acc = sum(r["intent_ok"] for r in done) / len(rs) if rs else 0
        lang_acc = sum(r["lang_ok"] for r in done) / len(rs) if rs else 0
        flag = "PASS" if acc >= TARGET_ACCURACY else "FAIL"
        failed |= acc < TARGET_ACCURACY
        print(f"{lang}: intent {acc:6.1%} [{flag} target {TARGET_ACCURACY:.0%}]  language detection {lang_acc:6.1%}  "
              f"errors {len(rs) - len(done)}")
        confusions = Counter((r["expected_intent"], r["got_intent"]) for r in done if not r["intent_ok"])
        for (exp, got), n in confusions.most_common(5):
            print(f"      {exp} -> {got}: {n}")
    done = [r for r in rows if "error" not in r]
    ho = [r for r in done if r["handoff_ok"] is not None]
    if ho:
        print(f"handoff on request/frustration: {sum(r['handoff_ok'] for r in ho)}/{len(ho)}")
    ung = [r for r in done if r["ungrounded_numbers"]]
    grounded = 1 - len(ung) / len(done) if done else 0
    failed |= bool(ung)
    if done:
        print(f"grounding (numbers from KB only): {grounded:.1%} [{'PASS' if not ung else 'FAIL'} target 100%]")
    else:
        print("grounding: n/a (no replies)")
    for r in ung[:10]:
        print(f"      {r['lang']} {r['id']}: {r['ungrounded_numbers']}  «{(r['reply'] or '')[:90]}»")
    lat = [r["latency_s"] for r in done]
    if lat:
        p95 = statistics.quantiles(lat, n=20)[-1] if len(lat) >= 20 else max(lat)
        print(f"latency: p50 {statistics.median(lat):.2f}s  p95 {p95:.2f}s  (full reply, not first token)")

    out = HERE / "results"
    out.mkdir(exist_ok=True)
    path = out / f"{datetime.now(UTC).strftime('%Y%m%dT%H%M%SZ')}.json"
    path.write_text(json.dumps({"url": args.url, "rows": rows}, ensure_ascii=False, indent=1))
    print(f"\nDetails: {path.relative_to(HERE.parent.parent)}")
    return 1 if failed or len(done) < len(rows) else 0


if __name__ == "__main__":
    sys.exit(main())
