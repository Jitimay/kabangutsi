import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

sealed class AgentQueueEvent extends Equatable {
  const AgentQueueEvent();
  @override
  List<Object?> get props => [];
}

/// Load the queue and start listening to live events.
class AgentQueueStarted extends AgentQueueEvent {
  const AgentQueueStarted();
}

class AgentQueueRefreshed extends AgentQueueEvent {
  const AgentQueueRefreshed();
}

class AgentQueueLiveEvent extends AgentQueueEvent {
  const AgentQueueLiveEvent(this.event);
  final WsEvent event;
  @override
  List<Object?> get props => [event];
}

class AgentQueueClaimRequested extends AgentQueueEvent {
  const AgentQueueClaimRequested(this.callId);
  final String callId;
  @override
  List<Object?> get props => [callId];
}

enum QueueStatus { loading, ready, failure }

class AgentQueueState extends Equatable {
  const AgentQueueState({
    this.status = QueueStatus.loading,
    this.calls = const [],
    this.claimingId,
    this.claimedCallId,
    this.conflictClaimedBy,
    this.effect = 0,
    this.error,
  });

  final QueueStatus status;

  /// Queued calls, critical first, then oldest first.
  final List<Call> calls;
  final String? claimingId;

  /// Set once this agent claimed a call: the view navigates to its detail.
  final String? claimedCallId;

  /// Set when the claim lost the race (409 already_claimed): shown once as a snack.
  final String? conflictClaimedBy;

  /// Incremented for each one-shot effect (navigation, snack).
  final int effect;
  final ApiError? error;

  AgentQueueState copyWith({
    QueueStatus? status,
    List<Call>? calls,
    String? Function()? claimingId,
    String? Function()? claimedCallId,
    String? Function()? conflictClaimedBy,
    int? effect,
    ApiError? Function()? error,
  }) =>
      AgentQueueState(
        status: status ?? this.status,
        calls: calls ?? this.calls,
        claimingId: claimingId != null ? claimingId() : this.claimingId,
        claimedCallId: claimedCallId != null ? claimedCallId() : this.claimedCallId,
        conflictClaimedBy: conflictClaimedBy != null ? conflictClaimedBy() : this.conflictClaimedBy,
        effect: effect ?? this.effect,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [status, calls, claimingId, claimedCallId, conflictClaimedBy, effect, error];
}

/// F10: live queue of calls waiting for a human agent.
class AgentQueueBloc extends Bloc<AgentQueueEvent, AgentQueueState> {
  AgentQueueBloc(this._repo, this.agentId) : super(const AgentQueueState()) {
    on<AgentQueueStarted>(_onStarted);
    on<AgentQueueRefreshed>((_, emit) => _load(emit));
    on<AgentQueueLiveEvent>(_onLive);
    on<AgentQueueClaimRequested>(_onClaim);
  }

  final AgentRepository _repo;
  final String agentId;
  StreamSubscription<WsEvent>? _sub;

  static List<Call> sorted(Iterable<Call> calls) => calls.toList()
    ..sort((a, b) {
      final u = (Call.urgencyRank[a.urgency] ?? 9).compareTo(Call.urgencyRank[b.urgency] ?? 9);
      if (u != 0) return u;
      return (a.queuedAt ?? a.startedAt).compareTo(b.queuedAt ?? b.startedAt);
    });

  Future<void> _onStarted(AgentQueueStarted e, Emitter<AgentQueueState> emit) async {
    _sub ??= _repo.events(agentId).listen((ev) => add(AgentQueueLiveEvent(ev)), onError: (_) {});
    await _load(emit);
  }

  Future<void> _load(Emitter<AgentQueueState> emit) async {
    try {
      final calls = await _repo.queue();
      emit(state.copyWith(status: QueueStatus.ready, calls: sorted(calls.where((c) => c.status == 'queued')), error: () => null));
    } on ApiError catch (err) {
      emit(state.copyWith(status: QueueStatus.failure, error: () => err));
    }
  }

  void _onLive(AgentQueueLiveEvent e, Emitter<AgentQueueState> emit) {
    final ev = e.event;
    switch (ev) {
      case CallHandoffRequestedEvent(:final call):
        final rest = state.calls.where((c) => c.id != call.id);
        emit(state.copyWith(calls: sorted([...rest, call])));
      case CallClaimedEvent(:final call):
        _remove(call.id, emit);
      case CallEndedEvent(:final call):
        _remove(call.id, emit);
      default:
        break;
    }
  }

  void _remove(String id, Emitter<AgentQueueState> emit) {
    if (state.calls.any((c) => c.id == id)) {
      emit(state.copyWith(calls: state.calls.where((c) => c.id != id).toList()));
    }
  }

  Future<void> _onClaim(AgentQueueClaimRequested e, Emitter<AgentQueueState> emit) async {
    if (state.claimingId != null) return;
    emit(state.copyWith(claimingId: () => e.callId, error: () => null));
    final rest = state.calls.where((c) => c.id != e.callId).toList();
    try {
      await _repo.claim(e.callId, agentId);
      emit(state.copyWith(calls: rest, claimingId: () => null, claimedCallId: () => e.callId, conflictClaimedBy: () => null, effect: state.effect + 1));
    } on ApiError catch (err) {
      if (err.code == 'already_claimed' || err.status == 409) {
        emit(state.copyWith(
          calls: rest,
          claimingId: () => null,
          claimedCallId: () => null,
          conflictClaimedBy: () => (err.details['claimed_by'] as String?) ?? '?',
          effect: state.effect + 1,
        ));
      } else {
        emit(state.copyWith(claimingId: () => null, error: () => err, effect: state.effect + 1));
      }
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
