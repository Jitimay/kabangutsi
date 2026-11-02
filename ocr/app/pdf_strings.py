"""PDF labels in fr / en / rn. Kirundi (rn) strings are a DRAFT: review by a native speaker needed.

No bank facts here: rates, fees and amounts come from the data sent by the backend.
"""

T = {
    "fr": {
        "loan_title": "Simulation de crédit",
        "product": "Produit", "amount": "Montant emprunté", "term": "Durée",
        "months": "mois", "rate": "Taux annuel", "monthly": "Mensualité",
        "total_payment": "Total remboursé", "total_interest": "Coût total des intérêts",
        "loan_note": "Simulation indicative et non contractuelle. Les conditions définitives sont "
                     "confirmées par un conseiller BancoBu.",
        "ticket_title": "Accusé de réception de réclamation",
        "ticket_number": "Numéro de ticket", "category": "Catégorie", "urgency": "Urgence",
        "status": "Statut", "created": "Créé le", "updated": "Mis à jour le",
        "phone": "Téléphone", "customer": "Client", "summary": "Résumé",
        "attachments": "Pièces jointes",
        "ticket_note": "Conservez ce numéro : il vous sera demandé pour suivre votre réclamation.",
        "generated": "Document généré le", "fictional": "Démonstration — données fictives",
    },
    "en": {
        "loan_title": "Loan simulation",
        "product": "Product", "amount": "Amount borrowed", "term": "Term",
        "months": "months", "rate": "Annual rate", "monthly": "Monthly payment",
        "total_payment": "Total repaid", "total_interest": "Total interest cost",
        "loan_note": "Indicative, non-binding simulation. Final terms are confirmed by a BancoBu advisor.",
        "ticket_title": "Complaint receipt",
        "ticket_number": "Ticket number", "category": "Category", "urgency": "Urgency",
        "status": "Status", "created": "Created", "updated": "Updated",
        "phone": "Phone", "customer": "Customer", "summary": "Summary",
        "attachments": "Attachments",
        "ticket_note": "Keep this number: you will be asked for it to follow up on your complaint.",
        "generated": "Generated on", "fictional": "Demo — fictional data",
    },
    "rn": {
        "loan_title": "Igereranya ry'ingurane",
        "product": "Serivisi", "amount": "Amahera y'ingurane", "term": "Igihe",
        "months": "amezi", "rate": "Inyungu ku mwaka", "monthly": "Ayo kwishura ku kwezi",
        "total_payment": "Ayo muzokwishura yose", "total_interest": "Inyungu zose",
        "loan_note": "Iri ni igereranya gusa, si amasezerano. Ivyemezo vya nyuma bitangwa "
                     "n'umukozi wa BancoBu.",
        "ticket_title": "Icemezo c'ikirego",
        "ticket_number": "Inomero y'ikirego", "category": "Ubwoko", "urgency": "Ihutirwa",
        "status": "Aho bigeze", "created": "Catanzwe ku wa", "updated": "Cahinduwe ku wa",
        "phone": "Terefone", "customer": "Umukiriya", "summary": "Incamake",
        "attachments": "Ivyometswe",
        "ticket_note": "Mubike iyi nomero: muzoyisabwa kugira mukurikirane ikirego canyu.",
        "generated": "Rwakozwe ku wa", "fictional": "Igerageza — amakuru y'agahimbano",
    },
}

CATEGORY = {
    "fr": {"fees": "Frais", "card": "Carte", "loan": "Crédit", "account": "Compte",
           "service_quality": "Qualité de service", "mobile_banking": "Banque mobile",
           "atm": "Guichet automatique", "other": "Autre"},
    "en": {"fees": "Fees", "card": "Card", "loan": "Loan", "account": "Account",
           "service_quality": "Service quality", "mobile_banking": "Mobile banking",
           "atm": "ATM", "other": "Other"},
    "rn": {"fees": "Amafaranga y'ibikorwa", "card": "Ikarata", "loan": "Ingurane", "account": "Konti",
           "service_quality": "Ubwiza bw'imikorere", "mobile_banking": "Banki kuri terefone",
           "atm": "Imashini ya ATM", "other": "Ibindi"},
}

URGENCY = {
    "fr": {"low": "Faible", "medium": "Moyenne", "high": "Haute", "critical": "Critique"},
    "en": {"low": "Low", "medium": "Medium", "high": "High", "critical": "Critical"},
    "rn": {"low": "Ntoya", "medium": "Hagati", "high": "Nyinshi", "critical": "Birihutirwa cane"},
}

STATUS = {
    "fr": {"open": "Ouvert", "in_progress": "En cours", "resolved": "Résolu", "closed": "Clôturé"},
    "en": {"open": "Open", "in_progress": "In progress", "resolved": "Resolved", "closed": "Closed"},
    "rn": {"open": "Carakiriwe", "in_progress": "Kiriko kirakorerwa", "resolved": "Catorewe inyishu",
           "closed": "Carugawe"},
}
