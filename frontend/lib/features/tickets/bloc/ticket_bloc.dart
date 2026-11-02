import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

sealed class TicketEvent extends Equatable {
  const TicketEvent();
  @override
  List<Object?> get props => [];
}

class TicketsStarted extends TicketEvent {
  const TicketsStarted();
}

class TicketsFilterChanged extends TicketEvent {
  const TicketsFilterChanged(this.filter);
  final TicketFilter filter;
  @override
  List<Object?> get props => [filter];
}

class TicketStatusChanged extends TicketEvent {
  const TicketStatusChanged(this.ticketId, this.status);
  final String ticketId;
  final String status;
  @override
  List<Object?> get props => [ticketId, status];
}

class TicketAssignedToMe extends TicketEvent {
  const TicketAssignedToMe(this.ticketId);
  final String ticketId;
  @override
  List<Object?> get props => [ticketId];
}

class TicketsLiveEvent extends TicketEvent {
  const TicketsLiveEvent(this.event);
  final WsEvent event;
  @override
  List<Object?> get props => [event];
}

enum TicketsStatus { loading, ready, failure }

class TicketState extends Equatable {
  const TicketState({
    this.status = TicketsStatus.loading,
    this.items = const [],
    this.total = 0,
    this.filter = const TicketFilter(),
    this.updatingId,
    this.error,
    this.errorVersion = 0,
  });

  final TicketsStatus status;

  /// Newest first.
  final List<Ticket> items;
  final int total;
  final TicketFilter filter;
  final String? updatingId;
  final ApiError? error;
  final int errorVersion;

  TicketState copyWith({
    TicketsStatus? status,
    List<Ticket>? items,
    int? total,
    TicketFilter? filter,
    String? Function()? updatingId,
    ApiError? Function()? error,
    int? errorVersion,
  }) =>
      TicketState(
        status: status ?? this.status,
        items: items ?? this.items,
        total: total ?? this.total,
        filter: filter ?? this.filter,
        updatingId: updatingId != null ? updatingId() : this.updatingId,
        error: error != null ? error() : this.error,
        errorVersion: errorVersion ?? this.errorVersion,
      );

  @override
  List<Object?> get props => [status, items, total, filter, updatingId, error, errorVersion];
}

/// Ticket list for agents: filters, status update, assignment, live updates.
class TicketBloc extends Bloc<TicketEvent, TicketState> {
  TicketBloc(this._tickets, this._agents, this.agentId) : super(const TicketState()) {
    on<TicketsStarted>(_onStarted);
    on<TicketsFilterChanged>((e, emit) => _load(emit, e.filter));
    on<TicketStatusChanged>((e, emit) => _update(emit, e.ticketId, () => _tickets.update(e.ticketId, status: e.status)));
    on<TicketAssignedToMe>((e, emit) => _update(emit, e.ticketId, () => _tickets.update(e.ticketId, assignedTo: () => agentId)));
    on<TicketsLiveEvent>(_onLive);
  }

  final TicketRepository _tickets;
  final AgentRepository _agents;
  final String agentId;
  StreamSubscription<WsEvent>? _sub;

  Future<void> _onStarted(TicketsStarted e, Emitter<TicketState> emit) async {
    _sub ??= _agents.events(agentId).listen((ev) => add(TicketsLiveEvent(ev)), onError: (_) {});
    await _load(emit, state.filter);
  }

  Future<void> _load(Emitter<TicketState> emit, TicketFilter filter) async {
    emit(state.copyWith(status: TicketsStatus.loading, filter: filter, error: () => null));
    try {
      final page = await _tickets.list(filter);
      emit(state.copyWith(status: TicketsStatus.ready, items: page.items, total: page.total));
    } on ApiError catch (err) {
      emit(state.copyWith(status: TicketsStatus.failure, error: () => err, errorVersion: state.errorVersion + 1));
    }
  }

  Future<void> _update(Emitter<TicketState> emit, String id, Future<Ticket> Function() call) async {
    emit(state.copyWith(updatingId: () => id, error: () => null));
    try {
      final t = await call();
      emit(_merged(t).copyWith(updatingId: () => null));
    } on ApiError catch (err) {
      emit(state.copyWith(updatingId: () => null, error: () => err, errorVersion: state.errorVersion + 1));
    }
  }

  /// State with [t] inserted, replaced or removed according to the current filter.
  TicketState _merged(Ticket t) {
    final exists = state.items.any((x) => x.id == t.id);
    final matches = state.filter.matches(t);
    if (exists && matches) {
      return state.copyWith(items: [for (final x in state.items) x.id == t.id ? t : x]);
    }
    if (exists) {
      return state.copyWith(items: state.items.where((x) => x.id != t.id).toList(), total: state.total - 1);
    }
    if (matches) {
      final items = [t, ...state.items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return state.copyWith(items: items, total: state.total + 1);
    }
    return state;
  }

  void _onLive(TicketsLiveEvent e, Emitter<TicketState> emit) {
    if (state.status != TicketsStatus.ready) return;
    switch (e.event) {
      case TicketCreatedEvent(:final ticket):
      case TicketUpdatedEvent(:final ticket):
        emit(_merged(ticket));
      default:
        break;
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
