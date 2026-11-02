"""Rule-based extraction on synthetic OCR lines (fast, no OCR engine)."""

from app import config
from app.engines import Line
from app.extract import detect, extract, key, normalize
from app.registry import load_registry

REG = load_registry(config.DOC_TYPES_DIR)


def L(text, x0, y0, x1=None, score=0.99, h=30):
    return Line(text, score, (x0, y0, x1 or x0 + 12 * len(text), y0 + h))


def by_name(fields):
    return {f["name"]: f for f in fields}


def test_key_strips_accents_and_punctuation():
    assert key("Prénoms :") == "prenoms" and key("Durée (mois)") == "dureemois"


def test_normalize_types():
    assert normalize("5 000 000 FBu", "integer") == (5000000, True)
    assert normalize("1.200", "integer") == (1200, True)
    assert normalize("312 kg", "number") == (312.0, True)
    assert normalize("12,5", "number") == (12.5, True)
    assert normalize("14/03/1992", "date") == ("1992-03-14", True)
    assert normalize("31/02/1992", "date")[1] is False
    assert normalize("abc", "integer")[1] is False


def test_cni_columns_and_composite_name():
    lines = [L("REPUBLIQUE DU BURUNDI - CARTE NATIONALE D'IDENTITE", 40, 40),
             L("Nom :", 40, 140), L("NDAYIZEYE", 380, 140),
             L("Prénoms :", 40, 250), L("Aline Fictive", 380, 250),
             L("Date de naissance :", 40, 360), L("14/03/1992", 380, 360),
             L("No CNI :", 40, 470), L("0123/456.789/2019", 380, 470)]
    dt, conf = detect(lines, REG)
    assert dt.id == "cni" and conf >= 0.8
    f = by_name(extract(dt, lines))
    assert f["full_name"]["value"] == "NDAYIZEYE Aline Fictive"
    assert f["date_of_birth"]["value"] == "1992-03-14"
    assert f["id_number"]["value"] == "0123/456.789/2019"
    assert "place_of_birth" not in f  # optional and absent: omitted
    assert not any(x["needs_review"] for x in f.values())


def test_value_after_colon_on_same_line():
    lines = [L("Nom complet : Jean-Claude Testeur", 40, 140), L("Durée (mois) : 24", 40, 250),
             L("Montant demandé (FBu) : 5 000 000", 40, 360)]
    f = by_name(extract(REG["loan_application"], lines))
    assert f["applicant_name"]["value"] == "Jean-Claude Testeur"
    assert f["term_months"]["value"] == 24 and f["amount"]["value"] == 5000000


def test_value_below_label():
    lines = [L("Producteur :", 40, 100), L("Pascal Exemple", 40, 135),
             L("Date :", 40, 200), L("21/10/2026", 40, 235)]
    f = by_name(extract(REG["coffee_receipt"], lines))
    assert f["farmer_name"]["value"] == "Pascal Exemple" and f["farmer_name"]["confidence"] < 1.0
    assert f["date"]["value"] == "2026-10-21"


def test_low_confidence_flagged_for_review():
    lines = [L("Nom complet :", 40, 100), L("Jean-Claude Testeur", 470, 100, score=0.62)]
    f = by_name(extract(REG["loan_application"], lines))
    assert f["applicant_name"]["confidence"] == 0.62 and f["applicant_name"]["needs_review"]


def test_missing_required_and_invalid_flagged():
    lines = [L("Durée (mois) :", 40, 100), L("999", 470, 100)]
    f = by_name(extract(REG["loan_application"], lines))
    assert f["term_months"]["valid"] is False and f["term_months"]["needs_review"]
    assert f["amount"]["value"] is None and f["amount"]["needs_review"]


def test_ocr_noise_in_label_tolerated():
    lines = [L("Date de naissanoe :", 40, 100), L("14/03/1992", 380, 100)]
    f = by_name(extract(REG["cni"], lines))
    assert f["date_of_birth"]["value"] == "1992-03-14"


def test_unknown_document_falls_back_to_complaint_photo():
    dt, conf = detect([L("Bonjour tout le monde", 0, 0)], REG)
    assert dt.id == "complaint_photo" and conf < 0.8
