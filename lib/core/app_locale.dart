import 'package:flutter/widgets.dart';

/// Idiomas soportados por la app. Cada uno se corresponde con un archivo
/// `lib/l10n/app_<code>.arb`.
///
/// Para añadir un nuevo idioma:
///   1. Crear `lib/l10n/app_<code>.arb`.
///   2. Agregar una entrada aquí con el código ISO 639-1.
///   3. Las claves faltantes en su .arb hacen fallback al español.
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
