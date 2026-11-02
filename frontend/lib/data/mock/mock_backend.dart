import 'dart:async';
import 'dart:math';

import 'package:get_it/get_it.dart';

import '../../core/env/env.dart';
import '../../core/util/format.dart';
import '../models/models.dart';
import '../repositories/repositories.dart';
import 'mock_seed.dart';
import 'mock_texts.dart';

/// Registers the in-memory mock implementations of every repository
/// (USE_MOCK=true, until G1). It follows contracts/openapi.yaml and ws_events.json
/// so screens behave the same against the real backend.
void registerMockRepositories(GetIt sl) {
  final b = MockBackend();
  final env = sl<Env>();
  sl
    ..registerSingleton<MockBackend>(b, dispose: (b) => b.dispose())
    ..registerLazySingleton<ModelRepository>(() => MockModelRepository(b))
    ..registerLazySingleton<ConversationRepository>(() => MockConversationRepository(b))
    ..registerLazySingleton<FileRepository>(() => MockFileRepository(b, env))
    ..registerLazySingleton<CardRepository>(() => MockCardRepository(b))
    ..registerLazySingleton<DocumentRepository>(() => MockDocumentRepository(b))
    ..registerLazySingleton<LoanRepository>(() => MockLoanRepository(b))
    ..registerLazySingleton<TicketRepository>(() => MockTicketRepository(b))
    ..registerLazySingleton<BranchRepository>(() => MockBranchRepository(b))
    ..registerLazySingleton<UssdRepository>(() => MockUssdRepository(b))
    ..registerLazySingleton<AgentRepository>(() => MockAgentRepository(b));
}

class _Conv {
  _Conv(this.call);
  Call call;
  final transcript = <Turn>[];
  final modelEvents = <ModelSwitch>[];
  String? flow; // card block flow: account | secret | confirm
  Map<String, dynamic>? persona;
  int failures = 0;
}

class _Ussd {
  _Ussd(this.lang);
  String lang;
  String menu = 'main';
  int page = 0;
  List<String> provinces = const [];
}

/// Shared state of the mock backend.
class MockBackend {
  MockBackend({this.latency = const Duration(milliseconds: 250), this.tokenDelay = const Duration(milliseconds: 35), int seed = 7, this.simulateIncoming = true})
      : _rnd = Random(seed) {
    _seed();
  }

  final Duration latency;
  final Duration tokenDelay;
  final Random _rnd;
  final bool simulateIncoming;

  final _convs = <String, _Conv>{};
  final _tickets = <Ticket>[];
  final _ussd = <String, _Ussd>{};
  final _pending = <String, (CardBlockPending, Map<String, dynamic>)>{};
  final _cardFailures = <String, int>{};
  final _blocked = <String>{};
  final _bus = StreamController<WsEvent>.broadcast();
  int _ticketSeq = 42;
  int _blockSeq = 17;
  int _incoming = 0;
  Timer? _incomingTimer;

  static const visionModel = 'gemma4:e4b';
  static const defaultModel = 'gemma:2b';

  final models = const ModelList(
    defaultModel: defaultModel,
    preferenceOrder: ['gemma4:e4b', 'gemma4:e2b', 'gemma:2b'],
    models: [
      LlmModel(name: 'gemma4:e4b', family: 'gemma4', parameterSize: '7.5B', quantization: 'Q4_K_M', sizeBytes: 9608350718, capabilities: ['completion', 'vision', 'audio', 'tools', 'thinking'], selectable: true, isDefault: false),
      LlmModel(name: 'gemma:2b', family: 'gemma', parameterSize: '3B', quantization: 'Q4_0', sizeBytes: 1678456656, capabilities: ['completion'], selectable: true, isDefault: true),
      LlmModel(name: 'nomic-embed-text:latest', family: 'nomic-bert', parameterSize: '137M', quantization: 'F16', sizeBytes: 274302450, capabilities: ['embedding'], selectable: false, isDefault: false),
    ],
  );

  Future<void> wait() => latency == Duration.zero ? Future.value() : Future.delayed(latency);

  String id() => uuidV4(_rnd);
  DateTime now() => DateTime.now().toUtc();

  void _emit(WsEvent Function(String id, DateTime ts) make) => _bus.add(make(id(), now()));

  /// Agent role: every event (+ one `stats.updated` on connect).
  Stream<WsEvent> agentEvents() {
    late StreamController<WsEvent> c;
    StreamSubscription<WsEvent>? sub;
    c = StreamController<WsEvent>(
      onListen: () {
        c.add(StatsUpdatedEvent(id(), now(), stats()));
        sub = _bus.stream.listen(c.add);
        _startIncoming();
      },
      onCancel: () => sub?.cancel(),
    );
    return c.stream.asBroadcastStream();
  }

  /// Customer role: only events of this conversation.
  Stream<WsEvent> customerEvents(String convId) => _bus.stream.where((e) => switch (e) {
        CallTurnEvent(:final turn) => turn.callId == convId,
        CallHandoffRequestedEvent(:final call) => call.id == convId,
        CallClaimedEvent(:final call) => call.id == convId,
        CallEndedEvent(:final call) => call.id == convId,
        ModelSwitchedEvent(:final change) => change.callId == convId,
        _ => false,
      });

  // ---------------------------------------------------------------- seed
  void _seed() {
    final t0 = now();
    const intents = ['branch_info', 'card_block', 'loan_info', 'complaint', 'product_info', 'account_opening'];
    const channels = ['phone', 'web', 'ussd', 'sms', 'whatsapp'];
    const langs = ['rn', 'fr', 'en'];
    for (var i = 0; i < 24; i++) {
      final start = t0.subtract(Duration(minutes: 20 + i * 13));
      final byAgent = i % 5 == 0;
      final queued = byAgent ? start.add(const Duration(minutes: 2)) : null;
      final call = Call(
        id: id(), phone: '+257790001${(10 + i).toString().padLeft(2, '0')}', channel: channels[i % 5], lang: langs[i % 3],
        status: 'ended', resolvedBy: byAgent ? 'agent' : 'ai', model: defaultModel, lastIntent: intents[i % 6], urgency: 'low',
        frustration: 0.1, handoffReason: byAgent ? 'customer_request' : null, summary: null, claimedBy: byAgent ? 'agent-01' : null,
        startedAt: start, queuedAt: queued, claimedAt: queued?.add(Duration(seconds: 20 + i * 3)),
        endedAt: start.add(const Duration(minutes: 4)), waitSeconds: byAgent ? 20 + i * 3 : null,
      );
      _convs[call.id] = _Conv(call);
    }
    _seedQueued(
      lang: 'rn', channel: 'phone', phone: '+25779000101', intent: 'complaint', urgency: 'high', frustration: 0.86, reason: 'frustration',
      summary: 'Cliente kirundophone (Ngozi). Se plaint de frais de tenue de compte prélevés deux fois en octobre. Ticket TCK-2026-00042 créé (frais, urgence haute). Très frustrée, demande un remboursement.',
      lines: const ['Mwaramutse, amafaranga y\'ukubungabunga konti yanje yakuweko kabiri muri uku kwezi.', 'Mwanyatse amafaranga kabiri! Ndashaka kuvugana n\'umuntu.'],
      minutesAgo: 3,
    );
    _seedQueued(
      lang: 'fr', channel: 'web', phone: '+25779000102', intent: 'card_block', urgency: 'critical', frustration: 0.55, reason: 'identity_failed',
      summary: 'Client francophone. Carte perdue, veut la bloquer. 3 échecs de vérification d\'identité : à vérifier par un conseiller.',
      lines: const ['J\'ai perdu ma carte au marché, il faut la bloquer tout de suite.', '••••'],
      minutesAgo: 1,
    );
    for (final (i, c) in [('fees', 'high', 'open'), ('atm', 'medium', 'in_progress'), ('service_quality', 'low', 'resolved')].indexed) {
      _tickets.add(Ticket(
        id: id(), number: 'TCK-2026-${(40 + i).toString().padLeft(5, '0')}', callId: null, phone: '+25779000${110 + i}',
        category: c.$1, urgency: c.$2, status: c.$3, lang: langs[i],
        summary: const ['Frais de tenue de compte prélevés deux fois en octobre.', 'ATM in Gitega kept the card yesterday evening.', 'Umurongo muremure ku ishami rya Ngozi.'][i],
        assignedTo: c.$3 == 'open' ? null : 'agent-02', createdAt: t0.subtract(Duration(hours: 5 - i)), updatedAt: t0.subtract(Duration(hours: 4 - i)),
      ));
    }
  }

  void _seedQueued({required String lang, required String channel, required String phone, required String intent, required String urgency, required double frustration, required String reason, required String summary, required List<String> lines, required int minutesAgo}) {
    final start = now().subtract(Duration(minutes: minutesAgo + 3));
    final c = _Conv(Call(
      id: id(), phone: phone, channel: channel, lang: lang, status: 'queued', resolvedBy: null, model: defaultModel, lastIntent: intent,
      urgency: urgency, frustration: frustration, handoffReason: reason, summary: summary, claimedBy: null, startedAt: start,
      queuedAt: now().subtract(Duration(minutes: minutesAgo)), claimedAt: null, endedAt: null, waitSeconds: minutesAgo * 60,
    ));
    for (final (i, l) in lines.indexed) {
      c.transcript.add(_turn(c.call.id, 'customer', l, lang, intent: intent, frustration: frustration, at: start.add(Duration(seconds: 30 * i))));
    }
    _convs[c.call.id] = c;
  }

  /// Agent demo: a new call arrives in the queue every 45 s (max 3) to show live updates.
  void _startIncoming() {
    if (!simulateIncoming || _incomingTimer != null) return;
    _incomingTimer = Timer.periodic(const Duration(seconds: 45), (t) {
      if (_incoming >= 3) return t.cancel();
      _incoming++;
      final lang = ['en', 'rn', 'fr'][_incoming % 3];
      final conv = _newConv(channel: ['whatsapp', 'sms', 'phone'][_incoming % 3], phone: '+2577900012$_incoming', lang: lang, model: null);
      final text = pick(const {'fr': 'Je veux parler à un conseiller pour mon crédit.', 'en': 'I want to talk to someone about my loan application.', 'rn': 'Ndashaka kuvugana n\'umukozi ku vyerekeye inguzanyo.'}, lang);
      _addTurn(conv, _turn(conv.call.id, 'customer', text, lang, intent: 'loan_info', frustration: 0.3));
      _handoff(conv, 'customer_request', text);
    });
  }

  // ---------------------------------------------------------------- helpers
  Turn _turn(String callId, String speaker, String text, String lang, {String? intent, double? confidence, double? frustration, String? model, String? agentId, List<Attachment> attachments = const [], DateTime? at}) => Turn(
        id: id(), callId: callId, speaker: speaker, agentId: agentId, text: text, lang: lang, intent: intent, confidence: confidence,
        frustration: frustration, attachments: attachments, modelUsed: model, ts: at ?? now(),
      );

  void _addTurn(_Conv c, Turn t) {
    c.transcript.add(t);
    _emit((i, ts) => CallTurnEvent(i, ts, t));
  }

  _Conv _conv(String id) => _convs[id] ?? (throw const ApiError(code: 'not_found', message: 'Conversation not found', status: 404));

  _Conv _newConv({required String channel, String? phone, String? lang, String? model}) {
    final c = _Conv(Call(
      id: id(), phone: phone, channel: channel, lang: lang ?? 'fr', status: 'active', resolvedBy: null, model: model ?? defaultModel,
      lastIntent: null, urgency: 'low', frustration: 0, handoffReason: null, summary: null, claimedBy: null, startedAt: now(),
      queuedAt: null, claimedAt: null, endedAt: null, waitSeconds: null,
    ));
    _convs[c.call.id] = c;
    _emit((i, ts) => CallStartedEvent(i, ts, c.call));
    return c;
  }

  OutgoingReply _reply(_Conv c, String text, {String speaker = 'ai', String? inReplyTo, String? intent, List<ReplyAction> actions = const [], String expected = 'text', bool handoff = false, bool end = false, String? model, String? notice, String? lang}) {
    final short = text.length <= 160 ? text : '${text.substring(0, 157)}...';
    return OutgoingReply(
      id: id(), conversationId: c.call.id, inReplyTo: inReplyTo, channel: c.call.channel, phone: c.call.phone, sessionId: c.call.id,
      lang: lang ?? c.call.lang, text: text, shortText: short, speaker: speaker, intent: intent, actions: actions, attachments: const [],
      expectedInput: expected, handoff: handoff, endSession: end, modelUsed: model, modelNotice: notice, ts: now(),
    );
  }

  static String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('ç', 'c');

  static bool _any(String t, List<String> words) => words.any(t.contains);

  static String? detectLang(String text) {
    final t = ' ${norm(text)} ';
    int score(List<String> w) => w.where((x) => t.contains(x)).length;
    final s = {
      'rn': score(const ['ndashaka', 'ishami', 'amafaranga', 'ikarata', 'murakoze', 'gute', 'ryari', 'inguzanyo', 'mwiriwe', 'amakuru', 'konti', 'yanje', 'umukozi', 'bwakeye', ' ego', ' oya', 'nshaka', 'ndagusavye', 'mwaramutse', 'kabiri', 'itako', 'ryugurura']),
      'en': score(const [' the ', ' my ', ' i ', ' want', 'hello', ' hi ', 'please', ' how ', ' what', 'where', ' when', 'branch', ' open', 'lost', ' yes', ' no ', 'loan', 'months']),
      'fr': score(const [' je ', ' mon ', ' ma ', 'bonjour', 'comment', ' pour ', 'agence', 'credit', 'voudrais', ' est ', ' oui', ' non', ' mois', 'carte', 'quelle', 'heure']),
    };
    final best = s.entries.reduce((a, b) => b.value > a.value ? b : a);
    return best.value == 0 ? null : best.key;
  }

  static String detectIntent(String text) {
    final t = norm(text);
    if (_any(t, const ['conseiller', 'agent', 'humain', 'human', 'someone', 'umukozi', 'umuntu', 'quelqu'])) return 'handoff';
    if (_any(t, const ['carte', 'card', 'ikarata', 'karata']) && _any(t, const ['bloq', 'perdu', 'vol', 'lost', 'stolen', 'block', 'swallow', 'avale', 'yatakaye', 'yibwe', 'hagarik', 'zibwe', 'ntakarata'])) return 'card_block';
    if (_any(t, const ['plainte', 'reclamation', 'complain', 'itako', 'ikirego', 'frais', 'fees', 'preleve', 'charged', 'twice', 'kabiri', 'rembours', 'refund'])) return 'complaint';
    if (_any(t, const ['credit', 'pret', 'loan', 'inguzanyo', 'ingurane', 'emprunt', 'borrow'])) return 'loan_info';
    if (_any(t, const ['agence', 'branch', 'ishami', 'amashami', 'heure', 'hours', 'horaire', 'ouvert', 'ryugurura', 'amasaha', 'ferme', 'opening'])) return 'branch_info';
    if (_any(t, const ['ouvrir', 'open an account', 'open account', 'gufungura', 'kwugurura konti'])) return 'account_opening';
    return 'product_info';
  }

  static double frustrationOf(String text) {
    final t = norm(text);
    var f = 0.05 + '!'.allMatches(text).length * 0.15;
    if (_any(t, const ['nul', 'inacceptable', 'angry', 'unacceptable', 'terrible', 'furieux', 'ndababaye', 'ntibikwiye', 'twice', 'deux fois', 'kabiri'])) f += 0.45;
    return f.clamp(0, 1).toDouble();
  }

  Map<String, dynamic> _article(String topic) => kMockKbArticles.firstWhere((a) => a['topic'] == topic);

  /// First [n] sentences of a knowledge base article in [lang] (no invented facts).
  String kb(String topic, String lang, {int n = 2}) {
    final body = (_article(topic)[lang] as Map)['body'] as String;
    return body.split(RegExp(r'(?<=[.!?])\s+')).take(n).join(' ');
  }

  /// Best knowledge base article for free text (word overlap), or null.
  String? searchKb(String text, String lang) {
    final words = norm(text).split(RegExp(r'[^a-z0-9]+')).where((w) => w.length > 3).toSet();
    var best = 0;
    String? topic;
    for (final a in kMockKbArticles) {
      final l = a[lang] as Map;
      final hay = norm('${l['title']} ${l['body']}');
      final s = words.where(hay.contains).length;
      if (s > best) (best, topic) = (s, a['topic'] as String);
    }
    return best >= 2 ? topic : null;
  }

  // ---------------------------------------------------------------- branches / loans
  Branch branch(Map<String, dynamic> b, String lang) {
    final hours = {for (final d in kWeekDays) d: DayHours.fromJson((b['hours'] as Map)[d])};
    return Branch(
      id: b['id'] as String, name: b['name'] as String, province: b['province'] as String, town: b['town'] as String,
      address: b['address'] as String, phone: b['phone'] as String, hours: hours, hoursText: hoursText(hours, lang),
      services: List<String>.from(b['services'] as List), isOpenNow: isOpen(hours, now()),
    );
  }

  static String hoursText(Map<String, DayHours?> h, String lang) {
    final names = kDayNames[lang]!;
    String range(DayHours d) => '${d.open}–${d.close}';
    final parts = <String>[];
    final mon = h['mon'];
    final weekSame = mon != null && ['tue', 'wed', 'thu', 'fri'].every((d) => h[d] == mon);
    if (weekSame) {
      parts.add('${names[0]}–${names[4]} ${range(mon)}');
    } else {
      for (var i = 0; i < 5; i++) {
        final d = h[kWeekDays[i]];
        parts.add(d == null ? fill(pick(kClosedOn, lang), {'day': names[i]}) : '${names[i]} ${range(d)}');
      }
    }
    for (final i in [5, 6]) {
      final d = h[kWeekDays[i]];
      parts.add(d == null ? fill(pick(kClosedOn, lang), {'day': names[i]}) : '${names[i]} ${range(d)}');
    }
    final s = parts.join(', ');
    return s[0].toUpperCase() + s.substring(1);
  }

  static bool isOpen(Map<String, DayHours?> h, DateTime utc) {
    final t = utc.add(const Duration(hours: 2)); // Africa/Bujumbura
    final d = h[kWeekDays[t.weekday - 1]];
    if (d == null) return false;
    final hm = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return hm.compareTo(d.open) >= 0 && hm.compareTo(d.close) < 0;
  }

  LoanProduct product(Map<String, dynamic> p, String lang) => LoanProduct(
        id: p['id'] as String, name: (p['name'] as Map)[lang] as String, description: (p['description'] as Map)[lang] as String,
        annualRatePct: (p['annual_rate_pct'] as num).toDouble(), minAmount: p['min_amount'] as int, maxAmount: p['max_amount'] as int,
        minTermMonths: p['min_term_months'] as int, maxTermMonths: p['max_term_months'] as int,
        requirements: List<String>.from((p['requirements'] as Map)[lang] as List),
      );

  LoanSimulation simulate(String productId, int amount, int term, String lang) {
    final raw = kMockLoanProducts.where((p) => p['id'] == productId).firstOrNull ?? (throw const ApiError(code: 'not_found', message: 'Loan product not found', status: 404));
    final p = product(raw, lang);
    if (amount < p.minAmount || amount > p.maxAmount || term < p.minTermMonths || term > p.maxTermMonths) {
      throw ApiError(
        code: 'out_of_range', status: 422,
        message: fill(pick(kOutOfRange, lang), {'min': formatFbu(p.minAmount), 'max': formatFbu(p.maxAmount), 'tmin': p.minTermMonths, 'tmax': p.maxTermMonths}),
        details: {'field': amount < p.minAmount || amount > p.maxAmount ? 'amount' : 'term_months', 'min': p.minAmount, 'max': p.maxAmount},
      );
    }
    final m = monthlyPayment(amount, p.annualRatePct, term);
    final total = m * term;
    final rate = p.annualRatePct == p.annualRatePct.roundToDouble() ? p.annualRatePct.toInt().toString() : p.annualRatePct.toString();
    return LoanSimulation(
      productId: p.id, productName: p.name, amount: amount, termMonths: term, annualRatePct: p.annualRatePct, monthlyPayment: m,
      totalPayment: total, totalInterest: total - amount, lang: lang,
      explanation: fill(pick(kLoanExplanation, lang), {'amount': formatFbu(amount), 'term': term, 'rate': rate, 'monthly': formatFbu(m), 'interest': formatFbu(total - amount)}),
    );
  }

  // ---------------------------------------------------------------- documents (F17)
  /// Fixed fictional extraction per doc type (same shape as ocr_api.yaml ExtractResult).
  /// The CNI has one low-confidence field, so it shows "to be checked" and hands off.
  /// A file name containing `ocr-down` simulates the OCR service being down (503).
  ExtractResult extractDocument({required FileUpload image, String? docType, String? conversationId}) {
    if (image.filename.contains('ocr-down')) {
      throw const ApiError(code: 'service_unavailable', message: 'OCR service unavailable', status: 503);
    }
    if (!kDocImageMimes.contains(image.mime)) {
      throw ApiError(code: 'unsupported_media_type', message: 'Unsupported image type: ${image.mime}', status: 415);
    }
    if (image.bytes.length > kDocMaxBytes) throw const ApiError(code: 'too_large', message: 'Image larger than 10 MB', status: 413);
    if (image.bytes.isEmpty) throw const ApiError(code: 'validation_error', message: 'image is required', details: {'field': 'image'}, status: 422);
    final name = image.filename.toLowerCase();
    final type = docType ??
        (name.contains('loan') ? 'loan_application' : name.contains('coffee') ? 'coffee_receipt' : name.contains('complaint') ? 'complaint_photo' : 'cni');
    ExtractedField f(String n, Object? v, double c) => ExtractedField(name: n, value: v, confidence: c, valid: true, needsReview: c < 0.8);
    final (fields, route) = switch (type) {
      'cni' => ([f('full_name', 'NIYONZIMA Claudine', 0.94), f('id_number', '0000/DEMO/123', 0.71), f('date_of_birth', '1990-03-14', 0.88)], 'account_opening'),
      'loan_application' => ([f('applicant_name', 'NDIKUMANA Jean-Bosco', 0.92), f('amount', 5000000, 0.9), f('term_months', 24, 0.95), f('product', 'Crédit commerce', 0.85)], 'loan_info'),
      'coffee_receipt' => ([f('farmer_name', 'IRAKOZE Divine', 0.9), f('weight_kg', 182.5, 0.86), f('amount', 638750, 0.83), f('date', '2026-10-28', 0.91)], 'loan_info'),
      _ => ([f('visible_text', 'DAB indisponible — carte retenue', 0.82)], 'complaint'),
    };
    final review = fields.any((x) => x.needsReview);
    final c = conversationId == null ? null : _convs[conversationId];
    if (review && c != null) _handoff(c, 'agent_review', null);
    return ExtractResult(
      docType: type, docTypeConfidence: docType == null ? 0.87 : 1.0, fields: fields, needsReview: review, routeTo: route,
      processingMs: 1200 + _rnd.nextInt(900), engine: 'paddleocr',
    );
  }

  // ---------------------------------------------------------------- cards
  CardBlockPending verifyCard(CardBlockRequest r) {
    final key = r.conversationId ?? r.accountNumber;
    if ((_cardFailures[key] ?? 0) >= 3) {
      throw const ApiError(code: 'locked', message: 'Too many failed attempts; an agent will call you back.', status: 423);
    }
    final persona = kMockPersonas.where((p) => p['account_number'] == r.accountNumber).firstOrNull;
    final ok = persona != null && ((r.pin != null && r.pin == persona['pin']) || (r.dateOfBirth != null && r.dateOfBirth == persona['date_of_birth']));
    if (!ok) {
      final n = (_cardFailures[key] ?? 0) + 1;
      _cardFailures[key] = n;
      if (n >= 3) {
        if (r.conversationId != null && _convs.containsKey(r.conversationId)) _handoff(_convs[r.conversationId]!, 'identity_failed', null);
        throw const ApiError(code: 'locked', message: 'Too many failed attempts; an agent will call you back.', status: 423);
      }
      throw ApiError(code: 'identity_failed', message: fill(pick(kIdentityFailed, r.lang), {'n': 3 - n}), details: {'attempts_left': 3 - n}, status: 403);
    }
    _cardFailures.remove(key);
    final cards = List<String>.from(persona['cards'] as List).where((c) => !_blocked.contains(c)).toList();
    final last4 = r.cardLast4 ?? (cards.isEmpty ? null : cards.first);
    if (last4 == null || !cards.contains(last4)) {
      throw const ApiError(code: 'not_found', message: 'No active card for this account', status: 404);
    }
    const card = 'visa_debit';
    final pending = CardBlockPending(
      confirmationId: id(), expiresAt: now().add(const Duration(minutes: 5)), card: CardInfo(last4: last4, type: card, status: 'active'),
      message: fill(pick(kCardDetails, r.lang), {'last4': last4, 'type': 'Visa debit'}),
    );
    _pending[pending.confirmationId] = (pending, {'lang': r.lang});
    return pending;
  }

  CardBlockResult confirmCard(String confirmationId) {
    final entry = _pending.remove(confirmationId) ?? (throw const ApiError(code: 'not_found', message: 'Confirmation not found', status: 404));
    final (p, meta) = entry;
    if (now().isAfter(p.expiresAt)) throw const ApiError(code: 'expired', message: 'Confirmation expired', status: 410);
    _blocked.add(p.card.last4);
    final ref = 'BLK-2026-${(_blockSeq++).toString().padLeft(5, '0')}';
    return CardBlockResult(
      reference: ref, card: CardInfo(last4: p.card.last4, type: p.card.type, status: 'blocked'), blockedAt: now(),
      message: fill(pick(kBlocked, meta['lang'] as String), {'last4': p.card.last4, 'ref': ref}),
    );
  }

  // ---------------------------------------------------------------- tickets
  Ticket createTicket(TicketCreate t) {
    final ticket = Ticket(
      id: id(), number: 'TCK-2026-${(++_ticketSeq).toString().padLeft(5, '0')}', callId: t.conversationId,
      phone: t.phone ?? (t.conversationId == null ? null : _convs[t.conversationId]?.call.phone), category: t.category, urgency: t.urgency,
      summary: t.description.length > 200 ? '${t.description.substring(0, 197)}...' : t.description, status: 'open', lang: t.lang,
      attachments: t.attachments, createdAt: now(), updatedAt: now(),
    );
    _tickets.insert(0, ticket);
    _emit((i, ts) => TicketCreatedEvent(i, ts, ticket));
    _emitStats();
    return ticket;
  }

  TicketPage listTickets(TicketFilter f) {
    final all = _tickets.where(f.matches).toList();
    return TicketPage(items: all.skip(f.offset).take(f.limit).toList(), total: all.length);
  }

  Ticket updateTicket(String idOrNumber, {String? status, String? urgency, String? Function()? assignedTo}) {
    final i = _tickets.indexWhere((t) => t.id == idOrNumber || t.number == idOrNumber);
    if (i < 0) throw const ApiError(code: 'not_found', message: 'Ticket not found', status: 404);
    final old = _tickets[i];
    final t = Ticket(
      id: old.id, number: old.number, callId: old.callId, phone: old.phone, customerName: old.customerName, category: old.category,
      urgency: urgency ?? old.urgency, summary: old.summary, status: status ?? old.status, lang: old.lang,
      assignedTo: assignedTo != null ? assignedTo() : old.assignedTo, attachments: old.attachments, createdAt: old.createdAt, updatedAt: now(),
    );
    _tickets[i] = t;
    _emit((i, ts) => TicketUpdatedEvent(i, ts, t));
    _emitStats();
    return t;
  }

  // ---------------------------------------------------------------- stats
  Stats stats() {
    final calls = _convs.values.map((c) => c.call).toList();
    final ai = calls.where((c) => c.resolvedBy == 'ai').length;
    final ag = calls.where((c) => c.resolvedBy == 'agent').length;
    final waits = calls.map((c) => c.waitSeconds).whereType<int>().toList();
    final intents = <String, int>{};
    for (final c in calls) {
      if (c.lastIntent != null) intents[c.lastIntent!] = (intents[c.lastIntent!] ?? 0) + 1;
    }
    final top = intents.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final t = now().add(const Duration(hours: 2));
    return Stats(
      periodStart: DateTime.utc(t.year, t.month, t.day).subtract(const Duration(hours: 2)),
      totalCalls: calls.length, resolvedByAi: ai, resolvedByAgent: ag, aiResolutionRate: ai + ag == 0 ? 0 : ai / (ai + ag),
      avgWaitSeconds: waits.isEmpty ? 0 : waits.reduce((a, b) => a + b) / waits.length,
      queueLength: calls.where((c) => c.status == 'queued').length, activeCalls: calls.where((c) => c.status == 'active' || c.status == 'with_agent').length,
      openTickets: _tickets.where((x) => x.status == 'open' || x.status == 'in_progress').length,
      topIntents: top.take(8).map((e) => IntentCount(e.key, e.value)).toList(),
      byChannel: {for (final ch in ['phone', 'web', 'ussd', 'sms', 'whatsapp']) ch: calls.where((c) => c.channel == ch).length},
      byLang: {for (final l in ['fr', 'en', 'rn']) l: calls.where((c) => c.lang == l).length},
      updatedAt: now(),
    );
  }

  void _emitStats() => _emit((i, ts) => StatsUpdatedEvent(i, ts, stats()));

  // ---------------------------------------------------------------- conversations
  Conversation createConversation({required String channel, String? phone, String? lang, String? model}) {
    final c = _newConv(channel: channel, phone: phone, lang: lang, model: model);
    final greeting = _reply(c, pick(kMockGreeting, c.call.lang));
    _addTurn(c, _turn(c.call.id, 'ai', greeting.text, c.call.lang));
    _emitStats();
    return _conversation(c, greeting: greeting);
  }

  Conversation _conversation(_Conv c, {OutgoingReply? greeting}) => Conversation(
        id: c.call.id, channel: c.call.channel, phone: c.call.phone, lang: c.call.lang, model: c.call.model ?? defaultModel,
        status: c.call.status, startedAt: c.call.startedAt, greeting: greeting,
      );

  Conversation updateConversation(String convId, {String? model, String? lang}) {
    final c = _conv(convId);
    if (model != null && !models.models.any((m) => m.name == model && m.selectable)) {
      throw ApiError(code: 'validation_error', message: 'Unknown model $model', details: const {'field': 'model'}, status: 422);
    }
    final old = c.call;
    c.call = Call(
      id: old.id, phone: old.phone, customerName: old.customerName, channel: old.channel, lang: lang ?? old.lang, status: old.status,
      resolvedBy: old.resolvedBy, model: model ?? old.model, lastIntent: old.lastIntent, urgency: old.urgency, frustration: old.frustration,
      handoffReason: old.handoffReason, summary: old.summary, claimedBy: old.claimedBy, startedAt: old.startedAt, queuedAt: old.queuedAt,
      claimedAt: old.claimedAt, endedAt: old.endedAt, waitSeconds: old.waitSeconds,
    );
    return _conversation(c);
  }

  CallDetail detail(String convId) {
    final c = _conv(convId);
    var call = c.call;
    if (call.status == 'queued' && call.queuedAt != null) call = call.copyWith(waitSeconds: now().difference(call.queuedAt!).inSeconds);
    return CallDetail(call: call, transcript: List.of(c.transcript), tickets: _tickets.where((t) => t.callId == convId).toList(), modelEvents: List.of(c.modelEvents));
  }

  void _handoff(_Conv c, String reason, String? lastText) {
    if (c.call.status != 'active') return;
    final summary = c.call.summary ??
        'Client (${c.call.lang}) via ${c.call.channel}. Intention : ${c.call.lastIntent ?? 'other'}. '
            '${lastText == null ? '' : 'Dernier message : « $lastText ». '}Raison : $reason.';
    final urgency = reason == 'identity_failed' ? 'critical' : (c.call.frustration >= 0.8 ? 'high' : 'medium');
    c.call = c.call.copyWith(status: 'queued', queuedAt: now(), handoffReason: reason, summary: summary, urgency: urgency, waitSeconds: 0);
    _emit((i, ts) => CallHandoffRequestedEvent(i, ts, c.call, reason, summary, List.of(c.transcript)));
    _emitStats();
  }

  OutgoingReply requestHandoff(String convId, String reason) {
    final c = _conv(convId);
    if (c.call.status != 'active') throw const ApiError(code: 'conflict', message: 'Already queued, with an agent, or ended', status: 409);
    _handoff(c, reason, c.transcript.lastWhere((t) => t.speaker == 'customer', orElse: () => _turn(c.call.id, 'customer', '', c.call.lang)).text);
    final r = _reply(c, pick(kHandoff, c.call.lang), speaker: 'system', handoff: true, expected: 'none', intent: 'handoff');
    _addTurn(c, _turn(c.call.id, 'system', r.text, c.call.lang));
    return r;
  }

  Call endConversation(String convId) {
    final c = _conv(convId);
    if (c.call.status != 'ended') {
      final by = c.call.status == 'active' ? (c.call.queuedAt == null ? 'ai' : 'agent') : (c.call.status == 'queued' ? 'abandoned' : 'agent');
      c.call = c.call.copyWith(status: 'ended', endedAt: now(), resolvedBy: by);
      _emit((i, ts) => CallEndedEvent(i, ts, c.call));
      _emitStats();
    }
    return c.call;
  }

  /// SSE simulation of `POST /v1/conversations/{id}/messages`.
  Stream<ChatStreamEvent> sendMessage(String convId, MessageInput input) async* {
    final c = _conv(convId);
    await wait();
    if (c.call.status == 'ended') throw const ApiError(code: 'conflict', message: 'Conversation ended', status: 409);
    final secret = c.flow == 'secret';
    var text = input.text?.trim() ?? '';
    if (input.audio != null) text = pick(kMockTranscripts, c.call.lang); // mock STT
    final lang = input.lang ?? detectLang(text) ?? c.call.lang;
    final attachments = [
      if (input.image != null) Attachment(type: 'image', url: '/v1/files/${id()}', mime: input.image!.mime, name: input.image!.filename, sizeBytes: input.image!.bytes.length),
      if (input.audio != null) Attachment(type: 'audio', url: '/v1/files/${id()}', mime: input.audio!.mime, sizeBytes: input.audio!.bytes.length),
    ];
    final intent = c.flow != null ? 'card_block' : (text.isEmpty && input.image != null ? 'other' : detectIntent(text));
    final frustration = secret ? 0.0 : frustrationOf(text);
    final requested = input.model ?? c.call.model ?? defaultModel;
    final customer = _turn(c.call.id, 'customer', secret ? '••••' : text, lang, intent: secret ? null : intent, confidence: secret ? null : 0.86, frustration: frustration, model: requested, attachments: attachments);
    _addTurn(c, customer);
    c.call = c.call.copyWith(lastIntent: intent, frustration: max(c.call.frustration, frustration));

    if (c.call.status == 'queued' || c.call.status == 'with_agent') {
      if (c.call.status == 'with_agent') _suggest(c, customer, text);
      throw ApiError(code: 'conflict', message: pick(kForwarded, lang), status: 409);
    }
    yield StreamTurn(customer);

    // Model router (F20/F21): capability needed by the request.
    var used = requested;
    String? notice;
    final need = input.image != null ? 'vision' : (input.audio != null ? 'audio' : null);
    final reqModel = models.models.where((m) => m.name == requested).firstOrNull;
    if (need != null && !(reqModel?.can(need) ?? false)) {
      used = visionModel;
      notice = fill(pick(kSwitchNotice, lang), {'used': used, 'req': requested, 'what': pick(need == 'vision' ? kCannotReadImages : kCannotHearAudio, lang)});
      final change = ModelSwitch(id: id(), callId: c.call.id, requestedModel: requested, usedModel: used, capabilityNeeded: need, reason: 'capability_missing', fallbackPath: null, notice: notice, lang: lang, ts: now());
      c.modelEvents.add(change);
      _emit((i, ts) => ModelSwitchedEvent(i, ts, change));
      yield StreamModelSwitched(change);
    }

    final a = _answer(c, text, lang, intent, hasImage: input.image != null);
    for (final w in a.text.split(' ')) {
      if (tokenDelay > Duration.zero) await Future<void>.delayed(tokenDelay);
      yield StreamToken('$w ');
    }
    for (final (i, s) in a.text.split(RegExp(r'(?<=[.!?])\s+')).indexed) {
      yield StreamSentence(i, s, null);
    }
    final handoff = a.handoff != null || frustration >= 0.8;
    var r = _reply(c, a.text, inReplyTo: customer.id, intent: intent, actions: a.actions, expected: a.expected, model: a.usesLlm ? used : null, notice: notice, lang: lang);
    _addTurn(c, _turn(c.call.id, 'ai', a.text, lang, intent: intent, model: r.modelUsed));
    if (handoff) {
      _handoff(c, a.handoff ?? 'frustration', text);
      final h = pick(kHandoff, lang);
      r = _reply(c, a.handoff == null ? '${a.text} $h' : a.text, inReplyTo: customer.id, intent: intent, actions: [...a.actions, const ReplyAction(type: 'handoff', status: 'done')], expected: 'none', handoff: true, model: r.modelUsed, notice: notice, lang: lang);
    }
    yield StreamDone(r);
  }

  void _suggest(_Conv c, Turn customer, String text) {
    final topic = searchKb(text, c.call.lang) ?? {'complaint': 'complaint_process', 'card_block': 'card_lost_stolen', 'loan_info': 'loans_overview', 'branch_info': 'branch_hours_general'}[customer.intent];
    final items = [
      if (topic != null) SuggestionItem(text: kb(topic, c.call.lang), lang: c.call.lang, sourceIds: ['kb-${topic.replaceAll('_', '-')}-${c.call.lang}-0']),
      SuggestionItem(text: pick(kAgentGenericSuggestion, c.call.lang), lang: c.call.lang, sourceIds: const []),
    ];
    Timer(const Duration(milliseconds: 700), () {
      _emit((i, ts) => AgentSuggestionEvent(i, ts, Suggestion(callId: c.call.id, turnId: customer.id, suggestions: items, generatedMs: 700)));
    });
  }

  ({String text, List<ReplyAction> actions, String expected, String? handoff, bool usesLlm}) _answer(_Conv c, String text, String lang, String intent, {required bool hasImage}) {
    ({String text, List<ReplyAction> actions, String expected, String? handoff, bool usesLlm}) out(String t, {List<ReplyAction> actions = const [], String expected = 'text', String? handoff, bool llm = true}) =>
        (text: t, actions: actions, expected: expected, handoff: handoff, usesLlm: llm);

    // Card block flow: identity is checked in code, the secret never reaches the "model".
    switch (c.flow) {
      case 'account':
        final acc = RegExp(r'\d{11}').firstMatch(text.replaceAll(' ', ''))?.group(0);
        final p = kMockPersonas.where((x) => x['account_number'] == acc).firstOrNull;
        if (p == null) return out(pick(kAccountNotFound, lang), expected: 'account_number', llm: false);
        c
          ..persona = p
          ..flow = 'secret';
        return out(pick(kAskPin, lang), expected: 'pin', llm: false);
      case 'secret':
        final p = c.persona!;
        if (text == p['pin'] || text == p['date_of_birth']) {
          c.flow = 'confirm';
          return out(fill(pick(kConfirmBlock, lang), {'last4': (p['cards'] as List).first}), expected: 'confirmation', actions: const [ReplyAction(type: 'identity_check', status: 'done')], llm: false);
        }
        c.failures++;
        if (c.failures >= 3) {
          c.flow = null;
          return out(pick(kHandoff, lang), expected: 'none', handoff: 'identity_failed', actions: const [ReplyAction(type: 'identity_check', status: 'failed')], llm: false);
        }
        return out(fill(pick(kIdentityFailed, lang), {'n': 3 - c.failures}), expected: 'pin', actions: const [ReplyAction(type: 'identity_check', status: 'failed')], llm: false);
      case 'confirm':
        c.flow = null;
        final t = norm(text);
        if (_any(t, const ['oui', 'yes', 'ego', 'yego', 'ok', 'confirm'])) {
          final last4 = (c.persona!['cards'] as List).first as String;
          _blocked.add(last4);
          final ref = 'BLK-2026-${(_blockSeq++).toString().padLeft(5, '0')}';
          return out(fill(pick(kBlocked, lang), {'last4': last4, 'ref': ref}), actions: [ReplyAction(type: 'card_block', status: 'done', reference: ref, data: {'last4': last4})], llm: false);
        }
        return out(pick(kBlockCancelled, lang), llm: false);
    }

    if (hasImage && text.isEmpty) return out(pick(kImageReceived, lang));
    switch (intent) {
      case 'handoff':
        return out(pick(kHandoff, lang), expected: 'none', handoff: 'customer_request');
      case 'card_block':
        c.flow = 'account';
        c.failures = 0;
        return out('${kb('card_lost_stolen', lang, n: 1)} ${pick(kAskAccount, lang)}', expected: 'account_number');
      case 'loan_info':
        final t = norm(text).replaceAll(RegExp(r'(\d)[\s .](?=\d{3})'), r'$1');
        final millions = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:millions?|m\b|miliyoni)').firstMatch(t);
        final amount = millions != null
            ? (double.parse(millions.group(1)!.replaceAll(',', '.')) * 1000000).round()
            : RegExp(r'\d{5,}').allMatches(t).map((m) => int.parse(m.group(0)!)).fold<int?>(null, (a, b) => a == null || b > a ? b : a);
        final term = int.tryParse(RegExp(r'(\d{1,3})\s*(?:mois|months?|amezi|mezi)').firstMatch(t)?.group(1) ?? '') ??
            int.tryParse(RegExp(r'(?:amezi|mezi)\s*(\d{1,3})').firstMatch(t)?.group(1) ?? '');
        final productId = _any(t, const ['agri', 'ubuhinzi', 'farm', 'cafe', 'coffee']) ? 'agri_loan'
            : _any(t, const ['salaire', 'salary', 'umushahara']) ? 'salary_advance'
            : _any(t, const ['maison', 'housing', 'house', 'inzu', 'logement']) ? 'housing_loan'
            : _any(t, const ['ecole', 'school', 'scolaire', 'amashure']) ? 'school_fees_loan'
            : _any(t, const ['femme', 'women', 'abagore', 'groupe']) ? 'women_group_loan'
            : 'business_loan';
        if (amount != null && term != null) {
          try {
            final s = simulate(productId, amount, term, lang);
            return out(s.explanation, actions: [ReplyAction(type: 'loan_simulation', status: 'done', data: {'product_id': s.productId, 'amount': s.amount, 'term_months': s.termMonths, 'monthly_payment': s.monthlyPayment})]);
          } on ApiError catch (e) {
            return out(e.message);
          }
        }
        final list = kMockLoanProducts.map((p) => '${(p['name'] as Map)[lang]} (${p['annual_rate_pct']} %)').join(', ');
        return out(fill(pick(kLoanAsk, lang), {'list': list}));
      case 'branch_info':
        final t = norm(text);
        final b = kMockBranches.where((b) => t.contains(norm(b['town'] as String)) || t.contains(norm(b['province'] as String))).firstOrNull;
        if (b == null) return out(kb('branch_hours_general', lang));
        final br = branch(b, lang);
        return out(fill(pick(kBranchAnswer, lang), {'name': br.name, 'hours': br.hoursText, 'phone': formatPhone(br.phone)}));
      case 'complaint':
        final t = norm(text);
        final cat = _any(t, const ['frais', 'fees', 'amafaranga', 'charged', 'preleve']) ? 'fees'
            : _any(t, const ['atm', 'guichet', 'distributeur']) ? 'atm'
            : _any(t, const ['carte', 'card', 'ikarata']) ? 'card'
            : 'other';
        final ticket = createTicket(TicketCreate(conversationId: c.call.id, phone: c.call.phone, category: cat, urgency: frustrationOf(text) > 0.6 ? 'high' : 'medium', description: text, lang: lang));
        return out('${fill(pick(kTicketCreated, lang), {'ref': ticket.number})} ${kb('complaint_process', lang, n: 1)}', actions: [ReplyAction(type: 'ticket_created', status: 'done', reference: ticket.number, data: {'ticket_id': ticket.id})]);
      case 'account_opening':
        return out(kb('account_opening_individual', lang));
      default:
        final topic = searchKb(text, lang);
        if (topic == null) return out(pick(kNoAnswer, lang), expected: 'none', handoff: 'no_answer');
        return out(kb(topic, lang));
    }
  }

  // ---------------------------------------------------------------- agents
  List<Call> queue() {
    final q = _convs.values.where((c) => c.call.status == 'queued').map((c) => c.call.copyWith(waitSeconds: now().difference(c.call.queuedAt!).inSeconds)).toList()
      ..sort((a, b) {
        final u = Call.urgencyRank[a.urgency]!.compareTo(Call.urgencyRank[b.urgency]!);
        return u != 0 ? u : a.queuedAt!.compareTo(b.queuedAt!);
      });
    return q;
  }

  Agent agent(String agentId) => kMockAgents.map(Agent.fromJson).where((a) => a.id == agentId).firstOrNull ??
      (throw const ApiError(code: 'not_found', message: 'Agent not found', status: 404));

  CallDetail claim(String callId, String agentId) {
    final c = _conv(callId);
    final a = agent(agentId);
    if (c.call.status != 'queued') {
      throw ApiError(code: 'already_claimed', message: 'Call already claimed by ${c.call.claimedBy ?? '-'}', details: {'claimed_by': c.call.claimedBy}, status: 409);
    }
    c.call = c.call.copyWith(status: 'with_agent', claimedBy: agentId, claimedAt: now(), waitSeconds: now().difference(c.call.queuedAt!).inSeconds);
    _emit((i, ts) => CallClaimedEvent(i, ts, c.call, agentId, a.name));
    _emitStats();
    return detail(callId);
  }

  OutgoingReply agentMessage(String callId, String agentId, String text) {
    final c = _conv(callId);
    if (c.call.claimedBy != agentId || c.call.status != 'with_agent') {
      throw const ApiError(code: 'forbidden', message: 'Call not claimed by this agent', status: 403);
    }
    _addTurn(c, _turn(callId, 'agent', text, c.call.lang, agentId: agentId));
    return _reply(c, text, speaker: 'agent');
  }

  Call agentEnd(String callId, String agentId) {
    final c = _conv(callId);
    if (c.call.claimedBy != agentId) throw const ApiError(code: 'forbidden', message: 'Not this agent\'s call', status: 403);
    c.call = c.call.copyWith(status: 'ended', endedAt: now(), resolvedBy: 'agent');
    _emit((i, ts) => CallEndedEvent(i, ts, c.call));
    _emitStats();
    return c.call;
  }

  // ---------------------------------------------------------------- USSD (same knowledge base as the chat)
  OutgoingReply ussd(InboundMessage m) {
    if (m.channel != 'ussd') throw const ApiError(code: 'validation_error', message: 'channel mismatch', status: 422);
    var s = _ussd[m.sessionId];
    final input = m.text.trim();
    final conv = _convs.putIfAbsent(m.sessionId, () => _Conv(Call(
          id: id(), phone: m.phone, channel: 'ussd', lang: m.lang ?? 'fr', status: 'active', resolvedBy: null, model: null, lastIntent: null,
          urgency: 'low', frustration: 0, handoffReason: null, summary: null, claimedBy: null, startedAt: now(), queuedAt: null, claimedAt: null,
          endedAt: null, waitSeconds: null)));
    OutgoingReply screen(String text, {bool end = false, String? intent}) {
      if (end) {
        _ussd.remove(m.sessionId);
        conv.call = conv.call.copyWith(status: 'ended', endedAt: now(), resolvedBy: 'ai', lastIntent: intent);
      }
      final r = _reply(conv, text, inReplyTo: m.id, expected: end ? 'none' : 'menu_choice', end: end, lang: s?.lang ?? m.lang ?? 'fr', intent: intent);
      return OutgoingReply(
        id: r.id, conversationId: r.conversationId, inReplyTo: r.inReplyTo, channel: 'ussd', phone: m.phone, sessionId: m.sessionId, lang: r.lang,
        text: r.text, shortText: r.shortText, speaker: 'ai', intent: intent, actions: const [], attachments: const [], expectedInput: r.expectedInput,
        handoff: false, endSession: end, modelUsed: null, modelNotice: null, ts: r.ts,
      );
    }

    if (s == null || input.isEmpty) {
      s = _ussd[m.sessionId] = _Ussd(m.lang ?? 'fr');
      return screen(pick(kUssdMain, s.lang));
    }
    final lang = s.lang;
    String withInvalid(String menu) => '${pick(kUssdInvalid, lang)}\n$menu';
    final n = int.tryParse(input);
    switch (s.menu) {
      case 'main':
        switch (n) {
          case 1:
            return screen(kb('card_lost_stolen', lang), end: true, intent: 'card_block');
          case 2:
            s.menu = 'loans';
            return screen(_ussdLoans(lang));
          case 3:
            s
              ..menu = 'provinces'
              ..page = 0
              ..provinces = kMockBranches.map((b) => b['province'] as String).toSet().toList();
            return screen(_ussdProvinces(s));
          case 4:
            return screen(kb('complaint_process', lang), end: true, intent: 'complaint');
          case 5:
            s.menu = 'lang';
            return screen(kUssdLang);
        }
        return screen(withInvalid(pick(kUssdMain, lang)));
      case 'lang':
        final l = {1: 'fr', 2: 'en', 3: 'rn'}[n];
        if (l == null) return screen(withInvalid(kUssdLang));
        s
          ..lang = l
          ..menu = 'main';
        return screen(pick(kUssdMain, l));
      case 'loans':
        if (n == 0) {
          s.menu = 'main';
          return screen(pick(kUssdMain, lang));
        }
        if (n == null || n < 1 || n > kMockLoanProducts.length) return screen(withInvalid(_ussdLoans(lang)));
        final p = product(kMockLoanProducts[n - 1], lang);
        return screen(
            fill(pick(kUssdLoanLine, lang), {'name': p.name, 'rate': p.annualRatePct, 'min': formatFbu(p.minAmount), 'max': formatFbu(p.maxAmount), 'tmin': p.minTermMonths, 'tmax': p.maxTermMonths}),
            end: true, intent: 'loan_info');
      case 'provinces':
        if (n == 0) {
          s.menu = 'main';
          return screen(pick(kUssdMain, lang));
        }
        if (n == 9 && (s.page + 1) * 8 < s.provinces.length) {
          s.page++;
          return screen(_ussdProvinces(s));
        }
        final idx = s.page * 8 + (n ?? 0) - 1;
        if (n == null || n < 1 || n > 8 || idx >= s.provinces.length) return screen(withInvalid(_ussdProvinces(s)));
        final b = branch(kMockBranches.firstWhere((b) => b['province'] == s!.provinces[idx]), lang);
        return screen(fill(pick(kBranchAnswer, lang), {'name': b.name, 'hours': b.hoursText, 'phone': formatPhone(b.phone)}), end: true, intent: 'branch_info');
    }
    return screen(pick(kUssdMain, lang));
  }

  String _ussdLoans(String lang) => [
        pick(kUssdPickLoan, lang),
        for (final (i, p) in kMockLoanProducts.indexed) '${i + 1}. ${(p['name'] as Map)[lang]}',
        pick(kUssdBack, lang),
      ].join('\n');

  String _ussdProvinces(_Ussd s) {
    final page = s.provinces.skip(s.page * 8).take(8).toList();
    return [
      pick(kUssdPickProvince, s.lang),
      for (final (i, p) in page.indexed) '${i + 1}. $p',
      if ((s.page + 1) * 8 < s.provinces.length) pick(kUssdMore, s.lang),
      pick(kUssdBack, s.lang),
    ].join('\n');
  }

  void dispose() {
    _incomingTimer?.cancel();
    _bus.close();
  }
}

// ------------------------------------------------------------------ repositories

class MockModelRepository implements ModelRepository {
  MockModelRepository(this.b);
  final MockBackend b;

  @override
  Future<ModelList> listModels({bool refresh = false}) async {
    await b.wait();
    return b.models;
  }
}

class MockConversationRepository implements ConversationRepository {
  MockConversationRepository(this.b);
  final MockBackend b;

  @override
  Future<Conversation> create({required String channel, String? phone, String? lang, String? model}) async {
    await b.wait();
    return b.createConversation(channel: channel, phone: phone, lang: lang, model: model);
  }

  @override
  Future<Conversation> update(String conversationId, {String? model, String? lang}) async {
    await b.wait();
    return b.updateConversation(conversationId, model: model, lang: lang);
  }

  @override
  Future<CallDetail> get(String conversationId) async {
    await b.wait();
    return b.detail(conversationId);
  }

  @override
  Stream<ChatStreamEvent> sendMessage(String conversationId, MessageInput input) => b.sendMessage(conversationId, input);

  @override
  Future<OutgoingReply> requestHandoff(String conversationId, {String reason = 'customer_request'}) async {
    await b.wait();
    return b.requestHandoff(conversationId, reason);
  }

  @override
  Future<Call> end(String conversationId) async {
    await b.wait();
    return b.endConversation(conversationId);
  }

  @override
  Stream<WsEvent> events(String conversationId) => b.customerEvents(conversationId);
}

class MockDocumentRepository implements DocumentRepository {
  MockDocumentRepository(this.b);
  final MockBackend b;

  @override
  Future<ExtractResult> extract({required FileUpload image, String? docType, required String lang, String? conversationId}) async {
    await b.wait();
    return b.extractDocument(image: image, docType: docType, conversationId: conversationId);
  }
}

class MockFileRepository implements FileRepository {
  MockFileRepository(this.b, this.env);
  final MockBackend b;
  final Env env;

  @override
  Future<FileRef> upload(FileUpload file) async {
    await b.wait();
    if (file.bytes.length > 10 * 1024 * 1024) throw const ApiError(code: 'too_large', message: 'File too large', status: 413);
    final type = file.mime.startsWith('image/') ? 'image' : file.mime.startsWith('audio/') ? 'audio' : file.mime == 'application/pdf' ? 'pdf' : null;
    if (type == null) throw const ApiError(code: 'unsupported_media_type', message: 'Unsupported type', status: 415);
    final fid = b.id();
    return FileRef(id: fid, url: '/v1/files/$fid', type: type, mime: file.mime, sizeBytes: file.bytes.length, createdAt: b.now());
  }

  @override
  String resolve(String url) => url.startsWith('http') ? url : '${env.apiUrl}$url';
}

class MockCardRepository implements CardRepository {
  MockCardRepository(this.b);
  final MockBackend b;

  @override
  Future<CardBlockPending> verify(CardBlockRequest request) async {
    await b.wait();
    return b.verifyCard(request);
  }

  @override
  Future<CardBlockResult> confirm(String confirmationId) async {
    await b.wait();
    return b.confirmCard(confirmationId);
  }
}

class MockLoanRepository implements LoanRepository {
  MockLoanRepository(this.b);
  final MockBackend b;

  @override
  Future<List<LoanProduct>> products(String lang) async {
    await b.wait();
    return kMockLoanProducts.map((p) => b.product(p, lang)).toList();
  }

  @override
  Future<LoanSimulation> simulate({required String productId, required int amount, required int termMonths, required String lang, bool pdf = false, String? conversationId}) async {
    await b.wait();
    return b.simulate(productId, amount, termMonths, lang);
  }
}

class MockTicketRepository implements TicketRepository {
  MockTicketRepository(this.b);
  final MockBackend b;

  @override
  Future<TicketPage> list(TicketFilter filter) async {
    await b.wait();
    return b.listTickets(filter);
  }

  @override
  Future<Ticket> create(TicketCreate ticket) async {
    await b.wait();
    if (ticket.description.trim().length < 3) throw const ApiError(code: 'validation_error', message: 'description too short', details: {'field': 'description'}, status: 422);
    return b.createTicket(ticket);
  }

  @override
  Future<Ticket> update(String ticketId, {String? status, String? urgency, String? Function()? assignedTo}) async {
    await b.wait();
    return b.updateTicket(ticketId, status: status, urgency: urgency, assignedTo: assignedTo);
  }
}

class MockBranchRepository implements BranchRepository {
  MockBranchRepository(this.b);
  final MockBackend b;

  @override
  Future<List<Branch>> list({String? province, String? q, required String lang}) async {
    await b.wait();
    final p = province == null ? null : MockBackend.norm(province);
    final s = (q == null || q.isEmpty) ? null : MockBackend.norm(q);
    return kMockBranches
        .where((x) => p == null || MockBackend.norm(x['province'] as String) == p)
        .where((x) => s == null || MockBackend.norm('${x['name']} ${x['town']} ${x['province']}').contains(s))
        .map((x) => b.branch(x, lang))
        .toList();
  }
}

class MockUssdRepository implements UssdRepository {
  MockUssdRepository(this.b);
  final MockBackend b;

  @override
  Future<OutgoingReply> send(InboundMessage message) async {
    await b.wait();
    return b.ussd(message);
  }
}

class MockAgentRepository implements AgentRepository {
  MockAgentRepository(this.b);
  final MockBackend b;

  @override
  Future<List<Agent>> agents() async {
    await b.wait();
    return kMockAgents.map(Agent.fromJson).toList();
  }

  @override
  Future<List<Call>> queue() async {
    await b.wait();
    return b.queue();
  }

  @override
  Future<CallDetail> call(String callId) async {
    await b.wait();
    return b.detail(callId);
  }

  @override
  Future<CallDetail> claim(String callId, String agentId) async {
    await b.wait();
    return b.claim(callId, agentId);
  }

  @override
  Future<OutgoingReply> sendMessage(String callId, String agentId, String text, {bool voice = false}) async {
    await b.wait();
    return b.agentMessage(callId, agentId, text);
  }

  @override
  Future<Call> end(String callId, String agentId, {String? note}) async {
    await b.wait();
    return b.agentEnd(callId, agentId);
  }

  @override
  Future<Stats> stats() async {
    await b.wait();
    return b.stats();
  }

  @override
  Stream<WsEvent> events(String agentId) => b.agentEvents();
}
