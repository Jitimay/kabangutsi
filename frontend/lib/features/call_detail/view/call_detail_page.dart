import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/repositories/repositories.dart';
import '../../agent_queue/widgets/agent_labels.dart';
import '../../agent_queue/widgets/agent_scope.dart';
import '../bloc/call_detail_bloc.dart';
import '../widgets/call_side_panel.dart';
import '../widgets/transcript_view.dart';

class CallDetailPage extends StatelessWidget {
  const CallDetailPage({super.key, required this.callId});

  final String callId;

  @override
  Widget build(BuildContext context) {
    return AgentScope(
      builder: (context, agent) => BlocProvider(
        key: ValueKey('${agent.id}/$callId'),
        create: (_) => CallDetailBloc(sl<AgentRepository>(), callId: callId, agentId: agent.id)..add(const CallDetailStarted()),
        child: const CallDetailView(),
      ),
    );
  }
}

class CallDetailView extends StatelessWidget {
  const CallDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MultiBlocListener(
      listeners: [
        BlocListener<CallDetailBloc, CallDetailState>(
          listenWhen: (a, b) => !a.closed && b.closed,
          listener: (context, _) => context.go(AgentRoutes.queue),
        ),
        BlocListener<CallDetailBloc, CallDetailState>(
          listenWhen: (a, b) => a.errorVersion != b.errorVersion && b.error != null && b.status == CallDetailStatus.ready,
          listener: (context, s) => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.error!.message.isEmpty ? l10n.agentLoadError : s.error!.message)),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.go(AgentRoutes.queue)),
          title: BlocBuilder<CallDetailBloc, CallDetailState>(
            buildWhen: (a, b) => a.call != b.call,
            builder: (context, s) {
              final c = s.call;
              if (c == null) return Text(l10n.callDetailTitle);
              return Row(children: [
                Flexible(child: Text([c.customerName, c.phone].whereType<String>().join(' · ').isEmpty
                    ? l10n.callDetailTitle
                    : [c.customerName, c.phone].whereType<String>().join(' · '), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 12),
                Pill(l10n.callStatus(c.status), color: Colors.white),
              ]);
            },
          ),
          actions: const [_CallActions(), AgentPicker(), LanguageMenu()],
        ),
        body: BlocBuilder<CallDetailBloc, CallDetailState>(
          buildWhen: (a, b) => a.status != b.status,
          builder: (context, s) => switch (s.status) {
            CallDetailStatus.loading => const Center(child: CircularProgressIndicator()),
            CallDetailStatus.failure => Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(s.error?.message ?? l10n.agentLoadError),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => context.read<CallDetailBloc>().add(const CallDetailStarted()),
                    child: Text(l10n.agentRetry),
                  ),
                ]),
              ),
            CallDetailStatus.ready => LayoutBuilder(
                builder: (context, box) {
                  const main = Column(children: [
                    SummaryCard(),
                    Expanded(child: TranscriptView()),
                    ReplyBox(),
                  ]);
                  if (box.maxWidth < 900) {
                    return const Column(children: [
                      Expanded(flex: 3, child: main),
                      Divider(height: 1),
                      Expanded(flex: 2, child: CallSidePanel()),
                    ]);
                  }
                  return const Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(flex: 3, child: main),
                    VerticalDivider(width: 1),
                    SizedBox(width: 380, child: CallSidePanel()),
                  ]);
                },
              ),
          },
        ),
      ),
    );
  }
}

class _CallActions extends StatelessWidget {
  const _CallActions();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocBuilder<CallDetailBloc, CallDetailState>(
      buildWhen: (a, b) => a.call != b.call || a.busy != b.busy,
      builder: (context, s) {
        final bloc = context.read<CallDetailBloc>();
        final c = s.call;
        if (c == null) return const SizedBox.shrink();
        final onPrimary = Theme.of(context).colorScheme.onPrimary;
        if (c.status == 'queued') {
          return TextButton.icon(
            key: const Key('detail_claim'),
            style: TextButton.styleFrom(foregroundColor: onPrimary),
            onPressed: s.busy ? null : () => bloc.add(const CallDetailClaimRequested()),
            icon: const Icon(Icons.headset_mic),
            label: Text(l10n.callDetailClaim),
          );
        }
        if (bloc.isMine) {
          return TextButton.icon(
            key: const Key('detail_end'),
            style: TextButton.styleFrom(foregroundColor: onPrimary),
            onPressed: s.busy ? null : () => _confirmEnd(context, bloc),
            icon: const Icon(Icons.call_end),
            label: Text(l10n.callDetailEnd),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _confirmEnd(BuildContext context, CallDetailBloc bloc) async {
    final l10n = context.l10n;
    final note = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.callDetailEnd),
        content: SizedBox(
          width: 420,
          child: TextField(controller: note, maxLines: 3, maxLength: 2000, decoration: InputDecoration(labelText: l10n.callDetailEndNote)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.callDetailCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.callDetailEnd)),
        ],
      ),
    );
    if (ok ?? false) bloc.add(CallDetailEndRequested(note: note.text.trim().isEmpty ? null : note.text.trim()));
    note.dispose();
  }
}
