// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cardAccountNumber => 'Account number';

  @override
  String get cardAccountNumberError => 'Enter the 11-digit account number';

  @override
  String get cardUsePin => 'PIN';

  @override
  String get cardUseDob => 'Date of birth';

  @override
  String get cardPin => 'PIN (4 digits)';

  @override
  String get cardFourDigitsError => 'Enter 4 digits';

  @override
  String get cardDobPick => 'Choose your date of birth';

  @override
  String get cardDobError => 'Choose your date of birth';

  @override
  String get cardLast4 => 'Last 4 digits of the card (optional)';

  @override
  String get cardReason => 'Reason';

  @override
  String get cardVerify => 'Verify my identity';

  @override
  String get cardSecurityNote =>
      'Your PIN is checked by the bank\'s system only. It is never shown, stored or sent to the AI.';

  @override
  String get cardConfirmTitle => 'Confirm the block';

  @override
  String get cardConfirm => 'Block the card';

  @override
  String get cardCancel => 'Cancel';

  @override
  String get cardBlockedTitle => 'Card blocked';

  @override
  String get cardReference => 'Your reference';

  @override
  String get cardBlockAnother => 'Block another card';

  @override
  String cardEnding(Object last4) {
    return 'Card ending in $last4';
  }

  @override
  String cardErrIdentity(Object attempts) {
    return 'The details do not match. Attempts left: $attempts';
  }

  @override
  String get cardErrLocked =>
      'Too many failed attempts. Your call has been passed to an agent.';

  @override
  String get cardErrExpired =>
      'The confirmation has expired. Please start again.';

  @override
  String get cardErrNotFound => 'No active card found for this account.';

  @override
  String get cardErrNetwork => 'Connection problem. Please try again.';

  @override
  String get cardErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get cardReasonLost => 'Lost';

  @override
  String get cardReasonStolen => 'Stolen';

  @override
  String get cardReasonBlocked => 'Blocked';

  @override
  String get cardReasonDamaged => 'Damaged';

  @override
  String get cardReasonSwallowedByAtm => 'Swallowed by an ATM';

  @override
  String get cardReasonFraudSuspected => 'Fraud suspected';

  @override
  String get cardTypeVisaDebit => 'Visa debit';

  @override
  String get cardTypeLocalDebit => 'Local debit card';

  @override
  String get cardTypePrepaid => 'Prepaid card';

  @override
  String get loanProduct => 'Loan product';

  @override
  String loanRate(Object rate) {
    return '$rate% per year';
  }

  @override
  String loanAmountRange(Object max, Object min) {
    return 'From $min to $max';
  }

  @override
  String loanTermRange(Object max, Object min) {
    return '$min to $max months';
  }

  @override
  String get loanRequirements => 'Requirements';

  @override
  String get loanAmount => 'Amount (FBu)';

  @override
  String get loanTerm => 'Term (months)';

  @override
  String loanAmountError(Object max, Object min) {
    return 'Enter an amount between $min and $max';
  }

  @override
  String loanTermError(Object max, Object min) {
    return 'Enter a term between $min and $max months';
  }

  @override
  String get loanSimulate => 'Calculate';

  @override
  String get loanMonthly => 'Monthly payment';

  @override
  String get loanTotal => 'Total to repay';

  @override
  String get loanInterest => 'Total interest';

  @override
  String get loanErrLoad => 'Could not load the loan products.';

  @override
  String get loanErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get loanRetry => 'Try again';

  @override
  String get loanFictional => 'Demo products: fictional rates and conditions.';

  @override
  String get complaintCategory => 'Category';

  @override
  String get complaintUrgency => 'Urgency';

  @override
  String get complaintDescription => 'Describe the problem';

  @override
  String get complaintDescriptionError =>
      'Describe the problem (at least 3 characters)';

  @override
  String get complaintPhone => 'Phone (optional)';

  @override
  String get complaintPhoneError => 'Format: +257XXXXXXXX';

  @override
  String get complaintAddPhoto => 'Add a photo';

  @override
  String get complaintRemovePhoto => 'Remove the photo';

  @override
  String get complaintSubmit => 'Send the complaint';

  @override
  String get complaintCreatedTitle => 'Complaint registered';

  @override
  String get complaintTicketNumber => 'Ticket number';

  @override
  String get complaintNew => 'New complaint';

  @override
  String get complaintErrUpload => 'The photo could not be sent.';

  @override
  String get complaintErrGeneric => 'Something went wrong. Please try again.';

  @override
  String get complaintCatFees => 'Fees';

  @override
  String get complaintCatCard => 'Card';

  @override
  String get complaintCatLoan => 'Loan';

  @override
  String get complaintCatAccount => 'Account';

  @override
  String get complaintCatServiceQuality => 'Service quality';

  @override
  String get complaintCatMobileBanking => 'Mobile banking';

  @override
  String get complaintCatAtm => 'ATM';

  @override
  String get complaintCatOther => 'Other';

  @override
  String get complaintUrgencyLow => 'Low';

  @override
  String get complaintUrgencyMedium => 'Medium';

  @override
  String get complaintUrgencyHigh => 'High';

  @override
  String get complaintUrgencyCritical => 'Critical';

  @override
  String get branchSearch => 'Search a branch or town';

  @override
  String get branchProvince => 'Province';

  @override
  String get branchAllProvinces => 'All provinces';

  @override
  String get branchOpenNow => 'Open now';

  @override
  String get branchClosedNow => 'Closed now';

  @override
  String get branchEmpty => 'No branch found.';

  @override
  String get branchErrLoad => 'Could not load the branches.';

  @override
  String get branchRetry => 'Try again';

  @override
  String get branchHours => 'Opening hours';

  @override
  String get branchDayClosed => 'Closed';

  @override
  String get branchDayMon => 'Monday';

  @override
  String get branchDayTue => 'Tuesday';

  @override
  String get branchDayWed => 'Wednesday';

  @override
  String get branchDayThu => 'Thursday';

  @override
  String get branchDayFri => 'Friday';

  @override
  String get branchDaySat => 'Saturday';

  @override
  String get branchDaySun => 'Sunday';

  @override
  String get branchSvcCash => 'Cash';

  @override
  String get branchSvcAccounts => 'Accounts';

  @override
  String get branchSvcLoans => 'Loans';

  @override
  String get branchSvcCards => 'Cards';

  @override
  String get branchSvcAtm => 'ATM';

  @override
  String get branchSvcForex => 'Foreign exchange';

  @override
  String get branchSvcMobileBanking => 'Mobile banking';

  @override
  String get ussdDialHint => 'Dial *123#';

  @override
  String get ussdSend => 'Send';

  @override
  String get ussdCancel => 'Cancel';

  @override
  String get ussdEnded => 'Session ended';

  @override
  String get ussdDialAgain => 'Dial again';

  @override
  String get ussdInputHint => 'Reply with a number';

  @override
  String get ussdErrNetwork => 'Connection problem. Please try again.';

  @override
  String get ussdRunning => 'USSD code running…';

  @override
  String get ussdInvalidCode => 'Unknown code. Dial *123#';

  @override
  String get cardChooseCard =>
      'You have several active cards. Choose the card to block, then enter your PIN again.';

  @override
  String get agentPickerLabel => 'Agent';

  @override
  String get agentRetry => 'Retry';

  @override
  String get agentLoadError => 'Could not load the data.';

  @override
  String get agentNone => 'none';

  @override
  String get queueEmpty => 'No calls waiting';

  @override
  String get queueClaim => 'Take call';

  @override
  String queueClaimedBy(Object agent) {
    return 'Already taken by $agent';
  }

  @override
  String queueWaiting(Object duration) {
    return 'Waiting $duration';
  }

  @override
  String queueFrustration(Object percent) {
    return 'Frustration $percent%';
  }

  @override
  String get queueLive => 'Live';

  @override
  String get callDetailSummary => 'AI summary';

  @override
  String get callDetailNoSummary => 'No summary yet.';

  @override
  String get callDetailTranscript => 'Transcript';

  @override
  String get callDetailTickets => 'Tickets';

  @override
  String get callDetailModelEvents => 'Model changes';

  @override
  String get callDetailSuggestions => 'Suggested replies';

  @override
  String get callDetailNoSuggestions =>
      'Suggestions appear when the customer writes.';

  @override
  String get callDetailReplyHint => 'Write to the customer';

  @override
  String get callDetailSend => 'Send';

  @override
  String get callDetailEnd => 'End call';

  @override
  String get callDetailEndNote => 'Note (optional)';

  @override
  String get callDetailCancel => 'Cancel';

  @override
  String get callDetailClaim => 'Take this call';

  @override
  String callDetailHandledBy(Object agent) {
    return 'Handled by $agent';
  }

  @override
  String get callDetailEnded => 'Call ended';

  @override
  String get callDetailCustomer => 'Customer';

  @override
  String get callDetailSpeakerCustomer => 'Customer';

  @override
  String get callDetailSpeakerAi => 'AI';

  @override
  String get callDetailSpeakerAgent => 'Agent';

  @override
  String get callDetailSpeakerSystem => 'System';

  @override
  String get callDetailInsert => 'Insert';

  @override
  String get statsAiRate => 'AI resolution rate';

  @override
  String get statsAvgWait => 'Average wait';

  @override
  String get statsQueue => 'In queue';

  @override
  String get statsActive => 'Active calls';

  @override
  String get statsOpenTickets => 'Open tickets';

  @override
  String get statsTotalCalls => 'Calls today';

  @override
  String statsResolvedSplit(Object agent, Object ai) {
    return 'AI $ai · agents $agent';
  }

  @override
  String get statsTopIntents => 'Top intents';

  @override
  String get statsByChannel => 'By channel';

  @override
  String get statsByLang => 'By language';

  @override
  String statsUpdatedAt(Object time) {
    return 'Updated at $time';
  }

  @override
  String get ticketsAll => 'All';

  @override
  String get ticketsStatus => 'Status';

  @override
  String get ticketsUrgency => 'Urgency';

  @override
  String get ticketsCategory => 'Category';

  @override
  String get ticketsEmpty => 'No tickets';

  @override
  String get ticketsAssignToMe => 'Assign to me';

  @override
  String ticketsAssignedTo(Object agent) {
    return 'Assigned to $agent';
  }

  @override
  String get ticketsUnassigned => 'Unassigned';

  @override
  String ticketsTotal(Object count) {
    return '$count tickets';
  }

  @override
  String get agentIntentProductInfo => 'Product info';

  @override
  String get agentIntentAccountOpening => 'Account opening';

  @override
  String get agentIntentCardBlock => 'Card block';

  @override
  String get agentIntentLoanInfo => 'Loans';

  @override
  String get agentIntentComplaint => 'Complaint';

  @override
  String get agentIntentBranchInfo => 'Branches & hours';

  @override
  String get agentIntentHandoff => 'Asked for an agent';

  @override
  String get agentIntentOther => 'Other';

  @override
  String get agentReasonCustomerRequest => 'Customer request';

  @override
  String get agentReasonFrustration => 'Frustration';

  @override
  String get agentReasonLowConfidence => 'Low confidence';

  @override
  String get agentReasonNoAnswer => 'No answer in knowledge base';

  @override
  String get agentReasonIdentityFailed => 'Identity check failed';

  @override
  String get agentReasonAgentReview => 'Document to review';

  @override
  String get agentReasonOther => 'Other';

  @override
  String get agentCallActive => 'With AI';

  @override
  String get agentCallQueued => 'Waiting';

  @override
  String get agentCallWithAgent => 'With agent';

  @override
  String get agentCallEnded => 'Ended';

  @override
  String get agentTicketOpen => 'Open';

  @override
  String get agentTicketInProgress => 'In progress';

  @override
  String get agentTicketResolved => 'Resolved';

  @override
  String get agentTicketClosed => 'Closed';

  @override
  String get agentCategoryFees => 'Fees';

  @override
  String get agentCategoryCard => 'Card';

  @override
  String get agentCategoryLoan => 'Loan';

  @override
  String get agentCategoryAccount => 'Account';

  @override
  String get agentCategoryServiceQuality => 'Service quality';

  @override
  String get agentCategoryMobileBanking => 'Mobile banking';

  @override
  String get agentCategoryAtm => 'ATM';

  @override
  String get agentCategoryOther => 'Other';

  @override
  String get agentUrgencyLow => 'Low';

  @override
  String get agentUrgencyMedium => 'Medium';

  @override
  String get agentUrgencyHigh => 'High';

  @override
  String get agentUrgencyCritical => 'Critical';

  @override
  String get agentChannelPhone => 'Phone';

  @override
  String get agentChannelWeb => 'Web chat';

  @override
  String get agentChannelUssd => 'USSD';

  @override
  String get agentChannelSms => 'SMS';

  @override
  String get agentChannelWhatsapp => 'WhatsApp';

  @override
  String get callStatusIdle => 'Press call to talk to Kabangutsi';

  @override
  String get callStatusConnecting => 'Connecting…';

  @override
  String get callStatusReady => 'Tap the microphone and speak';

  @override
  String get callStatusListening => 'Listening…';

  @override
  String get callStatusThinking => 'Thinking…';

  @override
  String get callStatusSpeaking => 'Kabangutsi is speaking';

  @override
  String get callStatusHandedOff => 'Waiting for an agent';

  @override
  String get callStatusEnded => 'Call ended';

  @override
  String get callStatusError => 'The call could not be connected';

  @override
  String callAgentJoined(String name) {
    return '$name joined the call';
  }

  @override
  String get callTapToTalk => 'Tap to talk';

  @override
  String get callTapToSend => 'Tap to send';

  @override
  String get callCancelRecording => 'Cancel';

  @override
  String get callNewCall => 'New call';

  @override
  String get callRetry => 'Try again';

  @override
  String get callMicDenied => 'Microphone access is needed for the call';

  @override
  String get callTurnFailed => 'Your message was not sent. Please try again.';

  @override
  String get callTranscriptEmpty => 'The conversation will appear here';

  @override
  String get callSpeakerYou => 'You';

  @override
  String get callSpeakerAgent => 'Agent';

  @override
  String get callSpeakerSystem => 'Info';

  @override
  String get chatStarting => 'Connecting…';

  @override
  String get chatStartFailed => 'Could not start the conversation.';

  @override
  String get chatRetry => 'Try again';

  @override
  String get chatNewConversation => 'New conversation';

  @override
  String get chatSessionEnded => 'This conversation has ended.';

  @override
  String get chatWaitingAgent => 'Waiting for an agent…';

  @override
  String get chatWithAgent => 'You are talking to an agent';

  @override
  String chatAgentJoined(String name) {
    return '$name joined the conversation';
  }

  @override
  String get chatAgentLabel => 'Agent';

  @override
  String get chatAssistantLabel => 'Kabangutsi';

  @override
  String get chatPinHint => 'Enter your 4-digit PIN (hidden)';

  @override
  String get chatDobHint => 'Date of birth YYYY-MM-DD (hidden)';

  @override
  String get chatErrorGeneric => 'Something went wrong. Please try again.';

  @override
  String get chatErrorNetwork => 'Cannot reach the server.';

  @override
  String chatModelInUse(String model) {
    return 'Model: $model';
  }

  @override
  String get chatModelDefault => 'Default model';

  @override
  String get chatLinkCopied => 'Link copied';

  @override
  String get chatImageTooLarge => 'The image is too large (max 10 MB).';

  @override
  String get chatHandoffConfirm => 'Talk to a human agent?';

  @override
  String get chatCancel => 'Cancel';

  @override
  String get chatConfirm => 'Yes';

  @override
  String get modelPickerRefresh => 'Refresh';

  @override
  String get modelDefaultBadge => 'Default';

  @override
  String get modelCapCompletion => 'Text';

  @override
  String get modelCapVision => 'Images';

  @override
  String get modelCapAudio => 'Audio';

  @override
  String get modelCapTools => 'Tools';

  @override
  String get modelCapThinking => 'Reasoning';

  @override
  String get modelCapEmbedding => 'Search';

  @override
  String get modelNotSelectable => 'Not available for chat';

  @override
  String get modelLoadFailed => 'Could not load the models.';

  @override
  String get modelNone => 'No model installed.';

  @override
  String get appTitleCustomer => 'Kabangutsi';

  @override
  String get appTitleAgent => 'Kabangutsi Agent';

  @override
  String get welcome => 'Hello! How can I help you today?';

  @override
  String get language => 'Language';

  @override
  String get languageFr => 'Français';

  @override
  String get languageEn => 'English';

  @override
  String get languageRn => 'Ikirundi';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get navChat => 'Chat';

  @override
  String get navCall => 'Call';

  @override
  String get navUssd => 'USSD';

  @override
  String get navServices => 'Services';

  @override
  String get chatInputHint => 'Type your message';

  @override
  String get send => 'Send';

  @override
  String get attachImage => 'Attach an image';

  @override
  String get talkToAgent => 'Talk to an agent';

  @override
  String get modelPickerTitle => 'Choose a model';

  @override
  String get callTitle => 'Voice call';

  @override
  String get callStart => 'Start call';

  @override
  String get callEnd => 'End call';

  @override
  String get ussdTitle => 'USSD simulator';

  @override
  String get ussdDial => 'Dial';

  @override
  String get servicesTitle => 'Services';

  @override
  String get cardBlockTitle => 'Block a card';

  @override
  String get loanSimulatorTitle => 'Loan simulator';

  @override
  String get complaintTitle => 'Make a complaint';

  @override
  String get branchFinderTitle => 'Branches and hours';

  @override
  String get agentQueueTitle => 'Call queue';

  @override
  String get callDetailTitle => 'Call details';

  @override
  String get ticketsTitle => 'Tickets';

  @override
  String get statsTitle => 'Statistics';
}
