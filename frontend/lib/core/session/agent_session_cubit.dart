import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';

class AgentSessionState extends Equatable {
  const AgentSessionState({this.agents = const [], this.current, this.error});

  final List<Agent> agents;

  /// The agent using the dashboard (no auth in the prototype: picked from /v1/agents).
  final Agent? current;
  final ApiError? error;

  @override
  List<Object?> get props => [agents, current, error];
}

/// Who is using the agent dashboard. Needed by claim / messages / end calls.
class AgentSessionCubit extends Cubit<AgentSessionState> {
  AgentSessionCubit(this._repo) : super(const AgentSessionState());

  final AgentRepository _repo;

  Future<void> load() async {
    try {
      final agents = await _repo.agents();
      emit(AgentSessionState(agents: agents, current: state.current ?? (agents.isEmpty ? null : agents.first)));
    } on ApiError catch (e) {
      emit(AgentSessionState(agents: state.agents, current: state.current, error: e));
    }
  }

  void select(Agent agent) => emit(AgentSessionState(agents: state.agents, current: agent));
}
