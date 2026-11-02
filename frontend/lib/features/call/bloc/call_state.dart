part of 'call_bloc.dart';

/// F1 call phases: idle → (connecting) → ready ⇄ listening → thinking → speaking → ready,
/// and handedOff (waiting for / talking with a human agent), ended, error.
enum CallPhase { idle, connecting, ready, listening, thinking, speaking, handedOff, ended, error }

/// One line of the live transcript.
class CallLine extends Equatable {
  const CallLine(this.speaker, this.text);

  /// customer | ai | agent | system | notice
  final String speaker;
  final String text;

  CallLine append(String more) => CallLine(speaker, text.isEmpty ? more : '$text $more');

  @override
  List<Object?> get props => [speaker, text];
}

/// Error codes shown by the view (translated there).
abstract final class CallErrors {
  static const micDenied = 'mic_denied';
  static const startFailed = 'start_failed';
  static const turnFailed = 'turn_failed';
}

class CallState extends Equatable {
  const CallState({
    this.phase = CallPhase.idle,
    this.conversationId,
    this.lines = const [],
    this.withAgent = false,
    this.agentName,
    this.error,
  });

  final CallPhase phase;
  final String? conversationId;
  final List<CallLine> lines;

  /// True once the call was handed over (queued or claimed by an agent).
  final bool withAgent;
  final String? agentName;

  /// One of [CallErrors] (null = no error to show).
  final String? error;

  bool get inCall => conversationId != null && phase != CallPhase.ended && phase != CallPhase.error;

  bool get canTalk => phase == CallPhase.ready || phase == CallPhase.handedOff;

  /// Phase to come back to after a turn.
  CallPhase get restingPhase => withAgent ? CallPhase.handedOff : CallPhase.ready;

  CallState copyWith({
    CallPhase? phase,
    String? conversationId,
    List<CallLine>? lines,
    bool? withAgent,
    String? Function()? agentName,
    String? Function()? error,
  }) =>
      CallState(
        phase: phase ?? this.phase,
        conversationId: conversationId ?? this.conversationId,
        lines: lines ?? this.lines,
        withAgent: withAgent ?? this.withAgent,
        agentName: agentName != null ? agentName() : this.agentName,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [phase, conversationId, lines, withAgent, agentName, error];
}
