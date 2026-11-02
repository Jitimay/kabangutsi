import shutil
import subprocess

import pytest

from app import pdf

LOAN = {"product_id": "business_loan", "product_name": "Crédit commerce", "amount": 5000000,
        "term_months": 24, "annual_rate_pct": 16.0, "monthly_payment": 244816,
        "total_payment": 5875584, "total_interest": 875584,
        "explanation": "Exemple fictif.", "lang": "fr", "pdf": None}


def ticket_example(contract_doc):
    """The Ticket from the ticket.created example in ws_events.json."""
    return contract_doc("ws_events.json")["$defs"]["TicketCreatedEvent"]["examples"][0]["data"]


def text_of(body: bytes, tmp_path) -> str:
    if not shutil.which("pdftotext"):
        pytest.skip("pdftotext not installed")
    p = tmp_path / "x.pdf"
    p.write_bytes(body)
    out = subprocess.run(["pdftotext", "-layout", str(p), "-"], capture_output=True, text=True, check=True)
    return out.stdout.replace(" ", " ")


def fonts_of(body: bytes, tmp_path) -> str:
    p = tmp_path / "f.pdf"
    p.write_bytes(body)
    return subprocess.run(["pdffonts", str(p)], capture_output=True, text=True).stdout


def test_contract_example_validates(contract_doc):
    ex = contract_doc("ocr_api.yaml")["paths"]["/pdf/render"]["post"]["requestBody"]["content"]["application/json"]["example"]
    pdf.LoanSimulation.model_validate(ex["data"])
    pdf.Ticket.model_validate(ticket_example(contract_doc))


@pytest.mark.parametrize("lang,words", [
    ("fr", ["Simulation de crédit", "Mensualité", "244 816 FBu", "16,0 %", "5 000 000 FBu"]),
    ("en", ["Loan simulation", "Monthly payment", "244 816 FBu", "16.0 %"]),
    ("rn", ["Igereranya ry'ingurane", "Ayo kwishura ku kwezi", "244 816 FBu"]),
])
def test_loan_simulation_pdf(lang, words, tmp_path):
    body = pdf.render("loan_simulation", lang, pdf.LoanSimulation.model_validate(LOAN))
    assert body[:5] == b"%PDF-"
    text = text_of(body, tmp_path)
    for w in words:
        assert w in text, w
    fonts = fonts_of(body, tmp_path)
    assert "Liberation" in fonts or "DejaVu" in fonts


@pytest.mark.parametrize("lang,words", [
    ("fr", ["Accusé de réception", "Frais", "Haute"]),
    ("en", ["Complaint receipt", "Fees", "High"]),
    ("rn", ["Icemezo c'ikirego", "Amafaranga y'ibikorwa", "Nyinshi"]),
])
def test_ticket_receipt_pdf(lang, words, tmp_path, contract_doc, contract):
    t = dict(ticket_example(contract_doc), category="fees", urgency="high")
    contract("ws_events.json", "/$defs/Ticket", t)
    body = pdf.render("ticket_receipt", lang, pdf.Ticket.model_validate(t))
    text = text_of(body, tmp_path)
    for w in words + [t["number"]]:
        assert w in text, w
    assert t["phone"] not in text  # phone masked on the receipt


def test_formatting():
    assert pdf.fbu(5000000) == "5 000 000 FBu"
    assert pdf.pct(16, "fr") == "16,0 %" and pdf.pct(16, "en") == "16.0 %"
    assert pdf.local_time("2026-11-02T08:15:30Z") == "02/11/2026 10:15 (CAT)"


def test_no_http_fetch():
    with pytest.raises(ValueError):
        pdf._fetcher.fetch("https://example.com/x.css")
