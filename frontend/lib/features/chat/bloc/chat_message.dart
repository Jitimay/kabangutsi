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

  ChatMessage copyWith({String? text, bool? streaming}) => ChatMessage(
        id: id,
        author: author,
        text: text ?? this.text,
        streaming: streaming ?? this.streaming,
        masked: masked,
        modelUsed: modelUsed,
        references: references,
        attachments: attachments,
        image: image,
      );

  @override
  List<Object?> get props => [id, author, text, streaming, masked, modelUsed, references, attachments, image?.length];
}
