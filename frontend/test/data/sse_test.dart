import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/api/sse.dart';
import 'package:kabangutsi/data/models/models.dart';

void main() {
  test('parses SSE events split across chunks', () async {
    const raw = 'event: token\ndata: {"delta":"Pour un"}\n\n: keep-alive\n\nevent: sentence\n'
        'data: {"index":0,"text":"Bonjour.","audio_url":null}\n\n';
    final bytes = utf8.encode(raw);
    final chunks = [bytes.sublist(0, 10), bytes.sublist(10, 47), bytes.sublist(47)];
    final events = await parseSse(Stream.fromIterable(chunks)).toList();
    expect(events.map((e) => e.event), ['token', 'sentence']);
    final ev = ChatStreamEvent.fromSse(events[1].event, jsonDecode(events[1].data) as Json);
    expect(ev, const StreamSentence(0, 'Bonjour.', null));
  });
}
