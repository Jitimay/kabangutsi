import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/l10n/l10n.dart';
import 'package:kabangutsi/core/locale/language_cubit.dart';
import 'package:kabangutsi/core/session/agent_session_cubit.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/agent_queue/bloc/agent_queue_bloc.dart';
import 'package:kabangutsi/features/agent_queue/view/agent_queue_page.dart';
import 'package:kabangutsi/features/call_detail/bloc/call_detail_bloc.dart';
import 'package:kabangutsi/features/call_detail/view/call_detail_page.dart';
import 'package:kabangutsi/features/stats/bloc/stats_cubit.dart';
import 'package:kabangutsi/features/stats/view/stats_page.dart';
import 'package:kabangutsi/features/tickets/bloc/ticket_bloc.dart';
import 'package:kabangutsi/features/tickets/view/tickets_page.dart';
import 'package:mocktail/mocktail.dart';

import 'agent_fixtures.dart';

late AgentSessionCubit session;

Widget app(Widget child) => MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => LanguageCubit()),
        BlocProvider.value(value: session),
      ],
      child: MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: kSupportedLocales,
        localizationsDelegates: kLocalizationsDelegates,
        home: child,
      ),
    );

void main() {
  late MockAgentRepository repo;
  late MockTicketRepository tickets;
  late StreamController<WsEvent> events;

  setUpAll(() => registerFallbackValue(const TicketFilter()));

  setUp(() async {
    repo = MockAgentRepository();
    tickets = MockTicketRepository();
    events = StreamController<WsEvent>.broadcast();
    when(() => repo.events(any())).thenAnswer((_) => events.stream);
    when(() => repo.agents()).thenAnswer((_) async => const [Agent(id: 'agent-01', name: 'Agent Aline (demo)', languages: ['rn', 'fr'], role: 'agent')]);
    session = AgentSessionCubit(repo);
    await session.load();
  });
  tearDown(() => events.close());

  Future<void> desktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('queue shows queued calls with claim buttons', (tester) async {
    await desktop(tester);
    when(() => repo.queue()).thenAnswer((_) async => [call('c1', urgency: 'critical'), call('c2')]);
    await tester.pumpWidget(app(BlocProvider(
      create: (_) => AgentQueueBloc(repo, 'agent-01')..add(const AgentQueueStarted()),
      child: const AgentQueueView(),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('claim_c1')), findsOneWidget);
    expect(find.text('Critique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('call detail shows the AI summary and inserts a suggestion into the reply field', (tester) async {
    await desktop(tester);
    final mine = call('c1', status: 'with_agent', claimedBy: 'agent-01');
    when(() => repo.call('c1')).thenAnswer((_) async => CallDetail(
        call: mine, transcript: [turn('t1', 'c1'), turn('t2', 'c1', speaker: 'ai', text: 'Nobafasha iki?')], tickets: [ticket('1', callId: 'c1')], modelEvents: const []));
    await tester.pumpWidget(app(BlocProvider(
      create: (_) => CallDetailBloc(repo, callId: 'c1', agentId: 'agent-01')..add(const CallDetailStarted()),
      child: const CallDetailView(),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('ai_summary')), findsOneWidget);
    expect(find.text('Résumé fictif'), findsOneWidget);
    events.add(AgentSuggestionEvent('e', t0, Suggestion(callId: 'c1', turnId: 't1', suggestions: const [SuggestionItem(text: 'Turabasavye imbabazi.', lang: 'rn', sourceIds: [])], generatedMs: 1)));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(const Key('suggestion_0')));
    await tester.pump();
    final field = tester.widget<TextField>(find.byKey(const Key('agent_reply_field')));
    expect(field.controller!.text, 'Turabasavye imbabazi.');
    expect(tester.takeException(), isNull);
  });

  testWidgets('stats and tickets render', (tester) async {
    await desktop(tester);
    when(() => repo.stats()).thenAnswer((_) async => stats());
    await tester.pumpWidget(app(BlocProvider(create: (_) => StatsCubit(repo, 'agent-01')..load(), child: const StatsView())));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('stat_ai_rate')), findsOneWidget);
    expect(find.text('80.0 %'), findsOneWidget);

    when(() => tickets.list(any())).thenAnswer((_) async => TicketPage(items: [ticket('1')], total: 1));
    await tester.pumpWidget(app(BlocProvider(
      create: (_) => TicketBloc(tickets, repo, 'agent-01')..add(const TicketsStarted()),
      child: const TicketsView(),
    )));
    await tester.pump();
    await tester.pump();
    expect(find.text('TCK-2026-00001'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
