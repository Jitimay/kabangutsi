import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/util/format.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../agent_queue/widgets/agent_labels.dart';
import '../../agent_queue/widgets/agent_scope.dart';
import '../bloc/ticket_bloc.dart';

class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AgentScope(
      builder: (context, agent) => BlocProvider(
        key: ValueKey(agent.id),
        create: (_) => TicketBloc(sl<TicketRepository>(), sl<AgentRepository>(), agent.id)..add(const TicketsStarted()),
        child: const TicketsView(),
      ),
    );
  }
}

class TicketsView extends StatelessWidget {
  const TicketsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<TicketBloc, TicketState>(
      listenWhen: (a, b) => a.errorVersion != b.errorVersion && b.status == TicketsStatus.ready,
      listener: (context, s) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.error?.message ?? l10n.agentLoadError))),
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<TicketBloc, TicketState>(
            buildWhen: (a, b) => a.total != b.total,
            builder: (context, s) => Row(children: [
              Text(l10n.ticketsTitle),
              const SizedBox(width: 12),
              Pill(l10n.ticketsTotal(s.total), color: Colors.white),
            ]),
          ),
          actions: [
            IconButton(
              tooltip: l10n.agentRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () {
                final b = context.read<TicketBloc>();
                b.add(TicketsFilterChanged(b.state.filter));
              },
            ),
            const AgentPicker(),
            const LanguageMenu(),
          ],
        ),
        body: Column(children: [
          const _Filters(),
          const Divider(height: 1),
          Expanded(
            child: BlocBuilder<TicketBloc, TicketState>(
              builder: (context, s) {
                if (s.status == TicketsStatus.loading && s.items.isEmpty) return const Center(child: CircularProgressIndicator());
                if (s.status == TicketsStatus.failure) {
                  return Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(l10n.agentLoadError),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.read<TicketBloc>().add(TicketsFilterChanged(s.filter)),
                        child: Text(l10n.agentRetry),
                      ),
                    ]),
                  );
                }
                if (s.items.isEmpty) return Center(child: Text(l10n.ticketsEmpty));
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => TicketCard(ticket: s.items[i], updating: s.updatingId == s.items[i].id),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<TicketBloc, TicketState>(
      buildWhen: (a, b) => a.filter != b.filter,
      builder: (context, s) {
        final bloc = context.read<TicketBloc>();
        final f = s.filter;
        Widget drop(String label, String? value, List<String> values, String Function(String) text, TicketFilter Function(String?) apply) =>
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<String?>(
                initialValue: value,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, isDense: true),
                items: [
                  DropdownMenuItem<String?>(value: null, child: Text(l10n.ticketsAll)),
                  for (final v in values) DropdownMenuItem<String?>(value: v, child: Text(text(v), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => bloc.add(TicketsFilterChanged(apply(v))),
              ),
            );
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            drop(l10n.ticketsStatus, f.status, kTicketStatuses, l10n.ticketStatus, (v) => f.copyWith(status: () => v)),
            drop(l10n.ticketsUrgency, f.urgency, kUrgencies, l10n.urgency, (v) => f.copyWith(urgency: () => v)),
            drop(l10n.ticketsCategory, f.category, kTicketCategories, l10n.ticketCategory, (v) => f.copyWith(category: () => v)),
          ]),
        );
      },
    );
  }
}

class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, this.updating = false});

  final Ticket ticket;
  final bool updating;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final bloc = context.read<TicketBloc>();
    final t = ticket;
    final mine = t.assignedTo == bloc.agentId;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(t.number, style: theme.textTheme.titleMedium),
                Pill(l10n.urgency(t.urgency), color: urgencyColor(t.urgency)),
                Pill(l10n.ticketCategory(t.category), icon: Icons.label_outline),
                Pill(t.lang.toUpperCase()),
              ]),
              const SizedBox(height: 6),
              Text(t.summary),
              const SizedBox(height: 6),
              Text(
                [
                  if (t.customerName != null) t.customerName!,
                  if (t.phone != null) formatPhone(t.phone!),
                  '${bujumburaTime(t.createdAt)} (${t.createdAt.toIso8601String().substring(0, 10)})',
                  t.assignedTo == null ? l10n.ticketsUnassigned : l10n.ticketsAssignedTo(t.assignedTo!),
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            SizedBox(
              width: 180,
              child: DropdownButtonFormField<String>(
                key: Key('ticket_status_${t.id}_${t.status}'),
                initialValue: t.status,
                isDense: true,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.ticketsStatus, isDense: true),
                items: [for (final st in kTicketStatuses) DropdownMenuItem(value: st, child: Text(l10n.ticketStatus(st), overflow: TextOverflow.ellipsis))],
                onChanged: updating ? null : (v) {
                  if (v != null && v != t.status) bloc.add(TicketStatusChanged(t.id, v));
                },
              ),
            ),
            const SizedBox(height: 8),
            if (updating)
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            else if (!mine)
              TextButton.icon(
                onPressed: () => bloc.add(TicketAssignedToMe(t.id)),
                icon: const Icon(Icons.person_add_alt),
                label: Text(l10n.ticketsAssignToMe),
              ),
          ]),
        ]),
      ),
    );
  }
}
