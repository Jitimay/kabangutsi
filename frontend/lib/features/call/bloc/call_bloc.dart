import 'dart:async';
import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../services/audio_player_service.dart';
import '../services/audio_recorder_service.dart';

part 'call_event.dart';
part 'call_state.dart';

/// Demo caller number (fictional, persona 1 of scripts/seed).
const kDemoCallerPhone = '+25779000101';

/// Time to show a sentence that has no TTS audio: ~40 ms per character, max 4 s.
Duration defaultReadDelay(String text) => Duration(milliseconds: min(text.length * 40, 4000));

/// F1 voice call: record → send audio (voice=true) → play the reply sentence by sentence.
class CallBloc extends Bloc<CallEvent, CallState> {
  CallBloc({
    required ConversationRepository repository,
    required this.recorder,
    required this.player,
    this.readDelay = defaultReadDelay,
    this.phone = kDemoCallerPhone,
  })  : _repo = repository,
        super(const CallState()) {
    on<CallStarted>(_onStarted);
    on<CallTalkToggled>(_onTalkToggled);
    on<CallRecordingCancelled>(_onCancelled);
    on<CallHandoffRequested>(_onHandoff);
    on<CallHungUp>(_onHungUp);
    on<_CallLiveEvent>(_onLive);
  }

  final ConversationRepository _repo;
  final AudioRecorderService recorder;
  final AudioPlayerService player;
  final Duration Function(String text) readDelay;
  final String phone;

  StreamSubscription<WsEvent>? _live;

  /// Incremented on hang-up so a reply still streaming is dropped.
  int _epoch = 0;

  bool _stale(int epoch) => epoch != _epoch || isClosed;

  Future<void> _onStarted(CallStarted event, Emitter<CallState> emit) async {
    if (state.inCall || state.phase == CallPhase.connecting) return;
    final epoch = ++_epoch;
    await _live?.cancel();
    _live = null;
    emit(const CallState(phase: CallPhase.connecting));
    try {
      final conv = await _repo.create(channel: 'phone', phone: phone, lang: event.lang);
      if (_stale(epoch)) return;
      emit(state.copyWith(conversationId: conv.id, phase: CallPhase.ready));
      final greeting = conv.greeting;
      if (greeting != null) {
        emit(state.copyWith(phase: CallPhase.speaking, lines: [...state.lines, CallLine('ai', greeting.text)]));
        final audio = _firstAudio(greeting.attachments);
        await _say(greeting.text, audio);
        if (_stale(epoch)) return;
        emit(state.copyWith(phase: state.restingPhase));
      }
    } on ApiError {
      if (_stale(epoch)) return;
      emit(state.copyWith(phase: CallPhase.error, error: () => CallErrors.startFailed));
    }
  }

  Future<void> _onTalkToggled(CallTalkToggled event, Emitter<CallState> emit) async {
    if (state.phase == CallPhase.listening) {
      final upload = await recorder.stop();
      if (upload == null) {
        emit(state.copyWith(phase: state.restingPhase));
        return;
      }
      await _sendTurn(upload, emit);
      return;
    }
    if (!state.canTalk) return;
    if (!await recorder.hasPermission()) {
      emit(state.copyWith(error: () => CallErrors.micDenied));
      return;
    }
    await player.stop();
    await recorder.start();
    emit(state.copyWith(phase: CallPhase.listening, error: () => null));
  }

  Future<void> _onCancelled(CallRecordingCancelled event, Emitter<CallState> emit) async {
    if (state.phase != CallPhase.listening) return;
    await recorder.cancel();
    emit(state.copyWith(phase: state.restingPhase));
  }

  Future<void> _sendTurn(FileUpload audio, Emitter<CallState> emit) async {
    final id = state.conversationId;
    if (id == null) return;
    final epoch = _epoch;
    emit(state.copyWith(phase: CallPhase.thinking, error: () => null));
    var speaking = Future<void>.value();
    OutgoingReply? done;
    var aiLine = -1;
    try {
      await for (final ev in _repo.sendMessage(id, MessageInput(audio: audio, voice: true))) {
        if (_stale(epoch)) return;
        switch (ev) {
          case StreamTurn(:final turn):
            emit(state.copyWith(lines: [...state.lines, CallLine('customer', turn.text)]));
          case StreamModelSwitched(:final change):
            emit(state.copyWith(lines: [...state.lines, CallLine('notice', change.notice)]));
          case StreamToken():
            break; // Voice calls follow sentences, not tokens.
          case StreamSentence(:final text, :final audioUrl):
            final lines = [...state.lines];
            if (aiLine < 0) {
              aiLine = lines.length;
              lines.add(CallLine('ai', text));
            } else {
              lines[aiLine] = lines[aiLine].append(text);
            }
            emit(state.copyWith(lines: lines));
            speaking = speaking.then((_) async {
              if (_stale(epoch)) return;
              emit(state.copyWith(phase: CallPhase.speaking));
              await _say(text, audioUrl);
            });
          case StreamDone(:final reply):
            done = reply;
          case StreamError(:final error):
            throw error;
        }
      }
      await speaking;
      if (_stale(epoch)) return;
      final reply = done;
      if (reply != null) {
        if (aiLine < 0 && reply.text.isNotEmpty) {
          // No sentence events (e.g. plain JSON or a system message): show and say the full reply.
          final speaker = reply.speaker == 'ai' ? 'ai' : 'system';
          emit(state.copyWith(phase: CallPhase.speaking, lines: [...state.lines, CallLine(speaker, reply.text)]));
          await _say(reply.text, _firstAudio(reply.attachments));
          if (_stale(epoch)) return;
        }
        if (reply.endSession) {
          await _finish(emit);
          return;
        }
        if (reply.handoff) {
          _goHandedOff(emit);
          return;
        }
      }
      emit(state.copyWith(phase: state.restingPhase));
    } on ApiError catch (e) {
      await speaking;
      if (_stale(epoch)) return;
      // With a human agent the backend answers 409 but still forwards the message.
      final forwarded = state.withAgent && e.code == 'conflict';
      emit(state.copyWith(phase: state.restingPhase, error: () => forwarded ? null : CallErrors.turnFailed));
    }
  }

  Future<void> _onHandoff(CallHandoffRequested event, Emitter<CallState> emit) async {
    final id = state.conversationId;
    if (id == null || state.withAgent || !state.canTalk) return;
    try {
      final reply = await _repo.requestHandoff(id);
      emit(state.copyWith(lines: [...state.lines, CallLine('system', reply.text)]));
      _goHandedOff(emit);
      await _say(reply.text, _firstAudio(reply.attachments));
    } on ApiError catch (e) {
      // 409 = already queued / with an agent: still a handed-over call.
      if (e.code == 'conflict') {
        _goHandedOff(emit);
      } else {
        emit(state.copyWith(error: () => CallErrors.turnFailed));
      }
    }
  }

  void _goHandedOff(Emitter<CallState> emit) {
    emit(state.copyWith(phase: CallPhase.handedOff, withAgent: true));
    final id = state.conversationId;
    if (_live == null && id != null) {
      _live = _repo.events(id).listen((e) => add(_CallLiveEvent(e)));
    }
  }

  Future<void> _onLive(_CallLiveEvent event, Emitter<CallState> emit) async {
    final id = state.conversationId;
    if (id == null || state.phase == CallPhase.ended) return;
    switch (event.event) {
      case CallClaimedEvent(:final call, :final agentName) when call.id == id:
        emit(state.copyWith(agentName: () => agentName));
      case CallTurnEvent(:final turn) when turn.callId == id && turn.speaker == 'agent':
        final epoch = _epoch;
        final busy = state.phase == CallPhase.listening || state.phase == CallPhase.thinking;
        emit(state.copyWith(
          lines: [...state.lines, CallLine('agent', turn.text)],
          phase: busy ? null : CallPhase.speaking,
        ));
        if (busy) return;
        final audio = _firstAudio(turn.attachments);
        if (audio != null) await player.play(audio);
        if (_stale(epoch)) return;
        if (state.phase == CallPhase.speaking) emit(state.copyWith(phase: CallPhase.handedOff));
      case CallEndedEvent(:final call) when call.id == id:
        await _finish(emit, notifyBackend: false);
      default:
        break;
    }
  }

  Future<void> _onHungUp(CallHungUp event, Emitter<CallState> emit) async {
    if (!state.inCall && state.phase != CallPhase.connecting) return;
    await _finish(emit);
  }

  Future<void> _finish(Emitter<CallState> emit, {bool notifyBackend = true}) async {
    _epoch++;
    final id = state.conversationId;
    if (state.phase == CallPhase.listening) await recorder.cancel();
    await player.stop();
    await _live?.cancel();
    _live = null;
    emit(state.copyWith(phase: CallPhase.ended));
    if (notifyBackend && id != null) {
      try {
        await _repo.end(id);
      } on ApiError {
        // Already ended on the server: nothing to do.
      }
    }
  }

  /// Plays the TTS audio, or leaves the text on screen for a readable time.
  Future<void> _say(String text, String? audioUrl) async {
    if (audioUrl != null) {
      await player.play(audioUrl);
    } else {
      await Future<void>.delayed(readDelay(text));
    }
  }

  static String? _firstAudio(List<Attachment> attachments) {
    for (final a in attachments) {
      if (a.type == 'audio') return a.url;
    }
    return null;
  }

  @override
  Future<void> close() async {
    _epoch++;
    await _live?.cancel();
    await recorder.dispose();
    await player.dispose();
    return super.close();
  }
}
