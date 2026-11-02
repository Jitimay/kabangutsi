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
import '../bloc/stats_cubit.dart';

class StatsPage extends StatelessWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AgentScope(
      builder: (context, agent) => BlocProvider(
        key: ValueKey(agent.id),
        create: (_) => StatsCubit(sl<AgentRepository>(), agent.id)..load(),
        child: const StatsView(),
      ),
    );
  }
}

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.statsTitle),
        actions: [
          IconButton(tooltip: l10n.agentRetry, icon: const Icon(Icons.refresh), onPressed: () => context.read<StatsCubit>().load()),
          const AgentPicker(),
          const LanguageMenu(),
        ],
      ),
      body: BlocBuilder<StatsCubit, StatsState>(
        builder: (context, s) {
          final st = s.stats;
          if (st == null && s.loading) return const Center(child: CircularProgressIndicator());
          if (st == null) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(l10n.agentLoadError),
                const SizedBox(height: 8),
                FilledButton(onPressed: () => context.read<StatsCubit>().load(), child: Text(l10n.agentRetry)),
              ]),
            );
          }
          return _StatsBody(stats: st);
        },
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});
  final Stats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final s = stats;
    final langLabel = {'fr': l10n.languageFr, 'en': l10n.languageEn, 'rn': l10n.languageRn};
    return ListView(padding: const EdgeInsets.all(16), children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        StatTile(
          key: const Key('stat_ai_rate'),
          icon: Icons.smart_toy_outlined,
          label: l10n.statsAiRate,
          value: '${(s.aiResolutionRate * 100).toStringAsFixed(1)} %',
          caption: l10n.statsResolvedSplit(s.resolvedByAi, s.resolvedByAgent),
          highlight: true,
        ),
        StatTile(icon: Icons.timer_outlined, label: l10n.statsAvgWait, value: formatDuration(s.avgWaitSeconds.round())),
        StatTile(icon: Icons.support_agent, label: l10n.statsQueue, value: '${s.queueLength}'),
        StatTile(icon: Icons.call, label: l10n.statsActive, value: '${s.activeCalls}'),
        StatTile(icon: Icons.confirmation_number_outlined, label: l10n.statsOpenTickets, value: '${s.openTickets}'),
        StatTile(icon: Icons.phone_in_talk_outlined, label: l10n.statsTotalCalls, value: '${s.totalCalls}'),
      ]),
      const SizedBox(height: 24),
      LayoutBuilder(builder: (context, box) {
        final cards = [
          BarCard(title: l10n.statsTopIntents, rows: [for (final i in s.topIntents) (l10n.intent(i.intent), i.count)]),
          BarCard(title: l10n.statsByChannel, rows: [for (final e in s.byChannel.entries) (l10n.channel(e.key), e.value)]),
          BarCard(title: l10n.statsByLang, rows: [for (final e in s.byLang.entries) (langLabel[e.key] ?? e.key, e.value)]),
        ];
        if (box.maxWidth < 900) {
          return Column(children: [for (final c in cards) Padding(padding: const EdgeInsets.only(bottom: 12), child: c)]);
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (final (i, c) in cards.indexed) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: c)],
        ]);
      }),
      const SizedBox(height: 12),
      Text(l10n.statsUpdatedAt(bujumburaTime(s.updatedAt)), style: theme.textTheme.bodySmall),
    ]);
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icon, required this.label, required this.value, this.caption, this.highlight = false});

  final IconData icon;
  final String label;
  final String value;
  final String? caption;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = highlight ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface;
    return SizedBox(
      width: 220,
      child: Card(
        color: highlight ? theme.colorScheme.primary : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Expanded(child: Text(label, style: theme.textTheme.labelLarge?.copyWith(color: fg))),
            ]),
            const SizedBox(height: 8),
            Text(value, style: theme.textTheme.headlineMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
            if (caption != null) Text(caption!, style: theme.textTheme.bodySmall?.copyWith(color: fg)),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal bars drawn with containers (no chart package, works offline).
class BarCard extends StatelessWidget {
  const BarCard({super.key, required this.title, required this.rows});

  final String title;
  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = rows.fold<int>(0, (m, r) => r.$2 > m ? r.$2 : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final (label, count) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                SizedBox(width: 130, child: Text(label, overflow: TextOverflow.ellipsis)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) => Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        height: 14,
                        width: max == 0 ? 0 : box.maxWidth * count / max,
                        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 40, child: Text('$count', textAlign: TextAlign.end)),
              ]),
            ),
        ]),
      ),
    );
  }
}
