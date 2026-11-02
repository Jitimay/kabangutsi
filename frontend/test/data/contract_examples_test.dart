import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/data/models/models.dart';
import 'package:yaml/yaml.dart';

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

  test('ocr_api.yaml ExtractResult example parses and round-trips', () {
    final doc = loadYaml(File('../contracts/ocr_api.yaml').readAsStringSync()) as YamlMap;
    final ex = jsonDecode(jsonEncode(
      doc['paths']['/ocr/extract']['post']['responses']['200']['content']['application/json']['example'],
    )) as Map<String, dynamic>;
    final r = ExtractResult.fromJson(ex);
    expect(r.docType, 'cni');
    expect(r.needsReview, isTrue);
    expect(r.fields.where((f) => f.needsReview).map((f) => f.name), ['id_number']);
    expect(ExtractResult.fromJson(r.toJson()), r);
  });

  test('openapi /v1/documents/extract returns ExtractResult and documents 503', () {
    final doc = loadYaml(File('../contracts/openapi.yaml').readAsStringSync()) as YamlMap;
    final op = doc['paths']['/v1/documents/extract']['post'] as YamlMap;
    final props = op['requestBody']['content']['multipart/form-data']['schema']['properties'] as YamlMap;
    expect(props.keys, containsAll(['image', 'doc_type', 'conversation_id', 'lang']));
    expect((op['responses'] as YamlMap).keys.map((k) => '$k'), containsAll(['200', '422', '503']));
  });
}
