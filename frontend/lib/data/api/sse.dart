import 'dart:async';
import 'dart:convert';

/// One Server-Sent Event.
class SseEvent {
  const SseEvent(this.event, this.data);
  final String event;
  final String data;
}

/// Parses a byte stream in the `text/event-stream` format.
Stream<SseEvent> parseSse(Stream<List<int>> bytes) async* {
  var event = 'message';
  final data = <String>[];
  await for (final line in bytes.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.isEmpty) {
      if (data.isNotEmpty) yield SseEvent(event, data.join('\n'));
      event = 'message';
      data.clear();
    } else if (line.startsWith(':')) {
      continue; // comment / keep-alive
    } else {
      final i = line.indexOf(':');
      final field = i < 0 ? line : line.substring(0, i);
      var value = i < 0 ? '' : line.substring(i + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      if (field == 'event') event = value;
      if (field == 'data') data.add(value);
    }
  }
  if (data.isNotEmpty) yield SseEvent(event, data.join('\n'));
}
