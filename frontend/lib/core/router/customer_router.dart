import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/branch_finder/view/branch_finder_page.dart';
import '../../features/call/view/call_page.dart';
import '../../features/card_block/view/card_block_page.dart';
import '../../features/chat/view/chat_page.dart';
import '../../features/complaint/view/complaint_page.dart';
import '../../features/document_scan/view/document_scan_page.dart';
import '../../features/loan_simulator/view/loan_simulator_page.dart';
import '../../features/model_picker/view/model_picker_page.dart';
import '../../features/services/view/services_page.dart';
import '../../features/ussd/view/ussd_page.dart';
import '../l10n/l10n.dart';
import 'routes.dart';

GoRouter buildCustomerRouter() => GoRouter(
      initialLocation: CustomerRoutes.chat,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _CustomerShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: CustomerRoutes.chat,
                builder: (_, _) => const ChatPage(),
                routes: [
                  GoRoute(path: 'models', builder: (_, _) => const ModelPickerPage()),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: CustomerRoutes.call, builder: (_, _) => const CallPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: CustomerRoutes.ussd, builder: (_, _) => const UssdPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: CustomerRoutes.services,
                builder: (_, _) => const ServicesPage(),
                routes: [
                  GoRoute(path: 'card-block', builder: (_, _) => const CardBlockPage()),
                  GoRoute(path: 'loan', builder: (_, _) => const LoanSimulatorPage()),
                  GoRoute(path: 'complaint', builder: (_, _) => const ComplaintPage()),
                  GoRoute(path: 'branches', builder: (_, _) => const BranchFinderPage()),
                  GoRoute(path: 'scan', builder: (_, _) => const DocumentScanPage()),
                ],
              ),
            ]),
          ],
        ),
      ],
    );

class _CustomerShell extends StatelessWidget {
  const _CustomerShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline), label: l10n.navChat),
          NavigationDestination(icon: const Icon(Icons.call_outlined), label: l10n.navCall),
          NavigationDestination(icon: const Icon(Icons.dialpad), label: l10n.navUssd),
          NavigationDestination(icon: const Icon(Icons.apps), label: l10n.navServices),
        ],
      ),
    );
  }
}
