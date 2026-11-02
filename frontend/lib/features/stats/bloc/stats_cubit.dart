import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

class StatsState extends Equatable {
  const StatsState({this.stats, this.loading = true, this.error});

  final Stats? stats;
  final bool loading;
  final ApiError? error;

  @override
  List<Object?> get props => [stats, loading, error];
}

/// F12: supervisor numbers, live from `stats.updated`.
class StatsCubit extends Cubit<StatsState> {
  StatsCubit(this._repo, this.agentId) : super(const StatsState());

  final AgentRepository _repo;
  final String agentId;
  StreamSubscription<WsEvent>? _sub;

  Future<void> load() async {
    _sub ??= _repo.events(agentId).listen((ev) {
      if (ev is StatsUpdatedEvent && !isClosed) emit(StatsState(stats: ev.stats, loading: false));
    }, onError: (_) {});
    emit(StatsState(stats: state.stats));
    try {
      final stats = await _repo.stats();
      // A live update may have arrived meanwhile: keep the newest.
      final current = state.stats;
      final newest = current != null && current.updatedAt.isAfter(stats.updatedAt) ? current : stats;
      emit(StatsState(stats: newest, loading: false));
    } on ApiError catch (e) {
      emit(StatsState(stats: state.stats, loading: false, error: e));
    }
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
