import 'dart:typed_data';

import 'package:equatable/equatable.dart';

import '../models/models.dart';

/// A file picked or recorded on the device, sent as multipart.
class FileUpload extends Equatable {
  const FileUpload({required this.bytes, required this.filename, required this.mime});

  final Uint8List bytes;
  final String filename;
  final String mime;

  @override
  List<Object?> get props => [filename, mime, bytes.length];
}

/// One customer turn for `POST /v1/conversations/{id}/messages`.
class MessageInput extends Equatable {
  const MessageInput({this.text, this.image, this.audio, this.model, this.lang, this.voice = false});

  final String? text;
  final FileUpload? image;
  final FileUpload? audio;
  final String? model;
  final String? lang;
  final bool voice;

  @override
  List<Object?> get props => [text, image, audio, model, lang, voice];
}

abstract interface class ModelRepository {
  Future<ModelList> listModels({bool refresh = false});
}

abstract interface class ConversationRepository {
  Future<Conversation> create({required String channel, String? phone, String? lang, String? model});
  Future<Conversation> update(String conversationId, {String? model, String? lang});
  Future<CallDetail> get(String conversationId);

  /// SSE stream: turn → model.switched? → token* → sentence* → done | error.
  Stream<ChatStreamEvent> sendMessage(String conversationId, MessageInput input);
  Future<OutgoingReply> requestHandoff(String conversationId, {String reason = 'customer_request'});
  Future<Call> end(String conversationId);

  /// Customer-side live events for this conversation (agent replies after handoff).
  Stream<WsEvent> events(String conversationId);
}

abstract interface class FileRepository {
  Future<FileRef> upload(FileUpload file);

  /// Absolute URL of `/v1/files/{id}` style paths (TTS audio, PDFs).
  String resolve(String url);
}

abstract interface class CardRepository {
  Future<CardBlockPending> verify(CardBlockRequest request);
  Future<CardBlockResult> confirm(String confirmationId);
}

abstract interface class LoanRepository {
  Future<List<LoanProduct>> products(String lang);
  Future<LoanSimulation> simulate({required String productId, required int amount, required int termMonths, required String lang, bool pdf = false, String? conversationId});
}

abstract interface class TicketRepository {
  Future<TicketPage> list(TicketFilter filter);
  Future<Ticket> create(TicketCreate ticket);
  Future<Ticket> update(String ticketId, {String? status, String? urgency, String? Function()? assignedTo});
}

abstract interface class BranchRepository {
  Future<List<Branch>> list({String? province, String? q, required String lang});
}

abstract interface class UssdRepository {
  /// `POST /v1/channels/ussd/inbound`.
  Future<OutgoingReply> send(InboundMessage message);
}

abstract interface class AgentRepository {
  Future<List<Agent>> agents();
  Future<List<Call>> queue();
  Future<CallDetail> call(String callId);
  Future<CallDetail> claim(String callId, String agentId);
  Future<OutgoingReply> sendMessage(String callId, String agentId, String text, {bool voice = false});
  Future<Call> end(String callId, String agentId, {String? note});
  Future<Stats> stats();

  /// All events (agent role).
  Stream<WsEvent> events(String agentId);
}
