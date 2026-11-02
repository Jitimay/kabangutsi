import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/util/format.dart';
import 'package:kabangutsi/data/mock/mock_backend.dart';
import 'package:kabangutsi/data/mock/mock_seed.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';

void main() {
  late MockBackend b;
  setUp(() => b = MockBackend(latency: Duration.zero, tokenDelay: Duration.zero, simulateIncoming: false));
  tearDown(() => b.dispose());

  test('annuity formula matches the contract example', () {
    expect(monthlyPayment(5000000, 16, 24), 244816);
    final s = b.simulate('business_loan', 5000000, 24, 'fr');
    expect(s.totalPayment, 5875584);
    expect(s.totalInterest, 875584);
  });

  test('out of range loan → 422 out_of_range', () {
    expect(() => b.simulate('business_loan', 100, 24, 'en'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'out_of_range')));
  });

  test('chat streams tokens then done, in the detected language', () async {
    final c = b.createConversation(channel: 'web', lang: 'fr');
    final events = await b.sendMessage(c.id, const MessageInput(text: 'Ishami rya Ngozi ryugurura ryari?')).toList();
    expect(events.first, isA<StreamTurn>());
    expect(events.whereType<StreamToken>(), isNotEmpty);
    final done = events.last as StreamDone;
    expect(done.reply.lang, 'rn');
    expect(done.reply.intent, 'branch_info');
    expect(done.reply.text, contains('Ngozi'));
  });

  test('image on a text-only model → model.switched notice (F20)', () async {
    final c = b.createConversation(channel: 'web', lang: 'en', model: 'gemma:2b');
    final events = await b
        .sendMessage(c.id, MessageInput(text: 'What is this?', image: FileUpload(bytes: Uint8List(4), filename: 'a.jpg', mime: 'image/jpeg')))
        .toList();
    final sw = events.whereType<StreamModelSwitched>().single.change;
    expect(sw.usedModel, 'gemma4:e4b');
    expect(sw.capabilityNeeded, 'vision');
    expect((events.last as StreamDone).reply.modelNotice, sw.notice);
  });

  test('card block by chat: PIN turn redacted, then blocked with a reference', () async {
    final p = kMockPersonas.first;
    final c = b.createConversation(channel: 'web', lang: 'fr');
    Future<OutgoingReply> say(String t) async => ((await b.sendMessage(c.id, MessageInput(text: t)).toList()).last as StreamDone).reply;
    expect((await say('J\'ai perdu ma carte, bloquez-la')).expectedInput, 'account_number');
    expect((await say(p['account_number'] as String)).expectedInput, 'pin');
    expect((await say(p['pin'] as String)).expectedInput, 'confirmation');
    final done = await say('oui');
    expect(done.actions.single.reference, matches(r'^BLK-\d{4}-\d{5}$'));
    expect(b.detail(c.id).transcript.any((t) => t.text == p['pin']), isFalse);
    expect(b.detail(c.id).transcript.any((t) => t.text == '••••'), isTrue);
  });

  test('handoff → queue → claim by one agent, second claim 409', () async {
    final events = <WsEvent>[];
    final sub = b.agentEvents().listen(events.add);
    final c = b.createConversation(channel: 'phone', lang: 'rn');
    b.requestHandoff(c.id, 'customer_request');
    expect(b.queue().map((x) => x.id), contains(c.id));
    b.claim(c.id, 'agent-01');
    expect(() => b.claim(c.id, 'agent-02'), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'already_claimed')));
    expect(b.queue().map((x) => x.id), isNot(contains(c.id)));
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<CallHandoffRequestedEvent>(), isNotEmpty);
    expect(events.whereType<CallClaimedEvent>().single.agentId, 'agent-01');
    await sub.cancel();
  });

  test('card block REST: wrong PIN → identity_failed with attempts_left, 3rd → locked', () {
    const req = CardBlockRequest(accountNumber: '40012345670', pin: '0000', reason: 'lost', lang: 'en');
    expect(() => b.verifyCard(req), throwsA(isA<ApiError>().having((e) => e.details['attempts_left'], 'left', 2)));
    expect(() => b.verifyCard(req), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'identity_failed')));
    expect(() => b.verifyCard(req), throwsA(isA<ApiError>().having((e) => e.code, 'code', 'locked')));
  });

  test('USSD: dial, choose branches, get an END screen', () {
    InboundMessage m(String text) => InboundMessage(id: uuidV4(), channel: 'ussd', phone: '+25779000103', sessionId: 'ussd-1', lang: 'en', text: text, ts: DateTime.now().toUtc());
    expect(b.ussd(m('')).text, contains('1. Block a card'));
    expect(b.ussd(m('3')).text, contains('Choose the province'));
    final end = b.ussd(m('1'));
    expect(end.endSession, isTrue);
    expect(end.expectedInput, 'none');
  });

  test('stats are consistent', () {
    final s = b.stats();
    expect(s.aiResolutionRate, closeTo(s.resolvedByAi / (s.resolvedByAi + s.resolvedByAgent), 1e-9));
    expect(s.queueLength, b.queue().length);
  });
}
