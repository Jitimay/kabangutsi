// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Rundi (`rn`).
class AppLocalizationsRn extends AppLocalizations {
  AppLocalizationsRn([String locale = 'rn']) : super(locale);

  @override
  String get cardAccountNumber => 'Inomero ya konti';

  @override
  String get cardAccountNumberError =>
      'Andika inomero ya konti y\'ibiharuro 11';

  @override
  String get cardUsePin => 'PIN';

  @override
  String get cardUseDob => 'Itariki y\'amavuko';

  @override
  String get cardPin => 'PIN (ibiharuro 4)';

  @override
  String get cardFourDigitsError => 'Andika ibiharuro 4';

  @override
  String get cardDobPick => 'Hitamwo itariki yawe y\'amavuko';

  @override
  String get cardDobError => 'Hitamwo itariki yawe y\'amavuko';

  @override
  String get cardLast4 => 'Ibiharuro 4 vya nyuma vy\'ikarata (si ngombwa)';

  @override
  String get cardReason => 'Imvo';

  @override
  String get cardVerify => 'Suzuma umwirondoro wanje';

  @override
  String get cardSecurityNote =>
      'PIN yawe isuzumwa n\'ubuhinga bwa banki gusa. Ntiyerekanwa, ntibikwa, kandi ntirungikwa ku AI.';

  @override
  String get cardConfirmTitle => 'Emeza ihagarikwa';

  @override
  String get cardConfirm => 'Hagarika ikarata';

  @override
  String get cardCancel => 'Reka';

  @override
  String get cardBlockedTitle => 'Ikarata yahagaritswe';

  @override
  String get cardReference => 'Inomero yawe y\'icemezo';

  @override
  String get cardBlockAnother => 'Hagarika iyindi karata';

  @override
  String cardEnding(Object last4) {
    return 'Ikarata irangizwa na $last4';
  }

  @override
  String cardErrIdentity(Object attempts) {
    return 'Amakuru ntahuye. Ubugerageza busigaye: $attempts';
  }

  @override
  String get cardErrLocked =>
      'Mwagerageje kenshi. Ikibazo canyu cashikirijwe umukozi.';

  @override
  String get cardErrExpired => 'Igihe co kwemeza carenze. Subira utangure.';

  @override
  String get cardErrNotFound => 'Nta karata ikora yabonetse kuri iyi konti.';

  @override
  String get cardErrNetwork => 'Hari ingorane y\'umuhora. Subira ugerageze.';

  @override
  String get cardErrGeneric => 'Hari ikitagenze neza. Subira ugerageze.';

  @override
  String get cardReasonLost => 'Yatakaye';

  @override
  String get cardReasonStolen => 'Yibwe';

  @override
  String get cardReasonBlocked => 'Yahagaze';

  @override
  String get cardReasonDamaged => 'Yononekaye';

  @override
  String get cardReasonSwallowedByAtm => 'Yamizwe na ATM';

  @override
  String get cardReasonFraudSuspected => 'Hakekwa uburyarya';

  @override
  String get cardTypeVisaDebit => 'Visa debit';

  @override
  String get cardTypeLocalDebit => 'Ikarata yo mu gihugu';

  @override
  String get cardTypePrepaid => 'Ikarata yashizwemwo amafaranga imbere';

  @override
  String get loanProduct => 'Ubwoko bw\'inguzanyo';

  @override
  String loanRate(Object rate) {
    return '$rate% ku mwaka';
  }

  @override
  String loanAmountRange(Object max, Object min) {
    return 'Kuva $min gushika $max';
  }

  @override
  String loanTermRange(Object max, Object min) {
    return 'Amezi $min gushika $max';
  }

  @override
  String get loanRequirements => 'Ibisabwa';

  @override
  String get loanAmount => 'Amafaranga (FBu)';

  @override
  String get loanTerm => 'Igihe (amezi)';

  @override
  String loanAmountError(Object max, Object min) {
    return 'Andika amafaranga ari hagati ya $min na $max';
  }

  @override
  String loanTermError(Object max, Object min) {
    return 'Andika igihe kiri hagati y\'amezi $min na $max';
  }

  @override
  String get loanSimulate => 'Harura';

  @override
  String get loanMonthly => 'Ayo kwishyura ku kwezi';

  @override
  String get loanTotal => 'Ayo kwishyura yose hamwe';

  @override
  String get loanInterest => 'Inyungu zose hamwe';

  @override
  String get loanErrLoad => 'Ntivyakunze kuzana ubwoko bw\'inguzanyo.';

  @override
  String get loanErrGeneric => 'Hari ikitagenze neza. Subira ugerageze.';

  @override
  String get loanRetry => 'Subira ugerageze';

  @override
  String get loanFictional =>
      'Ivyo kugerageza: inyungu n\'ibisabwa si ivy\'ukuri.';

  @override
  String get complaintCategory => 'Ubwoko bw\'ikibazo';

  @override
  String get complaintUrgency => 'Ingene byihutirwa';

  @override
  String get complaintDescription => 'Dondora ikibazo';

  @override
  String get complaintDescriptionError => 'Dondora ikibazo (nibura indome 3)';

  @override
  String get complaintPhone => 'Terefone (si ngombwa)';

  @override
  String get complaintPhoneError => 'Uburyo: +257XXXXXXXX';

  @override
  String get complaintAddPhoto => 'Shiramwo ifoto';

  @override
  String get complaintRemovePhoto => 'Kuraho ifoto';

  @override
  String get complaintSubmit => 'Rungika itako';

  @override
  String get complaintCreatedTitle => 'Itako ryanditswe';

  @override
  String get complaintTicketNumber => 'Inomero y\'itike';

  @override
  String get complaintNew => 'Itako rishasha';

  @override
  String get complaintErrUpload => 'Ifoto ntiyashoboye kurungikwa.';

  @override
  String get complaintErrGeneric => 'Hari ikitagenze neza. Subira ugerageze.';

  @override
  String get complaintCatFees => 'Amafaranga y\'ivyishyurwa';

  @override
  String get complaintCatCard => 'Ikarata';

  @override
  String get complaintCatLoan => 'Inguzanyo';

  @override
  String get complaintCatAccount => 'Konti';

  @override
  String get complaintCatServiceQuality => 'Ubwiza bw\'imfashanyo';

  @override
  String get complaintCatMobileBanking => 'Banki kuri terefone';

  @override
  String get complaintCatAtm => 'ATM';

  @override
  String get complaintCatOther => 'Ibindi';

  @override
  String get complaintUrgencyLow => 'Bike';

  @override
  String get complaintUrgencyMedium => 'Hagati';

  @override
  String get complaintUrgencyHigh => 'Vyinshi';

  @override
  String get complaintUrgencyCritical => 'Vyihutirwa cane';

  @override
  String get branchSearch => 'Rondera ishami canke igisagara';

  @override
  String get branchProvince => 'Intara';

  @override
  String get branchAllProvinces => 'Intara zose';

  @override
  String get branchOpenNow => 'Ryuguruye ubu';

  @override
  String get branchClosedNow => 'Ryugaye ubu';

  @override
  String get branchEmpty => 'Nta shami ryabonetse.';

  @override
  String get branchErrLoad => 'Ntivyakunze kuzana amashami.';

  @override
  String get branchRetry => 'Subira ugerageze';

  @override
  String get branchHours => 'Amasaha';

  @override
  String get branchDayClosed => 'Hugaye';

  @override
  String get branchDayMon => 'Ku wa mbere';

  @override
  String get branchDayTue => 'Ku wa kabiri';

  @override
  String get branchDayWed => 'Ku wa gatatu';

  @override
  String get branchDayThu => 'Ku wa kane';

  @override
  String get branchDayFri => 'Ku wa gatanu';

  @override
  String get branchDaySat => 'Ku wa gatandatu';

  @override
  String get branchDaySun => 'Ku w\'iyinga';

  @override
  String get branchSvcCash => 'Amafaranga';

  @override
  String get branchSvcAccounts => 'Konti';

  @override
  String get branchSvcLoans => 'Inguzanyo';

  @override
  String get branchSvcCards => 'Amakarata';

  @override
  String get branchSvcAtm => 'ATM';

  @override
  String get branchSvcForex => 'Ivunjisha';

  @override
  String get branchSvcMobileBanking => 'Banki kuri terefone';

  @override
  String get ussdDialHint => 'Kanda *123#';

  @override
  String get ussdSend => 'Rungika';

  @override
  String get ussdCancel => 'Reka';

  @override
  String get ussdEnded => 'Ikiganiro carangiye';

  @override
  String get ussdDialAgain => 'Subira ukande';

  @override
  String get ussdInputHint => 'Ishura n\'inomero';

  @override
  String get ussdErrNetwork => 'Hari ingorane y\'umuhora. Subira ugerageze.';

  @override
  String get ussdRunning => 'Kode ya USSD iriko irakora…';

  @override
  String get ussdInvalidCode => 'Kode ntizwi. Kanda *123#';

  @override
  String get cardChooseCard =>
      'Mufise amakarata menshi akora. Muhitemwo ikarata mushaka guhagarika, maze mwongere mwandike PIN yanyu.';

  @override
  String get agentPickerLabel => 'Umukozi';

  @override
  String get agentRetry => 'Subira ugerageze';

  @override
  String get agentLoadError => 'Ntivyakunze kuzana amakuru.';

  @override
  String get agentNone => 'nta na kimwe';

  @override
  String get queueEmpty => 'Nta muntu arindiriye';

  @override
  String get queueClaim => 'Fata ihamagara';

  @override
  String queueClaimedBy(Object agent) {
    return 'Ryafashwe na $agent';
  }

  @override
  String queueWaiting(Object duration) {
    return 'Amaze $duration arindiriye';
  }

  @override
  String queueFrustration(Object percent) {
    return 'Ishavu $percent%';
  }

  @override
  String get queueLive => 'Ubu nyene';

  @override
  String get callDetailSummary => 'Incamake ya AI';

  @override
  String get callDetailNoSummary => 'Nta ncamake iraboneka.';

  @override
  String get callDetailTranscript => 'Ivyavuzwe';

  @override
  String get callDetailTickets => 'Amatike';

  @override
  String get callDetailModelEvents => 'Ihindurwa rya modeli';

  @override
  String get callDetailSuggestions => 'Inyishu zisabwa';

  @override
  String get callDetailNoSuggestions =>
      'Inyishu zisabwa ziraboneka igihe umukiriya yanditse.';

  @override
  String get callDetailReplyHint => 'Andikira umukiriya';

  @override
  String get callDetailSend => 'Rungika';

  @override
  String get callDetailEnd => 'Hagarika ihamagara';

  @override
  String get callDetailEndNote => 'Icibutso (si ngombwa)';

  @override
  String get callDetailCancel => 'Reka';

  @override
  String get callDetailClaim => 'Fata iri hamagara';

  @override
  String callDetailHandledBy(Object agent) {
    return 'Ririko rirakurikiranwa na $agent';
  }

  @override
  String get callDetailEnded => 'Ihamagara ryarangiye';

  @override
  String get callDetailCustomer => 'Umukiriya';

  @override
  String get callDetailSpeakerCustomer => 'Umukiriya';

  @override
  String get callDetailSpeakerAi => 'AI';

  @override
  String get callDetailSpeakerAgent => 'Umukozi';

  @override
  String get callDetailSpeakerSystem => 'Sisitemu';

  @override
  String get callDetailInsert => 'Shiramwo';

  @override
  String get statsAiRate => 'Igipimo c\'ivyatorewe inyishu na AI';

  @override
  String get statsAvgWait => 'Ikiringo co kurindira hagati';

  @override
  String get statsQueue => 'Abarindiriye';

  @override
  String get statsActive => 'Amahamagara ariko arakorwa';

  @override
  String get statsOpenTickets => 'Amatike yuguruye';

  @override
  String get statsTotalCalls => 'Amahamagara y\'uyu musi';

  @override
  String statsResolvedSplit(Object agent, Object ai) {
    return 'AI $ai · abakozi $agent';
  }

  @override
  String get statsTopIntents => 'Ivyasabwe cane';

  @override
  String get statsByChannel => 'Ukurikije umuyoboro';

  @override
  String get statsByLang => 'Ukurikije ururimi';

  @override
  String statsUpdatedAt(Object time) {
    return 'Vyavuguruwe saa $time';
  }

  @override
  String get ticketsAll => 'Vyose';

  @override
  String get ticketsStatus => 'Uko bimeze';

  @override
  String get ticketsUrgency => 'Ihutirwa';

  @override
  String get ticketsCategory => 'Ubwoko';

  @override
  String get ticketsEmpty => 'Nta tike';

  @override
  String get ticketsAssignToMe => 'Ndabishinzwe';

  @override
  String ticketsAssignedTo(Object agent) {
    return 'Ashinzwe: $agent';
  }

  @override
  String get ticketsUnassigned => 'Ntawubishinzwe';

  @override
  String ticketsTotal(Object count) {
    return 'Amatike $count';
  }

  @override
  String get agentIntentProductInfo => 'Amakuru y\'ibicuruzwa';

  @override
  String get agentIntentAccountOpening => 'Gufungura konti';

  @override
  String get agentIntentCardBlock => 'Guhagarika ikarata';

  @override
  String get agentIntentLoanInfo => 'Ingurane';

  @override
  String get agentIntentComplaint => 'Itako';

  @override
  String get agentIntentBranchInfo => 'Amashami n\'amasaha';

  @override
  String get agentIntentHandoff => 'Yasavye umukozi';

  @override
  String get agentIntentOther => 'Ibindi';

  @override
  String get agentReasonCustomerRequest => 'Umukiriya yabisavye';

  @override
  String get agentReasonFrustration => 'Ishavu';

  @override
  String get agentReasonLowConfidence => 'AI ntiyizeye';

  @override
  String get agentReasonNoAnswer => 'Nta nyishu mu bumenyi';

  @override
  String get agentReasonIdentityFailed => 'Kwemeza umwirondoro vyanse';

  @override
  String get agentReasonAgentReview => 'Urupapuro rukwiye gusuzumwa';

  @override
  String get agentReasonOther => 'Ibindi';

  @override
  String get agentCallActive => 'Ari kumwe na AI';

  @override
  String get agentCallQueued => 'Arindiriye';

  @override
  String get agentCallWithAgent => 'Ari kumwe n\'umukozi';

  @override
  String get agentCallEnded => 'Vyarangiye';

  @override
  String get agentTicketOpen => 'Ryuguruye';

  @override
  String get agentTicketInProgress => 'Ririko rirakorwa';

  @override
  String get agentTicketResolved => 'Ryatorewe inyishu';

  @override
  String get agentTicketClosed => 'Ryugaye';

  @override
  String get agentCategoryFees => 'Amafaranga yishurwa';

  @override
  String get agentCategoryCard => 'Ikarata';

  @override
  String get agentCategoryLoan => 'Ingurane';

  @override
  String get agentCategoryAccount => 'Konti';

  @override
  String get agentCategoryServiceQuality => 'Ubwiza bw\'imfashanyo';

  @override
  String get agentCategoryMobileBanking => 'Banki kuri terefone';

  @override
  String get agentCategoryAtm => 'ATM';

  @override
  String get agentCategoryOther => 'Ibindi';

  @override
  String get agentUrgencyLow => 'Bitoyi';

  @override
  String get agentUrgencyMedium => 'Biringaniye';

  @override
  String get agentUrgencyHigh => 'Vyihutirwa';

  @override
  String get agentUrgencyCritical => 'Vyihutirwa cane';

  @override
  String get agentChannelPhone => 'Terefone';

  @override
  String get agentChannelWeb => 'Ikiganiro kuri web';

  @override
  String get agentChannelUssd => 'USSD';

  @override
  String get agentChannelSms => 'SMS';

  @override
  String get agentChannelWhatsapp => 'WhatsApp';

  @override
  String get callStatusIdle => 'Kanda guhamagara kugira uvugane na Kabangutsi';

  @override
  String get callStatusConnecting => 'Turiko turahuza…';

  @override
  String get callStatusReady => 'Kanda kuri mikoro uvuge';

  @override
  String get callStatusListening => 'Ndiko ndabumviriza…';

  @override
  String get callStatusThinking => 'Ndiko ndiyumvira…';

  @override
  String get callStatusSpeaking => 'Kabangutsi ariko aravuga';

  @override
  String get callStatusHandedOff => 'Murindire umukozi';

  @override
  String get callStatusEnded => 'Ihamagara ryarangiye';

  @override
  String get callStatusError => 'Ihamagara ntiryashoboye guhuzwa';

  @override
  String callAgentJoined(String name) {
    return '$name yinjiye mu ihamagara';
  }

  @override
  String get callTapToTalk => 'Kanda uvuge';

  @override
  String get callTapToSend => 'Kanda urungike';

  @override
  String get callCancelRecording => 'Hagarika';

  @override
  String get callNewCall => 'Ihamagara rishasha';

  @override
  String get callRetry => 'Subira ugerageze';

  @override
  String get callMicDenied => 'Mikoro irakenewe kugira ngo muhamagare';

  @override
  String get callTurnFailed =>
      'Ubutumwa bwanyu ntibwarungitswe. Subira ugerageze.';

  @override
  String get callTranscriptEmpty => 'Ikiganiro kizoboneka ngaha';

  @override
  String get callSpeakerYou => 'Mwebwe';

  @override
  String get callSpeakerAgent => 'Umukozi';

  @override
  String get callSpeakerSystem => 'Amakuru';

  @override
  String get chatStarting => 'Turiko turahuza…';

  @override
  String get chatStartFailed => 'Ntivyakunze gutangura ikiganiro.';

  @override
  String get chatRetry => 'Subira ugerageze';

  @override
  String get chatNewConversation => 'Ikiganiro gishasha';

  @override
  String get chatSessionEnded => 'Iki kiganiro carangiye.';

  @override
  String get chatWaitingAgent => 'Turindiriye umukozi…';

  @override
  String get chatWithAgent => 'Muriko muravugana n\'umukozi';

  @override
  String chatAgentJoined(String name) {
    return '$name yinjiye mu kiganiro';
  }

  @override
  String get chatAgentLabel => 'Umukozi';

  @override
  String get chatAssistantLabel => 'Kabangutsi';

  @override
  String get chatPinHint => 'Andika PIN yawe y\'ibiharuro 4 (inyegeje)';

  @override
  String get chatDobHint => 'Itariki y\'amavuko UUUU-AA-II (inyegeje)';

  @override
  String get chatErrorGeneric => 'Hari ikitagenze neza. Subira ugerageze.';

  @override
  String get chatErrorNetwork => 'Ntitushoboye gushika ku mashini nkuru.';

  @override
  String chatModelInUse(String model) {
    return 'Modeli: $model';
  }

  @override
  String get chatModelDefault => 'Modeli isanzwe';

  @override
  String get chatLinkCopied => 'Umurongo wakopowe';

  @override
  String get chatImageTooLarge => 'Ifoto ni nini cane (ntirenze 10 MB).';

  @override
  String get chatHandoffConfirm => 'Murashaka kuvugana n\'umukozi?';

  @override
  String get chatCancel => 'Reka';

  @override
  String get chatConfirm => 'Ego';

  @override
  String get modelPickerRefresh => 'Vugurura';

  @override
  String get modelDefaultBadge => 'Isanzwe';

  @override
  String get modelCapCompletion => 'Inyandiko';

  @override
  String get modelCapVision => 'Amafoto';

  @override
  String get modelCapAudio => 'Ijwi';

  @override
  String get modelCapTools => 'Ibikoresho';

  @override
  String get modelCapThinking => 'Iciyumviro';

  @override
  String get modelCapEmbedding => 'Kurondera';

  @override
  String get modelNotSelectable => 'Ntikoreshwa mu kiganiro';

  @override
  String get modelLoadFailed => 'Ntivyakunze kuzana amamodeli.';

  @override
  String get modelNone => 'Nta modeli yashizwemwo.';

  @override
  String chatWorking(String model, String seconds) {
    return '$model iriko irakora… $seconds s';
  }

  @override
  String chatAnsweredBy(String model, String seconds) {
    return '$model · $seconds s';
  }

  @override
  String get chatNoModel => 'ata modeli (amategeko)';

  @override
  String get chatCallNumber => 'Hamagara';

  @override
  String get chatCopyNumber => 'Kopiya inomero';

  @override
  String get chatNumberCopied => 'Inomero yakopiwe';

  @override
  String get chatCannotCall =>
      'Iki gikoresho ntigishobora guhamagara: inomero yakopiwe.';

  @override
  String get appTitleCustomer => 'Kabangutsi';

  @override
  String get appTitleAgent => 'Kabangutsi Umukozi';

  @override
  String get welcome => 'Bwakeye! Nobafasha iki uyu musi?';

  @override
  String get language => 'Ururimi';

  @override
  String get languageFr => 'Français';

  @override
  String get languageEn => 'English';

  @override
  String get languageRn => 'Ikirundi';

  @override
  String get comingSoon => 'Biraza vuba';

  @override
  String get navChat => 'Ikiganiro';

  @override
  String get navCall => 'Hamagara';

  @override
  String get navUssd => 'USSD';

  @override
  String get navServices => 'Serivisi';

  @override
  String get chatInputHint => 'Andika ubutumwa bwawe';

  @override
  String get send => 'Rungika';

  @override
  String get attachImage => 'Shiramwo ifoto';

  @override
  String get talkToAgent => 'Vugana n\'umukozi';

  @override
  String get modelPickerTitle => 'Hitamwo modeli';

  @override
  String get callTitle => 'Ihamagara ry\'ijwi';

  @override
  String get callStart => 'Tangura ihamagara';

  @override
  String get callEnd => 'Hagarika ihamagara';

  @override
  String get ussdTitle => 'Igerageza rya USSD';

  @override
  String get ussdDial => 'Kanda';

  @override
  String get servicesTitle => 'Serivisi';

  @override
  String get cardBlockTitle => 'Hagarika ikarata';

  @override
  String get loanSimulatorTitle => 'Harura inguzanyo';

  @override
  String get complaintTitle => 'Tanga itako';

  @override
  String get branchFinderTitle => 'Amashami n\'amasaha';

  @override
  String get agentQueueTitle => 'Abarindiriye';

  @override
  String get callDetailTitle => 'Amakuru y\'ihamagara';

  @override
  String get ticketsTitle => 'Amatike';

  @override
  String get statsTitle => 'Ibiharuro';

  @override
  String get docScanTitle => 'Gusikana urupapuro';

  @override
  String get docScanIntro =>
      'Fata ifoto y\'urupapuro rwa banki: turabasomera amakuru ariko.';

  @override
  String get docScanType => 'Ubwoko bw\'urupapuro';

  @override
  String get docTypeAuto => 'Bimenyekane ubwabyo';

  @override
  String get docTypeCni => 'Ikarata y\'ibiranga umuntu';

  @override
  String get docTypeLoanApplication => 'Isaba ry\'ingurane';

  @override
  String get docTypeCoffeeReceipt => 'Icemezo co gutanga ikawa';

  @override
  String get docTypeComplaintPhoto => 'Ifoto y\'ikirego';

  @override
  String get docScanTakePhoto => 'Fata ifoto';

  @override
  String get docScanChooseFile => 'Hitamwo idosiye';

  @override
  String get docScanFormats =>
      'Amafoto gusa: JPEG, PNG canke WebP, ntarenze 10 MB.';

  @override
  String get docScanSend => 'Soma urupapuro';

  @override
  String get docScanReading => 'Turiko turasoma urupapuro…';

  @override
  String get docScanResultTitle => 'Amakuru yasomwe';

  @override
  String docScanDetected(Object type) {
    return 'Ubwoko bwabonetse: $type';
  }

  @override
  String get docScanToCheck => 'Bikwiye gusuzumwa';

  @override
  String get docScanNotRead => '(ntivyasomwe)';

  @override
  String get docScanNoFields => 'Nta makuru yashoboye gusomwa.';

  @override
  String docScanTime(Object seconds) {
    return 'Vyasomwe mu masegonda $seconds';
  }

  @override
  String get docScanAgentReview =>
      'Amakuru amwe akwiye gusuzumwa: umukozi araraba uru rupapuro maze abishure muri iki kiganiro.';

  @override
  String get docScanNeedsReview =>
      'Amakuru amwe ntiyasomwe neza. Muyasuzume imbere yo kuyakoresha.';

  @override
  String get docScanAnother => 'Sikana urundi rupapuro';

  @override
  String get docScanErrPdf =>
      'Ubu dushobora gusoma amafoto y\'impapuro gusa. Fata ifoto y\'urupapuro canke muhitemwo ishusho ya JPEG, PNG canke WebP.';

  @override
  String get docScanErrUnsupported =>
      'Ubu bwoko bw\'idosiye ntibushobora gusomwa. Muhitemwo ifoto ya JPEG, PNG canke WebP.';

  @override
  String get docScanErrTooLarge =>
      'Ifoto irenze 10 MB. Muyisubiremwo ari ntoyi.';

  @override
  String get docScanErrInvalid =>
      'Ifoto ntiyashoboye gusomwa. Musubire mugerageze n\'ifoto ibona neza.';

  @override
  String get docScanErrUnavailable =>
      'Gusoma impapuro ntibishoboka muri iki gihe.';

  @override
  String get docScanErrNetwork => 'Hari ingorane y\'umuhora. Subira ugerageze.';

  @override
  String get docScanErrGeneric => 'Hari ikitagenze neza. Subira ugerageze.';

  @override
  String get docFieldFullName => 'Izina ryose';

  @override
  String get docFieldIdNumber => 'Inomero y\'ikarata';

  @override
  String get docFieldDateOfBirth => 'Itariki y\'amavuka';

  @override
  String get docFieldPlaceOfBirth => 'Aho yavukiye';

  @override
  String get docFieldApplicantName => 'Izina ry\'usaba';

  @override
  String get docFieldAmount => 'Amafaranga';

  @override
  String get docFieldTermMonths => 'Igihe (amezi)';

  @override
  String get docFieldProduct => 'Igicuruzwa';

  @override
  String get docFieldFarmerName => 'Izina ry\'umurimyi';

  @override
  String get docFieldWeightKg => 'Uburemere (kg)';

  @override
  String get docFieldDate => 'Itariki';

  @override
  String get docFieldVisibleText => 'Inyandiko ibonetse';
}
