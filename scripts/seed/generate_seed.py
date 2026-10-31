#!/usr/bin/env python3
"""Generate the Kabangutsi synthetic demo data.

ALL DATA IS FICTIONAL. Names are random combinations of common Burundian first names and
surnames; phone numbers, account numbers, IDs and cards are invented.

Inputs (hand-written):   branches.json, loan_products.json, kb_articles.json
Outputs (generated):     customers.json, cards.json, agents.json, kb_chunks.json,
                         demo_credentials.json, ../reset_demo.sql

Deterministic: the same inputs always give the same output (fixed random seed), except the
argon2 salts in pin_hash. Run it again only when the inputs change:

    pip install argon2-cffi          # same version as backend/requirements.txt
    python3 scripts/seed/generate_seed.py
"""

from __future__ import annotations

import json
import random
import re
import uuid
from datetime import date, timedelta
from pathlib import Path

try:
    from argon2 import PasswordHasher
except ImportError as exc:  # pragma: no cover
    raise SystemExit("argon2-cffi is required: pip install argon2-cffi") from exc

HERE = Path(__file__).resolve().parent
SQL_OUT = HERE.parent / "reset_demo.sql"
rng = random.Random(257)  # Burundi's calling code
ph = PasswordHasher()

FIRST_NAMES_F = ["Claudine", "Aline", "Divine", "Espérance", "Gloria", "Nadine", "Belyse", "Ornella",
                 "Joselyne", "Ange", "Chanelle", "Daniella", "Fabiola", "Josiane", "Nella", "Sandrine",
                 "Clarisse", "Inès", "Annick", "Doris"]
FIRST_NAMES_M = ["Eric", "Fabrice", "Jean-Bosco", "Innocent", "Pacifique", "Arsène", "Thierry", "Darius",
                 "Cédric", "Prosper", "Egide", "Gilbert", "Olivier", "Bienvenu", "Désiré", "Jimmy",
                 "Lambert", "Patrick", "Serges", "Vianney"]
SURNAMES = ["Niyonzima", "Hakizimana", "Nshimirimana", "Irakoze", "Ndikumana", "Bigirimana", "Manirakiza",
            "Nduwimana", "Havyarimana", "Niyongabo", "Iradukunda", "Ntakirutimana", "Bizimana",
            "Nizigiyimana", "Kwizera", "Habonimana", "Uwimana", "Ciza", "Kaneza", "Ininahazwe",
            "Nsabimana", "Ndayisenga", "Nimbona", "Hatungimana", "Barutwanayo", "Ndihokubwayo",
            "Nkeshimana", "Sindayigaya", "Mpawenimana", "Butoyi"]
# province -> towns (towns are real places; everything attached to them is fictional)
PROVINCES = {
    "Bujumbura": ["Bujumbura"], "Gitega": ["Gitega"], "Ngozi": ["Ngozi"], "Muyinga": ["Muyinga"],
    "Rumonge": ["Rumonge"], "Kayanza": ["Kayanza"], "Kirundo": ["Kirundo"], "Bururi": ["Bururi"],
    "Makamba": ["Makamba"], "Ruyigi": ["Ruyigi"], "Cibitoke": ["Cibitoke"], "Muramvya": ["Muramvya"],
    "Karuzi": ["Karuzi"], "Rutana": ["Rutana"],
}
PROVINCE_WEIGHTS = {"Bujumbura": 12, "Gitega": 6, "Ngozi": 6}

# Demo personas (PRD demo script). PIN 1234 for all of them; listed in demo_credentials.json.
PERSONAS = [
    dict(full_name="Claudine Niyonzima", phone="+25779000101", account_number="40012345670", province="Ngozi",
         language="rn", date_of_birth="1990-03-14", pin="1234", cards=[("1357", "local_debit", "active")]),
    dict(full_name="Jean-Bosco Ndikumana", phone="+25779000102", account_number="40012345671", province="Kayanza",
         language="fr", date_of_birth="1979-09-02", pin="1234", cards=[("2468", "visa_debit", "active")]),
    dict(full_name="Divine Irakoze", phone="+25779000103", account_number="40012345672", province="Gitega",
         language="en", date_of_birth="1995-12-25", pin="1234", cards=[("3579", "local_debit", "active")]),
    dict(full_name="Eric Hakizimana", phone="+25779000104", account_number="40012345679", province="Bujumbura",
         language="fr", date_of_birth="1988-04-12", pin="1234",
         cards=[("7710", "visa_debit", "active"), ("7711", "local_debit", "active")]),
    dict(full_name="Kevin Iradukunda", phone="+25779000105", account_number="40012345678", province="Bujumbura",
         language="en", date_of_birth="1992-07-30", pin="1234", cards=[("4821", "visa_debit", "active")]),
]

AGENTS = [
    dict(id="agent-01", name="Agent Aline (demo)", languages=["rn", "fr"], role="agent"),
    dict(id="agent-02", name="Agent Fabrice (demo)", languages=["fr", "en"], role="agent"),
    dict(id="agent-03", name="Agent Divine (demo)", languages=["rn", "en", "fr"], role="agent"),
    dict(id="supervisor-01", name="Superviseur Pacifique (demo)", languages=["fr", "en", "rn"], role="supervisor"),
]


def new_uuid() -> str:
    return str(uuid.UUID(int=rng.getrandbits(128), version=4))


def sql(v) -> str:
    """SQL literal."""
    if v is None:
        return "NULL"
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, (dict, list)):
        return sql(json.dumps(v, ensure_ascii=False)) + "::jsonb"
    return "'" + str(v).replace("'", "''") + "'"


def text_array(items: list[str]) -> str:
    return "ARRAY[" + ", ".join(sql(i) for i in items) + "]::text[]"


def fmt_fbu(n: int, lang: str) -> str:
    sep = "," if lang == "en" else " "
    return f"{n:,}".replace(",", sep) + " FBu"


# ---------------------------------------------------------------- customers + cards
def build_customers():
    customers, cards, creds = [], [], []
    used_phones, used_accounts = set(), set()

    def add(full_name, phone, account_number, province, language, dob, pin, card_specs):
        cid = new_uuid()
        used_phones.add(phone)
        used_accounts.add(account_number)
        customers.append(dict(id=cid, full_name=full_name, phone=phone, account_number=account_number,
                              province=province, town=rng.choice(PROVINCES[province]), language=language,
                              date_of_birth=dob, pin_hash=ph.hash(pin), fictional=True))
        creds.append(dict(full_name=full_name, phone=phone, account_number=account_number, pin=pin,
                          date_of_birth=dob, language=language,
                          cards=[c[0] for c in card_specs]))
        for last4, ctype, status in card_specs:
            exp = date(2027 + rng.randint(0, 3), rng.randint(1, 12), 1)
            if status == "expired":
                exp = date(2025, rng.randint(1, 12), 1)
            cards.append(dict(id=new_uuid(), customer_id=cid, last4=last4, card_type=ctype, status=status,
                              expires=exp.isoformat()))

    for p in PERSONAS:
        add(p["full_name"], p["phone"], p["account_number"], p["province"], p["language"],
            p["date_of_birth"], p["pin"], p["cards"])

    provinces = list(PROVINCES)
    weights = [PROVINCE_WEIGHTS.get(p, 2) for p in provinces]
    n = 0
    while len(customers) < 50:
        n += 1
        female = rng.random() < 0.5
        first = rng.choice(FIRST_NAMES_F if female else FIRST_NAMES_M)
        name = f"{first} {rng.choice(SURNAMES)}"
        province = rng.choices(provinces, weights)[0]
        language = rng.choices(["rn", "fr", "en"], [50, 35, 15])[0]
        phone = f"+257791{rng.randint(0, 99999):05d}"
        account = f"400{rng.randint(10_000_000, 99_999_999)}"
        if phone in used_phones or account in used_accounts:
            continue
        dob = (date(1960, 1, 1) + timedelta(days=rng.randint(0, 365 * 45))).isoformat()
        pin = f"{rng.randint(0, 9999):04d}"
        card_specs = []
        for _ in range(rng.choices([1, 2], [75, 25])[0]):
            last4 = f"{rng.randint(0, 9999):04d}"
            if any(c[0] == last4 for c in card_specs):
                continue
            ctype = rng.choices(["visa_debit", "local_debit", "prepaid"], [40, 50, 10])[0]
            status = rng.choices(["active", "blocked", "expired"], [85, 8, 7])[0]
            card_specs.append((last4, ctype, status))
        add(name, phone, account, province, language, dob, pin, card_specs)
    return customers, cards, creds


# ---------------------------------------------------------------- knowledge base
LOAN_TEMPLATES = {
    "fr": ("{name}", "{name} : {description} Taux : {rate} % par an. Montant : de {min} à {max}. "
           "Durée : de {tmin} à {tmax} mois. Conditions : {req}. Frais de dossier : 1 % du montant, minimum 5 000 FBu."),
    "en": ("{name}", "{name}: {description} Rate: {rate}% per year. Amount: from {min} to {max}. "
           "Term: from {tmin} to {tmax} months. Requirements: {req}. Processing fee: 1% of the amount, minimum 5,000 FBu."),
    "rn": ("{name}", "{name}: {description} Inyungu: {rate} % ku mwaka. Amafaranga: kuva kuri {min} gushika kuri {max}. "
           "Igihe: kuva ku mezi {tmin} gushika ku mezi {tmax}. Ivyo bisaba: {req}. Amafaranga y'idosiye: 1 % y'ayo musaba, ntarengwa 5 000 FBu."),
}


def build_kb(loans):
    src = json.loads((HERE / "kb_articles.json").read_text())["articles"]
    articles = []
    for a in src:
        for lang in ("fr", "en", "rn"):
            articles.append(dict(id=f"kb-{a['topic'].replace('_', '-')}-{lang}", topic=a["topic"], intent=a["intent"],
                                 lang=lang, title=a[lang]["title"], body=a[lang]["body"]))
    for p in loans:
        for lang in ("fr", "en", "rn"):
            t_title, t_body = LOAN_TEMPLATES[lang]
            rate = f"{p['annual_rate_pct']:g}".replace(".", "," if lang != "en" else ".")
            body = t_body.format(name=p["name"][lang], description=p["description"][lang], rate=rate,
                                 min=fmt_fbu(p["min_amount"], lang), max=fmt_fbu(p["max_amount"], lang),
                                 tmin=p["min_term_months"], tmax=p["max_term_months"],
                                 req="; ".join(p["requirements"][lang]))
            topic = f"loan_{p['id']}"
            articles.append(dict(id=f"kb-{topic.replace('_', '-')}-{lang}", topic=topic, intent="loan_info",
                                 lang=lang, title=t_title.format(name=p["name"][lang]), body=body))
    chunks = []
    for a in articles:
        for i, part in enumerate(split_chunks(a["body"])):
            chunks.append(dict(id=f"{a['id']}-{i}", article_id=a["id"], source=a["title"], lang=a["lang"],
                               chunk_index=i, text=f"{a['title']}. {part}"))
    return articles, chunks


def split_chunks(text: str, limit: int = 600) -> list[str]:
    sentences = re.split(r"(?<=[.!?])\s+", text.strip())
    out, cur = [], ""
    for s in sentences:
        if cur and len(cur) + 1 + len(s) > limit:
            out.append(cur)
            cur = s
        else:
            cur = f"{cur} {s}".strip()
    if cur:
        out.append(cur)
    return out


# ---------------------------------------------------------------- demo history (today, relative to now())
HISTORY_LINES = {
    "branch_info": {"fr": ("L'agence de Gitega ouvre à quelle heure ?", "L'agence Gitega est ouverte du lundi au vendredi de 8 h à 17 h et le samedi de 8 h à 13 h."),
                    "en": ("What time does the Rumonge branch close?", "The Rumonge branch closes at 17:00 on weekdays and at 12:00 on Saturday."),
                    "rn": ("Ishami rya Muyinga rikora gushika ryari?", "Ishami rya Muyinga rikora kuva 8:00 gushika 17:00, ku wa gatandatu gushika 12:00.")},
    "card_block": {"fr": ("J'ai perdu ma carte", "Votre carte est bloquée. Votre référence est {ref}."),
                   "en": ("My card was stolen", "Your card is blocked. Your reference is {ref}."),
                   "rn": ("Ikarata yanje yatakaye", "Ikarata yanyu yahagaritswe. Inomero y'icemezo ni {ref}.")},
    "loan_info": {"fr": ("Quel est le taux du crédit agricole ?", "Le crédit agricole est à 12 % par an, de 100 000 à 10 000 000 FBu."),
                  "en": ("How much can I borrow for school fees?", "The school fees loan goes from 100,000 to 3,000,000 FBu, over 3 to 10 months."),
                  "rn": ("Ingurane y'uburimyi ni angahe?", "Ingurane y'uburimyi ifise inyungu ya 12 % ku mwaka.")},
    "account_opening": {"fr": ("Quels documents pour ouvrir un compte ?", "Il faut votre CNI, deux photos et une attestation de résidence."),
                        "en": ("What do I need to open a savings account?", "Bring your national ID, two photos and a certificate of residence; minimum deposit 5,000 FBu."),
                        "rn": ("Nkeneye iki kugira nugurure konti?", "Muzane karangamuntu, amafoto abiri n'icemezo c'aho muba.")},
    "product_info": {"fr": ("Combien coûte la carte Visa ?", "L'émission coûte 10 000 FBu et la cotisation annuelle 12 000 FBu."),
                     "en": ("Is the youth account free?", "Yes, the youth account has no maintenance fee."),
                     "rn": ("Konti yo kuzigama ifise inyungu ingahe?", "Konti yo kuzigama ifise inyungu ya 3 % ku mwaka.")},
    "complaint": {"fr": ("On m'a prélevé des frais deux fois", "Votre réclamation est enregistrée sous le numéro {ticket}."),
                  "en": ("The ATM did not give me my money", "Your complaint is registered as {ticket}."),
                  "rn": ("Bankuyeko amafaranga kabiri", "Ikirego canyu candikwe ku nomero {ticket}.")},
}


def build_history(customers):
    """~30 finished calls earlier today + tickets, so the supervisor dashboard is not empty."""
    calls, turns, tickets, block_refs = [], [], [], []
    plan = (["branch_info"] * 8 + ["card_block"] * 6 + ["loan_info"] * 6 + ["account_opening"] * 4
            + ["product_info"] * 3 + ["complaint"] * 4)
    rng.shuffle(plan)
    ticket_n = 0
    block_n = 0
    for i, intent in enumerate(plan):
        cust = rng.choice(customers)
        lang = cust["language"]
        channel = rng.choices(["phone", "ussd", "sms", "whatsapp", "web"], [35, 20, 20, 10, 15])[0]
        start_min = 20 + i * 12 + rng.randint(0, 8)  # minutes before now
        dur = rng.randint(1, 6)
        escalated = intent == "complaint" or rng.random() < 0.12
        resolved_by = "agent" if escalated else ("abandoned" if rng.random() < 0.04 else "ai")
        wait = rng.randint(10, 120) if escalated else None
        cid = new_uuid()
        frustration = round(rng.uniform(0.6, 0.95), 2) if intent == "complaint" else round(rng.uniform(0, 0.4), 2)
        calls.append(dict(id=cid, phone=cust["phone"], channel=channel, language=lang, status="ended",
                          resolved_by=resolved_by, model="gemma4:e2b", last_intent=intent,
                          urgency="high" if intent == "complaint" else "low", frustration=frustration,
                          handoff_reason=("frustration" if intent == "complaint" else "customer_request") if escalated else None,
                          summary="Demo history (fictional)." if escalated else None,
                          claimed_by=rng.choice(["agent-01", "agent-02", "agent-03"]) if escalated else None,
                          start_min=start_min, dur=dur, wait=wait))
        q, a = HISTORY_LINES[intent][lang]
        ref = ticket = None
        if intent == "card_block":
            block_n += 1
            ref = f"BLK-2026-{block_n:05d}"
            block_refs.append(ref)
        if intent == "complaint":
            ticket_n += 1
            ticket = f"TCK-2026-{ticket_n:05d}"
            tickets.append(dict(id=new_uuid(), number=ticket, call_id=cid, customer_id=None, phone=cust["phone"],
                                category=rng.choice(["fees", "atm", "service_quality"]), urgency="high",
                                summary={"fr": "Réclamation de démonstration (fictive) : frais contestés.",
                                         "en": "Demo complaint (fictional): disputed fee.",
                                         "rn": "Ikirego c'akarorero (si ic'ukuri): amafaranga atumvikana."}[lang],
                                description=q, status=rng.choice(["open", "in_progress", "resolved"]), lang=lang,
                                start_min=start_min))
        turns.append(dict(id=new_uuid(), call_id=cid, speaker="customer", text=q, lang=lang, intent=intent,
                          confidence=round(rng.uniform(0.7, 0.98), 2), frustration=frustration, model_used="gemma4:e2b",
                          start_min=start_min))
        turns.append(dict(id=new_uuid(), call_id=cid, speaker="ai", text=a.format(ref=ref, ticket=ticket), lang=lang,
                          intent=None, confidence=None, frustration=None, model_used="gemma4:e2b",
                          start_min=start_min - 0.05))
    return calls, turns, tickets, block_n, ticket_n


# ---------------------------------------------------------------- SQL
def ago(minutes: float) -> str:
    return f"now() - interval '{minutes * 60:.0f} seconds'"


def write_sql(customers, cards, branches, std_hours, loans, articles, chunks, calls, turns, tickets, block_n, ticket_n):
    L = []
    w = L.append
    w("-- Kabangutsi demo data — GENERATED by scripts/seed/generate_seed.py. Do not edit by hand.")
    w("-- ALL DATA IS FICTIONAL. Requires the schema from contracts/db_schema.sql.")
    w("-- Demo history (calls, tickets) is placed relative to now() so today's stats are filled.")
    w("BEGIN;")
    w("TRUNCATE model_events, files, card_block_requests, sessions, tickets, call_turns, calls, kb_chunks, "
      "kb_articles, cards, customers, branches, loan_products, agents RESTART IDENTITY CASCADE;")
    w("")
    for a in AGENTS:
        w(f"INSERT INTO agents (id, name, languages, role) VALUES ({sql(a['id'])}, {sql(a['name'])}, "
          f"{text_array(a['languages'])}, {sql(a['role'])});")
    w("")
    for b in branches:
        hours = b.get("hours", std_hours)
        w(f"INSERT INTO branches (id, name, province, town, address, phone, hours, services, latitude, longitude) VALUES ("
          f"{sql(b['id'])}, {sql(b['name'])}, {sql(b['province'])}, {sql(b['town'])}, {sql(b['address'])}, "
          f"{sql(b['phone'])}, {sql(hours)}, {text_array(b['services'])}, {sql(b.get('latitude'))}, {sql(b.get('longitude'))});")
    w("")
    for p in loans:
        w(f"INSERT INTO loan_products (id, name, description, annual_rate_pct, min_amount, max_amount, min_term_months, "
          f"max_term_months, requirements) VALUES ({sql(p['id'])}, {sql(p['name'])}, {sql(p['description'])}, "
          f"{p['annual_rate_pct']}, {p['min_amount']}, {p['max_amount']}, {p['min_term_months']}, {p['max_term_months']}, "
          f"{sql(p['requirements'])});")
    w("")
    for c in customers:
        w(f"INSERT INTO customers (id, full_name, phone, account_number, province, town, language, date_of_birth, pin_hash) VALUES ("
          f"{sql(c['id'])}, {sql(c['full_name'])}, {sql(c['phone'])}, {sql(c['account_number'])}, {sql(c['province'])}, "
          f"{sql(c['town'])}, {sql(c['language'])}, {sql(c['date_of_birth'])}, {sql(c['pin_hash'])});")
    w("")
    for c in cards:
        blocked = c["status"] == "blocked"
        w(f"INSERT INTO cards (id, customer_id, last4, card_type, status, expires, blocked_at, block_reason) VALUES ("
          f"{sql(c['id'])}, {sql(c['customer_id'])}, {sql(c['last4'])}, {sql(c['card_type'])}, {sql(c['status'])}, "
          f"{sql(c['expires'])}, {'now() - interval ' + sql('30 days') if blocked else 'NULL'}, {sql('blocked') if blocked else 'NULL'});")
    w("")
    for a in articles:
        w(f"INSERT INTO kb_articles (id, topic, intent, lang, title, body) VALUES ({sql(a['id'])}, {sql(a['topic'])}, "
          f"{sql(a['intent'])}, {sql(a['lang'])}, {sql(a['title'])}, {sql(a['body'])});")
    w("")
    for c in chunks:
        w(f"INSERT INTO kb_chunks (id, article_id, source, lang, chunk_index, text) VALUES ({sql(c['id'])}, "
          f"{sql(c['article_id'])}, {sql(c['source'])}, {sql(c['lang'])}, {c['chunk_index']}, {sql(c['text'])});")
    w("")
    for c in calls:
        s = c["start_min"]
        queued = ago(s - 1) if c["wait"] is not None else "NULL"
        claimed = ago(s - 1 - c["wait"] / 60) if c["wait"] is not None else "NULL"
        w(f"INSERT INTO calls (id, phone, channel, session_key, language, status, resolved_by, model, last_intent, urgency, "
          f"frustration, handoff_reason, summary, claimed_by, started_at, queued_at, claimed_at, ended_at) VALUES ("
          f"{sql(c['id'])}, {sql(c['phone'])}, {sql(c['channel'])}, {sql(c['phone'])}, {sql(c['language'])}, 'ended', "
          f"{sql(c['resolved_by'])}, {sql(c['model'])}, {sql(c['last_intent'])}, {sql(c['urgency'])}, {c['frustration']}, "
          f"{sql(c['handoff_reason'])}, {sql(c['summary'])}, {sql(c['claimed_by'])}, {ago(s)}, {queued}, {claimed}, "
          f"{ago(s - c['dur'])});")
    w("")
    for t in turns:
        w(f"INSERT INTO call_turns (id, call_id, speaker, text, lang, intent, confidence, frustration, model_used, ts) VALUES ("
          f"{sql(t['id'])}, {sql(t['call_id'])}, {sql(t['speaker'])}, {sql(t['text'])}, {sql(t['lang'])}, {sql(t['intent'])}, "
          f"{sql(t['confidence'])}, {sql(t['frustration'])}, {sql(t['model_used'])}, {ago(t['start_min'])});")
    w("")
    for t in tickets:
        w(f"INSERT INTO tickets (id, number, call_id, phone, category, urgency, summary, description, status, lang, "
          f"created_at, updated_at) VALUES ({sql(t['id'])}, {sql(t['number'])}, {sql(t['call_id'])}, {sql(t['phone'])}, "
          f"{sql(t['category'])}, {sql(t['urgency'])}, {sql(t['summary'])}, {sql(t['description'])}, {sql(t['status'])}, "
          f"{sql(t['lang'])}, {ago(t['start_min'])}, {ago(t['start_min'])});")
    w("")
    w(f"SELECT setval('card_block_ref_seq', {block_n + 1}, false);")
    w(f"SELECT setval('ticket_number_seq', {ticket_n + 1}, false);")
    w("COMMIT;")
    SQL_OUT.write_text("\n".join(L) + "\n")


def dump(name: str, data) -> None:
    (HERE / name).write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n")


def main() -> None:
    branches_doc = json.loads((HERE / "branches.json").read_text())
    loans = json.loads((HERE / "loan_products.json").read_text())["items"]
    customers, cards, creds = build_customers()
    articles, chunks = build_kb(loans)
    calls, turns, tickets, block_n, ticket_n = build_history(customers)
    notice = "FICTIONAL DEMO DATA generated by generate_seed.py. Not real people, accounts or cards."
    dump("customers.json", {"_notice": notice, "items": customers})
    dump("cards.json", {"_notice": notice, "items": cards})
    dump("agents.json", {"_notice": notice, "items": AGENTS})
    dump("kb_chunks.json", {"_notice": notice + " Embeddings are computed by the backend.", "items": chunks})
    dump("demo_credentials.json", {"_notice": notice + " PINs for the demo and tests only.", "items": creds})
    write_sql(customers, cards, branches_doc["items"], branches_doc["standard_hours"], loans, articles, chunks,
              calls, turns, tickets, block_n, ticket_n)
    print(f"customers={len(customers)} cards={len(cards)} branches={len(branches_doc['items'])} loans={len(loans)} "
          f"kb_articles={len(articles)} kb_chunks={len(chunks)} calls={len(calls)} tickets={len(tickets)}")


if __name__ == "__main__":
    main()
