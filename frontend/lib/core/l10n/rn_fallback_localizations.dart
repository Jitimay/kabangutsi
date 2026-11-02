import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const _rn = 'rn';
const _fallback = Locale('fr');

class RnFallbackMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const RnFallbackMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _rn;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(RnFallbackMaterialLocalizationsDelegate old) => false;
}

class RnFallbackCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const RnFallbackCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _rn;

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(RnFallbackCupertinoLocalizationsDelegate old) => false;
}

class RnFallbackWidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const RnFallbackWidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == _rn;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      GlobalWidgetsLocalizations.delegate.load(_fallback);

  @override
  bool shouldReload(RnFallbackWidgetsLocalizationsDelegate old) => false;
}
