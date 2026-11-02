import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'gen/app_localizations.dart';
import 'rn_fallback_localizations.dart';

export 'gen/app_localizations.dart';

/// Supported app languages, equal priority. Order = order in the language menu.
const kSupportedLocales = [Locale('fr'), Locale('en'), Locale('rn')];

/// Delegates for both apps. Flutter has no Material/Cupertino strings for
/// Kirundi, so `rn` falls back to French for framework widgets (date pickers,
/// tooltips...). Our own strings are always translated in `app_rn.arb`.
const List<LocalizationsDelegate<dynamic>> kLocalizationsDelegates = [
  AppLocalizations.delegate,
  RnFallbackMaterialLocalizationsDelegate(),
  RnFallbackCupertinoLocalizationsDelegate(),
  RnFallbackWidgetsLocalizationsDelegate(),
  GlobalMaterialLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
];

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
