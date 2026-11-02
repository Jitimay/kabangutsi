import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

sealed class CallDetailEvent extends Equatable {
  const CallDetailEvent();
  @override
  List<Object?> get props => [];
}

class CallDetailStarted extends CallDetailEvent {
  const CallDetailStarted();
}

class CallDetailLiveEvent extends CallDetailEvent {
  const CallDetailLiveEvent(this.event);
  final WsEvent event;
  @override
  List<Object?> get props => [event];
}

class CallDetailClaimRequested extends CallDetailEvent {
  const CallDetailClaimRequested();
}

/// The agent typed in the reply field.
class CallDetailDraftChanged extends CallDetailEvent {
  const CallDetailDraftChanged(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

/// F11: click on a suggestion inserts it into the reply field.
class CallDetailSuggestionPicked extends CallDetailEvent {
  const CallDetailSuggestionPicked(this.text);
  final String text;
  @override
  List<Object?> get props => [text];
}

class CallDetailSendRequested extends CallDetailEvent {
  const CallDetailSendRequested();
}

class CallDetailEndRequested extends CallDetailEvent {
  const CallDetailEndRequested({this.note});
  final String? note;
  @override
  List<Object?> get props => [note];
}

enum CallDetailStatus { loading, ready, failure }

class CallDetailState extends Equatable {
  const CallDetailState({
    this.status = CallDetailStatus.loading,
    this.detail,
    this.suggestion,
    this.draft = '',
    this.draftVersion = 0,
    this.busy = false,
    this.closed = false,
    this.error,
    this.errorVersion = 0,
  });

  final CallDetailStatus status;
  final CallDetail? detail;

  /// Latest `agent.suggestion` for this call (up to 3 replies).
  final Suggestion? suggestion;

  /// Reply field text.
  final String draft;

  /// Incremented when the bloc changes [draft] itself (suggestion inserted, sent),
  /// so the view updates its text controller only then.
  final int draftVersion;

  /// A claim, send or end request is running.
  final bool busy;

  /// This agent ended the call: the view goes back to the queue.
  final bool closed;
  final ApiError? error;
  final int errorVersion;

  Call? get call => detail?.call;

  CallDetailState copyWith({
    CallDetailStatus? status,
    CallDetail? detail,
    Suggestion? suggestion,
    String? draft,
    int? draftVersion,
    bool? busy,
    bool? closed,
    ApiError? Function()? error,
    int? errorVersion,
  }) =>
      CallDetailState(
        status: status ?? this.status,
        detail: detail ?? this.detail,
        suggestion: suggestion ?? this.suggestion,
        draft: draft ?? this.draft,
        draftVersion: draftVersion ?? this.draftVersion,
        busy: busy ?? this.busy,
        closed: closed ?? this.closed,
        error: error != null ? error() : this.error,
        errorVersion: errorVersion ?? this.errorVersion,
      );

  @override
  List<Object?> get props => [status, detail, suggestion, draft, draftVersion, busy, closed, error, errorVersion];
}

/// F9 + F11: one call seen by an agent — summary, transcript, live turns,
/// suggested replies, agent messages, end of call.
class CallDetailBloc extends Bloc<CallDetailEvent, CallDetailState> {
  CallDetailBloc(this._repo, {required this.callId, required this.agentId}) : super(const CallDetailState()) {
    on<CallDetailStarted>(_onStarted);
    on<CallDetailLiveEvent>(_onLive);
    on<CallDetailClaimRequested>(_onClaim);
    on<CallDetailDraftChanged>((e, emit) => emit(state.copyWith(draft: e.text)));
    on<CallDetailSuggestionPicked>(
        (e, emit) => emit(state.copyWith(draft: e.text, draftVersion: state.draftVersion + 1)));
    on<CallDetailSendRequested>(_onSend);
    on<CallDetailEndRequested>(_onEnd);
  }

  final AgentRepository _repo;
  final String callId;
  final String agentId;
  StreamSubscription<WsEvent>? _sub;

  bool get isMine => state.call?.status == 'with_agent' && state.call?.claimedBy == agentId;

  Future<void> _onStarted(CallDetailStarted e, Emitter<CallDetailState> emit) async {
    _sub ??= _repo.events(agentId).listen((ev) => add(CallDetailLiveEvent(ev)), onError: (_) {});
    try {
      final detail = await _repo.call(callId);
      emit(state.copyWith(status: CallDetailStatus.ready, detail: _merge(detail, state.detail), error: () => null));
    } on ApiError catch (err) {
      emit(state.copyWith(status: CallDetailStatus.failure, error: () => err, errorVersion: state.errorVersion + 1));
    }
  }

  /// Keeps live turns that arrived while the detail was loading.
  CallDetail _merge(CallDetail fresh, CallDetail? live) {
    if (live == null) return fresh;
    final ids = fresh.transcript.map((t) => t.id).toSet();
    return CallDetail(
      call: fresh.call,
      transcript: [...fresh.transcript, ...live.transcript.where((t) => !ids.contains(t.id))],
      tickets: fresh.tickets,
      modelEvents: fresh.modelEvents,
    );
  }

  CallDetail _with({Call? call, List<Turn>? transcript, List<Ticket>? tickets, List<ModelSwitch>? modelEvents}) {
    final d = state.detail!;
    return CallDetail(
      call: call ?? d.call,
      transcript: transcript ?? d.transcript,
      tickets: tickets ?? d.tickets,
      modelEvents: modelEvents ?? d.modelEvents,
    );
  }

  void _onLive(CallDetailLiveEvent e, Emitter<CallDetailState> emit) {
    final ev = e.event;
    if (state.detail == null) return;
    switch (ev) {
      case CallTurnEvent(:final turn) when turn.callId == callId:
        if (!_hasTurn(turn)) emit(state.copyWith(detail: _with(transcript: [...state.detail!.transcript, turn])));
      case CallHandoffRequestedEvent(:final call) when call.id == callId:
        emit(state.copyWith(detail: _with(call: call)));
      case CallClaimedEvent(:final call) when call.id == callId:
        emit(state.copyWith(detail: _with(call: call)));
      case CallEndedEvent(:final call) when call.id == callId:
        emit(state.copyWith(detail: _with(call: call)));
      case ModelSwitchedEvent(:final change) when change.callId == callId:
        if (!state.detail!.modelEvents.any((m) => m.id == change.id)) {
          emit(state.copyWith(detail: _with(modelEvents: [...state.detail!.modelEvents, change])));
        }
      case TicketCreatedEvent(:final ticket) when ticket.callId == callId:
        emit(state.copyWith(detail: _with(tickets: [...state.detail!.tickets.where((t) => t.id != ticket.id), ticket])));
      case TicketUpdatedEvent(:final ticket) when ticket.callId == callId:
        emit(state.copyWith(detail: _with(tickets: [for (final t in state.detail!.tickets) t.id == ticket.id ? ticket : t])));
      case AgentSuggestionEvent(:final suggestion) when suggestion.callId == callId:
        emit(state.copyWith(suggestion: suggestion));
      default:
        break;
    }
  }

  /// Same id, or the echo of a message this agent just sent (added locally).
  bool _hasTurn(Turn turn) => state.detail!.transcript.any((t) =>
      t.id == turn.id ||
      (turn.speaker == 'agent' &&
          t.speaker == 'agent' &&
          t.text == turn.text &&
          t.ts.difference(turn.ts).inSeconds.abs() < 30));

  Future<void> _onClaim(CallDetailClaimRequested e, Emitter<CallDetailState> emit) async {
    if (state.busy) return;
    emit(state.copyWith(busy: true, error: () => null));
    try {
      final detail = await _repo.claim(callId, agentId);
      emit(state.copyWith(busy: false, detail: _merge(detail, state.detail)));
    } on ApiError catch (err) {
      emit(state.copyWith(busy: false, error: () => err, errorVersion: state.errorVersion + 1));
      try {
        final detail = await _repo.call(callId);
        emit(state.copyWith(detail: _merge(detail, state.detail)));
      } on ApiError {
        // keep what we have
      }
    }
  }

  Future<void> _onSend(CallDetailSendRequested e, Emitter<CallDetailState> emit) async {
    final text = state.draft.trim();
    final call = state.call;
    if (text.isEmpty || state.busy || call == null) return;
    emit(state.copyWith(busy: true, error: () => null));
    try {
      final reply = await _repo.sendMessage(callId, agentId, text, voice: call.channel == 'phone');
      final turn = Turn(
        id: reply.id,
        callId: callId,
        speaker: 'agent',
        agentId: agentId,
        text: reply.text,
        lang: reply.lang,
        intent: null,
        confidence: null,
        frustration: null,
        attachments: reply.attachments,
        modelUsed: null,
        ts: reply.ts,
      );
      final transcript = _hasTurn(turn) ? state.detail!.transcript : [...state.detail!.transcript, turn];
      emit(state.copyWith(busy: false, draft: '', draftVersion: state.draftVersion + 1, detail: _with(transcript: transcript)));
    } on ApiError catch (err) {
      emit(state.copyWith(busy: false, error: () => err, errorVersion: state.errorVersion + 1));
    }
  }

  Future<void> _onEnd(CallDetailEndRequested e, Emitter<CallDetailState> emit) async {
    if (state.busy || state.detail == null) return;
    emit(state.copyWith(busy: true, error: () => null));
    try {
      final call = await _repo.end(callId, agentId, note: e.note);
      emit(state.copyWith(busy: false, closed: true, detail: _with(call: call)));
    } on ApiError catch (err) {
      emit(state.copyWith(busy: false, error: () => err, errorVersion: state.errorVersion + 1));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
