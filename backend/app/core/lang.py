"""Language detection fr / en / rn (F2): keyword heuristics, combined with the LLM's guess by the NLU."""

from __future__ import annotations

import re
import unicodedata

# Frequent, language-specific words. Kept to words that rarely appear in the other two languages.
WORDS: dict[str, set[str]] = {
    "fr": {
        "je",
        "j",
        "le",
        "la",
        "les",
        "est",
        "pour",
        "mon",
        "ma",
        "mes",
        "une",
        "des",
        "du",
        "avec",
        "quel",
        "quelle",
        "quelles",
        "bonjour",
        "bonsoir",
        "merci",
        "voudrais",
        "veux",
        "carte",
        "perdu",
        "perdue",
        "agence",
        "heures",
        "horaires",
        "crédit",
        "credit",
        "compte",
        "ouvrir",
        "mois",
        "combien",
        "pourquoi",
        "comment",
        "suis",
        "vous",
        "votre",
        "vos",
        "pas",
        "plainte",
        "réclamation",
        "reclamation",
        "frais",
        "prêt",
        "pret",
        "volé",
        "volee",
        "ouvre",
        "ferme",
        "parler",
        "conseiller",
        "oui",
        "non",
        "s'il",
        "plait",
        "plaît",
        "et",
        "ou",
        "sur",
        "dans",
        "qui",
        "quoi",
        "aide",
        "besoin",
        "mais",
        "très",
        "tres",
        "argent",
        "bloquer",
        "documents",
        "faut",
        "il",
        "c",
        "ce",
        "cette",
        "au",
        "aux",
        "ai",
        "avez",
        "ouverture",
        "millions",
        "salut",
    },
    "en": {
        "i",
        "the",
        "my",
        "is",
        "what",
        "how",
        "hello",
        "hi",
        "please",
        "thanks",
        "thank",
        "you",
        "your",
        "want",
        "would",
        "like",
        "card",
        "lost",
        "stolen",
        "branch",
        "hours",
        "open",
        "opening",
        "loan",
        "account",
        "months",
        "month",
        "much",
        "why",
        "can",
        "do",
        "does",
        "need",
        "complaint",
        "fees",
        "charged",
        "talk",
        "agent",
        "human",
        "yes",
        "no",
        "and",
        "or",
        "of",
        "to",
        "in",
        "on",
        "with",
        "for",
        "it",
        "me",
        "a",
        "an",
        "are",
        "was",
        "when",
        "where",
        "which",
        "block",
        "documents",
        "required",
        "million",
        "money",
        "this",
        "that",
        "have",
        "has",
        "get",
    },
    "rn": {
        "ndashaka",
        "nshaka",
        "ndashobora",
        "amafaranga",
        "ishami",
        "amashami",
        "ryari",
        "ikarata",
        "karata",
        "murakoze",
        "mwaramutse",
        "mwiriwe",
        "amahoro",
        "amakuru",
        "ingurane",
        "konti",
        "kuri",
        "canke",
        "ni",
        "ku",
        "mu",
        "na",
        "nka",
        "iki",
        "ico",
        "ibiki",
        "gute",
        "kubera",
        "iyihe",
        "ryugurura",
        "ryugara",
        "rikora",
        "ryuguruye",
        "kwugurura",
        "yatakaye",
        "yibwe",
        "natakaje",
        "nibwe",
        "guhagarika",
        "hagarika",
        "umukozi",
        "kuvugana",
        "ikirego",
        "ndababaye",
        "ndarakaye",
        "amezi",
        "ukwezi",
        "kwezi",
        "miliyoni",
        "ego",
        "oya",
        "muraho",
        "ubu",
        "uyu",
        "umusi",
        "ejo",
        "ivyangombwa",
        "bisabwa",
        "inyungu",
        "kuzigama",
        "yanje",
        "yanyu",
        "wanje",
        "banki",
        "nkeneye",
        "ndagusaba",
        "ndabasaba",
        "mfise",
        "dufise",
        "mufise",
        "nta",
        "cane",
        "rwose",
        "ibiro",
        "ryibanga",
        "y'ibanga",
        "inomero",
        "itike",
        "vyanje",
        "nyabuneka",
        "murakaza",
        "bite",
        "nimumfashe",
        "mumfashe",
        "ishure",
        "kwubaka",
        "uburimyi",
        "ubudandaji",
        "yamizwe",
        "icuma",
        "intara",
        "igisagara",
        "rikorera",
        "hehe",
        "he",
        "amasaha",
        "saa",
        "angahe",
        "bingahe",
        "gushika",
        "kuva",
        "uri",
        "nde",
        "witwa",
        "mwitwa",
        "izina",
    },
}

_TOKEN = re.compile(r"[a-zà-ÿ']+")


def _norm(text: str) -> str:
    return unicodedata.normalize("NFC", text.lower())


def tokens(text: str) -> list[str]:
    toks = []
    for tok in _TOKEN.findall(_norm(text)):
        toks.append(tok)
        if "'" in tok:  # "y'ibanga" → also "y", "ibanga"; "j'ai" → "j", "ai"
            toks.extend(p for p in tok.split("'") if p)
    return toks


def scores(text: str) -> dict[str, float]:
    toks = tokens(text)
    out = {lg: 0.0 for lg in WORDS}
    for tok in toks:
        for lg, words in WORDS.items():
            if tok in words:
                out[lg] += 1.0
        # Kirundi morphology: long words with typical prefixes / clusters
        if (
            len(tok) >= 6
            and re.match(r"^(ndi|nda|nta|ama|ibi|ivy|ugu|ku|kw|guh|gus|mur|mwa|rya|ryu|iki|ica|umu|aba|uru)", tok)
            and re.search(r"(mw|nz|ny|ng|ry|vy|ts|shw|kw)", tok)
        ):
            out["rn"] += 0.5
    if re.search(r"[éèêàçùôî]", text.lower()):
        out["fr"] += 1.0
    return out


def detect(text: str) -> tuple[str | None, float]:
    """Returns (lang, margin). lang is None when the text gives no signal."""
    sc = scores(text)
    ranked = sorted(sc.items(), key=lambda kv: kv[1], reverse=True)
    (best, s1), (_, s2) = ranked[0], ranked[1]
    if s1 <= 0:
        return None, 0.0
    total = sum(sc.values())
    return best, (s1 - s2) / total if total else 0.0


def choose_lang(
    text: str, hint: str | None, previous: str | None, llm_lang: str | None = None, default: str = "fr"
) -> str:
    """Caller language for this turn: strong text evidence wins (switches mid-conversation),
    then the LLM's guess when the heuristic is unsure, then the channel hint, then the call language."""
    lang, margin = detect(text)
    n = len(tokens(text))
    if lang and (margin >= 0.34 or (n <= 3 and margin > 0)):
        return lang
    if llm_lang in ("fr", "en", "rn") and lang in (None, llm_lang):
        return llm_lang
    if lang and margin > 0:
        return lang
    return hint or previous or default
