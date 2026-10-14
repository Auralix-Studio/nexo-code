import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/design/font_file.dart';
import 'package:nexo/core/design/font_library.dart';
import 'package:nexo/core/design/font_store.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/theme_controller.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/features/settings/typography_card.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List _asset(String path) => File(path).readAsBytesSync();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hyperoTtf = _asset('assets/fonts/Hypero.ttf');
  final hyperoOtf = _asset('assets/fonts/Hypero.otf');
  final hyperoWoff = _asset('assets/fonts/Hypero.woff');
  final mindset = _asset('assets/fonts/Super Mindset.ttf');
  // Un "Hypero Bold" de mentira: mismo archivo, declarado como 700.
  final hyperoBold = FontFileInfo.withWeight(hyperoTtf, 700)!;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
  });

  group('FontFileInfo', () {
    test('lee familia, estilo y peso de TTF y OTF', () {
      final ttf = FontFileInfo.parse(hyperoTtf);
      expect(ttf.family, 'Hypero');
      expect(ttf.style, 'Regular');
      expect(ttf.weight, 400);
      expect(ttf.italic, isFalse);
      expect(ttf.variable, isFalse);
      expect(ttf.extension, 'ttf');

      final otf = FontFileInfo.parse(hyperoOtf);
      expect(otf.family, 'Hypero');
      expect(otf.extension, 'otf');

      expect(FontFileInfo.parse(mindset).family, 'Super Mindset');
    });

    test('rechaza lo que no es TTF ni OTF, diciendo por qué', () {
      Matcher problem(FontFileProblem p) =>
          isA<FontFileException>().having((e) => e.problem, 'problem', p);
      expect(
        () => FontFileInfo.parse(hyperoWoff),
        throwsA(problem(FontFileProblem.webFont)),
      );
      expect(
        () => FontFileInfo.parse(
          Uint8List.fromList([...ascii.encode('ttcf'), ...List.filled(20, 0)]),
        ),
        throwsA(problem(FontFileProblem.collection)),
      );
      expect(
        () => FontFileInfo.parse(Uint8List.fromList(utf8.encode('<html>…'))),
        throwsA(problem(FontFileProblem.notAFont)),
      );
      expect(
        () => FontFileInfo.parse(Uint8List.sublistView(hyperoTtf, 0, 300)),
        throwsA(problem(FontFileProblem.damaged)),
      );
    });

    test('la copia con otro peso deja intacto el original', () {
      expect(FontFileInfo.parse(hyperoBold).weight, 700);
      expect(FontFileInfo.parse(hyperoBold).family, 'Hypero');
      expect(FontFileInfo.parse(hyperoTtf).weight, 400);
      expect(hyperoBold.length, hyperoTtf.length);
    });
  });

  group('coverBoldWeights', () {
    List<int> weights(List<Uint8List> files) =>
        [for (final f in files) FontFileInfo.parse(f).weight]..sort();

    test('a una sola Regular le basta una copia de 900', () {
      final files = FontLibrary.coverBoldWeights([
        (weight: 400, italic: false, bytes: hyperoTtf),
      ]);
      expect(weights(files), [400, 900]);
    });

    test('con Regular y Bold reales la copia sale de la Bold', () {
      final files = FontLibrary.coverBoldWeights([
        (weight: 400, italic: false, bytes: hyperoTtf),
        (weight: 700, italic: false, bytes: hyperoBold),
      ]);
      expect(weights(files), [400, 700, 900]);
    });

    test('con una cara de 800 o más no hace falta copia', () {
      final heavy = FontFileInfo.withWeight(hyperoTtf, 800)!;
      final files = FontLibrary.coverBoldWeights([
        (weight: 400, italic: false, bytes: hyperoTtf),
        (weight: 800, italic: false, bytes: heavy),
      ]);
      expect(files, hasLength(2));
    });

    test('las cursivas se cubren aparte', () {
      final files = FontLibrary.coverBoldWeights([
        (weight: 400, italic: false, bytes: hyperoTtf),
        (weight: 700, italic: false, bytes: hyperoBold),
        (weight: 400, italic: true, bytes: hyperoTtf),
      ]);
      // Rectas: 400, 700 + 900. Cursiva: 400 + 900.
      expect(files, hasLength(5));
    });
  });

  group('FontLibrary', () {
    test('importa, guarda y vuelve a leer una familia', () async {
      final store = MemoryFontFileStore();
      final library = FontLibrary(store: store);
      final result = await library.import([
        (name: 'Hypero.ttf', bytes: hyperoTtf),
      ]);
      expect(result.rejected, isEmpty);
      expect(result.fonts.single.name, 'Hypero');
      expect(result.fonts.single.kind, FontKind.imported);
      expect(result.fonts.single.faces.single.weight, 400);
      expect(store.files, hasLength(1));

      final reloaded = FontLibrary(store: store)..load();
      expect(reloaded.imported.single.id, result.fonts.single.id);
      expect(reloaded.imported.single.family, result.fonts.single.family);
    });

    test('suma pesos a la familia que ya existe y no duplica', () async {
      final store = MemoryFontFileStore();
      final library = FontLibrary(store: store);
      final first = (await library.import([
        (name: 'Hypero.ttf', bytes: hyperoTtf),
      ])).fonts.single;
      await library.import([(name: 'Hypero.ttf', bytes: hyperoTtf)]);
      expect(library.imported.single.faces, hasLength(1));

      final merged = (await library.import([
        (name: 'Hypero-Bold.ttf', bytes: hyperoBold),
      ])).fonts.single;
      expect(library.imported, hasLength(1));
      expect(merged.id, first.id);
      expect(merged.faces.map((f) => f.weight), [400, 700]);
      // Con otros archivos, otra familia en el motor.
      expect(merged.family, isNot(first.family));
      expect(store.files, hasLength(2));
    });

    test('reemplaza el archivo de un peso que ya estaba', () async {
      final store = MemoryFontFileStore();
      final library = FontLibrary(store: store);
      await library.import([(name: 'Hypero.ttf', bytes: hyperoTtf)]);
      await library.import([(name: 'Hypero.otf', bytes: hyperoOtf)]);
      final face = library.imported.single.faces.single;
      expect(face.file, endsWith('.otf'));
      expect(store.files.keys.single, face.file, reason: 'borra el anterior');
    });

    test('informa cada archivo que no sirve', () async {
      final library = FontLibrary(store: MemoryFontFileStore(maxBytes: 100000));
      final result = await library.import([
        (name: 'Hypero.woff', bytes: hyperoWoff),
        (name: 'notas.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.7'))),
        (name: 'Super Mindset.ttf', bytes: mindset),
      ]);
      expect(result.fonts, isEmpty);
      expect(
        {for (final r in result.rejected) r.file: r.problem},
        {
          'Hypero.woff': FontImportProblem.webFont,
          'notas.pdf': FontImportProblem.notAFont,
          'Super Mindset.ttf': FontImportProblem.tooLarge,
        },
      );
      expect(library.imported, isEmpty);
    });

    test('quitar una familia borra sus archivos', () async {
      final store = MemoryFontFileStore();
      final library = FontLibrary(store: store);
      final font = (await library.import([
        (name: 'Hypero.ttf', bytes: hyperoTtf),
        (name: 'Hypero-Bold.ttf', bytes: hyperoBold),
      ])).fonts.single;
      await library.remove(font.id);
      expect(library.imported, isEmpty);
      expect(store.files, isEmpty);
      expect((FontLibrary(store: store)..load()).imported, isEmpty);
    });

    test('registra en el motor las incluidas y las importadas', () async {
      final library = FontLibrary(store: MemoryFontFileStore());
      expect(await library.ensureLoaded('hypero'), isTrue);
      expect(await library.ensureLoaded('supermindset'), isTrue);
      final font = (await library.import([
        (name: 'Hypero.ttf', bytes: hyperoTtf),
      ])).fonts.single;
      expect(await library.ensureLoaded(font.id), isTrue);
      expect(await library.ensureLoaded('no-existe'), isFalse);
    });
  });

  group('ThemeController', () {
    test('elige, guarda y recupera la fuente', () async {
      final store = MemoryFontFileStore();
      final theme = ThemeController(fonts: FontLibrary(store: store))..load();
      expect(theme.fontId, FontLibrary.defaultId);
      expect(theme.fontFamily, 'Roboto');

      await theme.setFont('system');
      expect(theme.fontFamily, isNull);
      await theme.setFont('hypero');
      expect(theme.fontFamily, 'Nexo Hypero');

      final again = ThemeController(fonts: FontLibrary(store: store))..load();
      expect(again.fontId, 'hypero');
    });

    test(
      'importar aplica la fuente y quitarla vuelve a la de siempre',
      () async {
        final theme = ThemeController(
          fonts: FontLibrary(store: MemoryFontFileStore()),
        )..load();
        var notified = 0;
        theme.addListener(() => notified++);

        final result = await theme.importFonts([
          (name: 'Hypero.ttf', bytes: hyperoTtf),
        ]);
        final font = result.fonts.single;
        expect(theme.fontId, font.id);
        expect(theme.fontFamily, font.family);
        expect(notified, 1);

        await theme.removeFont(font.id);
        expect(theme.fontId, FontLibrary.defaultId);
        expect(AppStorage.instance.fontId, FontLibrary.defaultId);
      },
    );

    test('migra la fuente que guardó la v1.9.0', () async {
      Future<ThemeController> withLegacy(String family) async {
        SharedPreferences.setMockInitialValues({'nexo.fontFamily': family});
        await AppStorage.init(secrets: MemorySecretStore());
        return ThemeController(fonts: FontLibrary(store: MemoryFontFileStore()))
          ..load();
      }

      expect((await withLegacy('SuperMindset')).fontId, 'supermindset');
      expect((await withLegacy('Hypero')).fontId, 'hypero');
      // Un nombre escrito a mano no tiene archivo detrás.
      expect((await withLegacy('Segoe UI')).fontId, FontLibrary.defaultId);
      await pumpEventQueue();
      expect(AppStorage.instance.legacyFontFamily, isNull);
      expect(AppStorage.instance.fontId, FontLibrary.defaultId);
    });

    test('si la fuente guardada ya no existe, usa la de siempre', () async {
      await AppStorage.instance.setFontId('user:borrada');
      final theme = ThemeController(
        fonts: FontLibrary(store: MemoryFontFileStore()),
      )..load();
      expect(theme.fontId, FontLibrary.defaultId);
    });
  });

  group('NexoTheme', () {
    test('la fuente llega a texto, barra, pestañas, botones y campos', () {
      final t = NexoTheme.themeFor(NexoColors.dark, fontFamily: 'Nexo Hypero');
      expect(t.textTheme.bodyMedium?.fontFamily, 'Nexo Hypero');
      expect(t.textTheme.headlineSmall?.fontFamily, 'Nexo Hypero');
      expect(t.appBarTheme.titleTextStyle?.fontFamily, 'Nexo Hypero');
      expect(t.tabBarTheme.labelStyle?.fontFamily, 'Nexo Hypero');
      expect(t.tabBarTheme.unselectedLabelStyle?.fontFamily, 'Nexo Hypero');
      expect(t.inputDecorationTheme.labelStyle?.fontFamily, 'Nexo Hypero');
      expect(
        t.elevatedButtonTheme.style?.textStyle?.resolve({})?.fontFamily,
        'Nexo Hypero',
      );
    });

    test('sin indicar nada sigue siendo Roboto; null es la del sistema', () {
      expect(
        NexoTheme.themeFor(
          NexoColors.light,
        ).appBarTheme.titleTextStyle?.fontFamily,
        'Roboto',
      );
      expect(
        NexoTheme.themeFor(
          NexoColors.light,
          fontFamily: null,
        ).appBarTheme.titleTextStyle?.fontFamily,
        isNull,
      );
    });
  });

  testWidgets('la tarjeta de tipografía cambia la fuente al tocarla', (
    tester,
  ) async {
    final theme = ThemeController(
      fonts: FontLibrary(store: MemoryFontFileStore()),
    )..load();
    // Registrar fuera del reloj falso: el motor responde de verdad.
    await tester.runAsync(() async {
      for (final f in theme.fonts.all) {
        await theme.fonts.ensureLoaded(f.id);
      }
    });
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: Scaffold(
          body: SingleChildScrollView(child: TypographyCard(theme: theme)),
        ),
      ),
    );
    expect(find.text('Tipografía'), findsOneWidget);
    expect(find.text('Importar fuente'), findsOneWidget);
    expect(find.text('Horario de hoy'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Hypero, Incluida en Nexo'));
    // La carga se resolvió en la zona real de `runAsync`; lo que espera por
    // ella también continúa allí, así que hay que darle un turno real.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(theme.fontId, 'hypero');
    // La muestra pasa a la fuente elegida.
    final sample = tester.widget<Text>(find.text('Horario de hoy'));
    expect(sample.style?.fontFamily, 'Nexo Hypero');
  });
}
