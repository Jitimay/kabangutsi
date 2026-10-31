import 'dart:async';
import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/chat/bloc/chat_bloc.dart';
import 'package:mocktail/mocktail.dart';

import 'chat_fixtures.dart';

class MockConversations extends Mock implements ConversationRepository {}

void main() {
  late MockConversations repo;

  setUpAll(() => registerFallbackValue(const MessageInput()));

  setUp(() {
    repo = MockConversations();
    when(() => repo.create(channel: any(named: 'channel'), phone: any(named: 'phone'), lang: any(named: 'lang'), model: any(named: 'model')))
        .thenAnswer((_) async => conversation());
    when(() => repo.events(any())).thenAnswer((_) => const Stream.empty());
  });

  ChatBloc started() => ChatBloc(repo)..add(const ChatStarted(lang: 'fr'));

  group('ChatBloc', () {
    blocTest<ChatBloc, ChatState>(
      'creates a web conversation in the UI language and shows the greeting',
      build: () => ChatBloc(repo),
      act: (b) => b.add(const ChatStarted(lang: 'rn', model: 'gemma:2b')),
      expect: () => [
        isA<ChatState>().having((s) => s.status, 'status', ChatStatus.starting),
        isA<ChatState>()
            .having((s) => s.status, 'status', ChatStatus.ready)
            .having((s) => s.conversationId, 'id', convId)
            .having((s) => s.messages.single.text, 'greeting', 'Bonjour, je suis Kabangutsi.'),
      ],
      verify: (_) => verify(() => repo.create(channel: 'web', lang: 'rn', model: 'gemma:2b')).called(1),
    );

    blocTest<ChatBloc, ChatState>(
      'start failure → failure state with the error',
      build: () {
        when(() => repo.create(channel: any(named: 'channel'), phone: any(named: 'phone'), lang: any(named: 'lang'), model: any(named: 'model')))
            .thenThrow(ApiError.network);
        return ChatBloc(repo);
      },
      act: (b) => b.add(const ChatStarted(lang: 'fr')),
      expect: () => [
        isA<ChatState>().having((s) => s.status, 'status', ChatStatus.starting),
        isA<ChatState>().having((s) => s.status, 'status', ChatStatus.failure).having((s) => s.error, 'error', ApiError.network),
      ],
    );

    blocTest<ChatBloc, ChatState>(
      'streams tokens word by word, then the final reply with references; lang stays null',
      build: () {
        when(() => repo.sendMessage(any(), any())).thenAnswer((_) => Stream.fromIterable([
              StreamTurn(turn(text: 'Je veux bloquer ma carte')),
              const StreamToken('Votre '),
              const StreamToken('carte'),
              StreamDone(reply(
                id: 'r1',
                text: 'Votre carte est bloquée.',
                actions: const [ReplyAction(type: 'card_block', status: 'done', reference: 'BLK-2026-00017')],
              )),
            ]));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('Je veux bloquer ma carte'));
      },
      skip: 2,
      expect: () => [
        // customer bubble + empty pending bubble
        isA<ChatState>().having((s) => s.sending, 'sending', true).having((s) => s.messages.last.streaming, 'pending', true),
        // turn event: same text as typed → no new state
        isA<ChatState>().having((s) => s.messages.last.text, 'token 1', 'Votre '),
        isA<ChatState>().having((s) => s.messages.last.text, 'token 2', 'Votre carte'),
        isA<ChatState>()
            .having((s) => s.sending, 'sending', false)
            .having((s) => s.messages.last.text, 'final', 'Votre carte est bloquée.')
            .having((s) => s.messages.last.references, 'refs', ['BLK-2026-00017'])
            .having((s) => s.messages.last.modelUsed, 'model', 'gemma:2b'),
      ],
      verify: (_) {
        final input = verify(() => repo.sendMessage(convId, captureAny())).captured.single as MessageInput;
        expect(input.text, 'Je veux bloquer ma carte');
        expect(input.lang, isNull);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'F20: model.switched shows the notice before the reply when sending an image',
      build: () {
        when(() => repo.sendMessage(any(), any())).thenAnswer((_) => Stream.fromIterable([
              StreamModelSwitched(modelSwitch()),
              const StreamToken('Je vois une carte.'),
              StreamDone(reply(id: 'r2', text: 'Je vois une carte.', modelUsed: 'gemma4:e4b')),
            ]));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(ChatImageSent(FileUpload(bytes: Uint8List.fromList([1, 2, 3]), filename: 'a.jpg', mime: 'image/jpeg')));
      },
      verify: (b) {
        final authors = b.state.messages.map((m) => m.author).toList();
        expect(authors, [ChatAuthor.ai, ChatAuthor.customer, ChatAuthor.notice, ChatAuthor.ai]);
        expect(b.state.messages[2].text, contains('ne peut pas lire les images'));
        expect(b.state.messages[1].image, isNotNull);
        final input = verify(() => repo.sendMessage(convId, captureAny())).captured.single as MessageInput;
        expect(input.image?.mime, 'image/jpeg');
      },
    );

    blocTest<ChatBloc, ChatState>(
      'reply.model_notice is shown when no model.switched event came',
      build: () {
        when(() => repo.sendMessage(any(), any())).thenAnswer(
            (_) => Stream.value(StreamDone(reply(id: 'r3', text: 'OCR', modelNotice: 'Nta modèle: twakoresheje OCR.'))));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('x'));
      },
      verify: (b) => expect(
          b.state.messages.where((m) => m.author == ChatAuthor.notice).single.text, 'Nta modèle: twakoresheje OCR.'),
    );

    blocTest<ChatBloc, ChatState>(
      'PIN prompt: input is secret and the customer bubble is masked',
      build: () {
        when(() => repo.create(channel: any(named: 'channel'), phone: any(named: 'phone'), lang: any(named: 'lang'), model: any(named: 'model')))
            .thenAnswer((_) async => conversation(greeting: reply(text: 'Votre PIN ?', expectedInput: 'pin')));
        when(() => repo.sendMessage(any(), any()))
            .thenAnswer((_) => Stream.value(StreamDone(reply(id: 'r4', text: 'Merci.'))));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        expect(b.state.secretInput, isTrue);
        b.add(const ChatTextSent('1234'));
      },
      verify: (b) {
        final customer = b.state.messages.firstWhere((m) => m.author == ChatAuthor.customer);
        expect(customer.text, kMaskedText);
        expect(customer.masked, isTrue);
        expect(b.state.toString(), isNot(contains('1234')));
        expect(const ChatTextSent('1234').toString(), isNot(contains('1234')));
        expect(b.state.secretInput, isFalse);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'stream error → pending bubble removed, error set',
      build: () {
        when(() => repo.sendMessage(any(), any())).thenAnswer((_) => Stream.fromIterable([
              const StreamToken('Par'),
              const StreamError(ApiError(code: 'internal_error', message: 'Boom')),
            ]));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('Bonjour'));
      },
      verify: (b) {
        expect(b.state.sending, isFalse);
        expect(b.state.error?.message, 'Boom');
        expect(b.state.messages.map((m) => m.author), [ChatAuthor.ai, ChatAuthor.customer]);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'network failure while sending → error',
      build: () {
        when(() => repo.sendMessage(any(), any())).thenAnswer((_) => Stream.error(ApiError.network));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('Bonjour'));
      },
      verify: (b) => expect(b.state.error, ApiError.network),
    );

    test('handoff: waiting, then agent joins, writes and ends the call', () async {
      final live = StreamController<WsEvent>();
      when(() => repo.events(convId)).thenAnswer((_) => live.stream);
      when(() => repo.requestHandoff(convId, reason: any(named: 'reason')))
          .thenAnswer((_) async => reply(id: 'h1', speaker: 'system', text: 'Un conseiller arrive.', handoff: true, modelUsed: null));
      final bloc = started();
      await Future<void>.delayed(Duration.zero);

      bloc.add(const ChatHandoffRequested());
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.handoff, HandoffStatus.waiting);
      expect(bloc.state.messages.last.author, ChatAuthor.system);

      final ts = DateTime.utc(2026, 11, 2, 8, 3);
      live.add(CallClaimedEvent('e1', ts, call(), 'agent-01', 'Agent Aline (demo)'));
      live.add(CallTurnEvent('e2', ts, turn(id: 'a1', speaker: 'agent', text: 'Bonjour, je suis Aline.')));
      live.add(CallTurnEvent('e3', ts, turn(id: 'c9', speaker: 'customer', text: 'ignored')));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.handoff, HandoffStatus.withAgent);
      expect(bloc.state.agentName, 'Agent Aline (demo)');
      expect(bloc.state.messages.map((m) => m.author).toList().sublist(2), [ChatAuthor.agentJoined, ChatAuthor.agent]);

      live.add(CallEndedEvent('e4', ts, call(status: 'ended')));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state.ended, isTrue);
      expect(bloc.state.handoff, HandoffStatus.ended);
      expect(bloc.state.canSend, isFalse);

      await bloc.close();
      await live.close();
    });

    blocTest<ChatBloc, ChatState>(
      '409 while sending → treated as forwarded to the agent (waiting)',
      build: () {
        when(() => repo.sendMessage(any(), any()))
            .thenAnswer((_) => Stream.error(const ApiError(code: 'conflict', message: 'with agent', status: 409)));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('Allô ?'));
      },
      verify: (b) {
        expect(b.state.handoff, HandoffStatus.waiting);
        expect(b.state.error, isNull);
        verify(() => repo.events(convId)).called(1);
      },
    );

    blocTest<ChatBloc, ChatState>(
      'end_session disables input; restart opens a new conversation',
      build: () {
        when(() => repo.sendMessage(any(), any()))
            .thenAnswer((_) => Stream.value(StreamDone(reply(id: 'r5', text: 'Au revoir', endSession: true))));
        return started();
      },
      act: (b) async {
        await Future<void>.delayed(Duration.zero);
        b.add(const ChatTextSent('Merci'));
        await Future<void>.delayed(Duration.zero);
        expect(b.state.ended, isTrue);
        expect(b.state.canSend, isFalse);
        b.add(const ChatRestarted(lang: 'fr'));
      },
      verify: (b) {
        expect(b.state.ended, isFalse);
        expect(b.state.messages, hasLength(1));
        verify(() => repo.create(channel: 'web', phone: any(named: 'phone'), lang: 'fr', model: any(named: 'model'))).called(2);
      },
    );
  });
}
