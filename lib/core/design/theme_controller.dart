import 'package:flutter/material.dart';
import 'package:nexo/core/app_locale.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/storage.dart';

class ThemeController extends ChangeNotifier {
  String _selection = 'system';
  String get selection => _selection;
  AppLocale _locale = AppLocale.es;
  AppLocale get locale => _locale;
  bool _use24h = true;
  bool get use24h => _use24h;
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

  Future<void> set(ThemeMode mode) => setSelection(switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  });
  NexoColors resolvedPalette(BuildContext context) {
    if (_selection == 'system') {
      final dark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;
      return dark ? NexoColors.dark : NexoColors.light;
    }
    return NexoColors.byId(_selection);
  }

  bool resolvedDark(BuildContext context) => resolvedPalette(context).isDark;
  Future<void> toggle(BuildContext context) =>
      setSelection(resolvedDark(context) ? 'light' : 'dark');
}
