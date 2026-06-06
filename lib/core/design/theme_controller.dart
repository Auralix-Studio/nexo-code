import 'package:flutter/material.dart';

import 'package:nexo/core/app_locale.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/storage.dart';

/// Selección posible: `system` o un id de paleta concreto.
/// `system` resuelve a `light` u `dark` según `MediaQuery.platformBrightness`.
class ThemeController extends ChangeNotifier {
  /// Selección del usuario. `'system'` o un `NexoColors.id`.
  String _selection = 'system';
  String get selection => _selection;

  /// Idioma activo (también propaga a [Strings.apply]).
  AppLocale _locale = AppLocale.es;
  AppLocale get locale => _locale;

  /// Formato de hora: true = 24h, false = 12h.
  bool _use24h = true;
  bool get use24h => _use24h;

  /// Compatibilidad con el modo Material clásico (claro/oscuro/sistema).
  /// Para paletas distintas a light/dark se asume oscuro/claro según su flag.
  ThemeMode get mode {
    switch (_selection) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return NexoColors.byId(_selection).isDark
            ? ThemeMode.dark
            : ThemeMode.light;
    }
  }

  void load() {
    final s = AppStorage.instance;
    final raw = s.themeMode;
    _selection = raw ?? 'system';
    _locale = AppLocale.fromCode(s.localeCode);
    _use24h = s.use24h;
  }

  Future<void> setLocale(AppLocale l) async {
    if (_locale == l) return;
    _locale = l;
    notifyListeners();
    await AppStorage.instance.setLocaleCode(l.code);
  }

  Future<void> setUse24h(bool value) async {
    if (_use24h == value) return;
    _use24h = value;
    notifyListeners();
    await AppStorage.instance.setUse24h(value);
  }

  Future<void> setSelection(String selection) async {
    if (_selection == selection) return;
    _selection = selection;
    notifyListeners();
    await AppStorage.instance.setThemeMode(selection);
  }

  /// API legacy: aceptar `ThemeMode` (lo usaba la UI antigua).
  Future<void> set(ThemeMode mode) => setSelection(switch (mode) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      });

  /// Resuelve la paleta a aplicar, considerando "Sistema".
  NexoColors resolvedPalette(BuildContext context) {
    if (_selection == 'system') {
      final dark =
          MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      return dark ? NexoColors.dark : NexoColors.light;
    }
    return NexoColors.byId(_selection);
  }

  /// Mantenido por compatibilidad: ¿el tema activo es oscuro?
  bool resolvedDark(BuildContext context) =>
      resolvedPalette(context).isDark;

  /// Alterna claro ↔ oscuro (manteniendo la API previa).
  Future<void> toggle(BuildContext context) =>
      setSelection(resolvedDark(context) ? 'light' : 'dark');
}
