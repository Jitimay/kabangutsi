// Fixed mock-backend texts in fr / en / rn. Only used with USE_MOCK=true until G1.
// Bank facts (products, hours, procedures) come from mock_seed.dart (fictional seed data).

typedef L3 = Map<String, String>;

String pick(L3 m, String lang) => m[lang] ?? m['fr']!;

const kMockGreeting = <String, String>{
  'fr': 'Bienvenue chez BancoBu. Je suis Kabangutsi, votre assistant. Comment puis-je vous aider ?',
  'en': 'Welcome to BancoBu. I am Kabangutsi, your assistant. How can I help you?',
  'rn': 'Murakaza neza kuri BancoBu. Ndi Kabangutsi, umufasha wanyu. Nobafasha iki?',
};

const kAskAccount = <String, String>{
  'fr': 'Pour bloquer votre carte, donnez votre numéro de compte (11 chiffres).',
  'en': 'To block your card, please give your account number (11 digits).',
  'rn': 'Kugira duhagarike ikarata yanyu, nimuduhe inomero ya konti (imibare 11).',
};

const kAskPin = <String, String>{
  'fr': 'Merci. Entrez maintenant votre code PIN à 4 chiffres, ou votre date de naissance (AAAA-MM-JJ).',
  'en': 'Thank you. Now enter your 4-digit PIN, or your date of birth (YYYY-MM-DD).',
  'rn': 'Murakoze. Ubu nimwinjize PIN yanyu y\'imibare 4, canke itariki y\'amavuka (YYYY-MM-DD).',
};

const kAccountNotFound = <String, String>{
  'fr': 'Je ne trouve pas ce numéro de compte. Vérifiez les 11 chiffres et réessayez.',
  'en': 'I cannot find this account number. Please check the 11 digits and try again.',
  'rn': 'Iyo nomero ya konti ntiboneka. Nimusubire murabe imibare 11.',
};

const kIdentityFailed = <String, String>{
  'fr': 'Les informations ne correspondent pas. Il vous reste {n} essai(s).',
  'en': 'The details do not match. You have {n} attempt(s) left.',
  'rn': 'Ivyo mwatanze ntibihuye. Musigaranye amahirwe {n}.',
};

const kConfirmBlock = <String, String>{
  'fr': 'Identité vérifiée. Confirmez-vous le blocage de la carte se terminant par {last4} ? Répondez oui ou non.',
  'en': 'Identity verified. Do you confirm blocking the card ending in {last4}? Answer yes or no.',
  'rn': 'Turabemeje. Muremeza ko duhagarika ikarata irangizwa na {last4}? Nimwishure ego canke oya.',
};

const kBlocked = <String, String>{
  'fr': 'Votre carte se terminant par {last4} est bloquée. Votre référence est {ref}.',
  'en': 'Your card ending in {last4} is blocked. Your reference is {ref}.',
  'rn': 'Ikarata yanyu irangizwa na {last4} yahagaritswe. Inomero y\'icemezo ni {ref}.',
};

const kBlockCancelled = <String, String>{
  'fr': 'D\'accord, la carte n\'a pas été bloquée. Puis-je vous aider autrement ?',
  'en': 'All right, the card was not blocked. Can I help you with something else?',
  'rn': 'Ni vyiza, ikarata ntiyahagaritswe. Hari ikindi nobafasha?',
};

const kCardDetails = <String, String>{
  'fr': 'La carte se terminant par {last4} ({type}) sera bloquée. Ce blocage ne peut pas être annulé par téléphone.',
  'en': 'The card ending in {last4} ({type}) will be blocked. This cannot be undone by phone.',
  'rn': 'Ikarata irangizwa na {last4} ({type}) izohagarikwa. Ivyo ntibishobora gusubirwako biciye kuri telefone.',
};

const kLoanExplanation = <String, String>{
  'fr': 'Pour {amount} sur {term} mois à {rate} % par an, vous paierez {monthly} par mois, soit {interest} d\'intérêts au total.',
  'en': 'For {amount} over {term} months at {rate}% a year, you will pay {monthly} per month, that is {interest} of interest in total.',
  'rn': 'Ku {amount} mu mezi {term} ku nyungu ya {rate}% ku mwaka, muzokwishura {monthly} ku kwezi, ni ukuvuga {interest} y\'inyungu yose hamwe.',
};

const kLoanAsk = <String, String>{
  'fr': 'Nos crédits : {list}. Dites-moi le montant et la durée en mois pour une simulation.',
  'en': 'Our loans: {list}. Tell me the amount and the term in months for a simulation.',
  'rn': 'Inguzanyo dufise: {list}. Nimumbwire amafaranga n\'amezi kugira mbaharurire.',
};

const kOutOfRange = <String, String>{
  'fr': 'Le montant doit être entre {min} et {max} et la durée entre {tmin} et {tmax} mois pour ce crédit.',
  'en': 'For this loan the amount must be between {min} and {max} and the term between {tmin} and {tmax} months.',
  'rn': 'Kuri iyi nguzanyo, amafaranga ategerezwa kuba hagati ya {min} na {max}, amezi hagati ya {tmin} na {tmax}.',
};

const kTicketCreated = <String, String>{
  'fr': 'Votre réclamation est enregistrée sous le numéro {ref}.',
  'en': 'Your complaint is registered with number {ref}.',
  'rn': 'Itako ryanyu ryanditswe ku nomero {ref}.',
};

const kBranchAnswer = <String, String>{
  'fr': '{name} : {hours}. Téléphone : {phone}.',
  'en': '{name}: {hours}. Phone: {phone}.',
  'rn': '{name}: {hours}. Telefone: {phone}.',
};

const kHandoff = <String, String>{
  'fr': 'Je vous transfère à un conseiller. Merci de patienter : il a déjà le résumé de notre échange.',
  'en': 'I am transferring you to an agent. Please wait: they already have a summary of our conversation.',
  'rn': 'Ndabahuza n\'umukozi. Mwihangane gato: yamaze kubona incamake y\'ikiganiro cacu.',
};

const kNoAnswer = <String, String>{
  'fr': 'Je n\'ai pas trouvé cette information dans notre base. Je vous passe un conseiller.',
  'en': 'I could not find this information in our knowledge base. I am passing you to an agent.',
  'rn': 'Sinabonye iyo nkuru mu bumenyi dufise. Ndabahuza n\'umukozi.',
};

const kImageReceived = <String, String>{
  'fr': 'J\'ai bien reçu votre image. Dites-moi ce que vous souhaitez faire avec ce document.',
  'en': 'I received your image. Tell me what you would like to do with this document.',
  'rn': 'Nakiriye ifoto yanyu. Nimumbwire ico mushaka ko tuyikoresha.',
};

const kForwarded = <String, String>{
  'fr': 'Message transmis au conseiller.',
  'en': 'Message forwarded to the agent.',
  'rn': 'Ubutumwa bwashikirijwe umukozi.',
};

const kSwitchNotice = <String, String>{
  'fr': 'Modèle changé pour {used} : {req} ne peut pas {what}.',
  'en': 'Switched to {used}: {req} cannot {what}.',
  'rn': 'Twahinduye modeli tuja kuri {used}: {req} ntishobora {what}.',
};

const kCannotReadImages = <String, String>{'fr': 'lire les images', 'en': 'read images', 'rn': 'gusoma amafoto'};
const kCannotHearAudio = <String, String>{'fr': 'écouter l\'audio', 'en': 'listen to audio', 'rn': 'kwumva amajwi'};

const kAgentGenericSuggestion = <String, String>{
  'fr': 'Je comprends. Je vérifie votre dossier et je reviens vers vous tout de suite.',
  'en': 'I understand. I am checking your file and will come back to you right away.',
  'rn': 'Ndabatahura. Ndiko ndaraba dosiye yanyu, ndabishura ubu nyene.',
};

/// What the mock "STT" hears for an audio turn.
const kMockTranscripts = <String, String>{
  'fr': 'Je voudrais bloquer ma carte, je l\'ai perdue.',
  'en': 'What are the opening hours of the Gitega branch?',
  'rn': 'Ishami rya Ngozi ryugurura ryari?',
};

const kDayNames = <String, List<String>>{
  'fr': ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'],
  'en': ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'],
  'rn': ['ku wa mbere', 'ku wa kabiri', 'ku wa gatatu', 'ku wa kane', 'ku wa gatanu', 'ku wa gatandatu', 'ku w\'iyinga'],
};

const kClosedOn = <String, String>{'fr': 'fermé le {day}', 'en': 'closed on {day}', 'rn': '{day} hugaye'};

// --- USSD menus ---
const kUssdMain = <String, String>{
  'fr': 'Kabangutsi\n1. Bloquer une carte\n2. Crédits\n3. Agences et horaires\n4. Réclamation\n5. Langue',
  'en': 'Kabangutsi\n1. Block a card\n2. Loans\n3. Branches and hours\n4. Complaint\n5. Language',
  'rn': 'Kabangutsi\n1. Guhagarika ikarata\n2. Inguzanyo\n3. Amashami n\'amasaha\n4. Itako\n5. Ururimi',
};
const kUssdLang = 'Langue / Language / Ururimi\n1. Français\n2. English\n3. Ikirundi';
const kUssdInvalid = <String, String>{'fr': 'Choix invalide.', 'en': 'Invalid choice.', 'rn': 'Ivyo mwahisemwo sivyo.'};
const kUssdBack = <String, String>{'fr': '0. Retour', 'en': '0. Back', 'rn': '0. Gusubira inyuma'};
const kUssdMore = <String, String>{'fr': '9. Suite', 'en': '9. More', 'rn': '9. Ibindi'};
const kUssdPickProvince = <String, String>{'fr': 'Choisissez la province :', 'en': 'Choose the province:', 'rn': 'Hitamwo intara:'};
const kUssdPickLoan = <String, String>{'fr': 'Choisissez un crédit :', 'en': 'Choose a loan:', 'rn': 'Hitamwo inguzanyo:'};
const kUssdLoanLine = <String, String>{
  'fr': '{name} : {rate} %/an, {min} à {max}, {tmin} à {tmax} mois.',
  'en': '{name}: {rate}%/year, {min} to {max}, {tmin} to {tmax} months.',
  'rn': '{name}: {rate}% ku mwaka, {min} gushika {max}, amezi {tmin} gushika {tmax}.',
};

String fill(String template, Map<String, Object> values) =>
    values.entries.fold(template, (s, e) => s.replaceAll('{${e.key}}', '${e.value}'));
