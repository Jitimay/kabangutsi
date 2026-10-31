"""10 synthetic call-center sentences per language (banking domain, no real data).

Kirundi sentences were written without a native speaker: they must be reviewed by one
before the numbers for `rn` are taken as final.
"""

SENTENCES: dict[str, list[str]] = {
    "fr": [
        "Bonjour, je voudrais connaître les horaires de votre agence.",
        "Ma carte bancaire est bloquée depuis ce matin.",
        "Je souhaite ouvrir un compte d'épargne.",
        "Quels documents faut-il pour demander un crédit ?",
        "Merci beaucoup pour votre aide.",
        "Je voudrais parler à un conseiller, s'il vous plaît.",
        "À quelle heure ouvre l'agence de Ngozi samedi ?",
        "J'ai oublié le code secret de ma carte.",
        "Je veux déposer une réclamation pour un retrait non reçu.",
        "L'argent envoyé hier n'est pas arrivé sur mon compte.",
    ],
    "en": [
        "Hello, I would like to know your branch opening hours.",
        "My bank card has been blocked since this morning.",
        "I want to open a savings account.",
        "Which documents do I need to apply for a loan?",
        "Thank you very much for your help.",
        "I would like to speak to an agent, please.",
        "What time does the Ngozi branch open on Saturday?",
        "I forgot the secret code of my card.",
        "I want to file a complaint about a withdrawal I did not receive.",
        "The money sent yesterday has not arrived in my account.",
    ],
    "rn": [
        "Amahoro, ndashaka kumenya amasaha ibiro vyanyu bikinguriraho.",
        "Ikarata yanje yafunzwe kuva muri iki gitondo.",
        "Ndashaka kwugurura konti yo kuzigama.",
        "Ni ibihe vyangombwa nkeneye kugira ngo nsabe ingurane?",
        "Murakoze cane ku bufasha bwanyu.",
        "Ndashaka kuvugana n'umukozi, ndabinginze.",
        "Ishami rya Ngozi rikingura ku yihe saha ku wa gatandatu?",
        "Nibagiye kode y'ibanga y'ikarata yanje.",
        "Ndashaka gutanga ikirego ku mafaranga ntaronse.",
        "Amafaranga narungitse ejo ntarashika kuri konti yanje.",
    ],
}
