"""OCR engines. PaddleOCR (primary, models from OCR_MODELS_DIR) and Tesseract (fallback).

Both return lines with text, confidence (0..1) and an axis-aligned box (x0, y0, x1, y1).
Nothing is downloaded at runtime: Paddle is given local model directories.
"""

from __future__ import annotations

import logging
import shutil
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass

import numpy as np

from . import config

log = logging.getLogger("ocr.engines")


@dataclass
class Line:
    text: str
    score: float
    box: tuple[float, float, float, float]

    @property
    def cy(self) -> float:
        return (self.box[1] + self.box[3]) / 2

    @property
    def h(self) -> float:
        return max(1.0, self.box[3] - self.box[1])


class PaddleEngine:
    name = "paddleocr"

    def __init__(self) -> None:
        self._ocr = None
        # Paddle/oneDNN keeps per-thread state: calling one predictor from several threads
        # fails at random ("RuntimeError: std::exception"). All Paddle work runs on this thread.
        self._thread = ThreadPoolExecutor(max_workers=1, thread_name_prefix="paddle")

    def available(self) -> bool:
        try:
            import paddleocr  # noqa: F401
        except ImportError:
            return False
        return config.has_models(config.MODELS_DIR)

    def _load(self):
        if self._ocr is None:
            from paddleocr import PaddleOCR

            self._ocr = PaddleOCR(
                use_doc_orientation_classify=False, use_doc_unwarping=False,
                use_textline_orientation=False,
                text_detection_model_name=config.DET_MODEL,
                text_detection_model_dir=str(config.MODELS_DIR / config.DET_MODEL),
                text_recognition_model_name=config.REC_MODEL,
                text_recognition_model_dir=str(config.MODELS_DIR / config.REC_MODEL),
            )
        return self._ocr

    def warmup(self) -> None:
        """Load the models and run one tiny image on the Paddle thread (first real call is then fast)."""
        blank = np.full((64, 256, 3), 255, np.uint8)
        self._thread.submit(lambda: self._load().predict(blank)).result()

    def run(self, img: np.ndarray) -> list[Line]:
        res = self._thread.submit(lambda: self._load().predict(img)[0]).result()
        boxes = res["rec_boxes"]
        return [Line(t, float(s), tuple(float(v) for v in b))
                for t, s, b in zip(res["rec_texts"], res["rec_scores"], boxes) if t.strip()]


class TesseractEngine:
    name = "tesseract"

    def available(self) -> bool:
        try:
            import pytesseract  # noqa: F401
        except ImportError:
            return False
        return shutil.which("tesseract") is not None

    def run(self, img: np.ndarray) -> list[Line]:
        import pytesseract

        d = pytesseract.image_to_data(img[:, :, ::-1], lang="fra+eng",
                                      output_type=pytesseract.Output.DICT)
        groups: dict[tuple, list[int]] = {}
        for i, t in enumerate(d["text"]):
            if t.strip() and float(d["conf"][i]) >= 0:
                groups.setdefault((d["block_num"][i], d["par_num"][i], d["line_num"][i]), []).append(i)
        lines = []
        for idx in groups.values():
            x0 = min(d["left"][i] for i in idx)
            y0 = min(d["top"][i] for i in idx)
            x1 = max(d["left"][i] + d["width"][i] for i in idx)
            y1 = max(d["top"][i] + d["height"][i] for i in idx)
            text = " ".join(d["text"][i] for i in idx)
            score = sum(float(d["conf"][i]) for i in idx) / len(idx) / 100
            lines.append(Line(text, score, (x0, y0, x1, y1)))
        return lines


class NoEngineError(RuntimeError):
    pass


PADDLE = PaddleEngine()
TESSERACT = TesseractEngine()


def available_engines() -> list[str]:
    return [e.name for e in (PADDLE, TESSERACT) if e.available()]


def run_ocr(img: np.ndarray) -> tuple[str, list[Line]]:
    """Run the configured engine; in auto mode fall back to Tesseract if Paddle fails."""
    order = {"paddle": [PADDLE], "tesseract": [TESSERACT]}.get(config.ENGINE, [PADDLE, TESSERACT])
    last: Exception | None = None
    for eng in order:
        if not eng.available():
            continue
        try:
            return eng.name, eng.run(img)
        except Exception as e:  # noqa: BLE001 - try the next engine
            log.warning("engine %s failed: %s", eng.name, type(e).__name__)  # no message: may quote text
            last = e
    raise NoEngineError("no OCR engine available") from last
