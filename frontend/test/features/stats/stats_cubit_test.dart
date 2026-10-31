import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/stats/bloc/stats_cubit.dart';
import 'package:mocktail/mocktail.dart';

import '../agent_queue/agent_fixtures.dart';

void main() {
  late MockAgentRepository repo;
  late StreamController<WsEvent> events;

  setUp(() {
    repo = MockAgentRepository();
    events = StreamController<WsEvent>.broadcast();
    when(() => repo.events('agent-01')).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  blocTest<StatsCubit, StatsState>(
    'loads stats then follows stats.updated live',
    setUp: () => when(() => repo.stats()).thenAnswer((_) async => stats()),
    build: () => StatsCubit(repo, 'agent-01'),
    act: (c) async {
      await c.load();
      events.add(StatsUpdatedEvent('e1', t0, stats(rate: 0.9, updatedAt: t0.add(const Duration(minutes: 1)))));
    },
    expect: () => [
      const StatsState(),
      StatsState(stats: stats(), loading: false),
      StatsState(stats: stats(rate: 0.9, updatedAt: t0.add(const Duration(minutes: 1))), loading: false),
    ],
  );

  blocTest<StatsCubit, StatsState>(
    'reports an error when stats cannot load',
    setUp: () => when(() => repo.stats()).thenThrow(apiError),
    build: () => StatsCubit(repo, 'agent-01'),
    act: (c) => c.load(),
    expect: () => [const StatsState(), const StatsState(loading: false, error: apiError)],
  );
}
