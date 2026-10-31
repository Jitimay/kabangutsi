import 'package:kabangutsi/data/models/models.dart';
import 'package:kabangutsi/data/repositories/repositories.dart';
import 'package:mocktail/mocktail.dart';

class MockAgentRepository extends Mock implements AgentRepository {}

class MockTicketRepository extends Mock implements TicketRepository {}

final t0 = DateTime.utc(2026, 11, 2, 11, 40);

Call call(String id, {String urgency = 'medium', String status = 'queued', DateTime? queuedAt, String? claimedBy, String channel = 'phone'}) => Call(
      id: id,
      phone: '+25779000101',
      channel: channel,
      lang: 'rn',
      status: status,
      resolvedBy: null,
      model: 'gemma:2b',
      lastIntent: 'complaint',
      urgency: urgency,
      frustration: 0.5,
      handoffReason: 'frustration',
      summary: 'Résumé fictif',
      claimedBy: claimedBy,
      startedAt: t0,
      queuedAt: queuedAt ?? t0,
      claimedAt: null,
      endedAt: null,
      waitSeconds: 0,
    );

Turn turn(String id, String callId, {String speaker = 'customer', String text = 'Muraho', DateTime? ts}) => Turn(
      id: id,
      callId: callId,
      speaker: speaker,
      text: text,
      lang: 'rn',
      intent: null,
      confidence: null,
      frustration: null,
      attachments: const [],
      modelUsed: null,
      ts: ts ?? t0,
    );

Ticket ticket(String id, {String status = 'open', String urgency = 'high', String category = 'fees', DateTime? createdAt, String? assignedTo, String? callId}) => Ticket(
      id: id,
      number: 'TCK-2026-${id.padLeft(5, '0')}',
      callId: callId,
      phone: '+25779000101',
      category: category,
      urgency: urgency,
      summary: 'Fictional summary',
      status: status,
      lang: 'rn',
      assignedTo: assignedTo,
      createdAt: createdAt ?? t0,
      updatedAt: createdAt ?? t0,
    );

OutgoingReply agentReply(String id, String callId, String text) => OutgoingReply(
      id: id,
      conversationId: callId,
      inReplyTo: null,
      channel: 'phone',
      phone: '+25779000101',
      sessionId: callId,
      lang: 'rn',
      text: text,
      shortText: text,
      speaker: 'agent',
      intent: null,
      actions: const [],
      attachments: const [],
      expectedInput: 'text',
      handoff: false,
      endSession: false,
      modelUsed: null,
      modelNotice: null,
      ts: t0.add(const Duration(minutes: 1)),
    );

Stats stats({double rate = 0.8, DateTime? updatedAt}) => Stats(
      periodStart: DateTime.utc(2026, 11, 1, 22),
      totalCalls: 10,
      resolvedByAi: 8,
      resolvedByAgent: 2,
      aiResolutionRate: rate,
      avgWaitSeconds: 41.5,
      queueLength: 1,
      activeCalls: 2,
      openTickets: 3,
      topIntents: const [IntentCount('branch_info', 4)],
      byChannel: const {'phone': 5, 'web': 5},
      byLang: const {'fr': 3, 'en': 2, 'rn': 5},
      updatedAt: updatedAt ?? t0,
    );

const apiError = ApiError(code: 'internal_error', message: 'boom', status: 500);
