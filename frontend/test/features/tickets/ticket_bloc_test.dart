import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/tickets/bloc/ticket_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../agent_queue/agent_fixtures.dart';

void main() {
  late MockTicketRepository tickets;
  late MockAgentRepository agents;
  late StreamController<WsEvent> events;
  final a = ticket('1');
  final b = ticket('2', status: 'in_progress', createdAt: t0.add(const Duration(hours: 1)));

  setUpAll(() => registerFallbackValue(const TicketFilter()));

  setUp(() {
    tickets = MockTicketRepository();
    agents = MockAgentRepository();
    events = StreamController<WsEvent>.broadcast();
    when(() => agents.events('agent-01')).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  TicketBloc build() => TicketBloc(tickets, agents, 'agent-01');

  blocTest<TicketBloc, TicketState>(
    'loads tickets',
    setUp: () => when(() => tickets.list(const TicketFilter())).thenAnswer((_) async => TicketPage(items: [b, a], total: 2)),
    build: build,
    act: (bl) => bl.add(const TicketsStarted()),
    expect: () => [
      const TicketState(),
      TicketState(status: TicketsStatus.ready, items: [b, a], total: 2),
    ],
  );

  blocTest<TicketBloc, TicketState>(
    'load error',
    setUp: () => when(() => tickets.list(any())).thenThrow(apiError),
    build: build,
    act: (bl) => bl.add(const TicketsStarted()),
    expect: () => [const TicketState(), const TicketState(status: TicketsStatus.failure, error: apiError, errorVersion: 1)],
  );

  blocTest<TicketBloc, TicketState>(
    'filter change reloads with the filter',
    setUp: () => when(() => tickets.list(const TicketFilter(status: 'open'))).thenAnswer((_) async => TicketPage(items: [a], total: 1)),
    build: build,
    act: (bl) => bl.add(const TicketsFilterChanged(TicketFilter(status: 'open'))),
    expect: () => [
      const TicketState(filter: TicketFilter(status: 'open')),
      TicketState(status: TicketsStatus.ready, items: [a], total: 1, filter: const TicketFilter(status: 'open')),
    ],
  );

  blocTest<TicketBloc, TicketState>(
    'status update replaces the ticket; assign to me sends my agent id',
    setUp: () {
      when(() => tickets.list(any())).thenAnswer((_) async => TicketPage(items: [a], total: 1));
      when(() => tickets.update('1', status: 'resolved')).thenAnswer((_) async => a.copyWith(status: 'resolved'));
      when(() => tickets.update('1', assignedTo: any(named: 'assignedTo'))).thenAnswer((_) async => a.copyWith(assignedTo: 'agent-01'));
    },
    build: build,
    act: (bl) async {
      bl.add(const TicketsStarted());
      await Future<void>.delayed(Duration.zero);
      bl.add(const TicketStatusChanged('1', 'resolved'));
      await Future<void>.delayed(Duration.zero);
      bl.add(const TicketAssignedToMe('1'));
    },
    skip: 2,
    expect: () => [
      isA<TicketState>().having((s) => s.updatingId, 'updating', '1'),
      isA<TicketState>().having((s) => s.items.single.status, 'status', 'resolved').having((s) => s.updatingId, 'done', isNull),
      isA<TicketState>().having((s) => s.updatingId, 'updating', '1'),
      isA<TicketState>().having((s) => s.items.single.assignedTo, 'assigned', 'agent-01'),
    ],
    verify: (_) {
      final captured = verify(() => tickets.update('1', assignedTo: captureAny(named: 'assignedTo'))).captured.single as String? Function();
      expect(captured(), 'agent-01');
    },
  );

  blocTest<TicketBloc, TicketState>(
    'update error is reported',
    setUp: () {
      when(() => tickets.list(any())).thenAnswer((_) async => TicketPage(items: [a], total: 1));
      when(() => tickets.update('1', status: 'closed')).thenThrow(apiError);
    },
    build: build,
    act: (bl) async {
      bl.add(const TicketsStarted());
      await Future<void>.delayed(Duration.zero);
      bl.add(const TicketStatusChanged('1', 'closed'));
    },
    skip: 3,
    expect: () => [isA<TicketState>().having((s) => s.error, 'error', apiError).having((s) => s.items.single.status, 'unchanged', 'open')],
  );

  blocTest<TicketBloc, TicketState>(
    'live: created ticket inserted on top, update leaving the filter removes it',
    setUp: () => when(() => tickets.list(const TicketFilter(status: 'open'))).thenAnswer((_) async => TicketPage(items: [a], total: 1)),
    build: build,
    seed: () => const TicketState(filter: TicketFilter(status: 'open')),
    act: (bl) async {
      bl.add(const TicketsStarted());
      await Future<void>.delayed(Duration.zero);
      events.add(TicketCreatedEvent('e1', t0, ticket('3', createdAt: t0.add(const Duration(hours: 2)))));
      events.add(TicketCreatedEvent('e2', t0, ticket('4', status: 'closed')));
      await Future<void>.delayed(Duration.zero);
      events.add(TicketUpdatedEvent('e3', t0, a.copyWith(status: 'in_progress')));
    },
    skip: 1, // the loading state equals the seed, so bloc does not emit it
    expect: () => [
      isA<TicketState>().having((s) => s.items.map((t) => t.id), 'created', ['3', '1']).having((s) => s.total, 'total', 2),
      isA<TicketState>().having((s) => s.items.map((t) => t.id), 'left filter', ['3']).having((s) => s.total, 'total', 1),
    ],
  );
}
