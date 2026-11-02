import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/chat_message.dart';

/// One chat bubble. Customer on the right, assistant / agent on the left,
/// notices (model switch, agent joined) centred.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message, this.fallbackModel});

  final ChatMessage message;

  /// Model shown while waiting when the session uses the backend default (picker's default model).
  final String? fallbackModel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (message.author == ChatAuthor.notice || message.author == ChatAuthor.agentJoined) {
      final text = message.author == ChatAuthor.agentJoined ? l10n.chatAgentJoined(message.text) : message.text;
      return Padding(
        key: Key('notice_${message.id}'),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(message.author == ChatAuthor.notice ? Icons.swap_horiz : Icons.support_agent,
                size: 16, color: scheme.tertiary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.tertiary, fontStyle: FontStyle.italic)),
            ),
          ],
        ),
      );
    }

    final mine = message.author == ChatAuthor.customer;
    final (Color bg, Color fg) = switch (message.author) {
      ChatAuthor.customer => (scheme.primary, scheme.onPrimary),
      ChatAuthor.agent => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      ChatAuthor.system => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
      _ => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    final label = switch (message.author) {
      ChatAuthor.agent => l10n.chatAgentLabel,
      ChatAuthor.ai => l10n.chatAssistantLabel,
      _ => null,
    };

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.8),
        child: Container(
          key: Key('bubble_${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(mine ? 16 : 4),
              bottomRight: Radius.circular(mine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (label != null)
                Text(label, style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.7))),
              if (message.image != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(message.image!, height: 160, fit: BoxFit.cover),
                  ),
                ),
              if (message.streaming && message.startedAt != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: WorkingLine(
                    key: Key('working_${message.id}'),
                    model: message.workingModel ?? fallbackModel ?? l10n.chatAssistantLabel,
                    since: message.startedAt!,
                    color: fg.withValues(alpha: 0.75),
                  ),
                ),
              if (message.text.isNotEmpty || message.streaming)
                message.text.isEmpty
                    ? SizedBox(
                        width: 24,
                        height: 16,
                        child: LinearProgressIndicator(color: fg, backgroundColor: bg),
                      )
                    : SelectableText(
                        message.text + (message.streaming ? ' ▍' : ''),
                        style: theme.textTheme.bodyMedium?.copyWith(color: fg),
                      ),
              if (message.references.isNotEmpty || message.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final r in message.references)
                        Chip(
                          key: Key('ref_$r'),
                          avatar: const Icon(Icons.confirmation_number_outlined, size: 16),
                          label: SelectableText(r),
                          visualDensity: VisualDensity.compact,
                        ),
                      for (final a in message.attachments)
                        ActionChip(
                          avatar: Icon(a.type == 'pdf' ? Icons.picture_as_pdf_outlined : Icons.attach_file, size: 16),
                          label: Text(a.name ?? a.type.toUpperCase()),
                          visualDensity: VisualDensity.compact,
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final copied = l10n.chatLinkCopied;
                            await Clipboard.setData(ClipboardData(text: sl<FileRepository>().resolve(a.url)));
                            messenger.showSnackBar(SnackBar(content: Text(copied)));
                          },
                        ),
                    ],
                  ),
                ),
              if (!message.streaming && (message.modelUsed != null || message.elapsed != null))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    key: Key('answered_${message.id}'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(message.modelUsed != null ? Icons.memory : Icons.rule, size: 11, color: fg.withValues(alpha: 0.6)),
                      const SizedBox(width: 3),
                      Text(
                        message.elapsed == null
                            ? (message.modelUsed ?? l10n.chatNoModel)
                            : l10n.chatAnsweredBy(message.modelUsed ?? l10n.chatNoModel, formatSeconds(message.elapsed!)),
                        style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "4.2" — one decimal under a minute, whole seconds above.
String formatSeconds(Duration d) {
  final s = d.inMilliseconds / 1000;
  return s < 60 ? s.toStringAsFixed(1) : s.round().toString();
}

/// "gemma:2b is working… 4.2 s", ticking every 100 ms while the reply is pending.
class WorkingLine extends StatefulWidget {
  const WorkingLine({super.key, required this.model, required this.since, required this.color});

  final String model;
  final DateTime since;
  final Color color;

  @override
  State<WorkingLine> createState() => _WorkingLineState();
}

class _WorkingLineState extends State<WorkingLine> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.since);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(color: widget.color);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: widget.color)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            context.l10n.chatWorking(widget.model, formatSeconds(elapsed.isNegative ? Duration.zero : elapsed)),
            style: style,
          ),
        ),
      ],
    );
  }
}
