import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/util/format.dart';
import '../../../data/models/models.dart';
import '../../agent_queue/widgets/agent_labels.dart';
import '../bloc/call_detail_bloc.dart';

/// AI summary, shown first so the agent understands the call immediately (F9).
class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return BlocBuilder<CallDetailBloc, CallDetailState>(
      buildWhen: (a, b) => a.call != b.call,
      builder: (context, s) {
        final c = s.call!;
        return Container(
          key: const Key('ai_summary'),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 8),
              Text(l10n.callDetailSummary, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer)),
              const Spacer(),
              Pill(l10n.urgency(c.urgency), color: urgencyColor(c.urgency)),
            ]),
            const SizedBox(height: 8),
            SelectableText(
              c.summary ?? l10n.callDetailNoSummary,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill(l10n.channel(c.channel), icon: channelIcon(c.channel)),
              Pill(c.lang.toUpperCase()),
              Pill(l10n.intent(c.lastIntent), icon: Icons.label_outline),
              if (c.handoffReason != null) Pill(l10n.handoffReason(c.handoffReason), icon: Icons.flag_outlined),
              Pill(l10n.queueFrustration((c.frustration * 100).round()), icon: Icons.sentiment_dissatisfied_outlined),
              if (c.claimedBy != null) Pill(l10n.callDetailHandledBy(c.claimedBy!), icon: Icons.headset_mic_outlined),
            ]),
          ]),
        );
      },
    );
  }
}

class TranscriptView extends StatefulWidget {
  const TranscriptView({super.key});

  @override
  State<TranscriptView> createState() => _TranscriptViewState();
}

class _TranscriptViewState extends State<TranscriptView> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CallDetailBloc, CallDetailState>(
      listenWhen: (a, b) => a.detail?.transcript.length != b.detail?.transcript.length,
      listener: (context, _) => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      }),
      buildWhen: (a, b) => a.detail?.transcript != b.detail?.transcript,
      builder: (context, s) {
        final turns = s.detail!.transcript;
        return ListView.builder(
          controller: _scroll,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: turns.length,
          itemBuilder: (context, i) => TurnBubble(turn: turns[i]),
        );
      },
    );
  }
}

class TurnBubble extends StatelessWidget {
  const TurnBubble({super.key, required this.turn});

  final Turn turn;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isCustomer = turn.speaker == 'customer';
    final (bg, fg) = switch (turn.speaker) {
      'customer' => (scheme.surfaceContainerHighest, scheme.onSurface),
      'ai' => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      'agent' => (scheme.primary, scheme.onPrimary),
      _ => (scheme.surfaceContainerLow, scheme.onSurfaceVariant),
    };
    if (turn.speaker == 'system') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(child: Text(turn.text, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
      );
    }
    final meta = [
      l10n.speaker(turn.speaker),
      bujumburaTime(turn.ts),
      if (turn.intent != null) l10n.intent(turn.intent),
      if (turn.confidence != null) '${(turn.confidence! * 100).round()}%',
      if (turn.modelUsed != null) turn.modelUsed!,
    ].join(' · ');
    return Align(
      alignment: isCustomer ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: isCustomer ? CrossAxisAlignment.start : CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SelectableText(turn.text, style: TextStyle(color: fg)),
                  for (final a in turn.attachments)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(switch (a.type) { 'image' => Icons.image_outlined, 'audio' => Icons.graphic_eq, _ => Icons.picture_as_pdf_outlined }, size: 16, color: fg),
                        const SizedBox(width: 4),
                        Text(a.name ?? a.type, style: TextStyle(color: fg, fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 2),
              Text(meta, style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent reply field (enabled once the call is claimed by this agent).
class ReplyBox extends StatefulWidget {
  const ReplyBox({super.key});

  @override
  State<ReplyBox> createState() => _ReplyBoxState();
}

class _ReplyBoxState extends State<ReplyBox> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = context.read<CallDetailBloc>().state.draft;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<CallDetailBloc>();
    return BlocConsumer<CallDetailBloc, CallDetailState>(
      listenWhen: (a, b) => a.draftVersion != b.draftVersion,
      listener: (context, s) {
        _controller.value = TextEditingValue(text: s.draft, selection: TextSelection.collapsed(offset: s.draft.length));
      },
      buildWhen: (a, b) => a.busy != b.busy || a.call != b.call,
      builder: (context, s) {
        final enabled = bloc.isMine;
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: TextField(
                  key: const Key('agent_reply_field'),
                  controller: _controller,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(hintText: l10n.callDetailReplyHint, counterText: ''),
                  onChanged: (t) => bloc.add(CallDetailDraftChanged(t)),
                  onSubmitted: (_) => bloc.add(const CallDetailSendRequested()),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                key: const Key('agent_send'),
                onPressed: enabled && !s.busy ? () => bloc.add(const CallDetailSendRequested()) : null,
                icon: const Icon(Icons.send),
                label: Text(l10n.callDetailSend),
              ),
            ]),
          ),
        );
      },
    );
  }
}
