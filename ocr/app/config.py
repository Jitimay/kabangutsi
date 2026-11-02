"""Settings from environment variables (all have working defaults)."""

from __future__ import annotations

import os
from pathlib import Path

OCR_DIR = Path(__file__).resolve().parents[1]
DOC_TYPES_DIR = Path(os.environ.get("OCR_DOC_TYPES_DIR", OCR_DIR / "doc_types"))
DET_MODEL = os.environ.get("OCR_DET_MODEL", "PP-OCRv5_mobile_det")
REC_MODEL = os.environ.get("OCR_REC_MODEL", "latin_PP-OCRv5_mobile_rec")
# Models baked into the Docker image at build time (ocr/Dockerfile).
BAKED_MODELS_DIR = Path(os.environ.get("OCR_BAKED_MODELS_DIR", "/opt/ocr-models"))


def has_models(d: Path) -> bool:
    return all((d / m / "inference.yml").exists() for m in (DET_MODEL, REC_MODEL))


def _models_dir() -> Path:
    """OCR_MODELS_DIR if it holds both models, else the models baked into the image.

    Compose mounts the (initially empty) `ocr-models` volume on /models: the baked copy is used
    until someone puts other models there. Nothing is ever downloaded.
    """
    wanted = Path(os.environ.get("OCR_MODELS_DIR", Path.home() / ".paddlex" / "official_models"))
    if not has_models(wanted) and has_models(BAKED_MODELS_DIR):
        return BAKED_MODELS_DIR
    return wanted


MODELS_DIR = _models_dir()
# auto = PaddleOCR, Tesseract if Paddle is unavailable; or force one
ENGINE = os.environ.get("OCR_ENGINE", "auto")
REVIEW_THRESHOLD = float(os.environ.get("OCR_REVIEW_THRESHOLD", "0.8"))
MAX_UPLOAD_BYTES = 10 * 1024 * 1024
MAX_SIDE = int(os.environ.get("OCR_MAX_SIDE", "1600"))

WARMUP = os.environ.get("OCR_WARMUP", "1") == "1"

# never let PaddleX reach model hosters at runtime (models are baked into the image)
os.environ.setdefault("PADDLE_PDX_DISABLE_MODEL_SOURCE_CHECK", "True")
