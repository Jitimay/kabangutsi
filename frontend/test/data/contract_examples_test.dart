import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';

/// Every example embedded in contracts/ws_events.json and message.schema.json
/// must parse with our DTOs (contracts are law).
void main() {
  Map<String, dynamic> load(String f) => jsonDecode(File('../contracts/$f').readAsStringSync()) as Map<String, dynamic>;

  test('all ws_events.json examples parse into typed events', () {
    final defs = load('ws_events.json')[r'$defs'] as Map<String, dynamic>;
    var n = 0;
    for (final def in defs.values) {
      for (final ex in ((def as Map)['examples'] as List?) ?? const []) {
        final ev = WsEvent.fromJson(ex as Map<String, dynamic>);
        expect(ev, isNot(isA<UnknownEvent>()), reason: '${ex['type']}');
        n++;
      }
    }
    expect(n, greaterThanOrEqualTo(10));
  });

  test('OutgoingReply examples parse and round-trip', () {
    final defs = load('message.schema.json')[r'$defs'] as Map<String, dynamic>;
    final examples = ((defs['OutgoingReply'] as Map)['examples'] as List?) ?? const [];
    for (final ex in examples) {
      final r = OutgoingReply.fromJson(ex as Map<String, dynamic>);
      expect(OutgoingReply.fromJson(r.toJson()), r);
      expect(r.shortText.length, lessThanOrEqualTo(160));
    }
  });
}
