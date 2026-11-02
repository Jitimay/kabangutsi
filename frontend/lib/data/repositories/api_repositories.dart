import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../api/api_client.dart';
import '../api/http_client_factory.dart';
import '../api/sse.dart';
import '../api/ws_client.dart';
import '../models/models.dart';
import 'repositories.dart';

class ApiModelRepository implements ModelRepository {
  ApiModelRepository(this.api);
  final ApiClient api;

  @override
  Future<ModelList> listModels({bool refresh = false}) async =>
      ModelList.fromJson(await api.get('/v1/models', query: {if (refresh) 'refresh': true}));
}

class ApiConversationRepository implements ConversationRepository {
  ApiConversationRepository(this.api, this.ws, {http.Client Function()? httpClient})
      : _httpClient = httpClient ?? createStreamingClient;

  final ApiClient api;
  final WsClient ws;
  final http.Client Function() _httpClient;

  @override
  Future<Conversation> create({required String channel, String? phone, String? lang, String? model}) async =>
      Conversation.fromJson(await api.post('/v1/conversations', body: {'channel': channel, 'phone': phone, 'lang': lang, 'model': model}));

  @override
  Future<Conversation> update(String conversationId, {String? model, String? lang}) async => Conversation.fromJson(
      await api.patch('/v1/conversations/$conversationId', body: {'model': ?model, 'lang': ?lang}));

  @override
  Future<CallDetail> get(String conversationId) async =>
      CallDetail.fromJson(await api.get('/v1/conversations/$conversationId'));

  @override
  Stream<ChatStreamEvent> sendMessage(String conversationId, MessageInput input) async* {
    final req = http.MultipartRequest('POST', Uri.parse(api.resolve('/v1/conversations/$conversationId/messages')))
      ..headers['Accept'] = 'text/event-stream';
    if (input.text != null && input.text!.isNotEmpty) req.fields['text'] = input.text!;
    if (input.lang != null) req.fields['lang'] = input.lang!;
    if (input.model != null) req.fields['model'] = input.model!;
    req.fields['voice'] = '${input.voice}';
    for (final (field, f) in [('image', input.image), ('audio', input.audio)]) {
      if (f != null) {
        req.files.add(http.MultipartFile.fromBytes(field, f.bytes, filename: f.filename, contentType: MediaType.parse(f.mime)));
      }
    }
    final client = _httpClient();
    try {
      final http.StreamedResponse res;
      try {
        res = await client.send(req);
      } catch (_) {
        throw ApiError.network;
      }
      if (res.statusCode >= 400) {
        final body = await res.stream.bytesToString();
        try {
          throw ApiError.fromJson(jsonDecode(body) as Json, status: res.statusCode);
        } on FormatException {
          throw ApiError(code: 'internal_error', message: 'HTTP ${res.statusCode}', status: res.statusCode);
        }
      }
      final type = res.headers['content-type'] ?? '';
      if (!type.contains('text/event-stream')) {
        // Backend answered with plain JSON: treat it as a single `done`.
        yield StreamDone(OutgoingReply.fromJson(jsonDecode(await res.stream.bytesToString()) as Json));
        return;
      }
      await for (final e in parseSse(res.stream)) {
        final ev = ChatStreamEvent.fromSse(e.event, jsonDecode(e.data) as Json);
        if (ev != null) yield ev;
      }
    } finally {
      client.close();
    }
  }

  @override
  Future<OutgoingReply> requestHandoff(String conversationId, {String reason = 'customer_request'}) async =>
      OutgoingReply.fromJson(await api.post('/v1/conversations/$conversationId/handoff', body: {'reason': reason}));

  @override
  Future<Call> end(String conversationId) async => Call.fromJson(await api.post('/v1/conversations/$conversationId/end'));

  @override
  Stream<WsEvent> events(String conversationId) => ws.events(ws.customerUri(conversationId));
}

class ApiFileRepository implements FileRepository {
  ApiFileRepository(this.api);
  final ApiClient api;

  @override
  Future<FileRef> upload(FileUpload file) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes, filename: file.filename, contentType: DioMediaType.parse(file.mime)),
    });
    return FileRef.fromJson(await api.post('/v1/files', body: form));
  }

  @override
  String resolve(String url) => api.resolve(url);
}

class ApiCardRepository implements CardRepository {
  ApiCardRepository(this.api);
  final ApiClient api;

  @override
  Future<CardBlockPending> verify(CardBlockRequest request) async =>
      CardBlockPending.fromJson(await api.post('/v1/cards/block', body: request.toJson()));

  @override
  Future<CardBlockResult> confirm(String confirmationId) async =>
      CardBlockResult.fromJson(await api.post('/v1/cards/block/$confirmationId/confirm'));
}

class ApiLoanRepository implements LoanRepository {
  ApiLoanRepository(this.api);
  final ApiClient api;

  @override
  Future<List<LoanProduct>> products(String lang) async =>
      parseList((await api.get('/v1/loan-products', query: {'lang': lang}))['items'], LoanProduct.fromJson);

  @override
  Future<LoanSimulation> simulate({required String productId, required int amount, required int termMonths, required String lang, bool pdf = false, String? conversationId}) async =>
      LoanSimulation.fromJson(await api.post('/v1/loans/simulate', body: {
        'product_id': productId,
        'amount': amount,
        'term_months': termMonths,
        'lang': lang,
        'pdf': pdf,
        'conversation_id': conversationId,
      }));
}

class ApiTicketRepository implements TicketRepository {
  ApiTicketRepository(this.api);
  final ApiClient api;

  @override
  Future<TicketPage> list(TicketFilter filter) async => TicketPage.fromJson(await api.get('/v1/tickets', query: filter.toQuery()));

  @override
  Future<Ticket> create(TicketCreate ticket) async => Ticket.fromJson(await api.post('/v1/tickets', body: ticket.toJson()));

  @override
  Future<Ticket> update(String ticketId, {String? status, String? urgency, String? Function()? assignedTo}) async =>
      Ticket.fromJson(await api.patch('/v1/tickets/$ticketId', body: {
        'status': ?status,
        'urgency': ?urgency,
        if (assignedTo != null) 'assigned_to': assignedTo(),
      }));
}

class ApiBranchRepository implements BranchRepository {
  ApiBranchRepository(this.api);
  final ApiClient api;

  @override
  Future<List<Branch>> list({String? province, String? q, required String lang}) async => parseList(
      (await api.get('/v1/branches', query: {'province': province, 'q': (q?.isEmpty ?? true) ? null : q, 'lang': lang}))['items'],
      Branch.fromJson);
}

class ApiUssdRepository implements UssdRepository {
  ApiUssdRepository(this.api);
  final ApiClient api;

  @override
  Future<OutgoingReply> send(InboundMessage message) async =>
      OutgoingReply.fromJson(await api.post('/v1/channels/ussd/inbound', body: message.toJson()));
}

class ApiAgentRepository implements AgentRepository {
  ApiAgentRepository(this.api, this.ws);
  final ApiClient api;
  final WsClient ws;

  @override
  Future<List<Agent>> agents() async => parseList((await api.get('/v1/agents'))['items'], Agent.fromJson);

  @override
  Future<List<Call>> queue() async => parseList((await api.get('/v1/calls/queue'))['items'], Call.fromJson);

  @override
  Future<CallDetail> call(String callId) async => CallDetail.fromJson(await api.get('/v1/calls/$callId'));

  @override
  Future<CallDetail> claim(String callId, String agentId) async =>
      CallDetail.fromJson(await api.post('/v1/calls/$callId/claim', body: {'agent_id': agentId}));

  @override
  Future<OutgoingReply> sendMessage(String callId, String agentId, String text, {bool voice = false}) async =>
      OutgoingReply.fromJson(await api.post('/v1/calls/$callId/messages', body: {'agent_id': agentId, 'text': text, 'voice': voice}));

  @override
  Future<Call> end(String callId, String agentId, {String? note}) async =>
      Call.fromJson(await api.post('/v1/calls/$callId/end', body: {'agent_id': agentId, if (note != null && note.isNotEmpty) 'note': note}));

  @override
  Future<Stats> stats() async => Stats.fromJson(await api.get('/v1/stats'));

  @override
  Stream<WsEvent> events(String agentId) => ws.events(ws.agentUri(agentId));
}
