import '../../../core/l10n/l10n.dart';

String complaintCategoryLabel(AppLocalizations l10n, String c) => switch (c) {
  'fees' => l10n.complaintCatFees,
  'card' => l10n.complaintCatCard,
  'loan' => l10n.complaintCatLoan,
  'account' => l10n.complaintCatAccount,
  'service_quality' => l10n.complaintCatServiceQuality,
  'mobile_banking' => l10n.complaintCatMobileBanking,
  'atm' => l10n.complaintCatAtm,
  _ => l10n.complaintCatOther,
};

String complaintUrgencyLabel(AppLocalizations l10n, String u) => switch (u) {
  'low' => l10n.complaintUrgencyLow,
  'high' => l10n.complaintUrgencyHigh,
  'critical' => l10n.complaintUrgencyCritical,
  _ => l10n.complaintUrgencyMedium,
};
