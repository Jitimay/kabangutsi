"""Generate the clearly FICTIONAL sample documents used by tests and the demo.

    python ocr/samples/make_samples.py [OUT_DIR]      # default: this folder

For each type writes <id>.jpg (photo-like: rotation, shading, blur, noise) and
<id>.expected.json (fields the OCR service must return). All names/numbers are invented.
Fonts: Liberation (Arch: ttf-liberation, Debian: fonts-liberation).
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_DIRS = [Path("/usr/share/fonts/liberation"), Path("/usr/share/fonts/truetype/liberation")]
FONT_DIR = next((d for d in FONT_DIRS if d.exists()), FONT_DIRS[0])
REG = str(FONT_DIR / "LiberationSans-Regular.ttf")
BOLD = str(FONT_DIR / "LiberationSans-Bold.ttf")
MONO = str(FONT_DIR / "LiberationMono-Regular.ttf")

DOCS = {
    "cni": {
        "size": (1000, 630), "bg": (225, 238, 228), "layout": "columns", "value_x": 380,
        "title": "REPUBLIQUE DU BURUNDI - CARTE NATIONALE D'IDENTITE",
        "lines": [("Nom", "NDAYIZEYE"), ("Prénoms", "Aline Fictive"),
                  ("Date de naissance", "14/03/1992"), ("Lieu de naissance", "Gitega"),
                  ("Sexe", "F"), ("No CNI", "0123/456.789/2019"),
                  ("Date de délivrance", "02/09/2019")],
        "stamp": "SPECIMEN - DOCUMENT FICTIF", "photo": True,
        "expected": {"full_name": "NDAYIZEYE Aline Fictive", "id_number": "0123/456.789/2019",
                     "date_of_birth": "1992-03-14", "place_of_birth": "Gitega"},
    },
    "loan_application": {
        "size": (1240, 1500), "bg": (250, 250, 247), "layout": "columns", "value_x": 470,
        "title": "BANCOBU - DEMANDE DE CREDIT (FORMULAIRE TEST)",
        "lines": [("Nom complet", "Jean-Claude Testeur"), ("Téléphone", "+25779000001"),
                  ("Type de crédit", "Crédit agricole"), ("Montant demandé (FBu)", "5 000 000"),
                  ("Durée (mois)", "24"), ("Objet du crédit", "Achat de matériel agricole"),
                  ("Revenu mensuel (FBu)", "850 000"), ("Date", "15/10/2026")],
        "stamp": "EXEMPLE FICTIF - NE PAS UTILISER",
        "expected": {"applicant_name": "Jean-Claude Testeur", "amount": 5000000,
                     "term_months": 24, "product": "Crédit agricole"},
    },
    "coffee_receipt": {
        "size": (620, 1000), "bg": (252, 250, 240), "layout": "stacked",
        "title": "STATION DE LAVAGE KAWA-TEST",
        "lines": [("Reçu No", "CR-2026-00417"), ("Date", "21/10/2026"),
                  ("Producteur", "Pascal Exemple"), ("Colline", "Kayanza-Test"),
                  ("Cerise (kg)", "312"), ("Prix/kg (FBu)", "1 200"), ("Total (FBu)", "374 400")],
        "stamp": "RECU FICTIF",
        "expected": {"farmer_name": "Pascal Exemple", "weight_kg": 312.0, "amount": 374400,
                     "date": "2026-10-21"},
    },
    "complaint_photo": {
        "size": (900, 600), "bg": (20, 40, 80), "fg": (235, 240, 255), "layout": "screen",
        "title": "GUICHET AUTOMATIQUE TEST",
        "lines": [("", "TRANSACTION ECHOUEE"), ("", "Erreur 51 : montant non distribue"),
                  ("", "Votre compte a peut-etre ete debite"), ("", "Ref. ATM-TEST-0042")],
        "stamp": "ECRAN FICTIF",
        "expected": {"visible_text": ["TRANSACTION ECHOUEE", "Erreur 51"]},
    },
}


def _photo_effects(img: Image.Image, rng: random.Random) -> Image.Image:
    img = img.rotate(rng.uniform(-3, 3), expand=True, fillcolor=(90, 80, 70))
    shade = Image.linear_gradient("L").resize(img.size).point(lambda v: 255 - v // 5)
    img = Image.composite(img, Image.new("RGB", img.size, (0, 0, 0)), shade)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    px = img.load()
    for _ in range(img.size[0] * img.size[1] // 40):
        x, y = rng.randrange(img.size[0]), rng.randrange(img.size[1])
        r, g, b = px[x, y]
        n = rng.randint(-35, 35)
        px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    return img


def render(spec: dict, rng: random.Random) -> Image.Image:
    w, h = spec["size"]
    img = Image.new("RGB", (w, h), spec["bg"])
    d = ImageDraw.Draw(img)
    fg = spec.get("fg", (10, 10, 10))
    title_f = ImageFont.truetype(BOLD, 26 if w < 1100 else 34)
    d.text((40, 40), spec["title"], font=title_f, fill=spec.get("fg", (20, 40, 90)))
    lab_f = ImageFont.truetype(REG, 26 if w > 700 else 24)
    val_f = ImageFont.truetype(MONO if spec["layout"] == "stacked" else BOLD, 28 if w > 700 else 26)
    y = 140
    step = min(110, (h - 260) // len(spec["lines"]))
    for label, value in spec["lines"]:
        if spec["layout"] == "screen":
            d.text((60, y + 20), value, font=ImageFont.truetype(BOLD, 34), fill=fg)
        elif spec["layout"] == "stacked":
            d.text((40, y), f"{label} :", font=lab_f, fill=(60, 60, 60))
            d.text((40, y + 34), value, font=val_f, fill=fg)
        else:
            d.text((40, y), f"{label} :", font=lab_f, fill=(60, 60, 60))
            d.text((spec["value_x"], y), value, font=val_f, fill=fg)
            if "loan" in spec["title"].lower() or "CREDIT" in spec["title"]:
                d.line((spec["value_x"], y + 38, w - 60, y + 38), fill=(170, 170, 170), width=1)
        y += step
    if spec.get("photo"):
        d.rectangle((760, 140, 950, 380), outline=(80, 80, 80), width=3)
        d.text((800, 250), "PHOTO", font=lab_f, fill=(120, 120, 120))
    d.text((40, h - 70), spec["stamp"], font=ImageFont.truetype(BOLD, 28), fill=(200, 30, 30))
    return _photo_effects(img, rng)


def main() -> int:
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(7)
    for doc_id, spec in DOCS.items():
        render(spec, rng).save(out / f"{doc_id}.jpg", quality=80)
        (out / f"{doc_id}.expected.json").write_text(
            json.dumps({"doc_type": doc_id, "fields": spec["expected"]}, indent=2, ensure_ascii=False) + "\n")
        print("wrote", out / f"{doc_id}.jpg")
    return 0


if __name__ == "__main__":
    sys.exit(main())
