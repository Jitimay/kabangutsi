import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kabangutsi/core/locale/language_cubit.dart';

void main() {
  group('LanguageCubit', () {
    test('starts in French', () {
      expect(LanguageCubit().state, const Locale('fr'));
    });

    blocTest<LanguageCubit, Locale>(
      'switches between fr, en and rn',
      build: LanguageCubit.new,
      act: (c) => c
        ..select(const Locale('rn'))
        ..select(const Locale('en')),
      expect: () => const [Locale('rn'), Locale('en')],
    );

    blocTest<LanguageCubit, Locale>(
      'ignores unsupported languages',
      build: LanguageCubit.new,
      act: (c) => c.select(const Locale('de')),
      expect: () => const <Locale>[],
    );
  });
}
