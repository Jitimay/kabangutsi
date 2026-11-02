import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/call_detail/bloc/call_detail_bloc.dart';
import 'package:mocktail/mocktail.dart';

import '../agent_queue/agent_fixtures.dart';

void main() {
  late MockAgentRepository repo;
  late StreamController<WsEvent> events;
  final mine = call('c1', status: 'with_agent', claimedBy: 'agent-01');
  final detail = CallDetail(call: mine, transcript: [turn('t1', 'c1')], tickets: const [], modelEvents: const []);

  setUp(() {
    repo = MockAgentRepository();
    events = StreamController<WsEvent>.broadcast();
    when(() => repo.events('agent-01')).thenAnswer((_) => events.stream);
  });
  tearDown(() => events.close());

  CallDetailBloc build() => CallDetailBloc(repo, callId: 'c1', agentId: 'agent-01');

  blocTest<CallDetailBloc, CallDetailState>(
    'loads the detail with the AI summary',
    setUp: () => when(() => repo.call('c1')).thenAnswer((_) async => detail),
    build: build,
    act: (b) => b.add(const CallDetailStarted()),
    expect: () => [
      isA<CallDetailState>().having((s) => s.status, 'status', CallDetailStatus.ready).having((s) => s.call?.summary, 'summary', 'Résumé fictif'),
    ],
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'emits failure when the call cannot load',
    setUp: () => when(() => repo.call('c1')).thenThrow(apiError),
    build: build,
    act: (b) => b.add(const CallDetailStarted()),
    expect: () => [isA<CallDetailState>().having((s) => s.status, 'status', CallDetailStatus.failure)],
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'live turns of this call are appended once; other calls ignored; suggestions shown',
    setUp: () => when(() => repo.call('c1')).thenAnswer((_) async => detail),
    build: build,
    act: (b) async {
      b.add(const CallDetailStarted());
      await Future<void>.delayed(Duration.zero);
      events
        ..add(CallTurnEvent('e1', t0, turn('t2', 'c1', text: 'Ndashaka amafaranga yanje')))
        ..add(CallTurnEvent('e2', t0, turn('t2', 'c1', text: 'Ndashaka amafaranga yanje')))
        ..add(CallTurnEvent('e3', t0, turn('t9', 'other')))
        ..add(AgentSuggestionEvent('e4', t0, Suggestion(callId: 'c1', turnId: 't2', suggestions: const [SuggestionItem(text: 'Turabasavye imbabazi.', lang: 'rn', sourceIds: ['kb-1'])], generatedMs: 900)));
    },
    skip: 1,
    expect: () => [
      isA<CallDetailState>().having((s) => s.detail!.transcript.map((t) => t.id), 'turns', ['t1', 't2']),
      isA<CallDetailState>().having((s) => s.suggestion?.suggestions.first.text, 'suggestion', 'Turabasavye imbabazi.'),
    ],
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'picking a suggestion fills the draft; sending posts it with voice for phone calls and clears the draft',
    setUp: () {
      when(() => repo.call('c1')).thenAnswer((_) async => detail);
      when(() => repo.sendMessage('c1', 'agent-01', 'Turabasavye imbabazi.', voice: true))
          .thenAnswer((_) async => agentReply('r1', 'c1', 'Turabasavye imbabazi.'));
    },
    build: build,
    act: (b) async {
      b.add(const CallDetailStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const CallDetailSuggestionPicked('Turabasavye imbabazi.'));
      b.add(const CallDetailSendRequested());
      await Future<void>.delayed(Duration.zero);
      // Echo of the same agent message over WebSocket (different id) is not duplicated.
      events.add(CallTurnEvent('e1', t0, turn('t-echo', 'c1', speaker: 'agent', text: 'Turabasavye imbabazi.', ts: t0.add(const Duration(minutes: 1)))));
    },
    skip: 1,
    expect: () => [
      isA<CallDetailState>().having((s) => s.draft, 'draft', 'Turabasavye imbabazi.').having((s) => s.draftVersion, 'v', 1),
      isA<CallDetailState>().having((s) => s.busy, 'busy', true),
      isA<CallDetailState>()
          .having((s) => s.draft, 'cleared', '')
          .having((s) => s.draftVersion, 'v', 2)
          .having((s) => s.detail!.transcript.map((t) => t.speaker), 'speakers', ['customer', 'agent']),
    ],
    verify: (_) => verify(() => repo.sendMessage('c1', 'agent-01', 'Turabasavye imbabazi.', voice: true)).called(1),
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'send error keeps the draft and reports the error',
    setUp: () {
      when(() => repo.call('c1')).thenAnswer((_) async => detail);
      when(() => repo.sendMessage(any(), any(), any(), voice: any(named: 'voice'))).thenThrow(apiError);
    },
    build: build,
    act: (b) async {
      b.add(const CallDetailStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const CallDetailDraftChanged('Muraho'));
      b.add(const CallDetailSendRequested());
    },
    skip: 3,
    expect: () => [isA<CallDetailState>().having((s) => s.error, 'error', apiError).having((s) => s.draft, 'draft', 'Muraho').having((s) => s.busy, 'busy', false)],
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'ending the call closes the screen',
    setUp: () {
      when(() => repo.call('c1')).thenAnswer((_) async => detail);
      when(() => repo.end('c1', 'agent-01', note: 'ok')).thenAnswer((_) async => mine.copyWith(status: 'ended', resolvedBy: 'agent'));
    },
    build: build,
    act: (b) async {
      b.add(const CallDetailStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const CallDetailEndRequested(note: 'ok'));
    },
    skip: 2,
    expect: () => [isA<CallDetailState>().having((s) => s.closed, 'closed', true).having((s) => s.call?.status, 'status', 'ended')],
  );

  blocTest<CallDetailBloc, CallDetailState>(
    'claiming a queued call from the detail',
    setUp: () {
      final queued = call('c1');
      when(() => repo.call('c1')).thenAnswer((_) async => CallDetail(call: queued, transcript: const [], tickets: const [], modelEvents: const []));
      when(() => repo.claim('c1', 'agent-01')).thenAnswer((_) async => detail);
    },
    build: build,
    act: (b) async {
      b.add(const CallDetailStarted());
      await Future<void>.delayed(Duration.zero);
      b.add(const CallDetailClaimRequested());
    },
    skip: 2,
    expect: () => [isA<CallDetailState>().having((s) => s.call?.claimedBy, 'claimed', 'agent-01').having((s) => s.busy, 'busy', false)],
  );
}
