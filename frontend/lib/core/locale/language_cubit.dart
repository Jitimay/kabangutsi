import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../l10n/l10n.dart';

/// UI language (fr, en, rn). The AI reply language follows the backend (F2).
class LanguageCubit extends Cubit<Locale> {
  LanguageCubit([super.initial = const Locale('fr')]);

  void select(Locale locale) {
    if (kSupportedLocales.any((l) => l.languageCode == locale.languageCode)) {
      emit(Locale(locale.languageCode));
    }
  }
}
