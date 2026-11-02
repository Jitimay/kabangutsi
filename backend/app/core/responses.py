"""Reply templates in fr / en / rn. Every user-facing string the backend writes in code lives here.

Kirundi strings need review by a native speaker (see status/T1.md).
"""

from __future__ import annotations

from typing import Any

from app.util import fmt_amount, short_text

T: dict[str, dict[str, str]] = {
    "greeting": {
        "fr": "Bienvenue chez BancoBu. Je suis Kabangutsi, votre assistant. Comment puis-je vous aider ?",
        "en": "Welcome to BancoBu. I am Kabangutsi, your assistant. How can I help you?",
        "rn": "Murakaza neza kuri BancoBu. Ndi Kabangutsi, umufasha wanyu. Nobafasha iki?",
    },
    "greeting_short": {
        "fr": "Bienvenue chez BancoBu. Comment puis-je vous aider ?",
        "en": "Welcome to BancoBu. How can I help you?",
        "rn": "Murakaza neza kuri BancoBu. Nobafasha iki?",
    },
    "cap_vision": {"fr": "lire les images", "en": "read images", "rn": "gusoma amafoto"},
    "cap_audio": {"fr": "écouter l'audio", "en": "listen to audio", "rn": "kwumviriza amajwi"},
    "cap_completion": {"fr": "répondre", "en": "answer", "rn": "kwishura"},
    "notice_switch": {
        "fr": "Modèle changé pour {used} : {requested} ne peut pas {cap}.",
        "en": "Switched to {used}: {requested} cannot {cap}.",
        "rn": "Twahinduye tujya kuri {used}: {requested} ntishobora {cap}.",
    },
    "notice_unavailable": {
        "fr": "{requested} n'est pas installé ; j'utilise {used}.",
        "en": "{requested} is not installed; using {used}.",
        "rn": "{requested} ntiyashizwemwo; turakoresha {used}.",
    },
    "notice_ocr": {
        "fr": "Aucun modèle installé ne peut lire les images : le texte a été lu par le lecteur de documents (OCR).",
        "en": "No installed model can read images: the text was read by the document reader (OCR).",
        "rn": "Nta modeli yashizwemwo ishobora gusoma amafoto: inyandiko yasomwe n'igisoma-nyandiko (OCR).",
    },
    "notice_stt": {
        "fr": "Aucun modèle installé ne peut écouter l'audio : la reconnaissance vocale a été utilisée.",
        "en": "No installed model can listen to audio: speech recognition was used instead.",
        "rn": "Nta modeli yashizwemwo ishobora kwumviriza amajwi: twakoresheje igihindura ijwi mu nyandiko.",
    },
    "image_unreadable": {
        "fr": "Je n'arrive pas à lire cette image pour le moment. Pouvez-vous écrire votre question ?",
        "en": "I cannot read this image right now. Could you type your question?",
        "rn": "Sinshoboye gusoma iyi foto ubu. Mwokwandika ikibazo canyu?",
    },
    "audio_unclear": {
        "fr": "Je n'ai pas bien entendu. Pouvez-vous répéter, s'il vous plaît ?",
        "en": "I did not hear that well. Could you repeat, please?",
        "rn": "Sinumvise neza. Mwosubiramwo, mubigiranye ikigongwe?",
    },
    "dont_know": {
        "fr": "Je n'ai pas cette information. Voulez-vous parler à un conseiller ?",
        "en": "I do not have that information. Would you like to talk to an agent?",
        "rn": "Ntafise iyo nkuru. Murashaka kuvugana n'umukozi wacu?",
    },
    "handoff_queued": {
        "fr": "Je vous transfère à un conseiller. Merci de patienter, il vous répondra bientôt.",
        "en": "I am transferring you to an agent. Please wait, an agent will answer you shortly.",
        "rn": "Ndabashikiriza umukozi wacu. Mwihangane gato, aragaruka vuba.",
    },
    "handoff_frustration": {
        "fr": "Je comprends votre mécontentement. Je vous transfère en priorité à un conseiller.",
        "en": "I understand you are upset. I am transferring you to an agent as a priority.",
        "rn": "Ndumva ko mutanezerewe. Ndabashikiriza umukozi wacu bwangu.",
    },
    "with_agent_wait": {
        "fr": "Votre message a été transmis au conseiller.",
        "en": "Your message has been passed to the agent.",
        "rn": "Ubutumwa bwanyu bwashikirijwe umukozi.",
    },
    "queued_wait": {
        "fr": "Vous êtes en attente d'un conseiller. Votre message lui sera transmis.",
        "en": "You are waiting for an agent. Your message will be passed on.",
        "rn": "Muriko murarindira umukozi. Ubutumwa bwanyu buzomushikirizwa.",
    },
    "ended": {
        "fr": "Cette conversation est terminée.",
        "en": "This conversation has ended.",
        "rn": "Iki kiganiro carangiye.",
    },
    "ask_account": {
        "fr": "Pour bloquer votre carte, donnez-moi votre numéro de compte à 11 chiffres.",
        "en": "To block your card, please give me your 11-digit account number.",
        "rn": "Kugira ngo duhagarike ikarata yanyu, nimumpe inomero ya konti yanyu y'ibiharuro 11.",
    },
    "bad_account": {
        "fr": "Ce numéro de compte n'est pas valide. Donnez les 11 chiffres, s'il vous plaît.",
        "en": "That account number is not valid. Please give the 11 digits.",
        "rn": "Iyo nomero ya konti si yo. Nimutange ibiharuro 11.",
    },
    "ask_pin": {
        "fr": "Merci. Entrez votre code PIN à 4 chiffres. Si vous l'avez oublié, tapez votre date de naissance (AAAA-MM-JJ).",
        "en": "Thank you. Please enter your 4-digit PIN. If you forgot it, type your date of birth (YYYY-MM-DD).",
        "rn": "Murakoze. Nimwinjize PIN yanyu y'ibiharuro 4. Nimba mwayibagiye, nimwandike itariki y'amavuka (YYYY-MM-DD).",
    },
    "ask_dob": {
        "fr": "Entrez votre date de naissance au format AAAA-MM-JJ.",
        "en": "Please enter your date of birth as YYYY-MM-DD.",
        "rn": "Nimwandike itariki y'amavuka yanyu nk'iyi: YYYY-MM-DD.",
    },
    "pin_format": {
        "fr": "Je n'ai pas compris. Entrez les 4 chiffres de votre PIN, ou votre date de naissance (AAAA-MM-JJ). Dites « annuler » pour arrêter.",
        "en": 'I did not understand. Enter the 4 digits of your PIN, or your date of birth (YYYY-MM-DD). Say "cancel" to stop.',
        "rn": "Sinatahuye. Nimwinjize ibiharuro 4 vya PIN, canke itariki y'amavuka (YYYY-MM-DD). Muvuge « hagarika » kugira muhagarike.",
    },
    "identity_failed": {
        "fr": "Les informations ne correspondent pas. Il vous reste {left} essai(s).",
        "en": "The details do not match. You have {left} attempt(s) left.",
        "rn": "Ivyo mwatanze ntibihuye. Musigaranye ibigeragezo {left}.",
    },
    "identity_locked": {
        "fr": "Trop d'essais incorrects. Pour votre sécurité, je vous transfère à un conseiller.",
        "en": "Too many failed attempts. For your security, I am transferring you to an agent.",
        "rn": "Mwagerageje kenshi bidakunze. Ku bw'umutekano wanyu, ndabashikiriza umukozi wacu.",
    },
    "no_active_card": {
        "fr": "Je ne trouve aucune carte active sur ce compte.",
        "en": "I cannot find an active card on this account.",
        "rn": "Nta karata ikora mbonye kuri iyi konti.",
    },
    "choose_card": {
        "fr": "Quelle carte voulez-vous bloquer ? Répondez avec les 4 derniers chiffres : {cards}.",
        "en": "Which card do you want to block? Reply with the last 4 digits: {cards}.",
        "rn": "Ni iyihe karata mushaka guhagarika? Nimwishure n'ibiharuro 4 vya nyuma: {cards}.",
    },
    "confirm_block": {
        "fr": "Veuillez confirmer : bloquer la carte {type} se terminant par {last4} ? Répondez oui ou non. Cette action ne peut pas être annulée par téléphone.",
        "en": "Please confirm: block the {type} card ending in {last4}? Reply yes or no. This cannot be undone by phone.",
        "rn": "Nimwemeze: duhagarike ikarata {type} irangizwa na {last4}? Nimwishure ego canke oya. Ibi ntibishobora gusubirwako kuri terefone.",
    },
    "card_blocked": {
        "fr": "Votre carte se terminant par {last4} est bloquée. Votre référence est {ref}. Passez dans une agence avec votre pièce d'identité pour commander une nouvelle carte.",
        "en": "Your card ending in {last4} is blocked. Your reference is {ref}. Visit any branch with your ID to order a new card.",
        "rn": "Ikarata yanyu irangizwa na {last4} yahagaritswe. Inomero y'icemezo ni {ref}. Nimuje ku ishami ryose mufise ikarata karangamuntu kugira musabe iyindi karata.",
    },
    "card_blocked_short": {
        "fr": "Carte {last4} bloquée. Référence {ref}.",
        "en": "Card {last4} blocked. Reference {ref}.",
        "rn": "Ikarata {last4} yahagaritswe. Icemezo {ref}.",
    },
    "block_cancelled": {
        "fr": "D'accord, la carte n'a pas été bloquée. Que puis-je faire d'autre pour vous ?",
        "en": "All right, the card was not blocked. What else can I do for you?",
        "rn": "Ni vyiza, ikarata ntiyahagaritswe. Ni iki kindi nobafasha?",
    },
    "confirm_expired": {
        "fr": "La demande de confirmation a expiré. Recommençons si vous voulez toujours bloquer la carte.",
        "en": "The confirmation request has expired. Let us start again if you still want to block the card.",
        "rn": "Igihe co kwemeza carenze. Dusubire dutangure nimba mukishaka guhagarika ikarata.",
    },
    "yes_no": {
        "fr": "Répondez par oui ou par non, s'il vous plaît.",
        "en": "Please answer yes or no.",
        "rn": "Nimwishure ego canke oya.",
    },
    "card_visa_debit": {"fr": "Visa débit", "en": "Visa debit", "rn": "Visa debit"},
    "card_local_debit": {"fr": "de débit locale", "en": "local debit", "rn": "yo kubikuza yo mu gihugu"},
    "card_prepaid": {"fr": "prépayée", "en": "prepaid", "rn": "y'amafaranga yishuwe imbere"},
    "loan_sim": {
        "fr": "Pour {amount} FBu sur {term} mois à {rate} % par an, vous paierez {monthly} FBu par mois, soit {interest} FBu d'intérêts au total.",
        "en": "For {amount} FBu over {term} months at {rate}% a year, you will pay {monthly} FBu a month, that is {interest} FBu of interest in total.",
        "rn": "Ku {amount} FBu mu mezi {term} ku nyungu ya {rate}% ku mwaka, muzokwishura {monthly} FBu ku kwezi, ni ukuvuga {interest} FBu y'inyungu yose hamwe.",
    },
    "loan_sim_short": {
        "fr": "{name} {amount} FBu/{term} mois a {rate}%: {monthly} FBu par mois.",
        "en": "{name} {amount} FBu/{term} months at {rate}%: {monthly} FBu a month.",
        "rn": "{name} {amount} FBu/amezi {term} ku {rate}%: {monthly} FBu ku kwezi.",
    },
    "loan_amount_min": {
        "fr": "Le montant minimum pour ce crédit est {x} FBu.",
        "en": "The minimum amount for this loan is {x} FBu.",
        "rn": "Amafaranga make ashoboka kuri iyi ngurane ni {x} FBu.",
    },
    "loan_amount_max": {
        "fr": "Le montant maximum pour ce crédit est {x} FBu.",
        "en": "The maximum amount for this loan is {x} FBu.",
        "rn": "Amafaranga menshi ashoboka kuri iyi ngurane ni {x} FBu.",
    },
    "loan_term_range": {
        "fr": "La durée pour ce crédit va de {a} à {b} mois.",
        "en": "The term for this loan is from {a} to {b} months.",
        "rn": "Igihe c'iyi ngurane kiva ku mezi {a} gushika ku mezi {b}.",
    },
    "loan_product": {
        "fr": "{name} : {description} Taux {rate} % par an, de {min} à {max} FBu, sur {tmin} à {tmax} mois.",
        "en": "{name}: {description} Rate {rate}% a year, from {min} to {max} FBu, over {tmin} to {tmax} months.",
        "rn": "{name}: {description} Inyungu {rate}% ku mwaka, kuva kuri {min} gushika kuri {max} FBu, mu mezi {tmin} gushika {tmax}.",
    },
    "loan_ask_amount_term": {
        "fr": "Dites-moi le montant et la durée en mois pour calculer votre mensualité.",
        "en": "Tell me the amount and the term in months to calculate your monthly payment.",
        "rn": "Mumbwire amafaranga n'amezi kugira ngo mbaharurire ivyo muzokwishura ku kwezi.",
    },
    "loan_list": {
        "fr": "Nos crédits : {names}. Lequel vous intéresse ?",
        "en": "Our loans: {names}. Which one interests you?",
        "rn": "Ingurane zacu: {names}. Ni iyihe ibashimishije?",
    },
    "loan_requirements": {
        "fr": "Documents demandés : {items}.",
        "en": "Documents required: {items}.",
        "rn": "Ivyangombwa bisabwa: {items}.",
    },
    "ask_complaint_details": {
        "fr": "Je suis désolé. Décrivez le problème en quelques mots, s'il vous plaît.",
        "en": "I am sorry about that. Please describe the problem in a few words.",
        "rn": "Mutubabarire. Nimudondore ikibazo mu majambo makeyi.",
    },
    "ticket_created": {
        "fr": "J'ai enregistré votre réclamation. Votre numéro de ticket est {number}. Un conseiller la traitera {delay}.",
        "en": "I have recorded your complaint. Your ticket number is {number}. An agent will handle it {delay}.",
        "rn": "Ikirego canyu carandikiwe. Inomero y'itike yanyu ni {number}. Umukozi azogikurikirana {delay}.",
    },
    "ticket_created_short": {
        "fr": "Reclamation enregistree. Ticket {number}.",
        "en": "Complaint recorded. Ticket {number}.",
        "rn": "Ikirego carandikiwe. Itike {number}.",
    },
    "delay_urgent": {"fr": "en priorité aujourd'hui", "en": "as a priority today", "rn": "bwangu uyu munsi"},
    "delay_normal": {"fr": "sous 48 heures", "en": "within 48 hours", "rn": "mu masaha 48"},
    "ticket_status": {
        "fr": "Le ticket {number} est {status}.",
        "en": "Ticket {number} is {status}.",
        "rn": "Itike {number} {status}.",
    },
    "ticket_not_found": {
        "fr": "Je ne trouve pas le ticket {number}.",
        "en": "I cannot find ticket {number}.",
        "rn": "Sinabonye itike {number}.",
    },
    "status_open": {"fr": "ouvert", "en": "open", "rn": "iracuguruye"},
    "status_in_progress": {"fr": "en cours de traitement", "en": "being handled", "rn": "iriko irakurikiranwa"},
    "status_resolved": {"fr": "résolu", "en": "resolved", "rn": "yatorewe inyishu"},
    "status_closed": {"fr": "fermé", "en": "closed", "rn": "yugaranye"},
    "branch_line": {
        "fr": "{name}, {address}. {hours}. Téléphone : {phone}.",
        "en": "{name}, {address}. {hours}. Phone: {phone}.",
        "rn": "{name}, {address}. {hours}. Terefone: {phone}.",
    },
    "branch_line_short": {
        "fr": "{town}: {hours}. Tel {phone}",
        "en": "{town}: {hours}. Tel {phone}",
        "rn": "{town}: {hours}. Tel {phone}",
    },
    "branch_many": {
        "fr": "Nous avons {n} agences à {place}.",
        "en": "We have {n} branches in {place}.",
        "rn": "Dufise amashami {n} i {place}.",
    },
    "branch_ask_town": {
        "fr": "Dans quelle ville ou province ? Nous avons des agences à {towns}.",
        "en": "In which town or province? We have branches in {towns}.",
        "rn": "Mu kihe gisagara canke intara? Dufise amashami i {towns}.",
    },
    "open_now": {"fr": "Ouverte maintenant", "en": "Open now", "rn": "Irakora ubu"},
    "closed_now": {"fr": "Fermée maintenant", "en": "Closed now", "rn": "Yugaye ubu"},
    "other": {
        "fr": "Je peux vous aider pour les produits, l'ouverture de compte, les cartes, les crédits, les réclamations et les horaires des agences. Que voulez-vous savoir ?",
        "en": "I can help with products, account opening, cards, loans, complaints and branch hours. What would you like to know?",
        "rn": "Nshobora kubafasha ku bijanye n'ibicuruzwa, kwugurura konti, amakarata, ingurane, ibirego n'amasaha y'amashami. Mushaka kumenya iki?",
    },
    "hello": {
        "fr": "Bonjour ! Comment puis-je vous aider ?",
        "en": "Hello! How can I help you?",
        "rn": "Amahoro! Nobafasha iki?",
    },
    "thanks": {
        "fr": "Avec plaisir. Puis-je vous aider pour autre chose ?",
        "en": "You are welcome. Can I help you with anything else?",
        "rn": "Ni ugushimwa. Hari ikindi nobafasha?",
    },
    "goodbye": {
        "fr": "Merci d'avoir contacté BancoBu. Au revoir !",
        "en": "Thank you for contacting BancoBu. Goodbye!",
        "rn": "Murakoze kuvugana na BancoBu. Mugire amahoro!",
    },
    "ok_else": {
        "fr": "D'accord. Que puis-je faire d'autre pour vous ?",
        "en": "All right. What else can I do for you?",
        "rn": "Ni vyiza. Ni iki kindi nobafasha?",
    },
    "error": {
        "fr": "Désolé, un problème technique est survenu. Pouvez-vous reformuler ?",
        "en": "Sorry, a technical problem occurred. Could you rephrase?",
        "rn": "Mutubabarire, habaye ingorane y'ubuhinga. Mwosubiramwo mu yandi majambo?",
    },
    # ---- agent dashboard (handoff summary written in code when the AI summary is not available)
    "summary_code": {
        "fr": "Motif : {reason}. Demande : {intent}. Langue : {call_lang}. Frustration : {frustration}. Le client a dit : {said}",
        "en": "Reason: {reason}. Request: {intent}. Language: {call_lang}. Frustration: {frustration}. Customer said: {said}",
        "rn": "Igituma: {reason}. Icasabwe: {intent}. Ururimi: {call_lang}. Ishavu: {frustration}. Umukiriya yavuze: {said}",
    },
    "reason_customer_request": {
        "fr": "le client demande un conseiller",
        "en": "customer asked for an agent",
        "rn": "umukiriya yasavye umukozi",
    },
    "reason_frustration": {"fr": "client mécontent", "en": "frustrated customer", "rn": "umukiriya ababaye"},
    "reason_low_confidence": {
        "fr": "demande non comprise",
        "en": "request not understood",
        "rn": "ivyasabwe ntivyatahuwe",
    },
    "reason_no_answer": {
        "fr": "pas de réponse dans la base de connaissances",
        "en": "no answer in the knowledge base",
        "rn": "nta nyishu iri mu bumenyi",
    },
    "reason_identity_failed": {
        "fr": "échec de la vérification d'identité",
        "en": "identity check failed",
        "rn": "kugenzura umwirondoro vyanse",
    },
    "reason_agent_review": {
        "fr": "document à vérifier",
        "en": "document needs review",
        "rn": "urupapuro rukeneye gusuzumwa",
    },
    "reason_other": {"fr": "autre", "en": "other", "rn": "ibindi"},
    "intent_product_info": {"fr": "produits et frais", "en": "products and fees", "rn": "ibicuruzwa n'amafaranga"},
    "intent_account_opening": {"fr": "ouverture de compte", "en": "account opening", "rn": "kwugurura konti"},
    "intent_card_block": {"fr": "blocage de carte", "en": "card block", "rn": "guhagarika ikarata"},
    "intent_loan_info": {"fr": "crédit", "en": "loan", "rn": "ingurane"},
    "intent_complaint": {"fr": "réclamation", "en": "complaint", "rn": "ikirego"},
    "intent_branch_info": {"fr": "agences et horaires", "en": "branches and hours", "rn": "amashami n'amasaha"},
    "intent_handoff": {"fr": "parler à un conseiller", "en": "talk to an agent", "rn": "kuvugana n'umukozi"},
    "intent_other": {"fr": "autre", "en": "other", "rn": "ibindi"},
    "conversation_ended": {
        "fr": "Cette conversation est terminée. Envoyez un nouveau message pour en commencer une autre.",
        "en": "This conversation has ended. Send a new message to start another one.",
        "rn": "Iki kiganiro carangiye. Rungika ubundi butumwa kugira mutangure ikindi.",
    },
    "already_queued": {
        "fr": "Votre demande est déjà transmise. Un conseiller va vous répondre.",
        "en": "Your request has already been passed on. An agent will answer you.",
        "rn": "Ivyo musaba vyamaze gushikirizwa. Umukozi agiye kubishura.",
    },
    "image_seen": {
        "fr": "Sur votre image : {desc}.",
        "en": "On your image: {desc}.",
        "rn": "Ku ifoto yanyu: {desc}.",
    },
    "stray_digits": {
        "fr": "Pour votre sécurité, n'envoyez jamais votre code PIN dans un message. Que puis-je faire pour vous ?",
        "en": "For your security, never send your PIN in a message. What can I do for you?",
        "rn": "Ku bw'umutekano wanyu, ntimurungike PIN yanyu mu butumwa. Nobafasha iki?",
    },
    "doc_read": {
        "fr": "J'ai lu votre document ({doc}).",
        "en": "I have read your document ({doc}).",
        "rn": "Nasomye urupapuro rwanyu ({doc}).",
    },
    "doc_review": {
        "fr": "J'ai lu votre document. Certaines informations doivent être vérifiées par un conseiller ; je vous transfère.",
        "en": "I have read your document. Some details must be checked by an agent; I am transferring you.",
        "rn": "Nasomye urupapuro rwanyu. Hari ivyo umukozi akwiye gusuzuma; ndabamushikiriza.",
    },
}

DAYS = {
    "fr": ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"],
    "en": ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"],
    "rn": [
        "ku wa mbere",
        "ku wa kabiri",
        "ku wa gatatu",
        "ku wa kane",
        "ku wa gatanu",
        "ku wa gatandatu",
        "ku w'iyinga",
    ],
}
DAY_KEYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
CLOSED_ON = {"fr": "fermé le {d}", "en": "closed on {d}", "rn": "rifunga {d}"}
RANGE_SEP = {"fr": "–", "en": "–", "rn": " gushika "}
AND_WORD = {"fr": "et", "en": "and", "rn": "na"}


def t(key: str, lang: str, **kw: Any) -> str:
    entry = T[key]
    s = entry.get(lang) or entry["fr"]
    return s.format(**kw) if kw else s


def all_langs(key: str, **kw: Any) -> dict[str, str]:
    return {lg: t(key, lg, **kw) for lg in ("fr", "en", "rn")}


def join_list(items: list[str], lang: str) -> str:
    if len(items) <= 1:
        return "".join(items)
    return ", ".join(items[:-1]) + f" {AND_WORD[lang]} " + items[-1]


def hours_text(hours: dict[str, Any], lang: str) -> str:
    """Groups consecutive days with the same hours: 'Lundi–vendredi 08:00–17:00, samedi 08:00–12:00, fermé le dimanche'."""
    names = DAYS[lang]
    groups: list[tuple[int, int, Any]] = []
    for i, k in enumerate(DAY_KEYS):
        h = hours.get(k)
        val = (h["open"], h["close"]) if h else None
        if groups and groups[-1][2] == val and groups[-1][1] == i - 1:
            groups[-1] = (groups[-1][0], i, val)
        else:
            groups.append((i, i, val))
    parts = []
    for a, b, val in groups:
        days = names[a] if a == b else f"{names[a]}{RANGE_SEP[lang]}{names[b]}"
        if val is None:
            parts.append(CLOSED_ON[lang].format(d=days))
        else:
            parts.append(f"{days} {val[0]}–{val[1]}")
    s = ", ".join(parts)
    return s[0].upper() + s[1:] if s else s


def card_type_name(card_type: str, lang: str) -> str:
    return t(f"card_{card_type}", lang)


def amount(n: int, lang: str) -> str:
    return fmt_amount(n, lang)


def rate(r: float, lang: str) -> str:
    s = f"{float(r):g}"
    return s.replace(".", ",") if lang == "fr" else s


__all__ = ["T", "t", "all_langs", "hours_text", "card_type_name", "amount", "rate", "join_list", "short_text"]
