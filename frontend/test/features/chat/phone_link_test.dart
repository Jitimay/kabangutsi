import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/l10n/l10n.dart';
import 'package:kabangutsi/features/chat/bloc/chat_message.dart';
import 'package:kabangutsi/features/chat/widgets/message_bubble.dart';
import 'package:kabangutsi/features/chat/widgets/phone_link_text.dart';

void main() {
  const answer = 'Agence Ngozi (fictive), Avenue de l\'Indépendance. Téléphone : +25779000201. Ouverte maintenant.';

  test('finds Burundi numbers as written by the backend', () {
    expect(kPhonePattern.allMatches(answer).map((m) => m.group(0)), ['+25779000201']);
    expect(kPhonePattern.hasMatch('+257 79 00 02 01'), isTrue);
    expect(kPhonePattern.hasMatch('Ticket TCK-2026-00042'), isFalse);
  });

  testWidgets('tapping a phone number opens Call / Copy; Copy puts it on the clipboard', (tester) async {
    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') clipboard = (call.arguments as Map)['text'] as String?;
      return null;
    });
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('fr'),
      supportedLocales: kSupportedLocales,
      localizationsDelegates: kLocalizationsDelegates,
      home: Scaffold(body: MessageBubble(message: ChatMessage(id: 'a', author: ChatAuthor.ai, text: answer))),
    ));
    await tester.tapOnText(find.textRange.ofSubstring('+25779000201'));
    await tester.pumpAndSettle();
    expect(find.text('Appeler'), findsOneWidget);
    expect(find.text('Copier le numéro'), findsOneWidget);
    await tester.tap(find.byKey(const Key('phone_copy')));
    await tester.pumpAndSettle();
    expect(clipboard, '+25779000201');
    expect(find.text('Numéro copié'), findsOneWidget);
  });
}
