"""Pre-G0 test: render one HTML template to PDF with WeasyPrint (offline).

    python pdf_test.py OUT_DIR [fr|en|rn ...]

Template uses only a local font (file:// URL) and inline CSS: no network fetch.
URLFetcher only allows file:/data: (WeasyPrint >= 70 API), so no http(s) fetch can happen.
Figures are a fictional loan simulation (rate is a placeholder, not a BancoBu fact).
"""

import sys
import time
from pathlib import Path

from weasyprint import HTML
from weasyprint.urls import URLFetcher

FONT = "/usr/share/fonts/liberation/LiberationSans-Regular.ttf"

T = {
    "fr": dict(title="Simulation de crédit", amount="Montant", months="Durée (mois)",
               rate="Taux annuel (exemple)", monthly="Mensualité", total="Coût total",
               note="Document fictif généré pour test. Montants indicatifs."),
    "en": dict(title="Loan simulation", amount="Amount", months="Term (months)",
               rate="Annual rate (example)", monthly="Monthly payment", total="Total cost",
               note="Fictional test document. Indicative amounts only."),
    "rn": dict(title="Igereranya ry'ingurane", amount="Amahera", months="Igihe (amezi)",
               rate="Inyungu ku mwaka (akarorero)", monthly="Ayo kwishura ku kwezi",
               total="Igiciro cyose",
               note="Urupapuro rw'igerageza, si urw'ukuri. Amahera ni ay'akarorero."),
}

HTML_TMPL = """<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><style>
@font-face {{ font-family: Body; src: url("file://{font}"); }}
@page {{ size: A4; margin: 2cm; @bottom-center {{ content: counter(page); font-family: Body; font-size: 9pt; }} }}
body {{ font-family: Body; color: #1b2a3a; }}
h1 {{ color: #0b4f8a; border-bottom: 3px solid #0b4f8a; padding-bottom: 6px; }}
table {{ border-collapse: collapse; width: 100%; margin-top: 1em; }}
td {{ padding: 8px; border-bottom: 1px solid #ccd; }}
td.v {{ text-align: right; font-weight: bold; }}
.note {{ margin-top: 2em; font-size: 9pt; color: #a33; }}
</style></head><body>
<h1>Kabangutsi — {title}</h1>
<table>
<tr><td>{amount}</td><td class="v">{p:,} FBu</td></tr>
<tr><td>{months}</td><td class="v">{n}</td></tr>
<tr><td>{rate}</td><td class="v">{r:.1f} %</td></tr>
<tr><td>{monthly}</td><td class="v">{m:,} FBu</td></tr>
<tr><td>{total}</td><td class="v">{c:,} FBu</td></tr>
</table>
<p class="note">{note}</p>
</body></html>"""


def main() -> int:
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    p, n, r = 5_000_000, 24, 16.0  # fictional
    i = r / 100 / 12
    m = round(p * i / (1 - (1 + i) ** -n))
    for lang in sys.argv[2:] or ["fr", "en", "rn"]:
        html = HTML_TMPL.format(lang=lang, font=FONT, p=p, n=n, r=r, m=m, c=m * n - p, **T[lang])
        t = time.perf_counter()
        HTML(string=html, url_fetcher=URLFetcher(allowed_protocols={"file", "data"})).write_pdf(out / f"loan_sim_{lang}.pdf")
        print(f"{lang}: {out / f'loan_sim_{lang}.pdf'} in {time.perf_counter() - t:.2f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
