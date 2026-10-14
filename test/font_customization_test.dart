import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/design/fonts.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NexoFontOption', () {
    test('resuelve presets conocidos y nombres personalizados', () {
      expect(NexoFontOption.resolveFontFamily('Roboto'), equals('Roboto'));
      expect(NexoFontOption.resolveFontFamily('system'), isNull);
      expect(NexoFontOption.resolveFontFamily('sistema'), isNull);
      expect(NexoFontOption.resolveFontFamily(''), isNull);
      expect(NexoFontOption.resolveFontFamily(null), isNull);
      expect(NexoFontOption.resolveFontFamily('Hypero'), equals('Hypero'));
      expect(NexoFontOption.resolveFontFamily('SuperMindset'), equals('SuperMindset'));
      expect(NexoFontOption.resolveFontFamily('Segoe UI'), equals('Segoe UI'));
      expect(NexoFontOption.resolveFontFamily('Fira Code'), equals('Fira Code'));
    });

    test('displayName devuelve nombres amigables', () {
      expect(NexoFontOption.displayName(null), equals('Sistema'));
      expect(NexoFontOption.displayName('system'), equals('Sistema'));
      expect(NexoFontOption.displayName('Roboto'), equals('Roboto'));
      expect(NexoFontOption.displayName('Hypero'), equals('Hypero'));
      expect(NexoFontOption.displayName('CustomFont'), equals('CustomFont'));
    });
  });

  group('NexoTheme y fuentes globales', () {
    test('aplica la fuente a ThemeData, textTheme, appBar y formularios', () {
      final theme = NexoTheme.themeFor(NexoColors.light, fontFamily: 'Hypero');
      expect(theme.textTheme.bodyMedium?.fontFamily, equals('Hypero'));
      expect(theme.textTheme.titleLarge?.fontFamily, equals('Hypero'));
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, equals('Hypero'));
      expect(theme.inputDecorationTheme.labelStyle?.fontFamily, equals('Hypero'));
      expect(theme.tabBarTheme.labelStyle?.fontFamily, equals('Hypero'));
    });

    test('aplica fuente personalizada a todos los componentes', () {
      final theme = NexoTheme.themeFor(NexoColors.dark, fontFamily: 'Segoe UI');
      expect(theme.textTheme.bodyMedium?.fontFamily, equals('Segoe UI'));
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, equals('Segoe UI'));
    });
  });

  group('ThemeController y persistencia de fuentes', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await AppStorage.init(secrets: MemorySecretStore());
    });

    test('cambia y notifica cambios de fuente', () async {
      final controller = ThemeController()..load();
      expect(controller.fontFamily, isNull);

      bool notified = false;
      controller.addListener(() => notified = true);

      await controller.setFontFamily('Hypero');
      expect(notified, isTrue);
      expect(controller.fontFamily, equals('Hypero'));
      expect(AppStorage.instance.fontFamily, equals('Hypero'));

      // Cambiar a personalizada
      notified = false;
      await controller.setFontFamily('Consolas');
      expect(notified, isTrue);
      expect(controller.fontFamily, equals('Consolas'));
      expect(AppStorage.instance.fontFamily, equals('Consolas'));

      // Volver a nativa / sistema
      notified = false;
      await controller.setFontFamily('system');
      expect(notified, isTrue);
      expect(controller.fontFamily, isNull);
      expect(AppStorage.instance.fontFamily, isNull);
    });
  });
}
