import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/env/env.dart';
import '../models/models.dart';

/// Connects to `GET /v1/ws` and exposes the events of ws_events.json.
/// Reconnects with a short back-off and drops duplicate event ids.
class WsClient {
  WsClient(this.env, {WebSocketChannel Function(Uri uri)? connect})
      : _connect = connect ?? WebSocketChannel.connect;

  final Env env;
  final WebSocketChannel Function(Uri uri) _connect;

  Uri agentUri(String agentId) => Uri.parse('${env.wsBaseUrl}?role=agent&agent_id=${Uri.encodeQueryComponent(agentId)}');

  Uri customerUri(String conversationId) =>
      Uri.parse('${env.wsBaseUrl}?role=customer&conversation_id=$conversationId');

  /// Broadcast stream of events; cancel all listeners to close the socket.
  Stream<WsEvent> events(Uri uri) {
    late StreamController<WsEvent> controller;
    WebSocketChannel? channel;
    StreamSubscription<dynamic>? sub;
    Timer? retry;
    var closed = false;
    var attempt = 0;
    final seen = <String>{};

    void open() {
      if (closed) return;
      channel = _connect(uri);
      sub = channel!.stream.listen(
        (raw) {
          attempt = 0;
          try {
            final ev = WsEvent.fromJson(jsonDecode(raw as String) as Json);
            if (seen.add(ev.id)) controller.add(ev);
            if (seen.length > 2000) seen.clear();
          } catch (_) {
            // Ignore frames that do not match the contract.
          }
        },
        onError: (_) {},
        onDone: () {
          if (closed) return;
          attempt++;
          retry = Timer(Duration(seconds: attempt.clamp(1, 10)), open);
        },
      );
    }

    controller = StreamController<WsEvent>.broadcast(
      onListen: open,
      onCancel: () {
        closed = true;
        retry?.cancel();
        sub?.cancel();
        channel?.sink.close();
      },
    );
    return controller.stream;
  }
}
