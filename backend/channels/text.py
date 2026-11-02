"""Text helpers shared by the channel adapters: phone normalisation, SMS-safe text, truncation."""

from __future__ import annotations

import re
import unicodedata

# GSM 03.38 basic character set (one septet each). Anything else forces UCS-2,
# which cuts an SMS from 160 to 70 characters.
GSM7_BASIC = set(
    "@£$¥èéùìòÇ\nØø\rÅåΔ_ΦΓΛΩΠΨΣΘΞÆæßÉ !\"#¤%&'()*+,-./0123456789:;<=>?"
    "¡ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÑÜ§¿abcdefghijklmnopqrstuvwxyzäöñüà"
)
# Extension table: valid but cost two septets (escape + char).
GSM7_EXT = set("^{}\\[~]|€")

_REPLACE = {
    "’": "'", "‘": "'", "“": '"', "”": '"', "«": '"', "»": '"', "–": "-", "—": "-",
    "…": "...", " ": " ", " ": " ", " ": " ", "•": "-", "ç": "c",
}


def normalize_phone(raw: str | None) -> str | None:
    """Return +257XXXXXXXX, or None if the number is not a Burundi number.

    Accepts '+25779000101', '25779000101', '0025779000101', '79000101', '79 00 01 01',
    and WhatsApp JIDs like '25779000101@s.whatsapp.net'.
    """
    if not raw:
        return None
    s = raw.split("@", 1)[0].split(":", 1)[0]
    digits = re.sub(r"\D", "", s)
    if digits.startswith("00"):
        digits = digits[2:]
    if len(digits) == 8:
        digits = "257" + digits
    if len(digits) == 11 and digits.startswith("257"):
        return "+" + digits
    return None


def to_gsm7(text: str) -> str:
    """Make text encodable in GSM-7 so one SMS holds 160 characters.

    Keeps GSM accents (é è à ù ...), maps typographic marks to ASCII, strips other
    diacritics (ê -> e, ô -> o, î -> i), drops anything still unencodable.
    """
    out = []
    for ch in text:
        ch = _REPLACE.get(ch, ch)
        if all(c in GSM7_BASIC or c in GSM7_EXT for c in ch):
            out.append(ch)
            continue
        base = "".join(c for c in unicodedata.normalize("NFD", ch) if not unicodedata.combining(c))
        out.append("".join(c for c in base if c in GSM7_BASIC or c in GSM7_EXT))
    return re.sub(r"[ \t]+", " ", "".join(out)).strip()


def gsm7_length(text: str) -> int:
    """Septets used by text (extension characters count twice)."""
    return sum(2 if c in GSM7_EXT else 1 for c in text)


def fit_gsm7(text: str, limit: int = 160) -> str:
    """GSM-7 text that fits in `limit` septets, cut on a word boundary with '...'."""
    t = to_gsm7(text)
    if gsm7_length(t) <= limit:
        return t
    cut = t
    while gsm7_length(cut) > limit - 3:
        cut = cut[:-1]
    if " " in cut[-20:]:
        cut = cut[: cut.rfind(" ")]
    return cut.rstrip(" ,;:.") + "..."


def truncate(text: str, limit: int) -> str:
    """Cut plain text to `limit` characters on a word boundary, adding '...'."""
    text = text.strip()
    if len(text) <= limit:
        return text
    cut = text[: limit - 3]
    if " " in cut[-20:]:
        cut = cut[: cut.rfind(" ")]
    return cut.rstrip(" ,;:.") + "..."
