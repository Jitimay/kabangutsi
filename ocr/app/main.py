"""Kabangutsi OCR + PDF service (contracts/ocr_api.yaml), port 8002. Called only by the backend.

Privacy: OCR text and field values are never logged (a CNI holds a date of birth).
No LLM is called: extraction uses local rules from the YAML registry.
"""

from __future__ import annotations

import logging
import threading
import time
import traceback
from contextlib import asynccontextmanager
from typing import Any, Literal

from fastapi import FastAPI, File, Form, Request, UploadFile
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, Response
from pydantic import BaseModel, ConfigDict, ValidationError
from starlette.concurrency import run_in_threadpool

from . import config, engines, extract, pdf, preprocess
from .registry import load_registry

log = logging.getLogger("ocr")
REGISTRY = load_registry(config.DOC_TYPES_DIR)


def _warmup() -> None:
    t0 = time.perf_counter()
    try:
        engines.PADDLE.warmup()
        log.info("paddleocr warm-up done in %d ms", int((time.perf_counter() - t0) * 1000))
    except Exception as e:  # noqa: BLE001 - Tesseract fallback still works
        log.warning("paddleocr warm-up failed: %s", type(e).__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI):
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    log.info("models dir %s, engines %s, doc types %d", config.MODELS_DIR, engines.available_engines(), len(REGISTRY))
    if config.WARMUP and engines.PADDLE.available():
        # background: /health answers at once; the first OCR request waits on the same Paddle thread
        threading.Thread(target=_warmup, name="paddle-warmup", daemon=True).start()
    yield


app = FastAPI(title="Kabangutsi OCR + PDF service", version="1.0.0", lifespan=lifespan)

# Error messages in the caller's language (contracts: fr, en, rn; rn is a draft for native review).
MESSAGES = {
    "too_large": {"fr": "Image trop grande (10 Mo maximum).", "en": "Image larger than 10 MB.",
                  "rn": "Ifoto ni nini cane (ntirenge 10 MB)."},
    "unsupported_media_type": {"fr": "Seules les images jpeg, png ou webp sont acceptées.",
                               "en": "Only jpeg, png or webp images are accepted.",
                               "rn": "Hakirwa gusa amafoto ya jpeg, png canke webp."},
    "undecodable": {"fr": "L'image n'a pas pu être lue.", "en": "The image could not be read.",
                    "rn": "Ifoto ntishoboye gusomwa."},
    "unknown_doc_type": {"fr": "Type de document inconnu.", "en": "Unknown document type.",
                         "rn": "Ubwoko bw'urupapuro ntibuzwi."},
    "no_engine": {"fr": "Lecture de document indisponible.", "en": "Document reading is unavailable.",
                  "rn": "Gusoma impapuro ntibishoboka ubu."},
}


def msg(key: str, lang: str | None) -> str:
    return MESSAGES[key][lang or "en"]


class ApiError(Exception):
    def __init__(self, status: int, code: str, message: str, details: dict | None = None):
        self.status, self.code, self.message, self.details = status, code, message, details


def _err(status: int, code: str, message: str, details: dict | None = None) -> JSONResponse:
    body: dict[str, Any] = {"code": code, "message": message}
    if details:
        body["details"] = details
    return JSONResponse(body, status_code=status)


@app.exception_handler(ApiError)
async def _api_error(_req: Request, e: ApiError):
    return _err(e.status, e.code, e.message, e.details)


@app.exception_handler(RequestValidationError)
async def _validation_error(_req: Request, e: RequestValidationError):
    errs = [{"loc": list(x["loc"]), "msg": x["msg"]} for x in e.errors()]
    return _err(422, "validation_error", "Invalid request", {"errors": errs})


@app.exception_handler(Exception)
async def _internal(_req: Request, e: Exception):
    # type + code locations only: the exception text could quote OCR content or field values
    where = " < ".join(f"{f.name}:{f.lineno}" for f in reversed(traceback.extract_tb(e.__traceback__)))
    log.error("internal error: %s at %s", type(e).__name__, where)
    return _err(500, "internal_error", "Internal error")


# ---------------------------------------------------------------- health / registry
@app.get("/health")
def health():
    eng = engines.available_engines()
    return {"status": "ok" if eng else "degraded", "engines": eng, "doc_types": len(REGISTRY)}


@app.get("/doc-types")
def doc_types():
    return {"items": [dt.public() for dt in REGISTRY.values()]}


# ---------------------------------------------------------------- OCR
def _sniff(data: bytes) -> str | None:
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    return None


def _extract(data: bytes, doc_type: str | None, lang: str | None) -> dict[str, Any]:
    t0 = time.perf_counter()
    img = preprocess.decode(data)
    if img is None:
        raise ApiError(415, "unsupported_media_type", msg("undecodable", lang))
    img = preprocess.preprocess(img, config.MAX_SIDE)
    engine, lines = engines.run_ocr(img)
    if doc_type:
        dt, dt_conf = REGISTRY[doc_type], 1.0
    else:
        dt, dt_conf = extract.detect(lines, REGISTRY)
    fields = extract.extract(dt, lines, config.REVIEW_THRESHOLD)
    ms = int((time.perf_counter() - t0) * 1000)
    log.info("extract doc_type=%s engine=%s lines=%d fields=%d review=%s ms=%d",
             dt.id, engine, len(lines), len(fields), any(f["needs_review"] for f in fields), ms)
    return {
        "doc_type": dt.id,
        "doc_type_confidence": dt_conf,
        "fields": fields,
        "needs_review": any(f["needs_review"] for f in fields),
        "route_to": dt.route_to,
        "raw_text": "\n".join(ln.text for ln in lines),
        "processing_ms": ms,
        "engine": engine,
    }


@app.post("/ocr/extract")
async def ocr_extract(image: UploadFile = File(...), doc_type: str | None = Form(None),
                      lang: Literal["fr", "en", "rn"] | None = Form(None)):
    data = await image.read(config.MAX_UPLOAD_BYTES + 1)
    if len(data) > config.MAX_UPLOAD_BYTES:
        raise ApiError(413, "too_large", msg("too_large", lang))
    if _sniff(data) is None:
        raise ApiError(415, "unsupported_media_type", msg("unsupported_media_type", lang))
    if doc_type and doc_type not in REGISTRY:
        raise ApiError(422, "unknown_doc_type", msg("unknown_doc_type", lang),
                       {"doc_type": doc_type, "known": sorted(REGISTRY)})
    try:
        return await run_in_threadpool(_extract, data, doc_type or None, lang)
    except engines.NoEngineError as e:
        raise ApiError(500, "internal_error", msg("no_engine", lang)) from e


# ---------------------------------------------------------------- PDF
class PdfRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    template: str
    lang: Literal["fr", "en", "rn"]
    data: dict[str, Any]


@app.post("/pdf/render")
async def pdf_render(req: PdfRequest):
    model = pdf.TEMPLATES.get(req.template)
    if model is None:
        raise ApiError(422, "unknown_template", f"Unknown template {req.template!r}",
                       {"known": sorted(pdf.TEMPLATES)})
    try:
        data = model.model_validate(req.data)
    except ValidationError as e:
        errs = [{"loc": ["data", *x["loc"]], "msg": x["msg"]} for x in e.errors()]
        raise ApiError(422, "validation_error", "Invalid template data", {"errors": errs}) from e
    body = await run_in_threadpool(pdf.render, req.template, req.lang, data)
    name = f"{req.template}_{req.lang}.pdf"
    return Response(body, media_type="application/pdf",
                    headers={"Content-Disposition": f'inline; filename="{name}"'})
