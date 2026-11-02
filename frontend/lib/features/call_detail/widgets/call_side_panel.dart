import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/util/format.dart';
import '../../agent_queue/widgets/agent_labels.dart';
import '../bloc/call_detail_bloc.dart';

/// Suggested replies (F11), tickets and model changes of the call.
class CallSidePanel extends StatelessWidget {
  const CallSidePanel({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<CallDetailBloc, CallDetailState>(
      buildWhen: (a, b) => a.suggestion != b.suggestion || a.detail != b.detail,
      builder: (context, s) {
        final bloc = context.read<CallDetailBloc>();
        final d = s.detail!;
        final items = s.suggestion?.suggestions.take(3).toList() ?? const [];
        return ListView(padding: const EdgeInsets.all(16), children: [
          _Header(icon: Icons.lightbulb_outline, text: l10n.callDetailSuggestions),
          if (items.isEmpty)
            Text(l10n.callDetailNoSuggestions, style: theme.textTheme.bodySmall)
          else
            for (final (i, sug) in items.indexed)
              Card(
                key: Key('suggestion_$i'),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => bloc.add(CallDetailSuggestionPicked(sug.text)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(sug.text),
                      const SizedBox(height: 6),
                      Row(children: [
                        Pill(sug.lang.toUpperCase()),
                        const Spacer(),
                        Icon(Icons.north_west, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(l10n.callDetailInsert, style: TextStyle(color: theme.colorScheme.primary)),
                      ]),
                    ]),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          _Header(icon: Icons.confirmation_number_outlined, text: l10n.callDetailTickets),
          if (d.tickets.isEmpty) Text(l10n.agentNone, style: theme.textTheme.bodySmall),
          for (final t in d.tickets)
            Card(
              child: ListTile(
                dense: true,
                title: Text(t.number),
                subtitle: Text(t.summary, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Pill(l10n.urgency(t.urgency), color: urgencyColor(t.urgency)),
                  const SizedBox(height: 4),
                  Text(l10n.ticketStatus(t.status), style: theme.textTheme.labelSmall),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          _Header(icon: Icons.swap_horiz, text: l10n.callDetailModelEvents),
          if (d.modelEvents.isEmpty) Text(l10n.agentNone, style: theme.textTheme.bodySmall),
          for (final m in d.modelEvents)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.memory),
              title: Text('${m.requestedModel} → ${m.usedModel ?? m.fallbackPath ?? '—'}'),
              subtitle: Text('${bujumburaTime(m.ts)} · ${m.notice}'),
            ),
        ]);
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(text, style: Theme.of(context).textTheme.titleSmall),
        ]),
      );
}
