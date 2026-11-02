"""Put the PaddleOCR models in a directory at BUILD time (ocr/Dockerfile). Never run at runtime.

    python scripts/fetch_models.py /opt/ocr-models [--from ./models]

--from: copy from a local folder (offline rebuild; e.g. a copy of ~/.paddlex/official_models).
Otherwise PaddleOCR downloads them once here, and they are moved to the target.
"""

from __future__ import annotations

import argparse
import os
import shutil
import sys
from pathlib import Path

DET = os.environ.get("OCR_DET_MODEL", "PP-OCRv5_mobile_det")
REC = os.environ.get("OCR_REC_MODEL", "latin_PP-OCRv5_mobile_rec")


def ok(d: Path) -> bool:
    return all((d / m / "inference.yml").exists() and (d / m / "inference.pdiparams").exists() for m in (DET, REC))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("target", type=Path)
    ap.add_argument("--from", dest="src", type=Path)
    a = ap.parse_args()
    a.target.mkdir(parents=True, exist_ok=True)
    if a.src and ok(a.src):
        src = a.src
        print(f"copying models from {src}")
    else:
        from paddleocr import PaddleOCR  # downloads into ~/.paddlex/official_models

        PaddleOCR(use_doc_orientation_classify=False, use_doc_unwarping=False, use_textline_orientation=False,
                  text_detection_model_name=DET, text_recognition_model_name=REC)
        src = Path.home() / ".paddlex" / "official_models"
    for m in (DET, REC):
        shutil.copytree(src / m, a.target / m, dirs_exist_ok=True)
    if not ok(a.target):
        print(f"models missing in {a.target}", file=sys.stderr)
        return 1
    print(f"models ready in {a.target}: {DET}, {REC}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
