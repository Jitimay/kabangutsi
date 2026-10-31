import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/widgets/language_menu.dart';
import '../../../data/repositories/repositories.dart';
import '../bloc/call_bloc.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';
import '../widgets/call_controls.dart';
import '../widgets/call_status_indicator.dart';
import '../widgets/call_transcript.dart';

/// F1 voice call screen (customer app).
class CallPage extends StatelessWidget {
  const CallPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => CallBloc(
          repository: sl<ConversationRepository>(),
          recorder: RecordAudioRecorder(),
          player: JustAudioPlayer(resolve: sl<FileRepository>().resolve),
        ),
        child: const CallView(),
      );
}

class CallView extends StatelessWidget {
  const CallView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.callTitle), actions: const [LanguageMenu()]),
      body: BlocConsumer<CallBloc, CallState>(
        listenWhen: (a, b) => b.error != null && a.error != b.error && b.phase != CallPhase.error,
        listener: (context, state) {
          final msg = state.error == CallErrors.micDenied ? l10n.callMicDenied : l10n.callTurnFailed;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(msg)));
        },
        builder: (context, state) => SafeArea(
          child: Column(children: [
            const SizedBox(height: 16),
            CallStatusIndicator(phase: state.phase),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _status(l10n, state),
                key: const Key('call_status_label'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(child: CallTranscript(lines: state.lines)),
            const Divider(height: 1),
            Padding(padding: const EdgeInsets.all(16), child: CallControls(state: state)),
          ]),
        ),
      ),
    );
  }

  static String _status(AppLocalizations l10n, CallState s) => switch (s.phase) {
        CallPhase.idle => l10n.callStatusIdle,
        CallPhase.connecting => l10n.callStatusConnecting,
        CallPhase.ready => l10n.callStatusReady,
        CallPhase.listening => l10n.callStatusListening,
        CallPhase.thinking => l10n.callStatusThinking,
        CallPhase.speaking => l10n.callStatusSpeaking,
        CallPhase.handedOff => s.agentName != null ? l10n.callAgentJoined(s.agentName!) : l10n.callStatusHandedOff,
        CallPhase.ended => l10n.callStatusEnded,
        CallPhase.error => l10n.callStatusError,
      };
}
