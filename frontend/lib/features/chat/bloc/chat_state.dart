part of 'chat_bloc.dart';

enum ChatStatus { initial, starting, ready, failure }

/// none → waiting (queued) → withAgent (claimed) → ended
enum HandoffStatus { none, waiting, withAgent, ended }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.conversationId,
    this.messages = const [],
    this.sending = false,
    this.expectedInput = 'text',
    this.handoff = HandoffStatus.none,
    this.agentName,
    this.ended = false,
    this.model,
    this.error,
  });

  final ChatStatus status;
  final String? conversationId;
  final List<ChatMessage> messages;

  /// A reply is streaming.
  final bool sending;

  /// `expected_input` of the last reply (pin / date_of_birth → masked field).
  final String expectedInput;
  final HandoffStatus handoff;
  final String? agentName;

  /// end_session received or call ended.
  final bool ended;

  /// Model chosen in the picker (null = default).
  final String? model;
  final ApiError? error;

  bool get secretInput => expectedInput == 'pin' || expectedInput == 'date_of_birth';

  bool get canSend => status == ChatStatus.ready && !sending && !ended;

  ChatState copyWith({
    ChatStatus? status,
    String? Function()? conversationId,
    List<ChatMessage>? messages,
    bool? sending,
    String? expectedInput,
    HandoffStatus? handoff,
    String? Function()? agentName,
    bool? ended,
    String? Function()? model,
    ApiError? Function()? error,
  }) =>
      ChatState(
        status: status ?? this.status,
        conversationId: conversationId != null ? conversationId() : this.conversationId,
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
        expectedInput: expectedInput ?? this.expectedInput,
        handoff: handoff ?? this.handoff,
        agentName: agentName != null ? agentName() : this.agentName,
        ended: ended ?? this.ended,
        model: model != null ? model() : this.model,
        error: error != null ? error() : this.error,
      );

  @override
  List<Object?> get props => [status, conversationId, messages, sending, expectedInput, handoff, agentName, ended, model, error];
}
