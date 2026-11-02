// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get cardAccountNumber => 'Numéro de compte';

  @override
  String get cardAccountNumberError =>
      'Saisissez le numéro de compte à 11 chiffres';

  @override
  String get cardUsePin => 'Code PIN';

  @override
  String get cardUseDob => 'Date de naissance';

  @override
  String get cardPin => 'Code PIN (4 chiffres)';

  @override
  String get cardFourDigitsError => 'Saisissez 4 chiffres';

  @override
  String get cardDobPick => 'Choisissez votre date de naissance';

  @override
  String get cardDobError => 'Choisissez votre date de naissance';

  @override
  String get cardLast4 => '4 derniers chiffres de la carte (facultatif)';

  @override
  String get cardReason => 'Motif';

  @override
  String get cardVerify => 'Vérifier mon identité';

  @override
  String get cardSecurityNote =>
      'Votre code PIN est vérifié uniquement par le système de la banque. Il n\'est jamais affiché, conservé ni envoyé à l\'IA.';

  @override
  String get cardConfirmTitle => 'Confirmer le blocage';

  @override
  String get cardConfirm => 'Bloquer la carte';

  @override
  String get cardCancel => 'Annuler';

  @override
  String get cardBlockedTitle => 'Carte bloquée';

  @override
  String get cardReference => 'Votre référence';

  @override
  String get cardBlockAnother => 'Bloquer une autre carte';

  @override
  String cardEnding(Object last4) {
    return 'Carte se terminant par $last4';
  }

  @override
  String cardErrIdentity(Object attempts) {
    return 'Les informations ne correspondent pas. Essais restants : $attempts';
  }

  @override
  String get cardErrLocked =>
      'Trop d\'essais échoués. Votre appel a été transmis à un conseiller.';

  @override
  String get cardErrExpired =>
      'La confirmation a expiré. Veuillez recommencer.';

  @override
  String get cardErrNotFound => 'Aucune carte active trouvée pour ce compte.';

  @override
  String get cardErrNetwork => 'Problème de connexion. Veuillez réessayer.';

  @override
  String get cardErrGeneric =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get cardReasonLost => 'Perdue';

  @override
  String get cardReasonStolen => 'Volée';

  @override
  String get cardReasonBlocked => 'Bloquée';

  @override
  String get cardReasonDamaged => 'Endommagée';

  @override
  String get cardReasonSwallowedByAtm => 'Avalée par un distributeur';

  @override
  String get cardReasonFraudSuspected => 'Fraude suspectée';

  @override
  String get cardTypeVisaDebit => 'Visa débit';

  @override
  String get cardTypeLocalDebit => 'Carte de débit locale';

  @override
  String get cardTypePrepaid => 'Carte prépayée';

  @override
  String get loanProduct => 'Type de crédit';

  @override
  String loanRate(Object rate) {
    return '$rate % par an';
  }

  @override
  String loanAmountRange(Object max, Object min) {
    return 'De $min à $max';
  }

  @override
  String loanTermRange(Object max, Object min) {
    return '$min à $max mois';
  }

  @override
  String get loanRequirements => 'Conditions';

  @override
  String get loanAmount => 'Montant (FBu)';

  @override
  String get loanTerm => 'Durée (mois)';

  @override
  String loanAmountError(Object max, Object min) {
    return 'Saisissez un montant entre $min et $max';
  }

  @override
  String loanTermError(Object max, Object min) {
    return 'Saisissez une durée entre $min et $max mois';
  }

  @override
  String get loanSimulate => 'Calculer';

  @override
  String get loanMonthly => 'Mensualité';

  @override
  String get loanTotal => 'Total à rembourser';

  @override
  String get loanInterest => 'Total des intérêts';

  @override
  String get loanErrLoad => 'Impossible de charger les crédits.';

  @override
  String get loanErrGeneric =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get loanRetry => 'Réessayer';

  @override
  String get loanFictional =>
      'Produits de démonstration : taux et conditions fictifs.';

  @override
  String get complaintCategory => 'Catégorie';

  @override
  String get complaintUrgency => 'Urgence';

  @override
  String get complaintDescription => 'Décrivez le problème';

  @override
  String get complaintDescriptionError =>
      'Décrivez le problème (au moins 3 caractères)';

  @override
  String get complaintPhone => 'Téléphone (facultatif)';

  @override
  String get complaintPhoneError => 'Format : +257XXXXXXXX';

  @override
  String get complaintAddPhoto => 'Ajouter une photo';

  @override
  String get complaintRemovePhoto => 'Retirer la photo';

  @override
  String get complaintSubmit => 'Envoyer la réclamation';

  @override
  String get complaintCreatedTitle => 'Réclamation enregistrée';

  @override
  String get complaintTicketNumber => 'Numéro de ticket';

  @override
  String get complaintNew => 'Nouvelle réclamation';

  @override
  String get complaintErrUpload => 'La photo n\'a pas pu être envoyée.';

  @override
  String get complaintErrGeneric =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get complaintCatFees => 'Frais';

  @override
  String get complaintCatCard => 'Carte';

  @override
  String get complaintCatLoan => 'Crédit';

  @override
  String get complaintCatAccount => 'Compte';

  @override
  String get complaintCatServiceQuality => 'Qualité de service';

  @override
  String get complaintCatMobileBanking => 'Banque mobile';

  @override
  String get complaintCatAtm => 'Distributeur (GAB)';

  @override
  String get complaintCatOther => 'Autre';

  @override
  String get complaintUrgencyLow => 'Faible';

  @override
  String get complaintUrgencyMedium => 'Moyenne';

  @override
  String get complaintUrgencyHigh => 'Élevée';

  @override
  String get complaintUrgencyCritical => 'Critique';

  @override
  String get branchSearch => 'Rechercher une agence ou une ville';

  @override
  String get branchProvince => 'Province';

  @override
  String get branchAllProvinces => 'Toutes les provinces';

  @override
  String get branchOpenNow => 'Ouvert';

  @override
  String get branchClosedNow => 'Fermé';

  @override
  String get branchEmpty => 'Aucune agence trouvée.';

  @override
  String get branchErrLoad => 'Impossible de charger les agences.';

  @override
  String get branchRetry => 'Réessayer';

  @override
  String get branchHours => 'Horaires';

  @override
  String get branchDayClosed => 'Fermé';

  @override
  String get branchDayMon => 'Lundi';

  @override
  String get branchDayTue => 'Mardi';

  @override
  String get branchDayWed => 'Mercredi';

  @override
  String get branchDayThu => 'Jeudi';

  @override
  String get branchDayFri => 'Vendredi';

  @override
  String get branchDaySat => 'Samedi';

  @override
  String get branchDaySun => 'Dimanche';

  @override
  String get branchSvcCash => 'Caisse';

  @override
  String get branchSvcAccounts => 'Comptes';

  @override
  String get branchSvcLoans => 'Crédits';

  @override
  String get branchSvcCards => 'Cartes';

  @override
  String get branchSvcAtm => 'Distributeur';

  @override
  String get branchSvcForex => 'Change';

  @override
  String get branchSvcMobileBanking => 'Banque mobile';

  @override
  String get ussdDialHint => 'Composez *123#';

  @override
  String get ussdSend => 'Envoyer';

  @override
  String get ussdCancel => 'Annuler';

  @override
  String get ussdEnded => 'Session terminée';

  @override
  String get ussdDialAgain => 'Recomposer';

  @override
  String get ussdInputHint => 'Répondez par un numéro';

  @override
  String get ussdErrNetwork => 'Problème de connexion. Veuillez réessayer.';

  @override
  String get ussdRunning => 'Code USSD en cours…';

  @override
  String get ussdInvalidCode => 'Code inconnu. Composez *123#';

  @override
  String get cardChooseCard =>
      'Vous avez plusieurs cartes actives. Choisissez la carte à bloquer, puis saisissez à nouveau votre code PIN.';

  @override
  String get agentPickerLabel => 'Agent';

  @override
  String get agentRetry => 'Réessayer';

  @override
  String get agentLoadError => 'Impossible de charger les données.';

  @override
  String get agentNone => 'aucun';

  @override
  String get queueEmpty => 'Aucun appel en attente';

  @override
  String get queueClaim => 'Prendre l\'appel';

  @override
  String queueClaimedBy(Object agent) {
    return 'Déjà pris par $agent';
  }

  @override
  String queueWaiting(Object duration) {
    return 'En attente depuis $duration';
  }

  @override
  String queueFrustration(Object percent) {
    return 'Frustration $percent %';
  }

  @override
  String get queueLive => 'En direct';

  @override
  String get callDetailSummary => 'Résumé de l\'IA';

  @override
  String get callDetailNoSummary => 'Pas encore de résumé.';

  @override
  String get callDetailTranscript => 'Transcription';

  @override
  String get callDetailTickets => 'Tickets';

  @override
  String get callDetailModelEvents => 'Changements de modèle';

  @override
  String get callDetailSuggestions => 'Réponses suggérées';

  @override
  String get callDetailNoSuggestions =>
      'Les suggestions apparaissent quand le client écrit.';

  @override
  String get callDetailReplyHint => 'Écrire au client';

  @override
  String get callDetailSend => 'Envoyer';

  @override
  String get callDetailEnd => 'Terminer l\'appel';

  @override
  String get callDetailEndNote => 'Note (facultative)';

  @override
  String get callDetailCancel => 'Annuler';

  @override
  String get callDetailClaim => 'Prendre cet appel';

  @override
  String callDetailHandledBy(Object agent) {
    return 'Pris en charge par $agent';
  }

  @override
  String get callDetailEnded => 'Appel terminé';

  @override
  String get callDetailCustomer => 'Client';

  @override
  String get callDetailSpeakerCustomer => 'Client';

  @override
  String get callDetailSpeakerAi => 'IA';

  @override
  String get callDetailSpeakerAgent => 'Conseiller';

  @override
  String get callDetailSpeakerSystem => 'Système';

  @override
  String get callDetailInsert => 'Insérer';

  @override
  String get statsAiRate => 'Taux de résolution par l\'IA';

  @override
  String get statsAvgWait => 'Attente moyenne';

  @override
  String get statsQueue => 'En file';

  @override
  String get statsActive => 'Appels actifs';

  @override
  String get statsOpenTickets => 'Tickets ouverts';

  @override
  String get statsTotalCalls => 'Appels aujourd\'hui';

  @override
  String statsResolvedSplit(Object agent, Object ai) {
    return 'IA $ai · conseillers $agent';
  }

  @override
  String get statsTopIntents => 'Demandes principales';

  @override
  String get statsByChannel => 'Par canal';

  @override
  String get statsByLang => 'Par langue';

  @override
  String statsUpdatedAt(Object time) {
    return 'Mis à jour à $time';
  }

  @override
  String get ticketsAll => 'Tous';

  @override
  String get ticketsStatus => 'Statut';

  @override
  String get ticketsUrgency => 'Urgence';

  @override
  String get ticketsCategory => 'Catégorie';

  @override
  String get ticketsEmpty => 'Aucun ticket';

  @override
  String get ticketsAssignToMe => 'M\'attribuer';

  @override
  String ticketsAssignedTo(Object agent) {
    return 'Attribué à $agent';
  }

  @override
  String get ticketsUnassigned => 'Non attribué';

  @override
  String ticketsTotal(Object count) {
    return '$count tickets';
  }

  @override
  String get agentIntentProductInfo => 'Info produit';

  @override
  String get agentIntentAccountOpening => 'Ouverture de compte';

  @override
  String get agentIntentCardBlock => 'Blocage de carte';

  @override
  String get agentIntentLoanInfo => 'Crédits';

  @override
  String get agentIntentComplaint => 'Réclamation';

  @override
  String get agentIntentBranchInfo => 'Agences et horaires';

  @override
  String get agentIntentHandoff => 'Demande un conseiller';

  @override
  String get agentIntentOther => 'Autre';

  @override
  String get agentReasonCustomerRequest => 'Demande du client';

  @override
  String get agentReasonFrustration => 'Frustration';

  @override
  String get agentReasonLowConfidence => 'Confiance faible';

  @override
  String get agentReasonNoAnswer => 'Pas de réponse dans la base';

  @override
  String get agentReasonIdentityFailed => 'Échec de vérification d\'identité';

  @override
  String get agentReasonAgentReview => 'Document à vérifier';

  @override
  String get agentReasonOther => 'Autre';

  @override
  String get agentCallActive => 'Avec l\'IA';

  @override
  String get agentCallQueued => 'En attente';

  @override
  String get agentCallWithAgent => 'Avec un conseiller';

  @override
  String get agentCallEnded => 'Terminé';

  @override
  String get agentTicketOpen => 'Ouvert';

  @override
  String get agentTicketInProgress => 'En cours';

  @override
  String get agentTicketResolved => 'Résolu';

  @override
  String get agentTicketClosed => 'Fermé';

  @override
  String get agentCategoryFees => 'Frais';

  @override
  String get agentCategoryCard => 'Carte';

  @override
  String get agentCategoryLoan => 'Crédit';

  @override
  String get agentCategoryAccount => 'Compte';

  @override
  String get agentCategoryServiceQuality => 'Qualité de service';

  @override
  String get agentCategoryMobileBanking => 'Banque mobile';

  @override
  String get agentCategoryAtm => 'Guichet automatique';

  @override
  String get agentCategoryOther => 'Autre';

  @override
  String get agentUrgencyLow => 'Faible';

  @override
  String get agentUrgencyMedium => 'Moyenne';

  @override
  String get agentUrgencyHigh => 'Haute';

  @override
  String get agentUrgencyCritical => 'Critique';

  @override
  String get agentChannelPhone => 'Téléphone';

  @override
  String get agentChannelWeb => 'Chat web';

  @override
  String get agentChannelUssd => 'USSD';

  @override
  String get agentChannelSms => 'SMS';

  @override
  String get agentChannelWhatsapp => 'WhatsApp';

  @override
  String get callStatusIdle => 'Appuyez sur appeler pour parler à Kabangutsi';

  @override
  String get callStatusConnecting => 'Connexion…';

  @override
  String get callStatusReady => 'Touchez le micro et parlez';

  @override
  String get callStatusListening => 'Je vous écoute…';

  @override
  String get callStatusThinking => 'Je réfléchis…';

  @override
  String get callStatusSpeaking => 'Kabangutsi parle';

  @override
  String get callStatusHandedOff => 'En attente d\'un conseiller';

  @override
  String get callStatusEnded => 'Appel terminé';

  @override
  String get callStatusError => 'L\'appel n\'a pas pu être établi';

  @override
  String callAgentJoined(String name) {
    return '$name a rejoint l\'appel';
  }

  @override
  String get callTapToTalk => 'Touchez pour parler';

  @override
  String get callTapToSend => 'Touchez pour envoyer';

  @override
  String get callCancelRecording => 'Annuler';

  @override
  String get callNewCall => 'Nouvel appel';

  @override
  String get callRetry => 'Réessayer';

  @override
  String get callMicDenied => 'L\'accès au micro est nécessaire pour l\'appel';

  @override
  String get callTurnFailed => 'Votre message n\'a pas été envoyé. Réessayez.';

  @override
  String get callTranscriptEmpty => 'La conversation s\'affichera ici';

  @override
  String get callSpeakerYou => 'Vous';

  @override
  String get callSpeakerAgent => 'Conseiller';

  @override
  String get callSpeakerSystem => 'Info';

  @override
  String get chatStarting => 'Connexion…';

  @override
  String get chatStartFailed => 'Impossible de démarrer la conversation.';

  @override
  String get chatRetry => 'Réessayer';

  @override
  String get chatNewConversation => 'Nouvelle conversation';

  @override
  String get chatSessionEnded => 'Cette conversation est terminée.';

  @override
  String get chatWaitingAgent => 'En attente d\'un conseiller…';

  @override
  String get chatWithAgent => 'Vous parlez avec un conseiller';

  @override
  String chatAgentJoined(String name) {
    return '$name a rejoint la conversation';
  }

  @override
  String get chatAgentLabel => 'Conseiller';

  @override
  String get chatAssistantLabel => 'Kabangutsi';

  @override
  String get chatPinHint => 'Saisissez votre code PIN à 4 chiffres (masqué)';

  @override
  String get chatDobHint => 'Date de naissance AAAA-MM-JJ (masquée)';

  @override
  String get chatErrorGeneric => 'Une erreur est survenue. Veuillez réessayer.';

  @override
  String get chatErrorNetwork => 'Le serveur est injoignable.';

  @override
  String chatModelInUse(String model) {
    return 'Modèle : $model';
  }

  @override
  String get chatModelDefault => 'Modèle par défaut';

  @override
  String get chatLinkCopied => 'Lien copié';

  @override
  String get chatImageTooLarge => 'L\'image est trop lourde (10 Mo max).';

  @override
  String get chatHandoffConfirm => 'Parler à un conseiller ?';

  @override
  String get chatCancel => 'Annuler';

  @override
  String get chatConfirm => 'Oui';

  @override
  String get modelPickerRefresh => 'Actualiser';

  @override
  String get modelDefaultBadge => 'Par défaut';

  @override
  String get modelCapCompletion => 'Texte';

  @override
  String get modelCapVision => 'Images';

  @override
  String get modelCapAudio => 'Audio';

  @override
  String get modelCapTools => 'Outils';

  @override
  String get modelCapThinking => 'Raisonnement';

  @override
  String get modelCapEmbedding => 'Recherche';

  @override
  String get modelNotSelectable => 'Non disponible pour la discussion';

  @override
  String get modelLoadFailed => 'Impossible de charger les modèles.';

  @override
  String get modelNone => 'Aucun modèle installé.';

  @override
  String chatWorking(String model, String seconds) {
    return '$model réfléchit… $seconds s';
  }

  @override
  String chatAnsweredBy(String model, String seconds) {
    return '$model · $seconds s';
  }

  @override
  String get chatNoModel => 'sans modèle (règles)';

  @override
  String get chatCallNumber => 'Appeler';

  @override
  String get chatCopyNumber => 'Copier le numéro';

  @override
  String get chatNumberCopied => 'Numéro copié';

  @override
  String get chatCannotCall =>
      'Cet appareil ne peut pas appeler : le numéro a été copié.';

  @override
  String get appTitleCustomer => 'Kabangutsi';

  @override
  String get appTitleAgent => 'Kabangutsi Agent';

  @override
  String get welcome => 'Bonjour ! Comment puis-je vous aider aujourd\'hui ?';

  @override
  String get language => 'Langue';

  @override
  String get languageFr => 'Français';

  @override
  String get languageEn => 'English';

  @override
  String get languageRn => 'Ikirundi';

  @override
  String get comingSoon => 'Bientôt disponible';

  @override
  String get navChat => 'Discussion';

  @override
  String get navCall => 'Appel';

  @override
  String get navUssd => 'USSD';

  @override
  String get navServices => 'Services';

  @override
  String get chatInputHint => 'Écrivez votre message';

  @override
  String get send => 'Envoyer';

  @override
  String get attachImage => 'Joindre une image';

  @override
  String get talkToAgent => 'Parler à un conseiller';

  @override
  String get modelPickerTitle => 'Choisir un modèle';

  @override
  String get callTitle => 'Appel vocal';

  @override
  String get callStart => 'Démarrer l\'appel';

  @override
  String get callEnd => 'Raccrocher';

  @override
  String get ussdTitle => 'Simulateur USSD';

  @override
  String get ussdDial => 'Composer';

  @override
  String get servicesTitle => 'Services';

  @override
  String get cardBlockTitle => 'Bloquer une carte';

  @override
  String get loanSimulatorTitle => 'Simulateur de crédit';

  @override
  String get complaintTitle => 'Faire une réclamation';

  @override
  String get branchFinderTitle => 'Agences et horaires';

  @override
  String get agentQueueTitle => 'File d\'appels';

  @override
  String get callDetailTitle => 'Détail de l\'appel';

  @override
  String get ticketsTitle => 'Tickets';

  @override
  String get statsTitle => 'Statistiques';

  @override
  String get docScanTitle => 'Scanner un document';

  @override
  String get docScanIntro =>
      'Prenez en photo un document de la banque : nous lisons les informations pour vous.';

  @override
  String get docScanType => 'Type de document';

  @override
  String get docTypeAuto => 'Détection automatique';

  @override
  String get docTypeCni => 'Carte nationale d\'identité';

  @override
  String get docTypeLoanApplication => 'Demande de crédit';

  @override
  String get docTypeCoffeeReceipt => 'Reçu de livraison de café';

  @override
  String get docTypeComplaintPhoto => 'Photo jointe à une réclamation';

  @override
  String get docScanTakePhoto => 'Prendre une photo';

  @override
  String get docScanChooseFile => 'Choisir un fichier';

  @override
  String get docScanFormats =>
      'Photos uniquement : JPEG, PNG ou WebP, 10 Mo maximum.';

  @override
  String get docScanSend => 'Lire le document';

  @override
  String get docScanReading => 'Lecture du document…';

  @override
  String get docScanResultTitle => 'Informations lues';

  @override
  String docScanDetected(Object type) {
    return 'Type détecté : $type';
  }

  @override
  String get docScanToCheck => 'À vérifier';

  @override
  String get docScanNotRead => '(non lu)';

  @override
  String get docScanNoFields => 'Aucune information n\'a pu être lue.';

  @override
  String docScanTime(Object seconds) {
    return 'Lu en $seconds s';
  }

  @override
  String get docScanAgentReview =>
      'Certaines informations doivent être vérifiées : un conseiller va examiner ce document et vous répondre dans cette discussion.';

  @override
  String get docScanNeedsReview =>
      'Certaines informations n\'ont pas pu être lues avec certitude. Vérifiez-les avant de les utiliser.';

  @override
  String get docScanAnother => 'Scanner un autre document';

  @override
  String get docScanErrPdf =>
      'Seules les photos de documents peuvent être lues pour l\'instant. Prenez la page en photo ou choisissez une image JPEG, PNG ou WebP.';

  @override
  String get docScanErrUnsupported =>
      'Ce type de fichier ne peut pas être lu. Choisissez une photo JPEG, PNG ou WebP.';

  @override
  String get docScanErrTooLarge =>
      'La photo dépasse 10 Mo. Reprenez-la en plus petite taille.';

  @override
  String get docScanErrInvalid =>
      'La photo n\'a pas pu être lue. Réessayez avec une photo nette du document.';

  @override
  String get docScanErrUnavailable =>
      'La lecture de documents n\'est pas disponible pour le moment.';

  @override
  String get docScanErrNetwork => 'Problème de connexion. Veuillez réessayer.';

  @override
  String get docScanErrGeneric =>
      'Une erreur s\'est produite. Veuillez réessayer.';

  @override
  String get docFieldFullName => 'Nom complet';

  @override
  String get docFieldIdNumber => 'Numéro de la carte';

  @override
  String get docFieldDateOfBirth => 'Date de naissance';

  @override
  String get docFieldPlaceOfBirth => 'Lieu de naissance';

  @override
  String get docFieldApplicantName => 'Nom du demandeur';

  @override
  String get docFieldAmount => 'Montant';

  @override
  String get docFieldTermMonths => 'Durée (mois)';

  @override
  String get docFieldProduct => 'Produit';

  @override
  String get docFieldFarmerName => 'Nom du producteur';

  @override
  String get docFieldWeightKg => 'Poids (kg)';

  @override
  String get docFieldDate => 'Date';

  @override
  String get docFieldVisibleText => 'Texte visible';
}
