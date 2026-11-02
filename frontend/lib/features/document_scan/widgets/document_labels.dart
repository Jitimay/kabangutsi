import '../../../core/l10n/l10n.dart';
import '../../../core/util/format.dart';
import '../bloc/document_scan_cubit.dart';

String docTypeLabel(AppLocalizations l10n, String id) => switch (id) {
      'auto' => l10n.docTypeAuto,
      'cni' => l10n.docTypeCni,
      'loan_application' => l10n.docTypeLoanApplication,
      'coffee_receipt' => l10n.docTypeCoffeeReceipt,
      'complaint_photo' => l10n.docTypeComplaintPhoto,
      _ => id,
    };

String docFieldLabel(AppLocalizations l10n, String name) => switch (name) {
      'full_name' => l10n.docFieldFullName,
      'id_number' => l10n.docFieldIdNumber,
      'date_of_birth' => l10n.docFieldDateOfBirth,
      'place_of_birth' => l10n.docFieldPlaceOfBirth,
      'applicant_name' => l10n.docFieldApplicantName,
      'amount' => l10n.docFieldAmount,
      'term_months' => l10n.docFieldTermMonths,
      'product' => l10n.docFieldProduct,
      'farmer_name' => l10n.docFieldFarmerName,
      'weight_kg' => l10n.docFieldWeightKg,
      'date' => l10n.docFieldDate,
      'visible_text' => l10n.docFieldVisibleText,
      // Unknown registry field: show its name readably.
      _ => name.replaceAll('_', ' '),
    };

/// Field value for display: FBu amounts grouped, null = not read.
String docFieldValue(AppLocalizations l10n, String name, Object? value) => switch (value) {
      null => l10n.docScanNotRead,
      final int v when name == 'amount' => formatFbu(v),
      final String v when v.isEmpty => l10n.docScanNotRead,
      _ => '$value',
    };

String docScanErrorText(AppLocalizations l10n, DocScanError e) => switch (e) {
      DocScanError.pdf => l10n.docScanErrPdf,
      DocScanError.unsupported => l10n.docScanErrUnsupported,
      DocScanError.tooLarge => l10n.docScanErrTooLarge,
      DocScanError.invalid => l10n.docScanErrInvalid,
      DocScanError.unavailable => l10n.docScanErrUnavailable,
      DocScanError.network => l10n.docScanErrNetwork,
      DocScanError.generic => l10n.docScanErrGeneric,
    };

/// "1.4" from 1400 ms.
String docSeconds(int ms) => (ms / 1000).toStringAsFixed(1);
