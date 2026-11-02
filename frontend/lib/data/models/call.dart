import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'json.dart';
import 'ticket.dart';

/// `Call` of ws_events.json.
class Call extends Equatable {
  const Call({
    required this.id,
    required this.phone,
    this.customerName,
    required this.channel,
    required this.lang,
    required this.status,
    required this.resolvedBy,
    required this.model,
    required this.lastIntent,
    required this.urgency,
    required this.frustration,
    required this.handoffReason,
    required this.summary,
    required this.claimedBy,
    required this.startedAt,
    required this.queuedAt,
    required this.claimedAt,
    required this.endedAt,
    required this.waitSeconds,
  });

  factory Call.fromJson(Json j) => Call(
        id: j['id'] as String,
        phone: j['phone'] as String?,
        customerName: j['customer_name'] as String?,
        channel: j['channel'] as String,
        lang: j['lang'] as String,
        status: j['status'] as String,
        resolvedBy: j['resolved_by'] as String?,
        model: j['model'] as String?,
        lastIntent: j['last_intent'] as String?,
        urgency: j['urgency'] as String,
        frustration: toDouble(j['frustration']),
        handoffReason: j['handoff_reason'] as String?,
        summary: j['summary'] as String?,
        claimedBy: j['claimed_by'] as String?,
        startedAt: parseTs(j['started_at']),
        queuedAt: parseTsOrNull(j['queued_at']),
        claimedAt: parseTsOrNull(j['claimed_at']),
        endedAt: parseTsOrNull(j['ended_at']),
        waitSeconds: j['wait_seconds'] as int?,
      );

  final String id;
  final String? phone;
  final String? customerName;
  final String channel;
  final String lang;

  /// active | queued | with_agent | ended
  final String status;
  final String? resolvedBy;
  final String? model;
  final String? lastIntent;

  /// low | medium | high | critical
  final String urgency;
  final double frustration;
  final String? handoffReason;
  final String? summary;
  final String? claimedBy;
  final DateTime startedAt;
  final DateTime? queuedAt;
  final DateTime? claimedAt;
  final DateTime? endedAt;
  final int? waitSeconds;

  static const urgencyRank = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};

  Json toJson() => {
        'id': id,
        'phone': phone,
        if (customerName != null) 'customer_name': customerName,
        'channel': channel,
        'lang': lang,
        'status': status,
        'resolved_by': resolvedBy,
        'model': model,
        'last_intent': lastIntent,
        'urgency': urgency,
        'frustration': frustration,
        'handoff_reason': handoffReason,
        'summary': summary,
        'claimed_by': claimedBy,
        'started_at': tsOf(startedAt),
        'queued_at': tsOrNull(queuedAt),
        'claimed_at': tsOrNull(claimedAt),
        'ended_at': tsOrNull(endedAt),
        'wait_seconds': waitSeconds,
      };

  Call copyWith({String? status, String? claimedBy, DateTime? claimedAt, DateTime? endedAt, String? resolvedBy, String? lastIntent, String? summary, String? handoffReason, DateTime? queuedAt, String? urgency, double? frustration, int? waitSeconds}) => Call(
        id: id,
        phone: phone,
        customerName: customerName,
        channel: channel,
        lang: lang,
        status: status ?? this.status,
        resolvedBy: resolvedBy ?? this.resolvedBy,
        model: model,
        lastIntent: lastIntent ?? this.lastIntent,
        urgency: urgency ?? this.urgency,
        frustration: frustration ?? this.frustration,
        handoffReason: handoffReason ?? this.handoffReason,
        summary: summary ?? this.summary,
        claimedBy: claimedBy ?? this.claimedBy,
        startedAt: startedAt,
        queuedAt: queuedAt ?? this.queuedAt,
        claimedAt: claimedAt ?? this.claimedAt,
        endedAt: endedAt ?? this.endedAt,
        waitSeconds: waitSeconds ?? this.waitSeconds,
      );

  @override
  List<Object?> get props => [id, phone, customerName, channel, lang, status, resolvedBy, model, lastIntent, urgency, frustration, handoffReason, summary, claimedBy, startedAt, queuedAt, claimedAt, endedAt, waitSeconds];
}

/// `Turn` of ws_events.json. PIN / date-of-birth answers arrive redacted as "••••".
class Turn extends Equatable {
  const Turn({
    required this.id,
    required this.callId,
    required this.speaker,
    this.agentId,
    required this.text,
    required this.lang,
    required this.intent,
    required this.confidence,
    required this.frustration,
    required this.attachments,
    required this.modelUsed,
    required this.ts,
  });

  factory Turn.fromJson(Json j) => Turn(
        id: j['id'] as String,
        callId: j['call_id'] as String,
        speaker: j['speaker'] as String,
        agentId: j['agent_id'] as String?,
        text: j['text'] as String,
        lang: j['lang'] as String,
        intent: j['intent'] as String?,
        confidence: toDoubleOrNull(j['confidence']),
        frustration: toDoubleOrNull(j['frustration']),
        attachments: parseList(j['attachments'], Attachment.fromJson),
        modelUsed: j['model_used'] as String?,
        ts: parseTs(j['ts']),
      );

  final String id;
  final String callId;

  /// customer | ai | agent | system
  final String speaker;
  final String? agentId;
  final String text;
  final String lang;
  final String? intent;
  final double? confidence;
  final double? frustration;
  final List<Attachment> attachments;
  final String? modelUsed;
  final DateTime ts;

  Json toJson() => {
        'id': id,
        'call_id': callId,
        'speaker': speaker,
        'agent_id': agentId,
        'text': text,
        'lang': lang,
        'intent': intent,
        'confidence': confidence,
        'frustration': frustration,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'model_used': modelUsed,
        'ts': tsOf(ts),
      };

  @override
  List<Object?> get props => [id, callId, speaker, agentId, text, lang, intent, confidence, frustration, attachments, modelUsed, ts];
}

/// `ModelSwitch` of ws_events.json (F20/F21).
class ModelSwitch extends Equatable {
  const ModelSwitch({
    required this.id,
    required this.callId,
    required this.requestedModel,
    required this.usedModel,
    required this.capabilityNeeded,
    required this.reason,
    required this.fallbackPath,
    required this.notice,
    required this.lang,
    required this.ts,
  });

  factory ModelSwitch.fromJson(Json j) => ModelSwitch(
        id: j['id'] as String,
        callId: j['call_id'] as String,
        requestedModel: j['requested_model'] as String,
        usedModel: j['used_model'] as String?,
        capabilityNeeded: j['capability_needed'] as String,
        reason: j['reason'] as String,
        fallbackPath: j['fallback_path'] as String?,
        notice: j['notice'] as String,
        lang: j['lang'] as String,
        ts: parseTs(j['ts']),
      );

  final String id;
  final String callId;
  final String requestedModel;
  final String? usedModel;
  final String capabilityNeeded;
  final String reason;
  final String? fallbackPath;
  final String notice;
  final String lang;
  final DateTime ts;

  Json toJson() => {
        'id': id,
        'call_id': callId,
        'requested_model': requestedModel,
        'used_model': usedModel,
        'capability_needed': capabilityNeeded,
        'reason': reason,
        'fallback_path': fallbackPath,
        'notice': notice,
        'lang': lang,
        'ts': tsOf(ts),
      };

  @override
  List<Object?> get props => [id, callId, requestedModel, usedModel, capabilityNeeded, reason, fallbackPath, notice, lang, ts];
}

class SuggestionItem extends Equatable {
  const SuggestionItem({required this.text, required this.lang, required this.sourceIds});

  factory SuggestionItem.fromJson(Json j) =>
      SuggestionItem(text: j['text'] as String, lang: j['lang'] as String, sourceIds: parseStrings(j['source_ids']));

  final String text;
  final String lang;
  final List<String> sourceIds;

  Json toJson() => {'text': text, 'lang': lang, 'source_ids': sourceIds};

  @override
  List<Object?> get props => [text, lang, sourceIds];
}

/// `Suggestion` of ws_events.json (F11).
class Suggestion extends Equatable {
  const Suggestion({required this.callId, required this.turnId, required this.suggestions, required this.generatedMs});

  factory Suggestion.fromJson(Json j) => Suggestion(
        callId: j['call_id'] as String,
        turnId: j['turn_id'] as String,
        suggestions: parseList(j['suggestions'], SuggestionItem.fromJson),
        generatedMs: j['generated_ms'] as int,
      );

  final String callId;
  final String turnId;
  final List<SuggestionItem> suggestions;
  final int generatedMs;

  Json toJson() => {'call_id': callId, 'turn_id': turnId, 'suggestions': suggestions.map((s) => s.toJson()).toList(), 'generated_ms': generatedMs};

  @override
  List<Object?> get props => [callId, turnId, suggestions, generatedMs];
}

/// `CallDetail` of openapi.yaml (F9).
class CallDetail extends Equatable {
  const CallDetail({required this.call, required this.transcript, required this.tickets, required this.modelEvents});

  factory CallDetail.fromJson(Json j) => CallDetail(
        call: Call.fromJson(j['call'] as Json),
        transcript: parseList(j['transcript'], Turn.fromJson),
        tickets: parseList(j['tickets'], Ticket.fromJson),
        modelEvents: parseList(j['model_events'], ModelSwitch.fromJson),
      );

  final Call call;
  final List<Turn> transcript;
  final List<Ticket> tickets;
  final List<ModelSwitch> modelEvents;

  Json toJson() => {
        'call': call.toJson(),
        'transcript': transcript.map((t) => t.toJson()).toList(),
        'tickets': tickets.map((t) => t.toJson()).toList(),
        'model_events': modelEvents.map((m) => m.toJson()).toList(),
      };

  @override
  List<Object?> get props => [call, transcript, tickets, modelEvents];
}
