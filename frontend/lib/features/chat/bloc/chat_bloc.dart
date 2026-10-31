import 'dart:async';
import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import 'chat_message.dart';

export 'chat_message.dart';

part 'chat_event.dart';
part 'chat_state.dart';

const kMaskedText = '••••';

/// Customer chat (Wave 1): conversation, streamed replies (SSE), model switch
/// notices (F20), masked PIN input, handoff to a human agent.
class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc(this._conversations) : super(const ChatState()) {
    on<ChatStarted>(_onStarted);
    on<ChatRestarted>(_onRestarted);
    on<ChatTextSent>(_onText);
    on<ChatImageSent>(_onImage);
    on<ChatModelChanged>((e, emit) => emit(state.copyWith(model: () => e.model)));
    on<ChatHandoffRequested>(_onHandoff);
    on<_ChatLiveEvent>(_onLive);
  }

  final ConversationRepository _conversations;
  StreamSubscription<WsEvent>? _live;
  int _seq = 0;

  // Per streamed turn.
  String? _customerId;
  String? _pendingId;
  bool _noticeShown = false;
  bool _gotTokens = false;

  String _localId(String prefix) => 'local-$prefix-${_seq++}';

  Future<void> _onStarted(ChatStarted e, Emitter<ChatState> emit) async {
    final model = e.model ?? state.model;
    emit(ChatState(status: ChatStatus.starting, model: model));
    try {
      final conv = await _conversations.create(channel: 'web', lang: e.lang, model: model);
      final greeting = conv.greeting;
      emit(state.copyWith(
        status: ChatStatus.ready,
        conversationId: () => conv.id,
        messages: [if (greeting != null) ChatMessage.fromReply(greeting)],
        expectedInput: greeting?.expectedInput ?? 'text',
      ));
    } on ApiError catch (err) {
      emit(state.copyWith(status: ChatStatus.failure, error: () => err));
    }
  }

  Future<void> _onRestarted(ChatRestarted e, Emitter<ChatState> emit) async {
    await _live?.cancel();
    _live = null;
    await _onStarted(ChatStarted(lang: e.lang), emit);
  }

  Future<void> _onText(ChatTextSent e, Emitter<ChatState> emit) async {
    final text = e.text.trim();
    if (text.isEmpty) return;
    final masked = state.secretInput;
    await _send(
      emit,
      MessageInput(text: text, model: state.model),
      ChatMessage(id: _localId('c'), author: ChatAuthor.customer, text: masked ? kMaskedText : text, masked: masked),
    );
  }

  Future<void> _onImage(ChatImageSent e, Emitter<ChatState> emit) async {
    final text = e.text?.trim();
    await _send(
      emit,
      MessageInput(text: (text?.isEmpty ?? true) ? null : text, image: e.image, model: state.model),
      ChatMessage(id: _localId('c'), author: ChatAuthor.customer, text: text ?? '', image: Uint8List.fromList(e.image.bytes)),
    );
  }

  Future<void> _send(Emitter<ChatState> emit, MessageInput input, ChatMessage customer) async {
    final id = state.conversationId;
    if (id == null || !state.canSend) return;
    _customerId = customer.id;
    _pendingId = _localId('p');
    _noticeShown = false;
    _gotTokens = false;
    final pending = ChatMessage(id: _pendingId!, author: ChatAuthor.ai, text: '', streaming: true);
    emit(state.copyWith(messages: [...state.messages, customer, pending], sending: true, error: () => null));
    try {
      await emit.forEach<ChatStreamEvent>(_conversations.sendMessage(id, input), onData: _apply);
    } on ApiError catch (err) {
      emit(_failed(err));
    } catch (_) {
      emit(_failed(ApiError.network));
    }
    if (state.sending) {
      // Stream closed without `done`: keep what arrived.
      emit(state.copyWith(
        sending: false,
        messages: [
          for (final m in state.messages)
            if (m.id != _pendingId) m else if (m.text.isNotEmpty) m.copyWith(streaming: false),
        ],
      ));
    }
    if (state.handoff == HandoffStatus.waiting) _listen(id);
  }

  ChatState _apply(ChatStreamEvent ev) {
    final s = state;
    switch (ev) {
      case StreamTurn(:final turn):
        if (turn.text.isEmpty) return s;
        return s.copyWith(messages: [
          for (final m in s.messages)
            if (m.id == _customerId && !m.masked) m.copyWith(text: turn.text) else m,
        ]);
      case StreamModelSwitched(:final change):
        _noticeShown = true;
        return s.copyWith(messages: _insertBeforePending(s.messages, _notice(change.notice)));
      case StreamToken(:final delta):
        _gotTokens = true;
        return _appendPending(s, delta);
      case StreamSentence(:final text):
        if (_gotTokens) return s;
        final current = s.messages.where((m) => m.id == _pendingId).firstOrNull?.text ?? '';
        return _appendPending(s, current.isEmpty ? text : ' $text');
      case StreamDone(:final reply):
        var messages = [
          for (final m in s.messages)
            if (m.id == _pendingId) ChatMessage.fromReply(reply) else m,
        ];
        if (reply.modelNotice != null && !_noticeShown) {
          final i = messages.indexWhere((m) => m.id == reply.id);
          messages = [...messages]..insert(i < 0 ? messages.length : i, _notice(reply.modelNotice!));
        }
        return s.copyWith(
          messages: messages,
          sending: false,
          expectedInput: reply.expectedInput,
          handoff: reply.handoff && s.handoff == HandoffStatus.none ? HandoffStatus.waiting : null,
          ended: reply.endSession || s.ended,
        );
      case StreamError(:final error):
        return _failed(error);
    }
  }

  ChatState _failed(ApiError err) {
    final messages = [for (final m in state.messages) if (m.id != _pendingId) m];
    if (err.status == 409 || err.code == 'conflict') {
      // With (or waiting for) a human agent: the message was forwarded.
      return state.copyWith(
        messages: messages,
        sending: false,
        handoff: state.handoff == HandoffStatus.none ? HandoffStatus.waiting : null,
      );
    }
    return state.copyWith(messages: messages, sending: false, error: () => err);
  }

  ChatMessage _notice(String text) => ChatMessage(id: _localId('n'), author: ChatAuthor.notice, text: text);

  List<ChatMessage> _insertBeforePending(List<ChatMessage> list, ChatMessage m) {
    final i = list.indexWhere((x) => x.id == _pendingId);
    return [...list]..insert(i < 0 ? list.length : i, m);
  }

  ChatState _appendPending(ChatState s, String delta) => s.copyWith(messages: [
        for (final m in s.messages)
          if (m.id == _pendingId) m.copyWith(text: m.text + delta) else m,
      ]);

  Future<void> _onHandoff(ChatHandoffRequested e, Emitter<ChatState> emit) async {
    final id = state.conversationId;
    if (id == null || state.handoff != HandoffStatus.none || state.ended) return;
    emit(state.copyWith(error: () => null));
    try {
      final reply = await _conversations.requestHandoff(id);
      emit(state.copyWith(
        messages: [...state.messages, ChatMessage.fromReply(reply)],
        handoff: HandoffStatus.waiting,
        expectedInput: reply.expectedInput,
      ));
    } on ApiError catch (err) {
      if (err.status == 409 || err.code == 'conflict') {
        emit(state.copyWith(handoff: HandoffStatus.waiting));
      } else {
        emit(state.copyWith(error: () => err));
        return;
      }
    }
    _listen(id);
  }

  void _listen(String conversationId) {
    _live ??= _conversations.events(conversationId).listen((e) => add(_ChatLiveEvent(e)), onError: (_) {});
  }

  void _onLive(_ChatLiveEvent e, Emitter<ChatState> emit) {
    final id = state.conversationId;
    switch (e.event) {
      case CallTurnEvent(:final turn) when turn.callId == id:
        if (turn.speaker != 'agent' && turn.speaker != 'system') return;
        if (state.messages.any((m) => m.id == turn.id)) return;
        emit(state.copyWith(messages: [
          ...state.messages,
          ChatMessage(
            id: turn.id,
            author: turn.speaker == 'agent' ? ChatAuthor.agent : ChatAuthor.system,
            text: turn.text,
            attachments: [for (final a in turn.attachments) if (a.type != 'audio') a],
          ),
        ]));
      case CallHandoffRequestedEvent(:final call) when call.id == id:
        if (state.handoff == HandoffStatus.none) emit(state.copyWith(handoff: HandoffStatus.waiting));
      case CallClaimedEvent(:final call, :final agentName) when call.id == id:
        emit(state.copyWith(
          handoff: HandoffStatus.withAgent,
          agentName: () => agentName,
          messages: [...state.messages, ChatMessage(id: e.event.id, author: ChatAuthor.agentJoined, text: agentName)],
        ));
      case CallEndedEvent(:final call) when call.id == id:
        emit(state.copyWith(
          ended: true,
          sending: false,
          handoff: state.handoff == HandoffStatus.none ? null : HandoffStatus.ended,
        ));
      default:
        return;
    }
  }

  @override
  Future<void> close() async {
    await _live?.cancel();
    return super.close();
  }
}
