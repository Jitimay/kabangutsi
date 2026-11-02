import 'package:equatable/equatable.dart';

import 'call.dart';
import 'json.dart';
import 'reply.dart';
import 'stats.dart';
import 'ticket.dart';
import 'api_error.dart';

/// WebSocket event of ws_events.json. Unknown types are kept as [UnknownEvent].
sealed class WsEvent extends Equatable {
  const WsEvent(this.id, this.ts);

  final String id;
  final DateTime ts;

  static WsEvent fromJson(Json j) {
    final id = j['id'] as String;
    final ts = parseTs(j['ts']);
    final d = j['data'] as Json;
    return switch (j['type']) {
      'call.started' => CallStartedEvent(id, ts, Call.fromJson(d)),
      'call.turn' => CallTurnEvent(id, ts, Turn.fromJson(d)),
      'call.handoff_requested' => CallHandoffRequestedEvent(
          id, ts, Call.fromJson(d['call'] as Json), d['reason'] as String, d['summary'] as String,
          parseList(d['transcript'], Turn.fromJson)),
      'call.claimed' => CallClaimedEvent(id, ts, Call.fromJson(d['call'] as Json), d['agent_id'] as String, d['agent_name'] as String),
      'call.ended' => CallEndedEvent(id, ts, Call.fromJson(d)),
      'ticket.created' => TicketCreatedEvent(id, ts, Ticket.fromJson(d)),
      'ticket.updated' => TicketUpdatedEvent(id, ts, Ticket.fromJson(d)),
      'model.switched' => ModelSwitchedEvent(id, ts, ModelSwitch.fromJson(d)),
      'stats.updated' => StatsUpdatedEvent(id, ts, Stats.fromJson(d)),
      'agent.suggestion' => AgentSuggestionEvent(id, ts, Suggestion.fromJson(d)),
      final t => UnknownEvent(id, ts, '$t'),
    };
  }

  @override
  List<Object?> get props => [id, ts];
}

class CallStartedEvent extends WsEvent {
  const CallStartedEvent(super.id, super.ts, this.call);
  final Call call;
}

class CallTurnEvent extends WsEvent {
  const CallTurnEvent(super.id, super.ts, this.turn);
  final Turn turn;
}

class CallHandoffRequestedEvent extends WsEvent {
  const CallHandoffRequestedEvent(super.id, super.ts, this.call, this.reason, this.summary, this.transcript);
  final Call call;
  final String reason;
  final String summary;
  final List<Turn> transcript;
}

class CallClaimedEvent extends WsEvent {
  const CallClaimedEvent(super.id, super.ts, this.call, this.agentId, this.agentName);
  final Call call;
  final String agentId;
  final String agentName;
}

class CallEndedEvent extends WsEvent {
  const CallEndedEvent(super.id, super.ts, this.call);
  final Call call;
}

class TicketCreatedEvent extends WsEvent {
  const TicketCreatedEvent(super.id, super.ts, this.ticket);
  final Ticket ticket;
}

class TicketUpdatedEvent extends WsEvent {
  const TicketUpdatedEvent(super.id, super.ts, this.ticket);
  final Ticket ticket;
}

class ModelSwitchedEvent extends WsEvent {
  const ModelSwitchedEvent(super.id, super.ts, this.change);
  final ModelSwitch change;
}

class StatsUpdatedEvent extends WsEvent {
  const StatsUpdatedEvent(super.id, super.ts, this.stats);
  final Stats stats;
}

class AgentSuggestionEvent extends WsEvent {
  const AgentSuggestionEvent(super.id, super.ts, this.suggestion);
  final Suggestion suggestion;
}

class UnknownEvent extends WsEvent {
  const UnknownEvent(super.id, super.ts, this.type);
  final String type;
}

/// One SSE event of `POST /v1/conversations/{id}/messages` (`StreamEvent` of openapi.yaml).
sealed class ChatStreamEvent extends Equatable {
  const ChatStreamEvent();

  static ChatStreamEvent? fromSse(String event, Json data) => switch (event) {
        'turn' => StreamTurn(Turn.fromJson(data)),
        'model.switched' => StreamModelSwitched(ModelSwitch.fromJson(data)),
        'token' => StreamToken(data['delta'] as String),
        'sentence' => StreamSentence(data['index'] as int, data['text'] as String, data['audio_url'] as String?),
        'done' => StreamDone(OutgoingReply.fromJson(data)),
        'error' => StreamError(ApiError.fromJson(data)),
        _ => null,
      };
}

class StreamTurn extends ChatStreamEvent {
  const StreamTurn(this.turn);
  final Turn turn;
  @override
  List<Object?> get props => [turn];
}

class StreamModelSwitched extends ChatStreamEvent {
  const StreamModelSwitched(this.change);
  final ModelSwitch change;
  @override
  List<Object?> get props => [change];
}

class StreamToken extends ChatStreamEvent {
  const StreamToken(this.delta);
  final String delta;
  @override
  List<Object?> get props => [delta];
}

class StreamSentence extends ChatStreamEvent {
  const StreamSentence(this.index, this.text, this.audioUrl);
  final int index;
  final String text;
  final String? audioUrl;
  @override
  List<Object?> get props => [index, text, audioUrl];
}

class StreamDone extends ChatStreamEvent {
  const StreamDone(this.reply);
  final OutgoingReply reply;
  @override
  List<Object?> get props => [reply];
}

class StreamError extends ChatStreamEvent {
  const StreamError(this.error);
  final ApiError error;
  @override
  List<Object?> get props => [error];
}
