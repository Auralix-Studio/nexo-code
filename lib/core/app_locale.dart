import 'package:flutter/widgets.dart';

enum AppLocale {
  es('es', 'Español'),
  en('en', 'English'),
  qu('qu', 'Runa Simi');

  final String code;
  final String label;
  const AppLocale(this.code, this.label);
  Locale get flutterLocale => Locale(code);
  static AppLocale fromCode(String? code) {
    for (final l in AppLocale.values) {
      if (l.code == code) return l;
    }
    return AppLocale.es;
  }
}
