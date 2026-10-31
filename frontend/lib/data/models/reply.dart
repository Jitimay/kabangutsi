import 'package:equatable/equatable.dart';

import 'attachment.dart';
import 'json.dart';

/// `Action` of message.schema.json.
class ReplyAction extends Equatable {
  const ReplyAction({required this.type, required this.status, this.reference, this.data = const {}});

  factory ReplyAction.fromJson(Json j) => ReplyAction(
        type: j['type'] as String,
        status: j['status'] as String,
        reference: j['reference'] as String?,
        data: (j['data'] as Json?) ?? const {},
      );

  final String type;
  final String status;
  final String? reference;
  final Json data;

  Json toJson() => {'type': type, 'status': status, 'reference': reference, 'data': data};

  @override
  List<Object?> get props => [type, status, reference, data];
}

/// `OutgoingReply` of message.schema.json.
class OutgoingReply extends Equatable {
  const OutgoingReply({
    required this.id,
    required this.conversationId,
    required this.inReplyTo,
    required this.channel,
    required this.phone,
    required this.sessionId,
    required this.lang,
    required this.text,
    required this.shortText,
    required this.speaker,
    required this.intent,
    required this.actions,
    required this.attachments,
    required this.expectedInput,
    required this.handoff,
    required this.endSession,
    required this.modelUsed,
    required this.modelNotice,
    required this.ts,
  });

  factory OutgoingReply.fromJson(Json j) => OutgoingReply(
        id: j['id'] as String,
        conversationId: j['conversation_id'] as String,
        inReplyTo: j['in_reply_to'] as String?,
        channel: j['channel'] as String,
        phone: j['phone'] as String?,
        sessionId: j['session_id'] as String,
        lang: j['lang'] as String,
        text: j['text'] as String,
        shortText: j['short_text'] as String,
        speaker: j['speaker'] as String,
        intent: j['intent'] as String?,
        actions: parseList(j['actions'], ReplyAction.fromJson),
        attachments: parseList(j['attachments'], Attachment.fromJson),
        expectedInput: j['expected_input'] as String,
        handoff: j['handoff'] as bool,
        endSession: j['end_session'] as bool,
        modelUsed: j['model_used'] as String?,
        modelNotice: j['model_notice'] as String?,
        ts: parseTs(j['ts']),
      );

  final String id;
  final String conversationId;
  final String? inReplyTo;
  final String channel;
  final String? phone;
  final String sessionId;
  final String lang;
  final String text;
  final String shortText;

  /// ai | agent | system
  final String speaker;
  final String? intent;
  final List<ReplyAction> actions;
  final List<Attachment> attachments;

  /// text | pin | date_of_birth | account_number | confirmation | menu_choice | none
  final String expectedInput;
  final bool handoff;
  final bool endSession;
  final String? modelUsed;
  final String? modelNotice;
  final DateTime ts;

  Json toJson() => {
        'id': id,
        'conversation_id': conversationId,
        'in_reply_to': inReplyTo,
        'channel': channel,
        'phone': phone,
        'session_id': sessionId,
        'lang': lang,
        'text': text,
        'short_text': shortText,
        'speaker': speaker,
        'intent': intent,
        'actions': actions.map((a) => a.toJson()).toList(),
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'expected_input': expectedInput,
        'handoff': handoff,
        'end_session': endSession,
        'model_used': modelUsed,
        'model_notice': modelNotice,
        'ts': tsOf(ts),
      };

  @override
  List<Object?> get props => [id, conversationId, text, speaker, expectedInput, handoff, endSession, modelUsed, modelNotice, actions, attachments, ts];
}

/// `InboundMessage` of message.schema.json (used by the USSD simulator).
class InboundMessage extends Equatable {
  const InboundMessage({
    required this.id,
    required this.channel,
    required this.phone,
    required this.sessionId,
    required this.lang,
    required this.text,
    this.attachments = const [],
    required this.ts,
  });

  final String id;
  final String channel;
  final String? phone;
  final String sessionId;
  final String? lang;
  final String text;
  final List<Attachment> attachments;
  final DateTime ts;

  Json toJson() => {
        'id': id,
        'channel': channel,
        'phone': phone,
        'session_id': sessionId,
        'lang': lang,
        'text': text,
        'attachments': attachments.map((a) => a.toJson()).toList(),
        'ts': tsOf(ts),
      };

  @override
  List<Object?> get props => [id, channel, phone, sessionId, lang, text, attachments, ts];
}
