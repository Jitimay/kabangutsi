"""Keyword NLU for fr / en / rn (F3 fallback). Produces exactly the intent.schema.json shape.

Also used next to the LLM: small models are weak in Kirundi, so a confident keyword match can override a
low-confidence LLM intent (see nlu.py). Entities parsed here are plain facts from the text (amounts,
months, last 4 digits, places); PINs and dates of birth are never handled here.
"""

from __future__ import annotations

import re
import unicodedata
from typing import Any

from app.core.lang import detect, tokens

INTENT_KEYWORDS: dict[str, list[str]] = {
    "card_block": [
        # fr
        "bloquer",
        "bloquez",
        "carte perdue",
        "perdu ma carte",
        "perdu ma carte",
        "carte volée",
        "carte volee",
        "volé ma carte",
        "vole ma carte",
        "on m'a volé",
        "carte avalée",
        "carte avalee",
        "avalé ma carte",
        "opposition",
        # en
        "block my card",
        "block the card",
        "block card",
        "lost my card",
        "lost card",
        "card was stolen",
        "stolen card",
        "stole my card",
        "card stolen",
        "swallowed",
        "freeze my card",
        # rn
        "ikarata yanje",
        "ikarata yatakaye",
        "karata yatakaye",
        "natakaje ikarata",
        "ikarata yibwe",
        "banyibye",
        "guhagarika ikarata",
        "hagarika ikarata",
        "muhagarike ikarata",
        "yamizwe",
        "ikarata yamizwe",
    ],
    "loan_info": [
        "crédit",
        "credit",
        "prêt",
        "pret",
        "emprunt",
        "emprunter",
        "mensualité",
        "mensualite",
        "taux",
        "loan",
        "borrow",
        "monthly payment",
        "repayment",
        "interest rate",
        "simulate",
        "ingurane",
        "inguzanyo",
        "kuguza",
        "ndashaka kuguza",
        "inyungu",
    ],
    "complaint": [
        "plainte",
        "réclamation",
        "reclamation",
        "me plaindre",
        "pas content",
        "inadmissible",
        "on m'a prélevé",
        "prélevé",
        "preleve",
        "débité",
        "debite",
        "arnaque",
        "scandale",
        "complaint",
        "complain",
        "charged twice",
        "wrongly charged",
        "unacceptable",
        "deducted",
        "not happy",
        "ikirego",
        "ndarega",
        "kurega",
        "ndababaye",
        "ndarakaye",
        "bankuyeko",
        "yakuweko",
        "akarenganyo",
        "ticket",
        "tck-",
    ],
    "branch_info": [
        "agence",
        "agences",
        "horaire",
        "horaires",
        "heure d'ouverture",
        "ouvre",
        "ferme à",
        "adresse",
        "succursale",
        "branch",
        "branches",
        "opening hours",
        "open on",
        "what time",
        "address",
        "closes",
        "opens",
        "ishami",
        "amashami",
        "ryugurura",
        "ryugara",
        "rikora",
        "amasaha",
        "rikorera",
        "ryuguruye",
    ],
    "account_opening": [
        "ouvrir un compte",
        "ouverture de compte",
        "ouvrir compte",
        "créer un compte",
        "creer un compte",
        "open an account",
        "open account",
        "opening an account",
        "new account",
        "create an account",
        "kwugurura konti",
        "kwugurura konte",
        "ndashaka konti",
        "gufungura konti",
        "kuronka konti",
        "ouvrir",
        "open a",
        "documents do i need",
        "documents required",
        "documents nécessaires",
        "pièces à fournir",
        "kwugurura",
        "ivyangombwa",
    ],
    "product_info": [
        "frais",
        "tarif",
        "produits",
        "compte épargne",
        "compte epargne",
        "carte visa",
        "mobile banking",
        "*123#",
        "épargne",
        "epargne",
        "fees",
        "charges",
        "savings",
        "products",
        "debit card",
        "visa card",
        "cost of",
        "amafaranga yo",
        "kuzigama",
        "konti zanyu",
        "konti zacu",
        "ibicuruzwa",
        "ikarata ya visa",
        "kuri terefone",
    ],
    "handoff": [
        "parler à un conseiller",
        "parler a un conseiller",
        "un conseiller",
        "un agent",
        "un humain",
        "une personne",
        "parler à quelqu'un",
        "talk to an agent",
        "speak to an agent",
        "talk to a human",
        "real person",
        "speak to someone",
        "customer service agent",
        "human agent",
        "an agent",
        "kuvugana n'umukozi",
        "umukozi",
        "umuntu nyawe",
        "ndashaka kuvugana",
    ],
}

# Added after the first live eval (2026-10-31): phrasings the small model got wrong, kept general.
INTENT_KEYWORDS["card_block"] += [
    "carte est bloquée",
    "carte est bloquee",
    "carte bloquée",
    "card is blocked",
    "card was blocked",
    "mauvais code",
    "wrong pin",
    "block it",
    "bloquez-la",
    "ikarata yanje yahagaze",
    "didn't make",
    "je n'ai pas faites",
]
INTENT_KEYWORDS["loan_info"] += [
    "crédits proposez",
    "credits proposez",
    "types de crédit",
    "loans do you offer",
    "what loans",
    "kinds of loans",
    "ingurane z'ubwoko",
    "ubwoko bw'ingurane",
]
INTENT_KEYWORDS["complaint"] += [
    "deux fois",
    "twice",
    "kabiri",
    "ne marche pas",
    "ne fonctionne pas",
    "not working",
    "doesn't work",
    "does not work",
    "ntikora",
    "robbed",
    "munyiba",
    "nticampaye",
    "didn't give",
    "n'a pas donné",
    "waited",
    "j'ai attendu",
    "nategereje",
    "ntibikwiye",
]
INTENT_KEYWORDS["handoff"] += ["a human", "ndashaka umuntu", "kuvugana n'umuntu", "umuntu ubu nyene"]
INTENT_KEYWORDS["product_info"] += [
    "coûte",
    "coute",
    "combien",
    "gratuit",
    "how much",
    "fee",
    "free",
    "cost",
    "interest",
    "ubuntu",
    "biriha",
    "iriha",
    "types de compte",
    "account types",
    "konti z'ubwoko",
    "inyungu ingahe",
]
PRICE_WORDS = [
    "frais",
    "coûte",
    "coute",
    "combien",
    "gratuit",
    "tarif",
    "intérêt",
    "interet",
    "fee",
    "fees",
    "free",
    "cost",
    "how much",
    "interest",
    "charge",
    "ubuntu",
    "biriha",
    "iriha",
    "angahe",
    "inyungu",
]
ACCOUNT_WORDS = ["compte", "account", "konti", "carte", "card", "ikarata", "retirer", "withdraw", "gukura"]
OPENING_WORDS = ["ouvrir", "ouverture", "open", "opening", "ugurur", "gufungura", "kuronka konti"]
OFF_TOPIC = [
    "météo",
    "meteo",
    "temps fera",
    "weather",
    "ikirere",
    "football",
    "match",
    "umupira",
    "yatsinze",
    "politique",
    "politics",
    "recette",
    "recipe",
]

COMPLAINT_EXPLICIT = [
    "plainte",
    "réclamation",
    "reclamation",
    "me plaindre",
    "porter plainte",
    "complaint",
    "complain",
    "ikirego",
    "kurega",
    "ndarega",
    "gutanga ikirego",
]

GREETINGS = [
    "bonjour",
    "bonsoir",
    "salut",
    "hello",
    "hi",
    "good morning",
    "mwaramutse",
    "mwiriwe",
    "amahoro",
    "muraho",
    "bite",
]
THANKS = ["merci", "thank you", "thanks", "murakoze", "nawe urakoze"]
GOODBYES = ["au revoir", "bye", "goodbye", "ni aho", "tuzosubira", "mugire amahoro", "c'est tout", "that's all"]

FRUSTRATION_WORDS = [
    "inadmissible",
    "scandale",
    "arnaque",
    "honte",
    "nul",
    "marre",
    "énervé",
    "enerve",
    "en colère",
    "colere",
    "voleurs",
    "incompétent",
    "toujours pas",
    "depuis des semaines",
    "j'en ai assez",
    "unacceptable",
    "ridiculous",
    "angry",
    "furious",
    "scam",
    "fed up",
    "terrible",
    "useless",
    "worst",
    "thieves",
    "nobody helps",
    "for weeks",
    "ndarakaye",
    "ndababaye cane",
    "ndababaye",
    "akarenganyo",
    "ibisuma",
    "ntibikwiye",
    "nararambiwe",
    "birambiye",
    "mwanyibye",
    "mwambye",
]

PRODUCTS: dict[str, list[str]] = {
    "business_loan": ["commerce", "commercial", "business", "ubudandaji", "boutique", "shop", "stock"],
    "agri_loan": [
        "agricole",
        "agri",
        "agriculture",
        "farm",
        "farming",
        "uburimyi",
        "café",
        "coffee",
        "ikawa",
        "récolte",
    ],
    "salary_advance": ["salaire", "salary", "avance", "advance", "umushahara"],
    "housing_loan": ["immobilier", "logement", "maison", "housing", "house", "home", "kwubaka", "inzu"],
    "school_fees_loan": [
        "scolaire",
        "école",
        "ecole",
        "school",
        "frais scolaires",
        "minerval",
        "amashure",
        "ishure",
        "kaminuza",
    ],
    "women_group_loan": ["femmes", "women", "abagore", "groupe de femmes", "women's group"],
    "savings_account": ["épargne", "epargne", "savings", "kuzigama"],
    "youth_account": ["jeune", "jeunes", "youth", "urwaruka"],
    "current_account": ["compte courant", "current account", "konti isanzwe"],
    "debit_card": ["carte de débit", "carte visa", "debit card", "visa", "ikarata yo kubikuza"],
    "mobile_banking": ["mobile", "*123#", "application", "app", "terefone", "ussd"],
}
LOAN_PRODUCTS = ["business_loan", "agri_loan", "salary_advance", "housing_loan", "school_fees_loan", "women_group_loan"]

CARD_ISSUES: dict[str, list[str]] = {
    "stolen": ["vol", "volé", "volee", "volée", "stolen", "stole", "yibwe", "banyibye", "bibwe"],
    "swallowed_by_atm": ["avalé", "avalee", "avalée", "swallowed", "yamizwe", "atm a gardé", "kept my card"],
    "fraud_suspected": ["fraude", "fraud", "suspect", "piratage", "hacked", "ubusuma"],
    "damaged": ["abîmée", "abimee", "cassée", "damaged", "broken", "yononekaye"],
    "blocked": ["bloquée", "bloquee", "blocked", "ntikora", "yahagaze"],
    "lost": ["perdu", "perdue", "lost", "yatakaye", "natakaje", "nayitaye"],
}

COMPLAINT_CATEGORIES: dict[str, list[str]] = {
    "atm": ["atm", "distributeur", "guichet automatique", "icuma"],
    "fees": [
        "frais",
        "prélevé",
        "preleve",
        "débité",
        "debite",
        "fees",
        "charged",
        "deducted",
        "amafaranga yakuweko",
        "bankuyeko",
    ],
    "card": ["carte", "card", "ikarata"],
    "loan": ["crédit", "credit", "prêt", "loan", "ingurane"],
    "mobile_banking": ["mobile", "*123#", "application", "app", "ussd"],
    "service_quality": ["accueil", "attente", "impoli", "service", "rude", "waited", "queue", "staff", "abakozi"],
    "account": ["compte", "account", "konti"],
}

PROVINCES = [
    "Bujumbura",
    "Gitega",
    "Ngozi",
    "Muyinga",
    "Rumonge",
    "Kayanza",
    "Kirundo",
    "Bururi",
    "Makamba",
    "Ruyigi",
    "Cibitoke",
    "Muramvya",
    "Karuzi",
    "Rutana",
    "Bubanza",
    "Cankuzo",
    "Mwaro",
    "Kanyosha",
    "Kamenge",
    "Rohero",
]

_NUM_WORDS = {
    "un": 1,
    "une": 1,
    "deux": 2,
    "trois": 3,
    "quatre": 4,
    "cinq": 5,
    "six": 6,
    "sept": 7,
    "huit": 8,
    "neuf": 9,
    "dix": 10,
    "douze": 12,
    "quinze": 15,
    "vingt": 20,
    "trente": 30,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "twelve": 12,
    "fifteen": 15,
    "twenty": 20,
    "thirty": 30,
    "rimwe": 1,
    "zibiri": 2,
    "zitatu": 3,
    "zine": 4,
    "zitanu": 5,
    "zitandatu": 6,
    "cumi": 10,
}


def fold(s: str) -> str:
    s = unicodedata.normalize("NFKD", s.lower())
    return "".join(c for c in s if not unicodedata.combining(c))


def _has(text_f: str, phrase: str) -> bool:
    p = fold(phrase)
    if " " in p or not p.isalnum():
        return p in text_f
    return re.search(rf"(?<![a-z0-9]){re.escape(p)}(?![a-z0-9])", text_f) is not None


def _num(s: str) -> float | None:
    s = s.strip().replace(" ", " ").replace("\xa0", " ")
    if s in _NUM_WORDS:
        return float(_NUM_WORDS[s])
    s2 = re.sub(r"(?<=\d)[ .,](?=\d{3}\b)", "", s)
    s2 = s2.replace(",", ".")
    try:
        return float(s2)
    except ValueError:
        return None


_NUMBER = r"(\d{1,3}(?:[ ., \xa0]\d{3})+|\d+(?:[.,]\d+)?|" + "|".join(_NUM_WORDS) + r")"


def parse_amount(text: str) -> int | None:
    """'5 millions', '5M', '5 000 000 FBu', '500k', 'miliyoni 5', '2,5 millions' → integer FBu."""
    t = fold(text)
    m = re.search(rf"{_NUMBER}\s*(millions?|million|mio|m\b|miliyoni)", t)
    if m and (v := _num(m.group(1))) is not None:
        return int(round(v * 1_000_000))
    m = re.search(rf"(?:miliyoni|amamiliyoni)\s*{_NUMBER}", t)
    if m and (v := _num(m.group(1))) is not None:
        return int(round(v * 1_000_000))
    m = re.search(rf"{_NUMBER}\s*(k\b|mille|thousand|ibihumbi)", t)
    if m and (v := _num(m.group(1))) is not None:
        return int(round(v * 1000))
    m = re.search(rf"ibihumbi\s*{_NUMBER}", t)
    if m and (v := _num(m.group(1))) is not None:
        return int(round(v * 1000))
    for m in re.finditer(r"(\d{1,3}(?:[ ., \xa0]\d{3})+|\d{5,})\s*(fbu|francs?|bif)?", t):
        v = _num(m.group(1))
        if v and v >= 10_000:
            return int(v)
    return None


def parse_term_months(text: str) -> int | None:
    t = fold(text)
    m = re.search(rf"{_NUMBER}\s*(mois|months?|mos)\b", t)
    if m and (v := _num(m.group(1))):
        return int(v)
    m = re.search(rf"(?:amezi|ameze|mezi|ukwezi)\s*{_NUMBER}", t)
    if m and (v := _num(m.group(1))):
        return int(v)
    m = re.search(rf"{_NUMBER}\s*(ans?|years?|imyaka)\b", t) or re.search(rf"imyaka\s*{_NUMBER}", t)
    if m and (v := _num(m.group(1))):
        return int(v * 12)
    return None


def find_product(text: str, loans_only: bool = False) -> str | None:
    tf = fold(text)
    for pid, words in PRODUCTS.items():
        if loans_only and pid not in LOAN_PRODUCTS:
            continue
        if any(_has(tf, w) for w in words):
            return pid
    return None


def find_place(text: str) -> str | None:
    tf = fold(text)
    for p in PROVINCES:
        if re.search(rf"(?<![a-z]){fold(p)}", tf):
            return p
    # small typos: "ngozy" → Ngozi
    for tok in tokens(text):
        tok_f = fold(tok)
        for p in PROVINCES:
            pf = fold(p)
            if (
                len(tok_f) >= 5
                and abs(len(tok_f) - len(pf)) <= 1
                and sum(a != b for a, b in zip(tok_f, pf, strict=False)) <= 1
            ):
                return p
    return None


STRONG_FRUSTRATION = {
    "inadmissible",
    "scandale",
    "arnaque",
    "voleurs",
    "en colère",
    "j'en ai assez",
    "unacceptable",
    "furious",
    "scam",
    "fed up",
    "thieves",
    "angry",
    "ndarakaye",
    "akarenganyo",
    "ibisuma",
    "nararambiwe",
    "mwanyibye",
}
INTENSIFIERS = ["cane", "rwose", "très", "tres", "vraiment", "really", "so", "totally"]


def frustration_score(text: str) -> float:
    tf = fold(text)
    score = 0.0
    hits = [w for w in FRUSTRATION_WORDS if _has(tf, w)]
    score += min(0.8, sum(0.55 if w in STRONG_FRUSTRATION else 0.35 for w in hits))
    if hits and any(_has(tf, w) for w in INTENSIFIERS):
        score += 0.15
    bangs = text.count("!")
    score += 0.15 if bangs >= 2 else 0.05 * bangs
    letters = [c for c in text if c.isalpha()]
    if len(letters) >= 12 and sum(c.isupper() for c in letters) / len(letters) > 0.6:
        score += 0.25
    return round(min(1.0, score), 2)


def keyword_intent(text: str) -> dict[str, Any]:
    """Keyword NLU. Returns a dict valid against intent.schema.json."""
    tf = fold(text)
    scores: dict[str, float] = {}
    for intent, kws in INTENT_KEYWORDS.items():
        s = 0.0
        for kw in kws:
            if _has(tf, kw):
                s += 1.0 + 0.5 * (" " in kw)  # phrases are stronger evidence
        if s:
            scores[intent] = s
    entities = extract_entities(text)
    # Off-topic (weather, football...) even when a town is named: other, trusted
    if any(_has(tf, w) for w in OFF_TOPIC) and not any(_has(tf, w) for w in COMPLAINT_EXPLICIT):
        return {
            "intent": "other",
            "lang": detect(text)[0] or "fr",
            "entities": {},
            "confidence": 0.85,
            "frustration": frustration_score(text),
        }
    # A price question about an account or a card is product info, not account opening
    opening = any(w in tf for w in OPENING_WORDS)
    if not opening and any(_has(tf, w) for w in PRICE_WORDS) and any(_has(tf, w) for w in ACCOUNT_WORDS):
        scores["product_info"] = scores.get("product_info", 0) + 2
    # Kirundi verb forms of "open" (kwugurura, nugurure, nokwugurura...) next to "konti"
    if re.search(r"\w*ugurur\w*", tf) and "konti" in tf:
        scores["account_opening"] = scores.get("account_opening", 0) + 2
    # Saying "complaint" explicitly beats the topic words of the complaint ("the ATM swallowed my card")
    if any(_has(tf, w) for w in COMPLAINT_EXPLICIT):
        scores["complaint"] = scores.get("complaint", 0) + 2.5
    # Entities are evidence too
    if "ticket_number" in entities:
        scores["complaint"] = scores.get("complaint", 0) + 2
    if "card_issue" in entities and ("carte" in tf or "card" in tf or "karata" in tf):
        scores["card_block"] = scores.get("card_block", 0) + 1.5
    if ("loan_amount" in entities or "term_months" in entities) and scores.get("loan_info"):
        scores["loan_info"] += 1
    if "loan_amount" in entities and "term_months" in entities:  # an amount over a term is a simulation
        scores["loan_info"] = scores.get("loan_info", 0) + 2
    if entities.get("province") and scores.get("branch_info"):
        scores["branch_info"] += 1
    # "Frais" alone is product info; with complaint words it is a complaint.
    if scores.get("complaint") and scores.get("product_info"):
        scores["product_info"] -= 0.5

    lang = detect(text)[0] or "fr"
    if not scores:
        return {
            "intent": "other",
            "lang": lang,
            "entities": entities,
            "confidence": 0.3,
            "frustration": frustration_score(text),
        }
    ranked = sorted(scores.items(), key=lambda kv: kv[1], reverse=True)
    best, s1 = ranked[0]
    s2 = ranked[1][1] if len(ranked) > 1 else 0.0
    conf = min(0.9, 0.45 + 0.15 * s1 - 0.1 * s2)
    frus = frustration_score(text)
    if best != "complaint":
        entities.pop("complaint_category", None)
    if best != "card_block":
        entities.pop("card_issue", None)
    if frus >= 0.7 and best == "complaint":
        entities.setdefault("urgency", "high")
    return {
        "intent": best,
        "lang": lang,
        "entities": entities,
        "confidence": round(max(0.0, conf), 2),
        "frustration": frus,
    }


def is_greeting(text: str) -> bool:
    tf = fold(text)
    return any(_has(tf, w) for w in GREETINGS) and len(tokens(text)) <= 5


def is_thanks(text: str) -> bool:
    tf = fold(text)
    return any(_has(tf, w) for w in THANKS) and len(tokens(text)) <= 6


def is_goodbye(text: str) -> bool:
    tf = fold(text)
    return any(_has(tf, w) for w in GOODBYES) and len(tokens(text)) <= 6


YES = [
    "oui",
    "ouais",
    "d'accord",
    "ok",
    "okay",
    "confirme",
    "je confirme",
    "yes",
    "yeah",
    "yep",
    "sure",
    "confirm",
    "ego",
    "ni vyo",
    "ndemeye",
    "ndabyemeye",
    "emeza",
    "1",
]
NO = ["non", "pas", "annule", "annuler", "no", "nope", "cancel", "stop", "oya", "hagarika", "reka", "2"]


def yes_no(text: str) -> bool | None:
    tf = fold(text).strip(" .!?")
    if any(_has(tf, w) for w in NO):
        return False
    if any(_has(tf, w) for w in YES):
        return True
    return None


def wants_cancel(text: str) -> bool:
    tf = fold(text)
    return any(_has(tf, w) for w in ["annuler", "annule", "cancel", "stop", "hagarika", "reka", "laisse tomber"])


def wants_agent(text: str) -> bool:
    tf = fold(text)
    return any(_has(tf, w) for w in INTENT_KEYWORDS["handoff"])


def forgot_pin(text: str) -> bool:
    tf = fold(text)
    return any(
        _has(tf, w)
        for w in [
            "oublié",
            "oublie",
            "forgot",
            "forgotten",
            "don't remember",
            "nibagiye",
            "nayibagiye",
            "sinyibuka",
            "date de naissance",
            "date of birth",
        ]
    )


def extract_entities(text: str) -> dict[str, Any]:
    tf = fold(text)
    e: dict[str, Any] = {}
    place = find_place(text)
    if place:
        e["province"] = place
    prod = find_product(text)
    if prod:
        e["product"] = prod
    amt = parse_amount(text)
    if amt is not None:
        e["loan_amount"] = amt
    term = parse_term_months(text)
    if term is not None and 1 <= term <= 360:
        e["term_months"] = term
    m = re.search(r"(?:termin\w*|finissant|ending|finit|irangizwa|last|derniers?)\D{0,20}(\d{4})\b", tf)
    if m:
        e["card_last4"] = m.group(1)
    for issue, words in CARD_ISSUES.items():
        if any(_has(tf, w) for w in words):
            e["card_issue"] = issue
            break
    for cat, words in COMPLAINT_CATEGORIES.items():
        if any(_has(tf, w) for w in words):
            e["complaint_category"] = cat
            break
    m = re.search(r"\bTCK-\d{4}-\d{5}\b", text.upper())
    if m:
        e["ticket_number"] = m.group(0)
    return e
