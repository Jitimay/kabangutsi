"""USSD screens and canned questions in fr / en / rn.

No bank facts here (rule 5): menus only route; every answer comes from the backend
orchestrator + knowledge base. Kirundi strings: draft, to be reviewed by a native speaker.
"""

from __future__ import annotations

S: dict[str, dict[str, str]] = {
    "main": {
        "fr": "Kabangutsi BancoBu\n1. Produits\n2. Carte\n3. Crédits\n4. Réclamation\n5. Agences\n6. Langue",
        "en": "Kabangutsi BancoBu\n1. Products\n2. Card\n3. Loans\n4. Complaint\n5. Branches\n6. Language",
        "rn": "Kabangutsi BancoBu\n1. Serivisi\n2. Ikarata\n3. Ingurane\n4. Ikirego\n5. Amashami\n6. Ururimi",
    },
    "products": {
        "fr": "Produits\n1. Liste des produits\n2. Ouvrir un compte\n3. Autre question\n0. Retour",
        "en": "Products\n1. Product list\n2. Open an account\n3. Other question\n0. Back",
        "rn": "Serivisi\n1. Urutonde rwa serivisi\n2. Kwugurura konti\n3. Ikindi kibazo\n0. Subira inyuma",
    },
    "card": {
        "fr": "Carte\n1. Bloquer ma carte (perdue/volée)\n2. Autre question carte\n0. Retour",
        "en": "Card\n1. Block my card (lost/stolen)\n2. Other card question\n0. Back",
        "rn": "Ikarata\n1. Guhagarika ikarata yanje (yatakaye/yibwe)\n2. Ikindi kibazo c'ikarata\n0. Subira inyuma",
    },
    "loans": {
        "fr": "Crédits\n1. Types de crédit\n2. Simuler un crédit\n3. Autre question\n0. Retour",
        "en": "Loans\n1. Loan types\n2. Simulate a loan\n3. Other question\n0. Back",
        "rn": "Ingurane\n1. Ubwoko bw'ingurane\n2. Kugereranya ingurane\n3. Ikindi kibazo\n0. Subira inyuma",
    },
    "lang": {
        "fr": "Langue / Language / Ururimi\n1. Français\n2. English\n3. Ikirundi\n0. Retour",
        "en": "Langue / Language / Ururimi\n1. Français\n2. English\n3. Ikirundi\n0. Back",
        "rn": "Langue / Language / Ururimi\n1. Français\n2. English\n3. Ikirundi\n0. Subira inyuma",
    },
    "ask_free": {
        "fr": "Écrivez votre question :",
        "en": "Type your question:",
        "rn": "Andika ikibazo cawe:",
    },
    "ask_complaint": {
        "fr": "Décrivez votre problème :",
        "en": "Describe your problem:",
        "rn": "Sigura ikibazo cawe:",
    },
    "ask_branch": {
        "fr": "Quelle ville ou agence ?",
        "en": "Which town or branch?",
        "rn": "Igisagara canke ishami irihe?",
    },
    "ask_amount": {
        "fr": "Montant souhaité en FBu :",
        "en": "Amount in FBu:",
        "rn": "Amahera mwipfuza (FBu):",
    },
    "ask_term": {
        "fr": "Durée en mois (1-360) :",
        "en": "Term in months (1-360):",
        "rn": "Igihe mu mezi (1-360):",
    },
    "invalid": {
        "fr": "Choix invalide.",
        "en": "Invalid choice.",
        "rn": "Ivyo mwahisemwo sivyo.",
    },
    "footer": {
        "fr": "0:Menu 00:Quitter",
        "en": "0:Menu 00:Exit",
        "rn": "0:Menu 00:Sohoka",
    },
    "bye": {
        "fr": "Merci d'avoir utilisé Kabangutsi BancoBu.",
        "en": "Thank you for using Kabangutsi BancoBu.",
        "rn": "Murakoze gukoresha Kabangutsi BancoBu.",
    },
    "unavailable": {
        "fr": "Service momentanément indisponible. Réessayez plus tard.",
        "en": "Service temporarily unavailable. Please try again later.",
        "rn": "Serivisi ntiboneka ubu. Mugerageze haheze akanya.",
    },
}

# Questions sent to the orchestrator for a menu choice (it detects the intent and answers
# from the knowledge base). {x} placeholders are filled from the customer's input.
Q: dict[str, dict[str, str]] = {
    "product_list": {
        "fr": "Quels produits et services proposez-vous ?",
        "en": "What products and services do you offer?",
        "rn": "Ni izihe serivisi mutanga?",
    },
    "open_account": {
        "fr": "Comment ouvrir un compte ?",
        "en": "How do I open an account?",
        "rn": "Nugurura gute konti?",
    },
    "block_card": {
        "fr": "Je veux bloquer ma carte.",
        "en": "I want to block my card.",
        "rn": "Ndashaka guhagarika ikarata yanje.",
    },
    "loan_types": {
        "fr": "Quels types de crédit proposez-vous ?",
        "en": "What types of loans do you offer?",
        "rn": "Ni ubuhe bwoko bw'ingurane mutanga?",
    },
    "loan_sim": {
        "fr": "Simulez un crédit de {amount} FBu sur {months} mois.",
        "en": "Simulate a loan of {amount} FBu over {months} months.",
        "rn": "Ndagusavye ugereranye ingurane y'amahera {amount} FBu mu mezi {months}.",
    },
    "complaint": {
        "fr": "Je veux faire une réclamation : {x}",
        "en": "I want to make a complaint: {x}",
        "rn": "Ndashaka gutanga ikirego: {x}",
    },
    "branch": {
        "fr": "Quels sont les horaires de l'agence de {x} ?",
        "en": "What are the opening hours of the {x} branch?",
        "rn": "Ishami rya {x} ryugurura ryari?",
    },
}
