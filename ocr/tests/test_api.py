import io
import json

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.main import app
from tests.conftest import SAMPLES
from tests.test_pdf import LOAN

client = TestClient(app)


def png(w=50, h=50) -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (w, h), "white").save(buf, "PNG")
    return buf.getvalue()


def test_health(contract_doc):
    r = client.get("/health")
    assert r.status_code == 200
    body = r.json()
    assert body["status"] in ("ok", "degraded") and body["doc_types"] == 4
    assert set(body["engines"]) <= {"paddleocr", "tesseract"}


def test_doc_types(contract):
    r = client.get("/doc-types")
    assert r.status_code == 200 and len(r.json()["items"]) == 4
    for item in r.json()["items"]:
        contract("ocr_api.yaml", "/components/schemas/DocType", item)


def test_extract_rejects_non_image():
    r = client.post("/ocr/extract", files={"image": ("x.txt", b"hello", "text/plain")})
    assert r.status_code == 415 and r.json()["code"] == "unsupported_media_type"


def test_extract_rejects_too_large():
    big = b"\x89PNG\r\n\x1a\n" + b"0" * (10 * 1024 * 1024 + 10)
    r = client.post("/ocr/extract", files={"image": ("x.png", big, "image/png")})
    assert r.status_code == 413 and r.json()["code"] == "too_large"


def test_extract_unknown_doc_type():
    r = client.post("/ocr/extract", files={"image": ("x.png", png(), "image/png")}, data={"doc_type": "passport"})
    assert r.status_code == 422 and r.json()["code"] == "unknown_doc_type"


def test_extract_missing_image():
    r = client.post("/ocr/extract", data={"doc_type": "cni"})
    assert r.status_code == 422 and r.json()["code"] == "validation_error"


def test_pdf_render_ok():
    r = client.post("/pdf/render", json={"template": "loan_simulation", "lang": "rn", "data": LOAN})
    assert r.status_code == 200 and r.headers["content-type"] == "application/pdf"
    assert r.content[:5] == b"%PDF-"


def test_pdf_unknown_template():
    r = client.post("/pdf/render", json={"template": "statement", "lang": "fr", "data": {}})
    assert r.status_code == 422 and r.json()["code"] == "unknown_template"


def test_pdf_bad_data():
    r = client.post("/pdf/render", json={"template": "loan_simulation", "lang": "fr", "data": {"amount": 1}})
    assert r.status_code == 422 and r.json()["code"] == "validation_error"


def test_pdf_bad_lang():
    r = client.post("/pdf/render", json={"template": "loan_simulation", "lang": "sw", "data": LOAN})
    assert r.status_code == 422 and r.json()["code"] == "validation_error"


# ---------------------------------------------------------------- real OCR on the samples
SAMPLE_IDS = ["cni", "loan_application", "coffee_receipt", "complaint_photo"]


@pytest.mark.slow
@pytest.mark.parametrize("doc_id", SAMPLE_IDS)
@pytest.mark.parametrize("given_type", [False, True])
def test_extract_sample(doc_id, given_type, contract):
    expected = json.loads((SAMPLES / f"{doc_id}.expected.json").read_text())
    data = {"doc_type": doc_id} if given_type else {}
    img = (SAMPLES / f"{doc_id}.jpg").read_bytes()
    r = client.post("/ocr/extract", files={"image": (f"{doc_id}.jpg", img, "image/jpeg")}, data=data)
    assert r.status_code == 200, r.text
    body = r.json()
    contract("ocr_api.yaml", "/components/schemas/ExtractResult", body)
    assert body["doc_type"] == doc_id and body["engine"] in ("paddleocr", "tesseract")
    got = {f["name"]: f for f in body["fields"]}
    for name, want in expected["fields"].items():
        if isinstance(want, list):  # visible text: must contain these fragments
            assert all(w in got[name]["value"] for w in want), name
        else:
            assert got[name]["value"] == want, name
            assert got[name]["valid"] and not got[name]["needs_review"], name
    assert body["needs_review"] is False


def test_error_message_in_caller_language():
    for lang, word in (("fr", "Seules"), ("en", "Only"), ("rn", "Hakirwa")):
        r = client.post("/ocr/extract", files={"image": ("x.txt", b"hello", "text/plain")}, data={"lang": lang})
        assert r.status_code == 415 and r.json()["message"].startswith(word)


def test_empty_models_volume_falls_back_to_baked_models(tmp_path, monkeypatch):
    """Compose mounts an empty ocr-models volume on /models: the baked models must still be found."""
    import importlib

    from app import config

    baked = tmp_path / "baked"
    for m in (config.DET_MODEL, config.REC_MODEL):
        (baked / m).mkdir(parents=True)
        (baked / m / "inference.yml").write_text("x")
    empty = tmp_path / "volume"
    empty.mkdir()
    monkeypatch.setenv("OCR_MODELS_DIR", str(empty))
    monkeypatch.setenv("OCR_BAKED_MODELS_DIR", str(baked))
    try:
        assert importlib.reload(config).MODELS_DIR == baked
        (empty / config.DET_MODEL).mkdir()
        (empty / config.REC_MODEL).mkdir()
        for m in (config.DET_MODEL, config.REC_MODEL):
            (empty / m / "inference.yml").write_text("x")
        assert importlib.reload(config).MODELS_DIR == empty  # models in the volume win
    finally:
        monkeypatch.undo()
        importlib.reload(config)
