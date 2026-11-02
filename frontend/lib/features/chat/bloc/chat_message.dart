import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../../../data/models/models.dart';

enum ChatAuthor { customer, ai, agent, system, notice, agentJoined }

/// One bubble of the chat. For [ChatAuthor.agentJoined] [text] is the agent name.
class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.author,
    required this.text,
    this.streaming = false,
    this.masked = false,
    this.modelUsed,
    this.references = const [],
    this.attachments = const [],
    this.image,
    this.workingModel,
    this.startedAt,
    this.elapsed,
  });

  factory ChatMessage.fromReply(OutgoingReply r) => ChatMessage(
        id: r.id,
        author: switch (r.speaker) {
          'agent' => ChatAuthor.agent,
          'system' => ChatAuthor.system,
          _ => ChatAuthor.ai,
        },
        text: r.text,
        modelUsed: r.modelUsed,
        references: [for (final a in r.actions) ?a.reference],
        attachments: [for (final a in r.attachments) if (a.type != 'audio') a],
      );

  final String id;
  final ChatAuthor author;
  final String text;

  /// True while tokens are still arriving.
  final bool streaming;

  /// PIN / date-of-birth answer: shown as "••••", the real value is never kept.
  final bool masked;
  final String? modelUsed;

  /// Card block / ticket references (BLK-…, TCK-…) of the turn's actions.
  final List<String> references;
  final List<Attachment> attachments;

  /// Preview of an image sent by the customer.
  final Uint8List? image;

  /// Pending reply: the model expected to answer (the session's choice; the switched model after
  /// `model.switched`). Null = the backend default, named by the UI.
  final String? workingModel;

  /// Pending reply: when the customer sent the turn (drives the live timer).
  final DateTime? startedAt;

  /// Finished reply: time from sending to the full answer, measured in the app.
  final Duration? elapsed;

  ChatMessage copyWith({String? text, bool? streaming, String? Function()? workingModel, Duration? elapsed}) =>
      ChatMessage(
        id: id,
        author: author,
        text: text ?? this.text,
        streaming: streaming ?? this.streaming,
        masked: masked,
        modelUsed: modelUsed,
        references: references,
        attachments: attachments,
        image: image,
        workingModel: workingModel != null ? workingModel() : this.workingModel,
        startedAt: startedAt,
        elapsed: elapsed ?? this.elapsed,
      );

  @override
  List<Object?> get props =>
      [id, author, text, streaming, masked, modelUsed, references, attachments, image?.length, workingModel, startedAt, elapsed];
}
