import '../../../core/l10n/l10n.dart';
import '../bloc/card_block_cubit.dart';

String cardReasonLabel(AppLocalizations l10n, String reason) => switch (reason) {
  'lost' => l10n.cardReasonLost,
  'stolen' => l10n.cardReasonStolen,
  'blocked' => l10n.cardReasonBlocked,
  'damaged' => l10n.cardReasonDamaged,
  'swallowed_by_atm' => l10n.cardReasonSwallowedByAtm,
  'fraud_suspected' => l10n.cardReasonFraudSuspected,
  _ => reason,
};

String cardTypeLabel(AppLocalizations l10n, String type) => switch (type) {
  'visa_debit' => l10n.cardTypeVisaDebit,
  'local_debit' => l10n.cardTypeLocalDebit,
  'prepaid' => l10n.cardTypePrepaid,
  _ => type,
};

String cardFailureText(AppLocalizations l10n, CardBlockFailure f, int? attemptsLeft) => switch (f) {
  CardBlockFailure.identityFailed => l10n.cardErrIdentity('${attemptsLeft ?? '-'}'),
  CardBlockFailure.expired => l10n.cardErrExpired,
  CardBlockFailure.notFound => l10n.cardErrNotFound,
  CardBlockFailure.network => l10n.cardErrNetwork,
  CardBlockFailure.generic => l10n.cardErrGeneric,
};
