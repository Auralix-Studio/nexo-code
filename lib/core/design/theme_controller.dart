import 'package:flutter/material.dart';

import 'package:nexo/core/storage.dart';

/// Controla el modo de tema (claro / oscuro / sistema) y lo persiste.
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  void load() {
    final raw = AppStorage.instance.themeMode;
    _mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await AppStorage.instance.setThemeMode(switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  /// Resuelve si el tema activo es oscuro (considera "sistema").
  bool resolvedDark(BuildContext context) {
    return switch (_mode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system =>
        MediaQuery.platformBrightnessOf(context) == Brightness.dark,
    };
  }

  /// Alterna claro ↔ oscuro.
  Future<void> toggle(BuildContext context) =>
      set(resolvedDark(context) ? ThemeMode.light : ThemeMode.dark);
}
