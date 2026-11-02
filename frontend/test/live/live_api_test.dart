// G1 live check: T2's real repositories (dio REST, SSE, WebSocket) against a
// running backend. Skipped unless LIVE_API_URL is given, so CI stays offline:
//
//   flutter test test/live --dart-define=LIVE_API_URL=http://localhost:8000
//
// Uses the fictional demo customers from scripts/seed/demo_credentials.json.
@Tags(['live'])
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/env/env.dart';
import 'package:kabangutsi/core/util/format.dart';
import 'package:kabangutsi/data/api/api_client.dart';
import 'package:kabangutsi/data/api/ws_client.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/api_repositories.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';

const _url = String.fromEnvironment('LIVE_API_URL');
final _skip = _url.isEmpty ? 'set --dart-define=LIVE_API_URL=http://host:8000' : null;

void main() {
  final env = const Env(apiUrl: _url, useMock: false);
  late ApiClient api;
  late WsClient ws;
  late ApiConversationRepository conv;

  setUpAll(() {
    if (_url.isEmpty) return;
    api = ApiClient(env);
    ws = WsClient(env);
    conv = ApiConversationRepository(api, ws);
  });

  /// One chat turn over SSE; returns the final reply and the streamed text.
  Future<(OutgoingReply, String)> say(String convId, String text, {String? lang}) async {
    final buf = StringBuffer();
    OutgoingReply? done;
    await for (final ev in conv.sendMessage(convId, MessageInput(text: text, lang: lang)).timeout(const Duration(seconds: 90))) {
      switch (ev) {
        case StreamToken(:final delta):
          buf.write(delta);
        case StreamDone(:final reply):
          done = reply;
        case StreamError(:final error):
          throw error;
        default:
      }
    }
    expect(done, isNotNull, reason: 'SSE ended without done for "$text"');
    return (done!, buf.toString());
  }

  group('live G1', skip: _skip, () {
    test('models: capabilities come from the API', () async {
      final list = await ApiModelRepository(api).listModels();
      expect(list.models, isNotEmpty);
      expect(list.models.any((m) => m.capabilities.contains('completion')), isTrue);
    });

    // The 6 request types x 3 languages by chat (G1 acceptance).
    const utterances = {
      'fr': {
        'product_info': 'Quels sont les frais du compte courant ?',
        'account_opening': 'Comment ouvrir un compte ?',
        'card_block': "J'ai perdu ma carte, je veux la bloquer",
        'loan_info': 'Je veux un crédit de 5000000 FBu sur 24 mois',
        'complaint': "Je veux déposer une plainte : le guichet automatique a avalé mon argent et personne ne m'aide",
        'branch_info': "Quels sont les horaires de l'agence de Ngozi ?",
      },
      'en': {
        'product_info': 'What are the fees for a current account?',
        'account_opening': 'How do I open an account?',
        'card_block': 'I lost my card, please block it',
        'loan_info': 'I want a loan of 5000000 FBu over 24 months',
        'complaint': 'I want to file a complaint: the ATM took my money and nobody helps me',
        'branch_info': 'What are the opening hours of the Ngozi branch?',
      },
      'rn': {
        'product_info': 'Ni angahe batwara kuri konti?',
        'account_opening': 'Nokwugurura konti gute?',
        'card_block': 'Natakaje ikarata yanje, ndashaka kuyihagarika',
        'loan_info': 'Ndashaka inguzanyo ya 5000000 FBu mu mezi 24',
        // From scripts/eval/utterances.json cmp-02 (an unseen phrasing is reported to T1 in status/T2.md).
        'complaint': 'Icuma ca ATM nticampaye amafaranga ariko yakuwe kuri konti yanje',
        'branch_info': 'Ishami rya Ngozi rikora ku masaha angahe?',
      },
    };

    for (final MapEntry(key: lang, value: byIntent) in utterances.entries) {
      for (final MapEntry(key: intent, value: text) in byIntent.entries) {
        test('chat $lang $intent', () async {
          final c = await conv.create(channel: 'web', lang: lang);
          final (reply, streamed) = await say(c.id, text, lang: lang);
          expect(reply.text, isNotEmpty);
          expect(reply.lang, lang);
          expect(reply.intent, intent, reason: reply.text);
          if (streamed.isNotEmpty) expect(reply.text.replaceAll(RegExp(r'\s+'), ' ').trim(), contains(streamed.trim().split(' ').first));
          if (intent == 'card_block') expect(reply.expectedInput, anyOf('account_number', 'pin', 'text', 'choice'));
          await conv.end(c.id);
        }, timeout: const Timeout(Duration(minutes: 3)));
      }
    }

    test('card block REST: verify → confirm → BLK reference; wrong PIN → 403', () async {
      final cards = ApiCardRepository(api);
      // Single-card demo customers (PIN 1234). Earlier runs may have blocked or locked some:
      // use the first one that still has an active card. Re-seed the database to reset.
      const accounts = ['40012345672', '40012345670', '40012345671', '40012345678'];
      CardBlockPending? pending;
      String? account;
      for (final a in accounts) {
        try {
          pending = await cards.verify(CardBlockRequest(accountNumber: a, pin: '1234', reason: 'lost', lang: 'en'));
          account = a;
          break;
        } on ApiError catch (e) {
          if (e.status != 404 && e.status != 423) rethrow;
        }
      }
      expect(pending, isNotNull, reason: 'every demo card is already blocked: re-seed the database');
      final done = await cards.confirm(pending!.confirmationId);
      expect(done.reference, matches(RegExp(r'^BLK-\d{4}-\d{5}$')));
      expect(done.card.status, 'blocked');
      try {
        await cards.verify(CardBlockRequest(accountNumber: account!, pin: '0000', reason: 'lost', lang: 'en'));
        fail('wrong PIN accepted');
      } on ApiError catch (e) {
        expect(e.status, anyOf(403, 423)); // identity is checked first (423 once locked)
      }
    });

    test('card block REST: several cards → 422 details.cards', () async {
      try {
        await ApiCardRepository(api).verify(const CardBlockRequest(accountNumber: '40012345679', pin: '1234', reason: 'lost', lang: 'fr'));
        fail('expected 422');
      } on ApiError catch (e) {
        expect(e.status, 422);
        expect(e.details['cards'], containsAll(['7710', '7711']));
      }
    });

    test('loans: products and the contract example (5 000 000 FBu, 24 months → 244 816)', () async {
      final loans = ApiLoanRepository(api);
      for (final lang in ['fr', 'en', 'rn']) {
        expect(await loans.products(lang), isNotEmpty);
      }
      final products = await loans.products('fr');
      final p16 = products.firstWhere((p) => p.annualRatePct == 16);
      final sim = await loans.simulate(productId: p16.id, amount: 5000000, termMonths: 24, lang: 'rn');
      expect(sim.monthlyPayment, 244816);
      expect(sim.explanation, isNotEmpty);
    });

    test('branches: by province with hours and phone in 3 languages', () async {
      final repo = ApiBranchRepository(api);
      for (final lang in ['fr', 'en', 'rn']) {
        final all = await repo.list(lang: lang);
        expect(all, isNotEmpty);
        final byProvince = await repo.list(province: all.first.province, lang: lang);
        expect(byProvince.every((b) => b.province == all.first.province), isTrue);
        expect(byProvince.first.hoursText, isNotEmpty);
        expect(byProvince.first.phone, startsWith('+257'));
      }
    });

    test('tickets: create → TCK number, list, status update', () async {
      final repo = ApiTicketRepository(api);
      final t = await repo.create(const TicketCreate(
        phone: '+25779000103',
        category: 'atm',
        urgency: 'medium',
        description: 'The ATM kept my card and my money at the market branch.',
        lang: 'en',
      ));
      expect(t.number, matches(RegExp(r'^TCK-\d{4}-\d{5}$')));
      final page = await repo.list(const TicketFilter(phone: '+25779000103'));
      expect(page.items.map((x) => x.id), contains(t.id));
      final updated = await repo.update(t.id, status: 'in_progress');
      expect(updated.status, 'in_progress');
    });

    test('USSD: *123# menu', () async {
      final r = await ApiUssdRepository(api).send(InboundMessage(
        id: uuidV4(),
        channel: 'ussd',
        phone: '+25779000102',
        sessionId: uuidV4(),
        lang: 'fr',
        text: '*123#',
        ts: DateTime.now().toUtc(),
      ));
      expect(r.text, contains('1'));
      expect(r.endSession, isFalse);
    });

    test('handoff → queue → two agents claim at once: one wins, one gets 409', () async {
      final agents = ApiAgentRepository(api, ws);
      final list = await agents.agents();
      expect(list.length, greaterThanOrEqualTo(2));
      final events = agents.events(list[0].id);
      final handoffSeen = Completer<void>();
      String? convId;
      final sub = events.listen((e) {
        if (e is CallHandoffRequestedEvent && e.call.id == convId && !handoffSeen.isCompleted) handoffSeen.complete();
      });
      final c = await conv.create(channel: 'web', lang: 'fr');
      convId = c.id;
      await say(c.id, 'Bonjour');
      await conv.requestHandoff(c.id);
      await handoffSeen.future.timeout(const Duration(seconds: 30));
      final queue = await agents.queue();
      expect(queue.map((x) => x.id), contains(c.id));

      final results = await Future.wait([
        agents.claim(c.id, list[0].id).then<Object>((v) => v, onError: (Object e) => e),
        agents.claim(c.id, list[1].id).then<Object>((v) => v, onError: (Object e) => e),
      ]);
      expect(results.whereType<CallDetail>().length, 1);
      expect(results.whereType<ApiError>().single.status, 409);

      final winner = results.indexWhere((r) => r is CallDetail);
      final detail = results[winner] as CallDetail;
      expect(detail.transcript, isNotEmpty);
      await agents.sendMessage(c.id, list[winner].id, 'Bonjour, je suis votre conseiller.');
      await agents.end(c.id, list[winner].id);
      expect((await agents.stats()).totalCalls, greaterThan(0));
      await sub.cancel();
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
