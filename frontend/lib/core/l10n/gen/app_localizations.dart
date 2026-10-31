import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_rn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
    Locale('rn'),
  ];

  /// No description provided for @cardAccountNumber.
  ///
  /// In en, this message translates to:
  /// **'Account number'**
  String get cardAccountNumber;

  /// No description provided for @cardAccountNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter the 11-digit account number'**
  String get cardAccountNumberError;

  /// No description provided for @cardUsePin.
  ///
  /// In en, this message translates to:
  /// **'PIN'**
  String get cardUsePin;

  /// No description provided for @cardUseDob.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get cardUseDob;

  /// No description provided for @cardPin.
  ///
  /// In en, this message translates to:
  /// **'PIN (4 digits)'**
  String get cardPin;

  /// No description provided for @cardFourDigitsError.
  ///
  /// In en, this message translates to:
  /// **'Enter 4 digits'**
  String get cardFourDigitsError;

  /// No description provided for @cardDobPick.
  ///
  /// In en, this message translates to:
  /// **'Choose your date of birth'**
  String get cardDobPick;

  /// No description provided for @cardDobError.
  ///
  /// In en, this message translates to:
  /// **'Choose your date of birth'**
  String get cardDobError;

  /// No description provided for @cardLast4.
  ///
  /// In en, this message translates to:
  /// **'Last 4 digits of the card (optional)'**
  String get cardLast4;

  /// No description provided for @cardReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get cardReason;

  /// No description provided for @cardVerify.
  ///
  /// In en, this message translates to:
  /// **'Verify my identity'**
  String get cardVerify;

  /// No description provided for @cardSecurityNote.
  ///
  /// In en, this message translates to:
  /// **'Your PIN is checked by the bank\'s system only. It is never shown, stored or sent to the AI.'**
  String get cardSecurityNote;

  /// No description provided for @cardConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm the block'**
  String get cardConfirmTitle;

  /// No description provided for @cardConfirm.
  ///
  /// In en, this message translates to:
  /// **'Block the card'**
  String get cardConfirm;

  /// No description provided for @cardCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cardCancel;

  /// No description provided for @cardBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Card blocked'**
  String get cardBlockedTitle;

  /// No description provided for @cardReference.
  ///
  /// In en, this message translates to:
  /// **'Your reference'**
  String get cardReference;

  /// No description provided for @cardBlockAnother.
  ///
  /// In en, this message translates to:
  /// **'Block another card'**
  String get cardBlockAnother;

  /// No description provided for @cardEnding.
  ///
  /// In en, this message translates to:
  /// **'Card ending in {last4}'**
  String cardEnding(Object last4);

  /// No description provided for @cardErrIdentity.
  ///
  /// In en, this message translates to:
  /// **'The details do not match. Attempts left: {attempts}'**
  String cardErrIdentity(Object attempts);

  /// No description provided for @cardErrLocked.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Your call has been passed to an agent.'**
  String get cardErrLocked;

  /// No description provided for @cardErrExpired.
  ///
  /// In en, this message translates to:
  /// **'The confirmation has expired. Please start again.'**
  String get cardErrExpired;

  /// No description provided for @cardErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'No active card found for this account.'**
  String get cardErrNotFound;

  /// No description provided for @cardErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Please try again.'**
  String get cardErrNetwork;

  /// No description provided for @cardErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get cardErrGeneric;

  /// No description provided for @cardReasonLost.
  ///
  /// In en, this message translates to:
  /// **'Lost'**
  String get cardReasonLost;

  /// No description provided for @cardReasonStolen.
  ///
  /// In en, this message translates to:
  /// **'Stolen'**
  String get cardReasonStolen;

  /// No description provided for @cardReasonBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get cardReasonBlocked;

  /// No description provided for @cardReasonDamaged.
  ///
  /// In en, this message translates to:
  /// **'Damaged'**
  String get cardReasonDamaged;

  /// No description provided for @cardReasonSwallowedByAtm.
  ///
  /// In en, this message translates to:
  /// **'Swallowed by an ATM'**
  String get cardReasonSwallowedByAtm;

  /// No description provided for @cardReasonFraudSuspected.
  ///
  /// In en, this message translates to:
  /// **'Fraud suspected'**
  String get cardReasonFraudSuspected;

  /// No description provided for @cardTypeVisaDebit.
  ///
  /// In en, this message translates to:
  /// **'Visa debit'**
  String get cardTypeVisaDebit;

  /// No description provided for @cardTypeLocalDebit.
  ///
  /// In en, this message translates to:
  /// **'Local debit card'**
  String get cardTypeLocalDebit;

  /// No description provided for @cardTypePrepaid.
  ///
  /// In en, this message translates to:
  /// **'Prepaid card'**
  String get cardTypePrepaid;

  /// No description provided for @loanProduct.
  ///
  /// In en, this message translates to:
  /// **'Loan product'**
  String get loanProduct;

  /// No description provided for @loanRate.
  ///
  /// In en, this message translates to:
  /// **'{rate}% per year'**
  String loanRate(Object rate);

  /// No description provided for @loanAmountRange.
  ///
  /// In en, this message translates to:
  /// **'From {min} to {max}'**
  String loanAmountRange(Object max, Object min);

  /// No description provided for @loanTermRange.
  ///
  /// In en, this message translates to:
  /// **'{min} to {max} months'**
  String loanTermRange(Object max, Object min);

  /// No description provided for @loanRequirements.
  ///
  /// In en, this message translates to:
  /// **'Requirements'**
  String get loanRequirements;

  /// No description provided for @loanAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (FBu)'**
  String get loanAmount;

  /// No description provided for @loanTerm.
  ///
  /// In en, this message translates to:
  /// **'Term (months)'**
  String get loanTerm;

  /// No description provided for @loanAmountError.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount between {min} and {max}'**
  String loanAmountError(Object max, Object min);

  /// No description provided for @loanTermError.
  ///
  /// In en, this message translates to:
  /// **'Enter a term between {min} and {max} months'**
  String loanTermError(Object max, Object min);

  /// No description provided for @loanSimulate.
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get loanSimulate;

  /// No description provided for @loanMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly payment'**
  String get loanMonthly;

  /// No description provided for @loanTotal.
  ///
  /// In en, this message translates to:
  /// **'Total to repay'**
  String get loanTotal;

  /// No description provided for @loanInterest.
  ///
  /// In en, this message translates to:
  /// **'Total interest'**
  String get loanInterest;

  /// No description provided for @loanErrLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the loan products.'**
  String get loanErrLoad;

  /// No description provided for @loanErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get loanErrGeneric;

  /// No description provided for @loanRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get loanRetry;

  /// No description provided for @loanFictional.
  ///
  /// In en, this message translates to:
  /// **'Demo products: fictional rates and conditions.'**
  String get loanFictional;

  /// No description provided for @complaintCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get complaintCategory;

  /// No description provided for @complaintUrgency.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get complaintUrgency;

  /// No description provided for @complaintDescription.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem'**
  String get complaintDescription;

  /// No description provided for @complaintDescriptionError.
  ///
  /// In en, this message translates to:
  /// **'Describe the problem (at least 3 characters)'**
  String get complaintDescriptionError;

  /// No description provided for @complaintPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get complaintPhone;

  /// No description provided for @complaintPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Format: +257XXXXXXXX'**
  String get complaintPhoneError;

  /// No description provided for @complaintAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add a photo'**
  String get complaintAddPhoto;

  /// No description provided for @complaintRemovePhoto.
  ///
  /// In en, this message translates to:
  /// **'Remove the photo'**
  String get complaintRemovePhoto;

  /// No description provided for @complaintSubmit.
  ///
  /// In en, this message translates to:
  /// **'Send the complaint'**
  String get complaintSubmit;

  /// No description provided for @complaintCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Complaint registered'**
  String get complaintCreatedTitle;

  /// No description provided for @complaintTicketNumber.
  ///
  /// In en, this message translates to:
  /// **'Ticket number'**
  String get complaintTicketNumber;

  /// No description provided for @complaintNew.
  ///
  /// In en, this message translates to:
  /// **'New complaint'**
  String get complaintNew;

  /// No description provided for @complaintErrUpload.
  ///
  /// In en, this message translates to:
  /// **'The photo could not be sent.'**
  String get complaintErrUpload;

  /// No description provided for @complaintErrGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get complaintErrGeneric;

  /// No description provided for @complaintCatFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get complaintCatFees;

  /// No description provided for @complaintCatCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get complaintCatCard;

  /// No description provided for @complaintCatLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get complaintCatLoan;

  /// No description provided for @complaintCatAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get complaintCatAccount;

  /// No description provided for @complaintCatServiceQuality.
  ///
  /// In en, this message translates to:
  /// **'Service quality'**
  String get complaintCatServiceQuality;

  /// No description provided for @complaintCatMobileBanking.
  ///
  /// In en, this message translates to:
  /// **'Mobile banking'**
  String get complaintCatMobileBanking;

  /// No description provided for @complaintCatAtm.
  ///
  /// In en, this message translates to:
  /// **'ATM'**
  String get complaintCatAtm;

  /// No description provided for @complaintCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get complaintCatOther;

  /// No description provided for @complaintUrgencyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get complaintUrgencyLow;

  /// No description provided for @complaintUrgencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get complaintUrgencyMedium;

  /// No description provided for @complaintUrgencyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get complaintUrgencyHigh;

  /// No description provided for @complaintUrgencyCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get complaintUrgencyCritical;

  /// No description provided for @branchSearch.
  ///
  /// In en, this message translates to:
  /// **'Search a branch or town'**
  String get branchSearch;

  /// No description provided for @branchProvince.
  ///
  /// In en, this message translates to:
  /// **'Province'**
  String get branchProvince;

  /// No description provided for @branchAllProvinces.
  ///
  /// In en, this message translates to:
  /// **'All provinces'**
  String get branchAllProvinces;

  /// No description provided for @branchOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get branchOpenNow;

  /// No description provided for @branchClosedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed now'**
  String get branchClosedNow;

  /// No description provided for @branchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No branch found.'**
  String get branchEmpty;

  /// No description provided for @branchErrLoad.
  ///
  /// In en, this message translates to:
  /// **'Could not load the branches.'**
  String get branchErrLoad;

  /// No description provided for @branchRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get branchRetry;

  /// No description provided for @branchHours.
  ///
  /// In en, this message translates to:
  /// **'Opening hours'**
  String get branchHours;

  /// No description provided for @branchDayClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get branchDayClosed;

  /// No description provided for @branchDayMon.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get branchDayMon;

  /// No description provided for @branchDayTue.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get branchDayTue;

  /// No description provided for @branchDayWed.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get branchDayWed;

  /// No description provided for @branchDayThu.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get branchDayThu;

  /// No description provided for @branchDayFri.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get branchDayFri;

  /// No description provided for @branchDaySat.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get branchDaySat;

  /// No description provided for @branchDaySun.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get branchDaySun;

  /// No description provided for @branchSvcCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get branchSvcCash;

  /// No description provided for @branchSvcAccounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get branchSvcAccounts;

  /// No description provided for @branchSvcLoans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get branchSvcLoans;

  /// No description provided for @branchSvcCards.
  ///
  /// In en, this message translates to:
  /// **'Cards'**
  String get branchSvcCards;

  /// No description provided for @branchSvcAtm.
  ///
  /// In en, this message translates to:
  /// **'ATM'**
  String get branchSvcAtm;

  /// No description provided for @branchSvcForex.
  ///
  /// In en, this message translates to:
  /// **'Foreign exchange'**
  String get branchSvcForex;

  /// No description provided for @branchSvcMobileBanking.
  ///
  /// In en, this message translates to:
  /// **'Mobile banking'**
  String get branchSvcMobileBanking;

  /// No description provided for @ussdDialHint.
  ///
  /// In en, this message translates to:
  /// **'Dial *123#'**
  String get ussdDialHint;

  /// No description provided for @ussdSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get ussdSend;

  /// No description provided for @ussdCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get ussdCancel;

  /// No description provided for @ussdEnded.
  ///
  /// In en, this message translates to:
  /// **'Session ended'**
  String get ussdEnded;

  /// No description provided for @ussdDialAgain.
  ///
  /// In en, this message translates to:
  /// **'Dial again'**
  String get ussdDialAgain;

  /// No description provided for @ussdInputHint.
  ///
  /// In en, this message translates to:
  /// **'Reply with a number'**
  String get ussdInputHint;

  /// No description provided for @ussdErrNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Please try again.'**
  String get ussdErrNetwork;

  /// No description provided for @ussdRunning.
  ///
  /// In en, this message translates to:
  /// **'USSD code running…'**
  String get ussdRunning;

  /// No description provided for @ussdInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Unknown code. Dial *123#'**
  String get ussdInvalidCode;

  /// No description provided for @agentPickerLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get agentPickerLabel;

  /// No description provided for @agentRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get agentRetry;

  /// No description provided for @agentLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load the data.'**
  String get agentLoadError;

  /// No description provided for @agentNone.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get agentNone;

  /// No description provided for @queueEmpty.
  ///
  /// In en, this message translates to:
  /// **'No calls waiting'**
  String get queueEmpty;

  /// No description provided for @queueClaim.
  ///
  /// In en, this message translates to:
  /// **'Take call'**
  String get queueClaim;

  /// No description provided for @queueClaimedBy.
  ///
  /// In en, this message translates to:
  /// **'Already taken by {agent}'**
  String queueClaimedBy(Object agent);

  /// No description provided for @queueWaiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting {duration}'**
  String queueWaiting(Object duration);

  /// No description provided for @queueFrustration.
  ///
  /// In en, this message translates to:
  /// **'Frustration {percent}%'**
  String queueFrustration(Object percent);

  /// No description provided for @queueLive.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get queueLive;

  /// No description provided for @callDetailSummary.
  ///
  /// In en, this message translates to:
  /// **'AI summary'**
  String get callDetailSummary;

  /// No description provided for @callDetailNoSummary.
  ///
  /// In en, this message translates to:
  /// **'No summary yet.'**
  String get callDetailNoSummary;

  /// No description provided for @callDetailTranscript.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get callDetailTranscript;

  /// No description provided for @callDetailTickets.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get callDetailTickets;

  /// No description provided for @callDetailModelEvents.
  ///
  /// In en, this message translates to:
  /// **'Model changes'**
  String get callDetailModelEvents;

  /// No description provided for @callDetailSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggested replies'**
  String get callDetailSuggestions;

  /// No description provided for @callDetailNoSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions appear when the customer writes.'**
  String get callDetailNoSuggestions;

  /// No description provided for @callDetailReplyHint.
  ///
  /// In en, this message translates to:
  /// **'Write to the customer'**
  String get callDetailReplyHint;

  /// No description provided for @callDetailSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get callDetailSend;

  /// No description provided for @callDetailEnd.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get callDetailEnd;

  /// No description provided for @callDetailEndNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get callDetailEndNote;

  /// No description provided for @callDetailCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get callDetailCancel;

  /// No description provided for @callDetailClaim.
  ///
  /// In en, this message translates to:
  /// **'Take this call'**
  String get callDetailClaim;

  /// No description provided for @callDetailHandledBy.
  ///
  /// In en, this message translates to:
  /// **'Handled by {agent}'**
  String callDetailHandledBy(Object agent);

  /// No description provided for @callDetailEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callDetailEnded;

  /// No description provided for @callDetailCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get callDetailCustomer;

  /// No description provided for @callDetailSpeakerCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get callDetailSpeakerCustomer;

  /// No description provided for @callDetailSpeakerAi.
  ///
  /// In en, this message translates to:
  /// **'AI'**
  String get callDetailSpeakerAi;

  /// No description provided for @callDetailSpeakerAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get callDetailSpeakerAgent;

  /// No description provided for @callDetailSpeakerSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get callDetailSpeakerSystem;

  /// No description provided for @callDetailInsert.
  ///
  /// In en, this message translates to:
  /// **'Insert'**
  String get callDetailInsert;

  /// No description provided for @statsAiRate.
  ///
  /// In en, this message translates to:
  /// **'AI resolution rate'**
  String get statsAiRate;

  /// No description provided for @statsAvgWait.
  ///
  /// In en, this message translates to:
  /// **'Average wait'**
  String get statsAvgWait;

  /// No description provided for @statsQueue.
  ///
  /// In en, this message translates to:
  /// **'In queue'**
  String get statsQueue;

  /// No description provided for @statsActive.
  ///
  /// In en, this message translates to:
  /// **'Active calls'**
  String get statsActive;

  /// No description provided for @statsOpenTickets.
  ///
  /// In en, this message translates to:
  /// **'Open tickets'**
  String get statsOpenTickets;

  /// No description provided for @statsTotalCalls.
  ///
  /// In en, this message translates to:
  /// **'Calls today'**
  String get statsTotalCalls;

  /// No description provided for @statsResolvedSplit.
  ///
  /// In en, this message translates to:
  /// **'AI {ai} · agents {agent}'**
  String statsResolvedSplit(Object agent, Object ai);

  /// No description provided for @statsTopIntents.
  ///
  /// In en, this message translates to:
  /// **'Top intents'**
  String get statsTopIntents;

  /// No description provided for @statsByChannel.
  ///
  /// In en, this message translates to:
  /// **'By channel'**
  String get statsByChannel;

  /// No description provided for @statsByLang.
  ///
  /// In en, this message translates to:
  /// **'By language'**
  String get statsByLang;

  /// No description provided for @statsUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Updated at {time}'**
  String statsUpdatedAt(Object time);

  /// No description provided for @ticketsAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get ticketsAll;

  /// No description provided for @ticketsStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get ticketsStatus;

  /// No description provided for @ticketsUrgency.
  ///
  /// In en, this message translates to:
  /// **'Urgency'**
  String get ticketsUrgency;

  /// No description provided for @ticketsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get ticketsCategory;

  /// No description provided for @ticketsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tickets'**
  String get ticketsEmpty;

  /// No description provided for @ticketsAssignToMe.
  ///
  /// In en, this message translates to:
  /// **'Assign to me'**
  String get ticketsAssignToMe;

  /// No description provided for @ticketsAssignedTo.
  ///
  /// In en, this message translates to:
  /// **'Assigned to {agent}'**
  String ticketsAssignedTo(Object agent);

  /// No description provided for @ticketsUnassigned.
  ///
  /// In en, this message translates to:
  /// **'Unassigned'**
  String get ticketsUnassigned;

  /// No description provided for @ticketsTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} tickets'**
  String ticketsTotal(Object count);

  /// No description provided for @agentIntentProductInfo.
  ///
  /// In en, this message translates to:
  /// **'Product info'**
  String get agentIntentProductInfo;

  /// No description provided for @agentIntentAccountOpening.
  ///
  /// In en, this message translates to:
  /// **'Account opening'**
  String get agentIntentAccountOpening;

  /// No description provided for @agentIntentCardBlock.
  ///
  /// In en, this message translates to:
  /// **'Card block'**
  String get agentIntentCardBlock;

  /// No description provided for @agentIntentLoanInfo.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get agentIntentLoanInfo;

  /// No description provided for @agentIntentComplaint.
  ///
  /// In en, this message translates to:
  /// **'Complaint'**
  String get agentIntentComplaint;

  /// No description provided for @agentIntentBranchInfo.
  ///
  /// In en, this message translates to:
  /// **'Branches & hours'**
  String get agentIntentBranchInfo;

  /// No description provided for @agentIntentHandoff.
  ///
  /// In en, this message translates to:
  /// **'Asked for an agent'**
  String get agentIntentHandoff;

  /// No description provided for @agentIntentOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get agentIntentOther;

  /// No description provided for @agentReasonCustomerRequest.
  ///
  /// In en, this message translates to:
  /// **'Customer request'**
  String get agentReasonCustomerRequest;

  /// No description provided for @agentReasonFrustration.
  ///
  /// In en, this message translates to:
  /// **'Frustration'**
  String get agentReasonFrustration;

  /// No description provided for @agentReasonLowConfidence.
  ///
  /// In en, this message translates to:
  /// **'Low confidence'**
  String get agentReasonLowConfidence;

  /// No description provided for @agentReasonNoAnswer.
  ///
  /// In en, this message translates to:
  /// **'No answer in knowledge base'**
  String get agentReasonNoAnswer;

  /// No description provided for @agentReasonIdentityFailed.
  ///
  /// In en, this message translates to:
  /// **'Identity check failed'**
  String get agentReasonIdentityFailed;

  /// No description provided for @agentReasonAgentReview.
  ///
  /// In en, this message translates to:
  /// **'Document to review'**
  String get agentReasonAgentReview;

  /// No description provided for @agentReasonOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get agentReasonOther;

  /// No description provided for @agentCallActive.
  ///
  /// In en, this message translates to:
  /// **'With AI'**
  String get agentCallActive;

  /// No description provided for @agentCallQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get agentCallQueued;

  /// No description provided for @agentCallWithAgent.
  ///
  /// In en, this message translates to:
  /// **'With agent'**
  String get agentCallWithAgent;

  /// No description provided for @agentCallEnded.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get agentCallEnded;

  /// No description provided for @agentTicketOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get agentTicketOpen;

  /// No description provided for @agentTicketInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get agentTicketInProgress;

  /// No description provided for @agentTicketResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get agentTicketResolved;

  /// No description provided for @agentTicketClosed.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get agentTicketClosed;

  /// No description provided for @agentCategoryFees.
  ///
  /// In en, this message translates to:
  /// **'Fees'**
  String get agentCategoryFees;

  /// No description provided for @agentCategoryCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get agentCategoryCard;

  /// No description provided for @agentCategoryLoan.
  ///
  /// In en, this message translates to:
  /// **'Loan'**
  String get agentCategoryLoan;

  /// No description provided for @agentCategoryAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get agentCategoryAccount;

  /// No description provided for @agentCategoryServiceQuality.
  ///
  /// In en, this message translates to:
  /// **'Service quality'**
  String get agentCategoryServiceQuality;

  /// No description provided for @agentCategoryMobileBanking.
  ///
  /// In en, this message translates to:
  /// **'Mobile banking'**
  String get agentCategoryMobileBanking;

  /// No description provided for @agentCategoryAtm.
  ///
  /// In en, this message translates to:
  /// **'ATM'**
  String get agentCategoryAtm;

  /// No description provided for @agentCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get agentCategoryOther;

  /// No description provided for @agentUrgencyLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get agentUrgencyLow;

  /// No description provided for @agentUrgencyMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get agentUrgencyMedium;

  /// No description provided for @agentUrgencyHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get agentUrgencyHigh;

  /// No description provided for @agentUrgencyCritical.
  ///
  /// In en, this message translates to:
  /// **'Critical'**
  String get agentUrgencyCritical;

  /// No description provided for @agentChannelPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get agentChannelPhone;

  /// No description provided for @agentChannelWeb.
  ///
  /// In en, this message translates to:
  /// **'Web chat'**
  String get agentChannelWeb;

  /// No description provided for @agentChannelUssd.
  ///
  /// In en, this message translates to:
  /// **'USSD'**
  String get agentChannelUssd;

  /// No description provided for @agentChannelSms.
  ///
  /// In en, this message translates to:
  /// **'SMS'**
  String get agentChannelSms;

  /// No description provided for @agentChannelWhatsapp.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp'**
  String get agentChannelWhatsapp;

  /// No description provided for @callStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Press call to talk to Kabangutsi'**
  String get callStatusIdle;

  /// No description provided for @callStatusConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get callStatusConnecting;

  /// No description provided for @callStatusReady.
  ///
  /// In en, this message translates to:
  /// **'Tap the microphone and speak'**
  String get callStatusReady;

  /// No description provided for @callStatusListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get callStatusListening;

  /// No description provided for @callStatusThinking.
  ///
  /// In en, this message translates to:
  /// **'Thinking…'**
  String get callStatusThinking;

  /// No description provided for @callStatusSpeaking.
  ///
  /// In en, this message translates to:
  /// **'Kabangutsi is speaking'**
  String get callStatusSpeaking;

  /// No description provided for @callStatusHandedOff.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an agent'**
  String get callStatusHandedOff;

  /// No description provided for @callStatusEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended'**
  String get callStatusEnded;

  /// No description provided for @callStatusError.
  ///
  /// In en, this message translates to:
  /// **'The call could not be connected'**
  String get callStatusError;

  /// No description provided for @callAgentJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the call'**
  String callAgentJoined(String name);

  /// No description provided for @callTapToTalk.
  ///
  /// In en, this message translates to:
  /// **'Tap to talk'**
  String get callTapToTalk;

  /// No description provided for @callTapToSend.
  ///
  /// In en, this message translates to:
  /// **'Tap to send'**
  String get callTapToSend;

  /// No description provided for @callCancelRecording.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get callCancelRecording;

  /// No description provided for @callNewCall.
  ///
  /// In en, this message translates to:
  /// **'New call'**
  String get callNewCall;

  /// No description provided for @callRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get callRetry;

  /// No description provided for @callMicDenied.
  ///
  /// In en, this message translates to:
  /// **'Microphone access is needed for the call'**
  String get callMicDenied;

  /// No description provided for @callTurnFailed.
  ///
  /// In en, this message translates to:
  /// **'Your message was not sent. Please try again.'**
  String get callTurnFailed;

  /// No description provided for @callTranscriptEmpty.
  ///
  /// In en, this message translates to:
  /// **'The conversation will appear here'**
  String get callTranscriptEmpty;

  /// No description provided for @callSpeakerYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get callSpeakerYou;

  /// No description provided for @callSpeakerAgent.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get callSpeakerAgent;

  /// No description provided for @callSpeakerSystem.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get callSpeakerSystem;

  /// No description provided for @chatStarting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get chatStarting;

  /// No description provided for @chatStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not start the conversation.'**
  String get chatStartFailed;

  /// No description provided for @chatRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get chatRetry;

  /// No description provided for @chatNewConversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get chatNewConversation;

  /// No description provided for @chatSessionEnded.
  ///
  /// In en, this message translates to:
  /// **'This conversation has ended.'**
  String get chatSessionEnded;

  /// No description provided for @chatWaitingAgent.
  ///
  /// In en, this message translates to:
  /// **'Waiting for an agent…'**
  String get chatWaitingAgent;

  /// No description provided for @chatWithAgent.
  ///
  /// In en, this message translates to:
  /// **'You are talking to an agent'**
  String get chatWithAgent;

  /// No description provided for @chatAgentJoined.
  ///
  /// In en, this message translates to:
  /// **'{name} joined the conversation'**
  String chatAgentJoined(String name);

  /// No description provided for @chatAgentLabel.
  ///
  /// In en, this message translates to:
  /// **'Agent'**
  String get chatAgentLabel;

  /// No description provided for @chatAssistantLabel.
  ///
  /// In en, this message translates to:
  /// **'Kabangutsi'**
  String get chatAssistantLabel;

  /// No description provided for @chatPinHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit PIN (hidden)'**
  String get chatPinHint;

  /// No description provided for @chatDobHint.
  ///
  /// In en, this message translates to:
  /// **'Date of birth YYYY-MM-DD (hidden)'**
  String get chatDobHint;

  /// No description provided for @chatErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get chatErrorGeneric;

  /// No description provided for @chatErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Cannot reach the server.'**
  String get chatErrorNetwork;

  /// No description provided for @chatModelInUse.
  ///
  /// In en, this message translates to:
  /// **'Model: {model}'**
  String chatModelInUse(String model);

  /// No description provided for @chatModelDefault.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get chatModelDefault;

  /// No description provided for @chatLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get chatLinkCopied;

  /// No description provided for @chatImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image is too large (max 10 MB).'**
  String get chatImageTooLarge;

  /// No description provided for @chatHandoffConfirm.
  ///
  /// In en, this message translates to:
  /// **'Talk to a human agent?'**
  String get chatHandoffConfirm;

  /// No description provided for @chatCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get chatCancel;

  /// No description provided for @chatConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get chatConfirm;

  /// No description provided for @modelPickerRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get modelPickerRefresh;

  /// No description provided for @modelDefaultBadge.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get modelDefaultBadge;

  /// No description provided for @modelCapCompletion.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get modelCapCompletion;

  /// No description provided for @modelCapVision.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get modelCapVision;

  /// No description provided for @modelCapAudio.
  ///
  /// In en, this message translates to:
  /// **'Audio'**
  String get modelCapAudio;

  /// No description provided for @modelCapTools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get modelCapTools;

  /// No description provided for @modelCapThinking.
  ///
  /// In en, this message translates to:
  /// **'Reasoning'**
  String get modelCapThinking;

  /// No description provided for @modelCapEmbedding.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get modelCapEmbedding;

  /// No description provided for @modelNotSelectable.
  ///
  /// In en, this message translates to:
  /// **'Not available for chat'**
  String get modelNotSelectable;

  /// No description provided for @modelLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the models.'**
  String get modelLoadFailed;

  /// No description provided for @modelNone.
  ///
  /// In en, this message translates to:
  /// **'No model installed.'**
  String get modelNone;

  /// No description provided for @appTitleCustomer.
  ///
  /// In en, this message translates to:
  /// **'Kabangutsi'**
  String get appTitleCustomer;

  /// No description provided for @appTitleAgent.
  ///
  /// In en, this message translates to:
  /// **'Kabangutsi Agent'**
  String get appTitleAgent;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Hello! How can I help you today?'**
  String get welcome;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageFr.
  ///
  /// In en, this message translates to:
  /// **'Français'**
  String get languageFr;

  /// No description provided for @languageEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEn;

  /// No description provided for @languageRn.
  ///
  /// In en, this message translates to:
  /// **'Ikirundi'**
  String get languageRn;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @navChat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get navChat;

  /// No description provided for @navCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get navCall;

  /// No description provided for @navUssd.
  ///
  /// In en, this message translates to:
  /// **'USSD'**
  String get navUssd;

  /// No description provided for @navServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get navServices;

  /// No description provided for @chatInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type your message'**
  String get chatInputHint;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @attachImage.
  ///
  /// In en, this message translates to:
  /// **'Attach an image'**
  String get attachImage;

  /// No description provided for @talkToAgent.
  ///
  /// In en, this message translates to:
  /// **'Talk to an agent'**
  String get talkToAgent;

  /// No description provided for @modelPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a model'**
  String get modelPickerTitle;

  /// No description provided for @callTitle.
  ///
  /// In en, this message translates to:
  /// **'Voice call'**
  String get callTitle;

  /// No description provided for @callStart.
  ///
  /// In en, this message translates to:
  /// **'Start call'**
  String get callStart;

  /// No description provided for @callEnd.
  ///
  /// In en, this message translates to:
  /// **'End call'**
  String get callEnd;

  /// No description provided for @ussdTitle.
  ///
  /// In en, this message translates to:
  /// **'USSD simulator'**
  String get ussdTitle;

  /// No description provided for @ussdDial.
  ///
  /// In en, this message translates to:
  /// **'Dial'**
  String get ussdDial;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @cardBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block a card'**
  String get cardBlockTitle;

  /// No description provided for @loanSimulatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Loan simulator'**
  String get loanSimulatorTitle;

  /// No description provided for @complaintTitle.
  ///
  /// In en, this message translates to:
  /// **'Make a complaint'**
  String get complaintTitle;

  /// No description provided for @branchFinderTitle.
  ///
  /// In en, this message translates to:
  /// **'Branches and hours'**
  String get branchFinderTitle;

  /// No description provided for @agentQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Call queue'**
  String get agentQueueTitle;

  /// No description provided for @callDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Call details'**
  String get callDetailTitle;

  /// No description provided for @ticketsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tickets'**
  String get ticketsTitle;

  /// No description provided for @statsTitle.
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statsTitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr', 'rn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'rn':
      return AppLocalizationsRn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
