import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/agent_queue/bloc/agent_queue_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'agent_fixtures.dart';

void main() {
  late MockAgentRepository repo;
  late StreamController<WsEvent> events;

  setUp(() {
    repo = MockAgentRepository();
    events = StreamController<WsEvent>.broadcast();
    when(() => repo.events('agent-01')).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  final low = call('c-low', urgency: 'low');
  final critical = call('c-crit', urgency: 'critical', queuedAt: t0.add(const Duration(minutes: 5)));
  final high = call('c-high', urgency: 'high');

  blocTest<AgentQueueBloc, AgentQueueState>(
    'loads the queue sorted critical first',
    setUp: () => when(() => repo.queue()).thenAnswer((_) async => [low, high, critical]),
    build: () => AgentQueueBloc(repo, 'agent-01'),
    act: (b) => b.add(const AgentQueueStarted()),
    expect: () => [
      isA<AgentQueueState>().having((s) => s.calls.map((c) => c.id), 'order', ['c-crit', 'c-high', 'c-low']).having((s) => s.status, 'status', QueueStatus.ready),
    ],
  );

  blocTest<AgentQueueBloc, AgentQueueState>(
    'emits failure when the queue cannot load',
    setUp: () => when(() => repo.queue()).thenThrow(apiError),
    build: () => AgentQueueBloc(repo, 'agent-01'),
    act: (b) => b.add(const AgentQueueStarted()),
    expect: () => [isA<AgentQueueState>().having((s) => s.status, 'status', QueueStatus.failure).having((s) => s.error, 'error', apiError)],
  );

  blocTest<AgentQueueBloc, AgentQueueState>(
    'live: handoff adds, claimed by another agent removes, ended removes',
    setUp: () => when(() => repo.queue()).thenAnswer((_) async => [low]),
    build: () => AgentQueueBloc(repo, 'agent-01'),
    act: (b) async {
      b.add(const AgentQueueStarted());
      await Future<void>.delayed(Duration.zero);
      events.add(CallHandoffRequestedEvent('e1', t0, critical, 'frustration', 's', const []));
      await Future<void>.delayed(Duration.zero);
      events.add(CallClaimedEvent('e2', t0, critical.copyWith(status: 'with_agent', claimedBy: 'agent-02'), 'agent-02', 'Agent Fabrice (demo)'));
      await Future<void>.delayed(Duration.zero);
      events.add(CallEndedEvent('e3', t0, low.copyWith(status: 'ended')));
    },
    expect: () => [
      isA<AgentQueueState>().having((s) => s.calls.map((c) => c.id), 'loaded', ['c-low']),
      isA<AgentQueueState>().having((s) => s.calls.map((c) => c.id), 'handoff', ['c-crit', 'c-low']),
      isA<AgentQueueState>().having((s) => s.calls.map((c) => c.id), 'claimed elsewhere', ['c-low']),
      isA<AgentQueueState>().having((s) => s.calls, 'ended', isEmpty),
    ],
  );

  blocTest<AgentQueueBloc, AgentQueueState>(
    'claim success removes the call and asks to open its detail',
    setUp: () {
      when(() => repo.queue()).thenAnswer((_) async => [high]);
      when(() => repo.claim('c-high', 'agent-01'))
          .thenAnswer((_) async => CallDetail(call: high.copyWith(status: 'with_agent', claimedBy: 'agent-01'), transcript: const [], tickets: const [], modelEvents: const []));
    },
    build: () => AgentQueueBloc(repo, 'agent-01'),
    act: (b) async {
      b.add(const AgentQueueStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const AgentQueueClaimRequested('c-high'));
    },
    skip: 1,
    expect: () => [
      isA<AgentQueueState>().having((s) => s.claimingId, 'claiming', 'c-high'),
      isA<AgentQueueState>().having((s) => s.claimedCallId, 'claimed', 'c-high').having((s) => s.calls, 'calls', isEmpty).having((s) => s.effect, 'effect', 1),
    ],
  );

  blocTest<AgentQueueBloc, AgentQueueState>(
    'claim conflict (409 already_claimed) removes the call and reports who has it',
    setUp: () {
      when(() => repo.queue()).thenAnswer((_) async => [high]);
      when(() => repo.claim('c-high', 'agent-01')).thenThrow(
          const ApiError(code: 'already_claimed', message: 'Call already claimed by agent-02', details: {'claimed_by': 'agent-02'}, status: 409));
    },
    build: () => AgentQueueBloc(repo, 'agent-01'),
    act: (b) async {
      b.add(const AgentQueueStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const AgentQueueClaimRequested('c-high'));
    },
    skip: 2,
    expect: () => [
      isA<AgentQueueState>()
          .having((s) => s.conflictClaimedBy, 'by', 'agent-02')
          .having((s) => s.claimedCallId, 'not mine', isNull)
          .having((s) => s.calls, 'removed', isEmpty),
    ],
  );

  test('close cancels the live subscription', () async {
    when(() => repo.queue()).thenAnswer((_) async => []);
    final b = AgentQueueBloc(repo, 'agent-01')..add(const AgentQueueStarted());
    await Future<void>.delayed(Duration.zero);
    expect(events.hasListener, isTrue);
    await b.close();
    expect(events.hasListener, isFalse);
  });
}
