import 'package:flutter/material.dart';

import '../../../core/l10n/l10n.dart';
import '../bloc/call_bloc.dart';

/// Live transcript of the call (customer, Kabangutsi, agent, notices).
class CallTranscript extends StatefulWidget {
  const CallTranscript({super.key, required this.lines});

  final List<CallLine> lines;

  @override
  State<CallTranscript> createState() => _CallTranscriptState();
}

class _CallTranscriptState extends State<CallTranscript> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(CallTranscript old) {
    super.didUpdateWidget(old);
    if (old.lines != widget.lines) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    if (widget.lines.isEmpty) {
      return Center(child: Text(l10n.callTranscriptEmpty, style: theme.textTheme.bodyMedium));
    }
    return ListView.builder(
      key: const Key('call_transcript'),
      controller: _scroll,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: widget.lines.length,
      itemBuilder: (context, i) {
        final line = widget.lines[i];
        if (line.speaker == 'notice') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.swap_horiz, size: 16, color: theme.colorScheme.secondary),
              const SizedBox(width: 6),
              Expanded(child: Text(line.text, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
            ]),
          );
        }
        final mine = line.speaker == 'customer';
        final label = switch (line.speaker) {
          'customer' => l10n.callSpeakerYou,
          'agent' => l10n.callSpeakerAgent,
          'system' => l10n.callSpeakerSystem,
          _ => l10n.appTitleCustomer,
        };
        final bg = mine ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: theme.textTheme.labelSmall),
              const SizedBox(height: 2),
              Text(line.text),
            ]),
          ),
        );
      },
    );
  }
}
