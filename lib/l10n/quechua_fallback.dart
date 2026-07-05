import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

const Locale _fallbackLocale = Locale('es');

class QuechuaMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const QuechuaMaterialDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';
  @override
  Future<MaterialLocalizations> load(Locale _) =>
      GlobalMaterialLocalizations.delegate.load(_fallbackLocale);
  @override
  bool shouldReload(QuechuaMaterialDelegate old) => false;
}

class QuechuaCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const QuechuaCupertinoDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';
  @override
  Future<CupertinoLocalizations> load(Locale _) =>
      GlobalCupertinoLocalizations.delegate.load(_fallbackLocale);
  @override
  bool shouldReload(QuechuaCupertinoDelegate old) => false;
}

class QuechuaWidgetsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const QuechuaWidgetsDelegate();
  @override
  bool isSupported(Locale locale) => locale.languageCode == 'qu';
  @override
  Future<WidgetsLocalizations> load(Locale _) =>
      GlobalWidgetsLocalizations.delegate.load(_fallbackLocale);
  @override
  bool shouldReload(QuechuaWidgetsDelegate old) => false;
}
