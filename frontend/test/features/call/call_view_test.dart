import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/l10n/l10n.dart';
import 'package:kabangutsi/core/locale/language_cubit.dart';
import 'package:kabangutsi/features/call/bloc/call_bloc.dart';
import 'package:kabangutsi/features/call/view/call_page.dart';
import 'package:mocktail/mocktail.dart';

import 'call_fixtures.dart';

class MockCallBloc extends MockBloc<CallEvent, CallState> implements CallBloc {}

void main() {
  late MockCallBloc bloc;

  setUp(() => bloc = MockCallBloc());

  Future<void> pump(WidgetTester tester, CallState state, {Locale locale = const Locale('en')}) async {
    when(() => bloc.state).thenReturn(state);
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: MultiBlocProvider(
        providers: [
          BlocProvider<LanguageCubit>(create: (_) => LanguageCubit(locale)),
          BlocProvider<CallBloc>.value(value: bloc),
        ],
        child: const CallView(),
      ),
    ));
    // Animated indicators repeat forever: pump frames, never pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 100));
  }

  String label(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('call_status_label'))).data!;

  const inCall = CallState(phase: CallPhase.ready, conversationId: convId);

  final cases = <CallState, (String, String)>{
    const CallState(): ('call_indicator_idle', 'Press call to talk to Kabangutsi'),
    const CallState(phase: CallPhase.connecting): ('call_indicator_connecting', 'Connecting…'),
    inCall: ('call_indicator_ready', 'Tap the microphone and speak'),
    const CallState(phase: CallPhase.listening, conversationId: convId): ('call_indicator_listening', 'Listening…'),
    const CallState(phase: CallPhase.thinking, conversationId: convId): ('call_indicator_thinking', 'Thinking…'),
    const CallState(phase: CallPhase.speaking, conversationId: convId): ('call_indicator_speaking', 'Kabangutsi is speaking'),
    const CallState(phase: CallPhase.handedOff, conversationId: convId, withAgent: true): ('call_indicator_handedOff', 'Waiting for an agent'),
    const CallState(phase: CallPhase.ended, conversationId: convId): ('call_indicator_ended', 'Call ended'),
    const CallState(phase: CallPhase.error, error: CallErrors.startFailed): ('call_indicator_error', 'The call could not be connected'),
  };

  for (final MapEntry(key: state, value: (indicator, text)) in cases.entries) {
    testWidgets('phase ${state.phase.name} shows its indicator and label', (tester) async {
      await pump(tester, state);
      expect(find.byKey(Key(indicator)), findsOneWidget);
      expect(label(tester), text);
    });
  }

  testWidgets('idle: only the call button; tapping it dials in the UI language', (tester) async {
    await pump(tester, const CallState(), locale: const Locale('rn'));
    expect(find.byKey(const Key('call_talk')), findsNothing);
    expect(find.byKey(const Key('call_hangup')), findsNothing);
    await tester.tap(find.byKey(const Key('call_start')));
    verify(() => bloc.add(const CallStarted('rn'))).called(1);
  });

  testWidgets('ready: talk, handoff and hang-up buttons send their events', (tester) async {
    await pump(tester, inCall);
    await tester.tap(find.byKey(const Key('call_talk')));
    await tester.tap(find.byKey(const Key('call_handoff')));
    await tester.tap(find.byKey(const Key('call_hangup')));
    verifyInOrder([
      () => bloc.add(const CallTalkToggled()),
      () => bloc.add(const CallHandoffRequested()),
      () => bloc.add(const CallHungUp()),
    ]);
  });

  testWidgets('listening: tap to send + cancel button', (tester) async {
    await pump(tester, const CallState(phase: CallPhase.listening, conversationId: convId));
    expect(find.text('Tap to send'), findsOneWidget);
    await tester.tap(find.byKey(const Key('call_cancel_recording')));
    verify(() => bloc.add(const CallRecordingCancelled())).called(1);
  });

  testWidgets('thinking / speaking: talk button disabled', (tester) async {
    for (final phase in [CallPhase.thinking, CallPhase.speaking]) {
      await pump(tester, CallState(phase: phase, conversationId: convId));
      expect(tester.widget<FilledButton>(find.byKey(const Key('call_talk'))).onPressed, isNull);
    }
  });

  testWidgets('handedOff with agent: agent name, no handoff button, transcript lines', (tester) async {
    await pump(tester, const CallState(
      phase: CallPhase.handedOff,
      conversationId: convId,
      withAgent: true,
      agentName: 'Agent Aline (demo)',
      lines: [CallLine('customer', 'Ndashaka umukozi'), CallLine('agent', 'Muraho, ndi Aline.'), CallLine('notice', 'Modèle changé')],
    ));
    expect(label(tester), 'Agent Aline (demo) joined the call');
    expect(find.byKey(const Key('call_handoff')), findsNothing);
    expect(find.text('Muraho, ndi Aline.'), findsOneWidget);
    expect(find.text('Agent'), findsOneWidget);
    expect(find.text('Modèle changé'), findsOneWidget);
  });

  testWidgets('ended: new call button', (tester) async {
    await pump(tester, const CallState(phase: CallPhase.ended, conversationId: convId));
    expect(find.text('New call'), findsOneWidget);
  });

  testWidgets('mic refused shows a snackbar in Kirundi', (tester) async {
    whenListen(bloc, Stream.value(inCall.copyWith(error: () => CallErrors.micDenied)), initialState: inCall);
    await pump(tester, inCall, locale: const Locale('rn'));
    await tester.pump();
    expect(find.text('Mikoro irakenewe kugira ngo muhamagare'), findsOneWidget);
  });
}
