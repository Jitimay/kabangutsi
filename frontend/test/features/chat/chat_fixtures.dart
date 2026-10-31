import 'package:kabangutsi/data/models/models.dart';

const convId = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';

OutgoingReply reply({
  String id = '0b1c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
  String text = 'Hello',
  String speaker = 'ai',
  String expectedInput = 'text',
  bool handoff = false,
  bool endSession = false,
  String? modelUsed = 'gemma:2b',
  String? modelNotice,
  List<ReplyAction> actions = const [],
}) =>
    OutgoingReply(
      id: id,
      conversationId: convId,
      inReplyTo: null,
      channel: 'web',
      phone: null,
      sessionId: convId,
      lang: 'fr',
      text: text,
      shortText: text,
      speaker: speaker,
      intent: null,
      actions: actions,
      attachments: const [],
      expectedInput: expectedInput,
      handoff: handoff,
      endSession: endSession,
      modelUsed: modelUsed,
      modelNotice: modelNotice,
      ts: DateTime.utc(2026, 11, 2, 8),
    );

Conversation conversation({OutgoingReply? greeting}) => Conversation(
      id: convId,
      channel: 'web',
      phone: null,
      lang: 'fr',
      model: 'gemma:2b',
      status: 'active',
      startedAt: DateTime.utc(2026, 11, 2, 8),
      greeting: greeting ?? reply(text: 'Bonjour, je suis Kabangutsi.', modelUsed: null),
    );

Turn turn({String id = 't1', String speaker = 'customer', String text = 'Bonjour'}) => Turn(
      id: id,
      callId: convId,
      speaker: speaker,
      text: text,
      lang: 'fr',
      intent: null,
      confidence: null,
      frustration: null,
      attachments: const [],
      modelUsed: null,
      ts: DateTime.utc(2026, 11, 2, 8),
    );

Call call({String status = 'with_agent'}) => Call(
      id: convId,
      phone: null,
      channel: 'web',
      lang: 'fr',
      status: status,
      resolvedBy: null,
      model: 'gemma:2b',
      lastIntent: null,
      urgency: 'low',
      frustration: 0,
      handoffReason: 'customer_request',
      summary: 'Résumé',
      claimedBy: 'agent-01',
      startedAt: DateTime.utc(2026, 11, 2, 8),
      queuedAt: DateTime.utc(2026, 11, 2, 8, 1),
      claimedAt: DateTime.utc(2026, 11, 2, 8, 2),
      endedAt: null,
      waitSeconds: 60,
    );

ModelSwitch modelSwitch() => ModelSwitch(
      id: 'm1',
      callId: convId,
      requestedModel: 'gemma:2b',
      usedModel: 'gemma4:e4b',
      capabilityNeeded: 'vision',
      reason: 'capability_missing',
      fallbackPath: null,
      notice: 'Modèle changé pour gemma4:e4b : gemma:2b ne peut pas lire les images.',
      lang: 'fr',
      ts: DateTime.utc(2026, 11, 2, 8),
    );
