import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/features/legal/legal_document_screen.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';

Widget _app(Widget home, {String locale = 'es'}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: Locale(locale),
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el texto se divide en título, secciones, párrafos y viñetas', () {
    final blocks = parseLegalText(
      '# Política\n\n## 1. Objeto\n\nPrimera línea\nsigue el párrafo.\n\n'
      '- Uno\n- Dos\n',
    );
    expect(blocks.map((b) => (b.runtimeType, b.text)), [
      (LegalTitle, 'Política'),
      (LegalHeading, '1. Objeto'),
      (LegalParagraph, 'Primera línea sigue el párrafo.'),
      (LegalBullet, 'Uno'),
      (LegalBullet, 'Dos'),
    ]);
    final spans = legalSpans('Ley **N.º 29733** vigente', const TextStyle());
    expect(spans.map((s) => s.text), ['Ley ', 'N.º 29733', ' vigente']);
    expect(spans[1].style, isNotNull);
  });

  test(
    'cada documento existe en español e inglés y cita su marco legal',
    () async {
      for (final lang in ['es', 'en']) {
        final terms = await LegalDoc.terms.load(lang);
        expect(terms, contains('29733'));
        expect(terms, contains('30096'));
        expect(terms, contains('1328'));
        expect(terms, contains('29571'));
        final privacy = await LegalDoc.privacy.load(lang);
        expect(privacy, contains('016-2024-JUS'));
        expect(privacy, contains('GitHub'));
        final cookies = await LegalDoc.cookies.load(lang);
        expect(cookies, contains('29733'));
        for (final doc in [terms, privacy, cookies]) {
          expect(parseLegalText(doc).first, isA<LegalTitle>());
        }
      }
      // Idioma sin traducción: cae al español.
      expect(
        await LegalDoc.cookies.load('qu'),
        contains('Política de Cookies'),
      );
    },
  );

  testWidgets('desde los términos se abren los documentos completos', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const TermsScreen()));
    await tester.pumpAndSettle();
    final l = AppLocalizations.of(tester.element(find.byType(TermsScreen)));
    await tester.scrollUntilVisible(
      find.text(l.legalPrivacyTitle),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l.legalPrivacyTitle));
    // Leer el asset es E/S real: se le da tiempo fuera del reloj simulado.
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('1. Responsable y contacto').evaluate().isNotEmpty) break;
    }
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('1. Responsable y contacto'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LegalDocumentScreen),
        matching: find.textContaining('Versión ${LegalTerms.version}'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
