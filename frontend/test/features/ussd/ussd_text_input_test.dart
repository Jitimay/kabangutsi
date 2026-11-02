import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/l10n/l10n.dart';
import 'package:kabangutsi/core/locale/language_cubit.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/features/ussd/bloc/ussd_cubit.dart';
import 'package:kabangutsi/features/ussd/view/ussd_page.dart';
import 'package:mocktail/mocktail.dart';

import 'ussd_cubit_test.dart' show MockUssdRepository, reply;

/// "Autre question" → the backend answers with expected_input = text: letters must be accepted.
void main() {
  setUpAll(
    () => registerFallbackValue(
      InboundMessage(id: '', channel: 'ussd', phone: null, sessionId: '', lang: null, text: '', ts: DateTime.utc(2026)),
    ),
  );

  testWidgets('menu accepts only digits; a free question accepts letters', (tester) async {
    final repo = MockUssdRepository();
    var n = 0;
    when(() => repo.send(any())).thenAnswer((_) async {
      final r = reply(n++ == 0 ? 'Menu\n1. Produits' : 'Écrivez votre question :');
      return n == 1 ? r : r.copyWithExpectedInput('text');
    });
    final cubit = UssdCubit(repo);
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [BlocProvider(create: (_) => LanguageCubit()), BlocProvider.value(value: cubit)],
          child: const UssdView(),
        ),
      ),
    ));
    final input = find.byKey(const Key('ussd_input'));

    await cubit.dial('*123#', lang: 'fr');
    await tester.pump();
    await tester.enterText(input, 'abc12');
    expect(tester.widget<TextField>(input).controller!.text, '12');

    await cubit.reply('1', lang: 'fr');
    await tester.pump();
    expect(cubit.state.expectsText, isTrue);
    await tester.enterText(input, 'ouvrir un compte');
    expect(tester.widget<TextField>(input).controller!.text, 'ouvrir un compte');
  });
}

extension on OutgoingReply {
  OutgoingReply copyWithExpectedInput(String v) => OutgoingReply(
    id: id,
    conversationId: conversationId,
    inReplyTo: inReplyTo,
    channel: channel,
    phone: phone,
    sessionId: sessionId,
    lang: lang,
    text: text,
    shortText: shortText,
    speaker: speaker,
    intent: intent,
    actions: actions,
    attachments: attachments,
    expectedInput: v,
    handoff: handoff,
    endSession: endSession,
    modelUsed: modelUsed,
    modelNotice: modelNotice,
    ts: ts,
  );
}
