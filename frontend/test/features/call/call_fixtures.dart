import 'dart:typed_data';

import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';

// Fictional test data only.
const convId = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
final t0 = DateTime.utc(2026, 11, 2, 8, 15, 28);

OutgoingReply reply(String text, {String speaker = 'ai', bool handoff = false, bool end = false, List<Attachment> attachments = const []}) =>
    OutgoingReply(
      id: '0b1c2d3e-4f5a-4b6c-8d7e-9f0a1b2c3d4e',
      conversationId: convId,
      inReplyTo: null,
      channel: 'phone',
      phone: '+25779000101',
      sessionId: convId,
      lang: 'fr',
      text: text,
      shortText: text,
      speaker: speaker,
      intent: null,
      actions: const [],
      attachments: attachments,
      expectedInput: 'text',
      handoff: handoff,
      endSession: end,
      modelUsed: null,
      modelNotice: null,
      ts: t0,
    );

Conversation conversation({OutgoingReply? greeting}) => Conversation(
      id: convId,
      channel: 'phone',
      phone: '+25779000101',
      lang: 'fr',
      model: 'gemma:2b',
      status: 'active',
      startedAt: t0,
      greeting: greeting,
    );

Turn turn(String text, {String speaker = 'customer', List<Attachment> attachments = const []}) => Turn(
      id: '7e8f9a0b-1c2d-4e3f-a4b5-c6d7e8f9a0b1',
      callId: convId,
      speaker: speaker,
      agentId: speaker == 'agent' ? 'agent-01' : null,
      text: text,
      lang: 'fr',
      intent: null,
      confidence: null,
      frustration: null,
      attachments: attachments,
      modelUsed: null,
      ts: t0,
    );

Call call({String status = 'ended'}) => Call(
      id: convId,
      phone: '+25779000101',
      channel: 'phone',
      lang: 'fr',
      status: status,
      resolvedBy: status == 'ended' ? 'agent' : null,
      model: 'gemma:2b',
      lastIntent: null,
      urgency: 'low',
      frustration: 0,
      handoffReason: null,
      summary: null,
      claimedBy: null,
      startedAt: t0,
      queuedAt: null,
      claimedAt: null,
      endedAt: null,
      waitSeconds: null,
    );

final wavUpload = FileUpload(bytes: Uint8List.fromList(List.filled(64, 1)), filename: 'turn.wav', mime: 'audio/wav');
