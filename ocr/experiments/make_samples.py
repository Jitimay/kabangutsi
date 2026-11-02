"""Generate 3 clearly FICTIONAL test documents + ground truth for the pre-G0 OCR test.

    python make_samples.py OUT_DIR [--hard]

--hard: also degrade like a cheap phone photo (half resolution, stronger blur, JPEG q=35).

Writes <name>.png (photo-like: slight rotation, blur, noise, uneven light) and
<name>.json (expected fields). All names, numbers and IDs are invented.
"""

import io
import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT_DIR = Path("/usr/share/fonts/liberation")
REG = str(FONT_DIR / "LiberationSans-Regular.ttf")
BOLD = str(FONT_DIR / "LiberationSans-Bold.ttf")
MONO = str(FONT_DIR / "LiberationMono-Regular.ttf")

DOCS = {
    "cni": {
        "size": (1000, 630),
        "bg": (225, 238, 228),
        "title": ("REPUBLIQUE DU BURUNDI - CARTE NATIONALE D'IDENTITE", 26),
        "lines": [
            ("Nom", "NDAYIZEYE"),
            ("Prenoms", "Aline Fictive"),
            ("Date de naissance", "14/03/1992"),
            ("Lieu de naissance", "Gitega"),
            ("Sexe", "F"),
            ("No CNI", "0123/456.789/2019"),
            ("Date de delivrance", "02/09/2019"),
        ],
        "stamp": "SPECIMEN - DOCUMENT FICTIF",
    },
    "loan_form": {
        "size": (1240, 1600),
        "bg": (250, 250, 247),
        "title": ("BANCOBU - DEMANDE DE CREDIT (FORMULAIRE TEST)", 34),
        "lines": [
            ("Nom complet", "Jean-Claude Testeur"),
            ("Telephone", "+25779000001"),
            ("No de compte", "BB-0000-123456"),
            ("Montant demande (FBu)", "5 000 000"),
            ("Duree (mois)", "24"),
            ("Objet du credit", "Achat de materiel agricole"),
            ("Revenu mensuel (FBu)", "850 000"),
            ("Employeur", "Cooperative Imaginaire de Ngozi"),
            ("Date", "15/10/2026"),
        ],
        "stamp": "EXEMPLE FICTIF - NE PAS UTILISER",
    },
    "coffee_receipt": {
        "size": (620, 1000),
        "bg": (252, 250, 240),
        "title": ("STATION DE LAVAGE KAWA-TEST", 30),
        "lines": [
            ("Recu No", "CR-2026-00417"),
            ("Date", "21/10/2026"),
            ("Producteur", "Pascal Exemple"),
            ("Colline", "Kayanza-Test"),
            ("Cerise (kg)", "312"),
            ("Prix/kg (FBu)", "1 200"),
            ("Total (FBu)", "374 400"),
        ],
        "stamp": "RECU FICTIF",
    },
}


def render(name: str, spec: dict, rng: random.Random, hard: bool = False) -> Image.Image:
    w, h = spec["size"]
    img = Image.new("RGB", (w, h), spec["bg"])
    d = ImageDraw.Draw(img)
    title, tsize = spec["title"]
    d.text((40, 40), title, font=ImageFont.truetype(BOLD, tsize), fill=(20, 40, 90))
    lab_f = ImageFont.truetype(REG, 26 if w > 700 else 24)
    val_f = ImageFont.truetype(MONO if name == "coffee_receipt" else BOLD, 28 if w > 700 else 24)
    y = 140
    step = (h - 260) // len(spec["lines"])
    step = min(step, 120)
    for label, value in spec["lines"]:
        d.text((40, y), f"{label} :", font=lab_f, fill=(60, 60, 60))
        vx = 40 if w < 700 else 420
        vy = y + 34 if w < 700 else y
        d.text((vx, vy), value, font=val_f, fill=(10, 10, 10))
        if name == "loan_form":
            d.line((vx, vy + 36, w - 60, vy + 36), fill=(170, 170, 170), width=1)
        y += step
    if name == "cni":
        d.rectangle((760, 140, 950, 380), outline=(80, 80, 80), width=3)
        d.text((800, 250), "PHOTO", font=lab_f, fill=(120, 120, 120))
    d.text((40, h - 70), spec["stamp"], font=ImageFont.truetype(BOLD, 28), fill=(200, 30, 30))

    # make it look like a phone photo
    img = img.rotate(rng.uniform(-4, 4), expand=True, fillcolor=(90, 80, 70))
    shade = Image.linear_gradient("L").resize(img.size).point(lambda v: 255 - v // 5)
    img = Image.composite(img, Image.new("RGB", img.size, (0, 0, 0)), shade)
    img = img.filter(ImageFilter.GaussianBlur(0.8))
    px = img.load()
    for _ in range(img.size[0] * img.size[1] // 40):
        x, yy = rng.randrange(img.size[0]), rng.randrange(img.size[1])
        r, g, b = px[x, yy]
        n = rng.randint(-40, 40)
        px[x, yy] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    if hard:
        img = img.resize((img.size[0] // 2, img.size[1] // 2)).filter(ImageFilter.GaussianBlur(0.9))
        buf = io.BytesIO()
        img.save(buf, "JPEG", quality=35)
        img = Image.open(io.BytesIO(buf.getvalue())).convert("RGB")
    return img


def main() -> int:
    out = Path(sys.argv[1])
    hard = "--hard" in sys.argv
    out.mkdir(parents=True, exist_ok=True)
    rng = random.Random(42)
    for name, spec in DOCS.items():
        render(name, spec, rng, hard).save(out / f"{name}.png")
        truth = {"title": spec["title"][0], "fields": dict(spec["lines"]), "stamp": spec["stamp"]}
        (out / f"{name}.json").write_text(json.dumps(truth, indent=2, ensure_ascii=False))
        print("wrote", out / f"{name}.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
