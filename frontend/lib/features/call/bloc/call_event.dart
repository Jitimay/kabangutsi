part of 'call_bloc.dart';

sealed class CallEvent extends Equatable {
  const CallEvent();

  @override
  List<Object?> get props => [];
}

/// Dial: creates a `phone` conversation in [lang] and plays the greeting.
class CallStarted extends CallEvent {
  const CallStarted(this.lang);
  final String lang;

  @override
  List<Object?> get props => [lang];
}

/// Push-to-talk toggle: starts recording, or stops and sends the turn.
class CallTalkToggled extends CallEvent {
  const CallTalkToggled();
}

/// Stops recording without sending.
class CallRecordingCancelled extends CallEvent {
  const CallRecordingCancelled();
}

/// "Talk to an agent".
class CallHandoffRequested extends CallEvent {
  const CallHandoffRequested();
}

/// Hang up.
class CallHungUp extends CallEvent {
  const CallHungUp();
}

class _CallLiveEvent extends CallEvent {
  const _CallLiveEvent(this.event);
  final WsEvent event;

  @override
  List<Object?> get props => [event];
}
