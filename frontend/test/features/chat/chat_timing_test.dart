// Waiting indicator: which model is working + live timer; finished reply: model used + total time.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/l10n/l10n.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/chat/bloc/chat_bloc.dart';
import 'package:kabangutsi/features/chat/widgets/message_bubble.dart';
import 'package:mocktail/mocktail.dart';

import 'chat_fixtures.dart';

class MockConversations extends Mock implements ConversationRepository {}

void main() {
  late MockConversations repo;
  late DateTime now;

  setUpAll(() => registerFallbackValue(const MessageInput()));

  setUp(() {
    repo = MockConversations();
    now = DateTime.utc(2026, 11, 2, 9);
    when(() => repo.create(channel: any(named: 'channel'), phone: any(named: 'phone'), lang: any(named: 'lang'), model: any(named: 'model')))
        .thenAnswer((_) async => conversation());
    when(() => repo.events(any())).thenAnswer((_) => const Stream.empty());
  });

  Future<ChatBloc> ready() async {
    final b = ChatBloc(repo, clock: () => now)..add(const ChatStarted(lang: 'fr'));
    await b.stream.firstWhere((s) => s.status == ChatStatus.ready);
    return b;
  }

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test('pending reply knows the chosen model and when it started; the reply gets the elapsed time', () async {
    final ctrl = StreamController<ChatStreamEvent>();
    when(() => repo.sendMessage(any(), any())).thenAnswer((_) => ctrl.stream);
    final b = await ready();
    b
      ..add(const ChatModelChanged('gemma:2b'))
      ..add(const ChatTextSent('Bonjour'));
    await settle();
    final pending = b.state.messages.last;
    expect(pending.streaming, isTrue);
    expect(pending.workingModel, 'gemma:2b');
    expect(pending.startedAt, now);

    now = now.add(const Duration(milliseconds: 2500));
    ctrl.add(StreamDone(reply(id: 'r1', text: 'Bonjour !', modelUsed: 'gemma:2b')));
    await ctrl.close();
    await settle();
    final done = b.state.messages.last;
    expect(done.streaming, isFalse);
    expect(done.elapsed, const Duration(milliseconds: 2500));
    expect(done.modelUsed, 'gemma:2b');
    await b.close();
  });

  test('model.switched changes the working model of the pending reply', () async {
    final ctrl = StreamController<ChatStreamEvent>();
    when(() => repo.sendMessage(any(), any())).thenAnswer((_) => ctrl.stream);
    final b = await ready();
    b.add(ChatImageSent(FileUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'a.jpg', mime: 'image/jpeg')));
    await settle();
    ctrl.add(StreamModelSwitched(modelSwitch()));
    await settle();
    final pending = b.state.messages.last;
    expect(pending.streaming, isTrue);
    expect(pending.workingModel, 'gemma4:e4b');
    await ctrl.close();
    await b.close();
  });

  group('MessageBubble', () {
    Future<void> pump(WidgetTester tester, ChatMessage m, {String? fallback}) => tester.pumpWidget(MaterialApp(
          locale: const Locale('en'),
          supportedLocales: kSupportedLocales,
          localizationsDelegates: kLocalizationsDelegates,
          home: Scaffold(body: MessageBubble(message: m, fallbackModel: fallback)),
        ));

    testWidgets('while waiting: model name and a running timer', (tester) async {
      final m = ChatMessage(
          id: 'p', author: ChatAuthor.ai, text: '', streaming: true, startedAt: DateTime.now().subtract(const Duration(seconds: 3)));
      await pump(tester, m, fallback: 'gemma:2b');
      expect(find.textContaining('gemma:2b is working…'), findsOneWidget);
      expect(find.textContaining(RegExp(r'3\.\d s')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose the ticker
    });

    testWidgets('finished: model used and total time; "no model" when the answer came from rules', (tester) async {
      await pump(tester,
          const ChatMessage(id: 'a', author: ChatAuthor.ai, text: 'Hi', modelUsed: 'gemma4:e2b', elapsed: Duration(milliseconds: 6800)));
      expect(find.text('gemma4:e2b · 6.8 s'), findsOneWidget);
      await pump(tester, const ChatMessage(id: 'b', author: ChatAuthor.ai, text: 'Hi', elapsed: Duration(milliseconds: 300)));
      expect(find.text('no model (rules) · 0.3 s'), findsOneWidget);
    });
  });

  test('formatSeconds', () {
    expect(formatSeconds(const Duration(milliseconds: 4230)), '4.2');
    expect(formatSeconds(const Duration(seconds: 95)), '95');
  });
}
