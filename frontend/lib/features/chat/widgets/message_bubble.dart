import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/chat_message.dart';

/// One chat bubble. Customer on the right, assistant / agent on the left,
/// notices (model switch, agent joined) centred.
class MessageBubble extends StatelessWidget {
  const MessageBubble({super.key, required this.message});

  final ChatMessage message;

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
              if (message.modelUsed != null && !message.streaming)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(message.modelUsed!,
                      style: theme.textTheme.labelSmall?.copyWith(color: fg.withValues(alpha: 0.6), fontSize: 10)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
