import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';

enum AppLocale {
  es('es', 'Español'),
  en('en', 'English'),
  qu('qu', 'Runa Simi');

  final String code;
  final String label;
  const AppLocale(this.code, this.label);
  Locale get flutterLocale => Locale(code);

  /// Resuelve el [AppLocale] a partir del código guardado en preferencias.
  ///
  /// Si [code] es `null` (primer inicio, sin preferencia guardada), detecta
  /// automáticamente el idioma del sistema operativo usando
  /// [PlatformDispatcher]. Se evalúan todos los locales del sistema en orden
  /// de prioridad del usuario y se elige el primer match soportado.
  /// Si ninguno coincide, se usa [AppLocale.es] como fallback.
  static AppLocale fromCode(String? code) {
    // Preferencia explícita del usuario → respetarla.
    if (code != null) {
      for (final l in AppLocale.values) {
        if (l.code == code) return l;
      }
    }

    // Primer inicio: detectar idioma del sistema operativo.
    final platformLocales = PlatformDispatcher.instance.locales;
    for (final locale in platformLocales) {
      for (final l in AppLocale.values) {
        if (l.code == locale.languageCode) return l;
      }
    }

    return AppLocale.es;
  }
}
