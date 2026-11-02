import 'package:equatable/equatable.dart';

import 'json.dart';
import 'reply.dart';

/// `Conversation` of openapi.yaml (conversation id == call id).
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.channel,
    required this.phone,
    required this.lang,
    required this.model,
    required this.status,
    required this.startedAt,
    this.greeting,
  });

  factory Conversation.fromJson(Json j) => Conversation(
        id: j['id'] as String,
        channel: j['channel'] as String,
        phone: j['phone'] as String?,
        lang: j['lang'] as String,
        model: j['model'] as String,
        status: j['status'] as String,
        startedAt: parseTs(j['started_at']),
        greeting: j['greeting'] == null ? null : OutgoingReply.fromJson(j['greeting'] as Json),
      );

  final String id;
  final String channel;
  final String? phone;
  final String lang;
  final String model;
  final String status;
  final DateTime startedAt;
  final OutgoingReply? greeting;

  @override
  List<Object?> get props => [id, channel, phone, lang, model, status, startedAt, greeting];
}
