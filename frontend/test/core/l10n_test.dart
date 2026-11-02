import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every user-facing string must exist in fr, en and rn (hard rule 6).
void main() {
  Map<String, dynamic> load(String lang) => jsonDecode(
        File('lib/core/l10n/arb/app_$lang.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

  Set<String> keys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();

  test('fr, en and rn have the same keys and no empty values', () {
    final en = load('en');
    for (final lang in ['fr', 'rn']) {
      final other = load(lang);
      expect(keys(other), keys(en), reason: 'keys differ in app_$lang.arb');
      for (final k in keys(other)) {
        expect((other[k] as String).trim(), isNotEmpty, reason: '$lang.$k');
      }
    }
  });
}
