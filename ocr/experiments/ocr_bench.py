"""Pre-G0 test: OCR accuracy and CPU time on the fictional samples.

    python ocr_bench.py SAMPLES_DIR --engine paddle [--det-dir D --rec-dir R]
    python ocr_bench.py SAMPLES_DIR --engine tesseract

Accuracy, per document:
  field hit  = expected field value found in OCR text (case/space-insensitive)
  char acc   = 1 - CER of each expected value vs. its best-matching OCR line (difflib)
Time = wall time per image after the model is loaded (load time printed separately).

Offline: pass --det-dir/--rec-dir pointing at pre-downloaded models and set
PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK=True; then run under `unshare -rn` (no network)
to prove nothing is fetched at runtime.
"""

import argparse
import difflib
import json
import re
import time
from pathlib import Path


def norm(s: str) -> str:
    return re.sub(r"\s+", "", s).lower()


def score(lines: list[str], fields: dict[str, str]) -> tuple[float, float, dict]:
    blob = norm(" ".join(lines))
    hits, accs, detail = 0, [], {}
    for k, v in fields.items():
        hit = norm(v) in blob
        hits += hit
        best = max((difflib.SequenceMatcher(None, norm(v), norm(seg)).ratio()
                    for line in lines for seg in [line, *line.split(":")]), default=0.0)
        accs.append(1.0 if hit else best)
        detail[k] = {"expected": v, "hit": hit, "char_acc": round(1.0 if hit else best, 2)}
    return hits / len(fields), sum(accs) / len(accs), detail


def paddle_engine(a):
    from paddleocr import PaddleOCR

    kw = dict(lang="fr", use_doc_orientation_classify=False, use_doc_unwarping=False,
              use_textline_orientation=False,
              text_detection_model_name=a.det_name, text_recognition_model_name=a.rec_name)
    if a.det_dir:
        kw["text_detection_model_dir"] = a.det_dir
    if a.rec_dir:
        kw["text_recognition_model_dir"] = a.rec_dir
    if a.no_mkldnn:
        kw["enable_mkldnn"] = False
    ocr = PaddleOCR(**kw)

    def run(path: str) -> list[tuple[str, float]]:
        res = ocr.predict(path)[0]
        return list(zip(res["rec_texts"], res["rec_scores"]))

    return run


def tesseract_engine(a):
    import pytesseract
    from PIL import Image

    def run(path: str) -> list[tuple[str, float]]:
        d = pytesseract.image_to_data(Image.open(path), lang="fra+eng",
                                      output_type=pytesseract.Output.DICT)
        lines: dict[tuple, list] = {}
        for i, t in enumerate(d["text"]):
            if t.strip():
                lines.setdefault((d["block_num"][i], d["par_num"][i], d["line_num"][i]), []).append(
                    (t, float(d["conf"][i]) / 100))
        return [(" ".join(w for w, _ in ws), sum(c for _, c in ws) / len(ws)) for ws in lines.values()]

    return run


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("samples")
    p.add_argument("--engine", choices=["paddle", "tesseract"], default="paddle")
    p.add_argument("--det-name", default="PP-OCRv5_mobile_det")
    p.add_argument("--rec-name", default="latin_PP-OCRv5_mobile_rec")
    p.add_argument("--det-dir")
    p.add_argument("--rec-dir")
    p.add_argument("--no-mkldnn", action="store_true",
                   help="workaround for paddlepaddle 3.3 oneDNN 'ConvertPirAttribute' crash")
    p.add_argument("--dump", action="store_true", help="print raw OCR lines")
    a = p.parse_args()

    t0 = time.perf_counter()
    run = (paddle_engine if a.engine == "paddle" else tesseract_engine)(a)
    print(f"engine={a.engine} load={time.perf_counter() - t0:.1f}s")

    rows = []
    for img in sorted(Path(a.samples).glob("*.png")):
        truth = json.loads(img.with_suffix(".json").read_text())
        run(str(img)) if not rows else None  # warm-up on first image
        t = time.perf_counter()
        out = run(str(img))
        dt = time.perf_counter() - t
        lines = [txt for txt, _ in out]
        hit, acc, detail = score(lines, truth["fields"])
        conf = sum(c for _, c in out) / max(len(out), 1)
        rows.append((img.stem, dt, hit, acc, conf))
        print(f"\n== {img.stem}: {dt:.2f}s  field_hit={hit:.0%}  char_acc={acc:.0%}  mean_conf={conf:.2f}")
        for k, v in detail.items():
            if not v["hit"]:
                print(f"   MISS {k}: expected {v['expected']!r} (best char_acc {v['char_acc']})")
        if a.dump:
            for txt, c in out:
                print(f"   {c:.2f} {txt}")

    print("\n| doc | s/image | field hit | char acc | mean conf |\n|---|---|---|---|---|")
    for name, dt, hit, acc, conf in rows:
        print(f"| {name} | {dt:.2f} | {hit:.0%} | {acc:.0%} | {conf:.2f} |")


if __name__ == "__main__":
    main()
