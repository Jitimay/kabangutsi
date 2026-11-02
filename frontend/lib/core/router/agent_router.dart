import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/agent_queue/view/agent_queue_page.dart';
import '../../features/call_detail/view/call_detail_page.dart';
import '../../features/stats/view/stats_page.dart';
import '../../features/tickets/view/tickets_page.dart';
import '../l10n/l10n.dart';
import 'routes.dart';

GoRouter buildAgentRouter() => GoRouter(
      initialLocation: AgentRoutes.queue,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _AgentShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: AgentRoutes.queue,
                builder: (_, _) => const AgentQueuePage(),
                routes: [
                  GoRoute(
                    path: ':callId',
                    builder: (_, state) =>
                        CallDetailPage(callId: state.pathParameters['callId']!),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AgentRoutes.tickets, builder: (_, _) => const TicketsPage()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: AgentRoutes.stats, builder: (_, _) => const StatsPage()),
            ]),
          ],
        ),
      ],
    );

class _AgentShell extends StatelessWidget {
  const _AgentShell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              NavigationRailDestination(
                icon: const Icon(Icons.support_agent),
                label: Text(l10n.agentQueueTitle),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(l10n.ticketsTitle),
              ),
              NavigationRailDestination(
                icon: const Icon(Icons.insights_outlined),
                label: Text(l10n.statsTitle),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: shell),
        ],
      ),
    );
  }
}
