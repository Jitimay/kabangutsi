import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/agent_queue_bloc.dart';
import '../widgets/agent_labels.dart';
import '../widgets/agent_scope.dart';

class AgentQueuePage extends StatelessWidget {
  const AgentQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AgentScope(
      builder: (context, agent) => BlocProvider(
        key: ValueKey(agent.id),
        create: (_) => AgentQueueBloc(sl<AgentRepository>(), agent.id)..add(const AgentQueueStarted()),
        child: const AgentQueueView(),
      ),
    );
  }
}

class AgentQueueView extends StatelessWidget {
  const AgentQueueView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<AgentQueueBloc, AgentQueueState>(
      listenWhen: (a, b) => a.effect != b.effect,
      listener: (context, s) {
        if (s.claimedCallId != null) {
          context.go(AgentRoutes.callDetail(s.claimedCallId!));
        } else if (s.conflictClaimedBy != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.queueClaimedBy(s.conflictClaimedBy!))));
        } else if (s.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.error!.message.isEmpty ? l10n.agentLoadError : s.error!.message)));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Flexible(child: Text(l10n.agentQueueTitle, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 12),
            BlocBuilder<AgentQueueBloc, AgentQueueState>(
              buildWhen: (a, b) => a.calls.length != b.calls.length,
              builder: (context, s) => Pill('${s.calls.length}', color: Colors.white),
            ),
          ]),
          actions: [
            IconButton(
              tooltip: l10n.agentRetry,
              icon: const Icon(Icons.refresh),
              onPressed: () => context.read<AgentQueueBloc>().add(const AgentQueueRefreshed()),
            ),
            const AgentPicker(),
            const LanguageMenu(),
          ],
        ),
        body: BlocBuilder<AgentQueueBloc, AgentQueueState>(
          builder: (context, s) => switch (s.status) {
            QueueStatus.loading => const Center(child: CircularProgressIndicator()),
            QueueStatus.failure when s.calls.isEmpty => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(l10n.agentLoadError),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.read<AgentQueueBloc>().add(const AgentQueueRefreshed()),
                    child: Text(l10n.agentRetry),
                  ),
                ]),
              ),
            _ when s.calls.isEmpty => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.inbox_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 8),
                  Text(l10n.queueEmpty, style: Theme.of(context).textTheme.titleMedium),
                ]),
              ),
            _ => _Ticker(
                builder: (now) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: s.calls.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) => QueueCallCard(call: s.calls[i], now: now, claiming: s.claimingId == s.calls[i].id),
                ),
              ),
          },
        ),
      ),
    );
  }
}

/// Rebuilds every second so waiting times stay live.
class _Ticker extends StatefulWidget {
  const _Ticker({required this.builder});
  final Widget Function(DateTime now) builder;

  @override
  State<_Ticker> createState() => _TickerState();
}

class _TickerState extends State<_Ticker> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(DateTime.now().toUtc());
  }
}

class QueueCallCard extends StatelessWidget {
  const QueueCallCard({super.key, required this.call, required this.now, this.claiming = false});

  final Call call;
  final DateTime now;
  final bool claiming;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final color = urgencyColor(call.urgency);
    final waited = call.queuedAt == null ? (call.waitSeconds ?? 0) : now.difference(call.queuedAt!).inSeconds;
    final claim = FilledButton.icon(
      key: Key('claim_${call.id}'),
      onPressed: claiming ? null : () => context.read<AgentQueueBloc>().add(AgentQueueClaimRequested(call.id)),
      icon: claiming
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.headset_mic),
      label: Text(l10n.queueClaim),
    );
    // Narrow windows: claim button under the details instead of beside them.
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 6, color: color),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Pill(l10n.urgency(call.urgency), color: color),
                  Pill(l10n.channel(call.channel), icon: channelIcon(call.channel)),
                  Pill(call.lang.toUpperCase()),
                  Pill(l10n.handoffReason(call.handoffReason), icon: Icons.flag_outlined, color: theme.colorScheme.tertiary),
                  Pill(l10n.queueFrustration((call.frustration * 100).round()),
                      icon: Icons.sentiment_dissatisfied_outlined, color: call.frustration >= 0.7 ? const Color(0xFFB91C1C) : theme.colorScheme.outline),
                  Text(l10n.queueWaiting(formatDuration(waited)), style: theme.textTheme.bodySmall),
                ]),
                const SizedBox(height: 10),
                Text(
                  [call.customerName, call.phone].whereType<String>().join(' · ').ifEmpty(l10n.callDetailCustomer),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(l10n.intent(call.lastIntent), style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                if (call.summary != null) ...[
                  const SizedBox(height: 6),
                  Text(call.summary!, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium),
                ],
                if (narrow) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerRight, child: claim),
                ],
              ]),
            ),
          ),
          if (!narrow) Padding(padding: const EdgeInsets.all(16), child: Center(child: claim)),
        ]),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
