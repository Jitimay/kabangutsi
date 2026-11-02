import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/l10n/l10n.dart';
import '../../../core/locale/language_cubit.dart';
import '../bloc/call_bloc.dart';

/// Start / push-to-talk / handoff / hang-up buttons.
class CallControls extends StatelessWidget {
  const CallControls({super.key, required this.state});

  final CallState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<CallBloc>();
    final scheme = Theme.of(context).colorScheme;

    if (!state.inCall && state.phase != CallPhase.connecting) {
      final label = switch (state.phase) {
        CallPhase.ended => l10n.callNewCall,
        CallPhase.error => l10n.callRetry,
        _ => l10n.callStart,
      };
      return FilledButton.icon(
        key: const Key('call_start'),
        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700, minimumSize: const Size(200, 56)),
        onPressed: () => bloc.add(CallStarted(context.read<LanguageCubit>().state.languageCode)),
        icon: const Icon(Icons.call),
        label: Text(label),
      );
    }

    final listening = state.phase == CallPhase.listening;
    final canTalk = state.canTalk || listening;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (listening)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.outlined(
              key: const Key('call_cancel_recording'),
              tooltip: l10n.callCancelRecording,
              onPressed: () => bloc.add(const CallRecordingCancelled()),
              icon: const Icon(Icons.close),
            ),
          ),
        SizedBox(
          width: 88,
          height: 88,
          child: FilledButton(
            key: const Key('call_talk'),
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: listening ? scheme.error : scheme.primary,
            ),
            onPressed: canTalk ? () => bloc.add(const CallTalkToggled()) : null,
            child: Icon(listening ? Icons.send : Icons.mic, size: 40),
          ),
        ),
      ]),
      const SizedBox(height: 6),
      Text(listening ? l10n.callTapToSend : l10n.callTapToTalk, style: Theme.of(context).textTheme.labelMedium),
      const SizedBox(height: 16),
      Wrap(spacing: 12, runSpacing: 8, alignment: WrapAlignment.center, children: [
        if (!state.withAgent)
          OutlinedButton.icon(
            key: const Key('call_handoff'),
            onPressed: state.canTalk ? () => bloc.add(const CallHandoffRequested()) : null,
            icon: const Icon(Icons.support_agent),
            label: Text(l10n.talkToAgent),
          ),
        FilledButton.icon(
          key: const Key('call_hangup'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => bloc.add(const CallHungUp()),
          icon: const Icon(Icons.call_end),
          label: Text(l10n.callEnd),
        ),
      ]),
    ]);
  }
}
