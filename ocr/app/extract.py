"""Doc-type detection and label-anchored field extraction from OCR lines (local rules, no LLM).

For each field, find a line whose label part equals one of the field's labels; the value is
  1. the text after ':' on the same line, else
  2. the nearest line to the right on the same row, else
  3. the nearest line below (left-aligned with the label).
Then: optional pattern, type normalisation, validation, confidence = OCR score x match factor.
"""

from __future__ import annotations

import difflib
import re
import unicodedata
from datetime import date
from typing import Any

from .engines import Line
from .registry import DocType, FieldSpec

FACTOR = {"colon": 1.0, "right": 1.0, "below": 0.95}
LABEL_MATCH = 0.86  # fuzzy ratio to accept an OCR'd label


def key(s: str) -> str:
    """Comparison key: lowercase, no accents, only letters and digits."""
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c for c in s if not unicodedata.combining(c))
    return re.sub(r"[^a-z0-9]", "", s)


def _same(a: str, b: str) -> bool:
    return a == b or (len(b) >= 4 and difflib.SequenceMatcher(None, a, b).ratio() >= LABEL_MATCH)


# ---------------------------------------------------------------- doc type detection
def detect(lines: list[Line], types: dict[str, DocType]) -> tuple[DocType, float]:
    blob = key(" ".join(ln.text for ln in lines))
    best, best_score = None, 0.0
    for dt in types.values():
        kws = dt.detect.keywords
        if not kws:
            continue
        hits = sum(1 for k in kws if key(k) in blob)
        # confidence grows with keyword hits: 1 hit = 0.4, 3+ hits = 0.8+, all = 1.0
        score = 0.0 if hits == 0 else min(1.0, 0.2 + 0.2 * hits + 0.2 * hits / len(kws))
        if score > best_score:
            best, best_score = dt, score
    if best is not None and best_score >= 0.4:
        return best, round(best_score, 2)
    fallback = next((dt for dt in types.values() if dt.detect.fallback), None)
    if fallback is None:
        fallback = best or next(iter(types.values()))
    return fallback, round(max(best_score, 0.3), 2)


# ---------------------------------------------------------------- value location
def _split_label(text: str) -> tuple[str, str | None]:
    if ":" in text:
        lab, val = text.split(":", 1)
        return lab, val.strip()
    return text, None


def _is_label(line: Line, all_labels: set[str]) -> bool:
    lab, _ = _split_label(line.text)
    k = key(lab)
    return any(_same(k, lk) for lk in all_labels)


def find_value(lines: list[Line], labels: list[str], all_labels: set[str]) -> tuple[str, float, str] | None:
    """Return (raw value, ocr score, how) for the first matching label."""
    wanted = [key(lb) for lb in labels]
    for want in wanted:
        for ln in lines:
            lab, val = _split_label(ln.text)
            if not _same(key(lab), want):
                continue
            if val:
                return val, ln.score, "colon"
            # same row, to the right
            row = [o for o in lines if o is not ln and o.box[0] >= ln.box[2] - 5
                   and abs(o.cy - ln.cy) < 0.6 * max(ln.h, o.h) and not _is_label(o, all_labels)]
            if row:
                o = min(row, key=lambda o: o.box[0] - ln.box[2])
                return o.text.lstrip(": ").strip(), o.score, "right"
            # below, left-aligned (within one label width)
            below = [o for o in lines if o is not ln and o.box[1] >= ln.cy
                     and o.box[1] - ln.box[3] < 2.5 * ln.h
                     and abs(o.box[0] - ln.box[0]) < max(80.0, (ln.box[2] - ln.box[0]))
                     and not _is_label(o, all_labels)]
            if below:
                o = min(below, key=lambda o: o.box[1])
                return o.text.lstrip(": ").strip(), o.score, "below"
    return None


# ---------------------------------------------------------------- normalisation
def normalize(value: str, ftype: str) -> tuple[Any, bool]:
    """Return (typed value, parsed_ok)."""
    v = value.strip()
    if ftype == "string":
        return re.sub(r"\s+", " ", v), bool(v)
    if ftype == "integer":
        digits = re.sub(r"(?i)fbu|bif|[\s.,'_]", "", v)
        digits = digits.replace("O", "0").replace("o", "0")
        return (int(digits), True) if digits.isdigit() else (v, False)
    if ftype == "number":
        m = re.search(r"\d[\d\s]*(?:[.,]\d+)?", v)
        if not m:
            return v, False
        n = m.group(0).replace(" ", "").replace(",", ".")
        return float(n), True
    if ftype == "date":
        m = re.search(r"(\d{1,2})\s*[/.-]\s*(\d{1,2})\s*[/.-]\s*(\d{4})", v)
        if m:
            d, mo, y = map(int, m.groups())
        else:
            m = re.search(r"(\d{4})-(\d{2})-(\d{2})", v)
            if not m:
                return v, False
            y, mo, d = map(int, m.groups())
        try:
            return date(y, mo, d).isoformat(), True
        except ValueError:
            return v, False
    return v, False


def validate(value: Any, spec: FieldSpec) -> bool:
    rule = spec.validate_
    if rule.regex and not re.fullmatch(rule.regex, str(value)):
        return False
    if spec.type in ("integer", "number"):
        if rule.min is not None and value < float(rule.min):
            return False
        if rule.max is not None and value > float(rule.max):
            return False
    if spec.type == "date":
        if rule.min is not None and value < str(rule.min):
            return False
        if rule.max is not None and value > str(rule.max):
            return False
    return True


# ---------------------------------------------------------------- per field
def extract_field(spec: FieldSpec, lines: list[Line], all_labels: set[str],
                  threshold: float) -> dict[str, Any] | None:
    if spec.source == "all_text":
        if not lines:
            return None
        text = " ".join(ln.text for ln in lines)
        conf = sum(ln.score for ln in lines) / len(lines)
        return _result(spec, text, conf, True, threshold)

    groups = [p.labels for p in spec.parts] if spec.parts else [spec.labels]
    found = [find_value(lines, g, all_labels) for g in groups]
    if any(f is None for f in found):
        if not spec.required:
            return None  # missing optional field: omitted
        return {"name": spec.name, "value": None, "confidence": 0.0, "valid": False, "needs_review": True}
    raw = " ".join(f[0] for f in found)
    conf = min(f[1] * FACTOR[f[2]] for f in found)
    if spec.pattern:
        m = re.search(spec.pattern, raw)
        if m:
            raw = m.group(1) if m.groups() else m.group(0)
        else:
            conf *= 0.5
    value, ok = normalize(raw, spec.type)
    valid = ok and validate(value, spec)
    return _result(spec, value, conf, valid, threshold)


def _result(spec: FieldSpec, value: Any, conf: float, valid: bool, threshold: float) -> dict[str, Any]:
    conf = round(max(0.0, min(1.0, conf)), 2)
    return {"name": spec.name, "value": value, "confidence": conf, "valid": valid,
            "needs_review": conf < threshold or not valid}


def extract(dt: DocType, lines: list[Line], threshold: float = 0.8) -> list[dict[str, Any]]:
    all_labels = {key(lb) for f in dt.fields for lb in f.labels}
    all_labels |= {key(lb) for f in dt.fields for p in f.parts for lb in p.labels}
    # top-to-bottom, left-to-right reading order
    ordered = sorted(lines, key=lambda ln: (round(ln.cy / max(ln.h, 1)), ln.box[0]))
    out = []
    for spec in dt.fields:
        r = extract_field(spec, ordered, all_labels, threshold)
        if r is not None:
            out.append(r)
    return out
