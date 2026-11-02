import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/language_menu.dart';

/// Hub for the action screens (Wave 2).
class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (Icons.credit_card_off_outlined, l10n.cardBlockTitle, CustomerRoutes.cardBlock),
      (Icons.calculate_outlined, l10n.loanSimulatorTitle, CustomerRoutes.loanSimulator),
      (Icons.report_problem_outlined, l10n.complaintTitle, CustomerRoutes.complaint),
      (Icons.location_on_outlined, l10n.branchFinderTitle, CustomerRoutes.branchFinder),
      (Icons.document_scanner_outlined, l10n.docScanTitle, CustomerRoutes.scanDocument),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.servicesTitle),
        actions: const [LanguageMenu()],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final (icon, title, path) = items[i];
          return Card(
            child: ListTile(
              leading: Icon(icon),
              title: Text(title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(path),
            ),
          );
        },
      ),
    );
  }
}
