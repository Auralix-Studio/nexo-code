import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexo/core/app_locale.dart';
import 'package:nexo/core/design/font_library.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/storage.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({FontLibrary? fonts}) : fonts = fonts ?? FontLibrary();

  final FontLibrary fonts;
  String _selection = 'system';
  String get selection => _selection;
  AppLocale _locale = AppLocale.es;
  AppLocale get locale => _locale;
  bool _use24h = true;
  bool get use24h => _use24h;
  String _fontId = FontLibrary.defaultId;
  String get fontId => _fontId;
  FontChoice get font => fonts.byId(_fontId) ?? FontLibrary.presets.first;

  /// Familia para `ThemeData.fontFamily`; `null` es la del sistema.
  String? get fontFamily => font.family;
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
    fonts.load();
    final savedFont = s.fontId ?? _migrateLegacyFont(s);
    _fontId = savedFont != null && fonts.byId(savedFont) != null
        ? savedFont
        : FontLibrary.defaultId;
  }

  /// La v1.9.0 guardaba el nombre de la familia, incluso uno escrito a mano.
  /// Las incluidas pasan a su id; un nombre suelto no tiene archivo detrás y
  /// vuelve a la predeterminada.
  static String? _migrateLegacyFont(AppStorage s) {
    final legacy = s.legacyFontFamily;
    if (legacy == null) return null;
    final id = switch (legacy) {
      'Roboto' => FontLibrary.defaultId,
      'Hypero' => 'hypero',
      'SuperMindset' => 'supermindset',
      _ => FontLibrary.defaultId,
    };
    unawaited(s.setFontId(id));
    unawaited(s.clearLegacyFontFamily());
    return id;
  }

  /// Aplica la fuente cuando ya está registrada, para que el cambio no pase
  /// por la del sistema durante un instante.
  Future<void> setFont(String id) async {
    if (_fontId == id || fonts.byId(id) == null) return;
    await fonts.ensureLoaded(id);
    _fontId = id;
    notifyListeners();
    await AppStorage.instance.setFontId(id);
  }

  /// Importa los archivos y aplica la última familia que entró.
  Future<FontImport> importFonts(List<PickedFontFile> files) async {
    final result = await fonts.import(files);
    if (result.fonts.isNotEmpty) {
      final id = result.fonts.last.id;
      await fonts.ensureLoaded(id);
      // Aunque sea la fuente activa: si sumó archivos, cambió su familia.
      _fontId = id;
      notifyListeners();
      await AppStorage.instance.setFontId(id);
    }
    return result;
  }

  Future<void> removeFont(String id) async {
    await fonts.remove(id);
    if (_fontId == id) {
      _fontId = FontLibrary.defaultId;
      await AppStorage.instance.setFontId(_fontId);
    }
    notifyListeners();
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
