import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:kabangutsi/features/ussd/bloc/ussd_cubit.dart';
import 'package:mocktail/mocktail.dart';

class MockUssdRepository extends Mock implements UssdRepository {}

OutgoingReply reply(String text, {bool end = false}) => OutgoingReply(
  id: '9f8e7d6c-5b4a-4c3d-8e2f-1a0b9c8d7e6f',
  conversationId: '2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e',
  inReplyTo: null,
  channel: 'ussd',
  phone: '+25779000103',
  sessionId: 'ussd-1',
  lang: 'en',
  text: text,
  shortText: text,
  speaker: 'ai',
  intent: null,
  actions: const [],
  attachments: const [],
  expectedInput: end ? 'none' : 'menu_choice',
  handoff: false,
  endSession: end,
  modelUsed: null,
  modelNotice: null,
  ts: DateTime.utc(2026, 11, 2),
);

void main() {
  const menu = 'Kabangutsi\n1. Block a card\n2. Loans\n3. Branches';
  const end = 'Branch Ngozi: Mon–Fri 08:00–17:00';
  late MockUssdRepository repo;

  setUpAll(
    () => registerFallbackValue(
      InboundMessage(id: '', channel: 'ussd', phone: null, sessionId: '', lang: null, text: '', ts: DateTime.utc(2026)),
    ),
  );
  setUp(() => repo = MockUssdRepository());

  blocTest<UssdCubit, UssdState>(
    'dial *123# → menu; reply → END screen',
    setUp: () {
      var n = 0;
      when(() => repo.send(any())).thenAnswer((_) async => n++ == 0 ? reply(menu) : reply(end, end: true));
    },
    build: () => UssdCubit(repo, clock: () => DateTime.utc(2026, 11, 2, 10, 20)),
    act: (c) async {
      await c.dial('*123#', lang: 'en');
      await c.reply('3', lang: 'en');
    },
    expect: () => [
      isA<UssdState>().having((s) => s.phase, 'phase', UssdPhase.loading),
      isA<UssdState>().having((s) => s.phase, 'phase', UssdPhase.menu).having((s) => s.screen, 'screen', menu),
      isA<UssdState>().having((s) => s.phase, 'phase', UssdPhase.loading),
      isA<UssdState>()
          .having((s) => s.phase, 'phase', UssdPhase.ended)
          .having((s) => s.screen, 'screen', end)
          .having((s) => s.sessionId, 'session', isNull),
    ],
    verify: (_) {
      final sent = verify(() => repo.send(captureAny())).captured.cast<InboundMessage>();
      expect(sent, hasLength(2));
      expect(sent[0].text, '');
      expect(sent[1].text, '3');
      expect(sent[0].channel, 'ussd');
      expect(sent[0].phone, UssdCubit.demoPhone);
      expect(sent[0].lang, 'en');
      expect(sent[0].sessionId, startsWith('ussd-'));
      expect(sent[1].sessionId, sent[0].sessionId);
      expect(sent[0].id, isNot(sent[1].id));
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(sent[0].id),
        isTrue,
      );
      expect(sent[0].toJson()['ts'], '2026-11-02T10:20:00Z');
    },
  );

  blocTest<UssdCubit, UssdState>(
    'unknown code → invalidCode, nothing sent',
    build: () => UssdCubit(repo),
    act: (c) => c.dial('*999#', lang: 'fr'),
    expect: () => [const UssdState(phase: UssdPhase.invalidCode)],
    verify: (_) => verifyNever(() => repo.send(any())),
  );

  blocTest<UssdCubit, UssdState>(
    'network error → error phase; cancel resets',
    setUp: () => when(() => repo.send(any())).thenThrow(ApiError.network),
    build: () => UssdCubit(repo),
    act: (c) async {
      await c.dial('*123#', lang: 'rn');
      c.cancel();
    },
    skip: 1,
    expect: () => [const UssdState(phase: UssdPhase.error), const UssdState()],
  );
}
