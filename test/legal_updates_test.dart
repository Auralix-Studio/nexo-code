import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/features/legal/legal_updates.dart';
import 'package:nexo/features/legal/terms_screen.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _info(int version) => {
  'version': version,
  'updated_at': '2026-12-01',
  'summary': ['Nuevo proveedor de notificaciones.'],
  'documents': [
    {
      'id': 'privacy',
      'title': 'Política de Privacidad',
      'url': 'https://api.nexo.aurx.pro/privacidad',
    },
  ],
};

class _Fake {
  _Fake(this.info);
  Map<String, dynamic>? info;
  int fetches = 0;
  final uploads = <int>[];
  bool signedIn = false;
  bool failUpload = false;
  DateTime now = DateTime(2026, 11, 14, 10);

  LegalUpdates build(AppStorage storage) => LegalUpdates(
    fetch: () async {
      fetches++;
      final i = info;
      if (i == null) throw Exception('sin red');
      return i;
    },
    upload: (v) async {
      if (failUpload) throw Exception('sin red');
      uploads.add(v);
    },
    signedIn: () => signedIn,
    storage: storage,
    clock: () => now,
  );
}

Future<AppStorage> _storage(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return AppStorage.init(secrets: MemorySecretStore());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('la app trae la versión 5', () {
    expect(LegalTerms.version, 5);
    expect(LegalTerms.updatedAt, DateTime(2026, 11, 14));
  });

  test('quien aceptó la v4 tiene que aceptar la v5 aun sin red', () async {
    final storage = await _storage({'nexo.acceptedTermsVersion': 4});
    final fake = _Fake(null);
    final legal = fake.build(storage);

    expect(await legal.check(), isFalse);
    expect(legal.needsAcceptance, isTrue);
    expect(legal.isUpdate, isTrue);
    expect(legal.requiredVersion, LegalTerms.version);
    expect(legal.onlineDocuments, isEmpty);
  });

  test('una versión nueva del servidor pide aceptar otra vez', () async {
    final storage = await _storage({'nexo.acceptedTermsVersion': 5});
    final fake = _Fake(_info(6));
    final legal = fake.build(storage);
    var notified = 0;
    legal.addListener(() => notified++);

    expect(legal.needsAcceptance, isFalse);
    expect(await legal.check(), isTrue);
    expect(notified, 1);
    expect(legal.needsAcceptance, isTrue);
    expect(legal.requiredVersion, 6);
    expect(legal.changes, ['Nuevo proveedor de notificaciones.']);
    expect(legal.onlineDocuments.single.url, endsWith('/privacidad'));

    // Sin sesión se acepta en el dispositivo y la constancia queda pendiente.
    await legal.accept();
    expect(legal.needsAcceptance, isFalse);
    expect(storage.acceptedTermsVersion, 6);
    await legal.syncAcceptance();
    expect(fake.uploads, isEmpty);

    // Al iniciar sesión se envía una sola vez.
    fake.signedIn = true;
    await legal.syncAcceptance();
    await legal.syncAcceptance();
    expect(fake.uploads, [6]);

    // Otra cuenta que entre después también queda registrada.
    await legal.signedOut();
    await legal.syncAcceptance();
    expect(fake.uploads, [6, 6]);
  });

  test('consulta como mucho una vez por hora', () async {
    final storage = await _storage({'nexo.acceptedTermsVersion': 5});
    final fake = _Fake(_info(5));
    final legal = fake.build(storage);

    await legal.check();
    await legal.check();
    expect(fake.fetches, 1);

    fake.now = fake.now.add(const Duration(minutes: 61));
    await legal.check();
    expect(fake.fetches, 2);

    await legal.check(force: true);
    expect(fake.fetches, 3);
    // La misma versión que trae la app: nada que aceptar ni abrir en la web.
    expect(legal.needsAcceptance, isFalse);
    expect(legal.onlineDocuments, isEmpty);
  });

  test('si falla el envío se reintenta después', () async {
    final storage = await _storage({});
    final fake = _Fake(_info(5))
      ..signedIn = true
      ..failUpload = true;
    final legal = fake.build(storage);

    await legal.accept();
    await legal.syncAcceptance();
    expect(fake.uploads, isEmpty);

    fake.failUpload = false;
    await legal.syncAcceptance();
    expect(fake.uploads, [5]);
  });

  testWidgets('el aviso de actualización lista los cambios', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('es'),
        home: TermsScreen(
          isUpdate: true,
          version: 6,
          changes: const ['Nuevo proveedor de notificaciones.'],
          onAccept: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Qué cambió'), findsOneWidget);
    expect(
      find.textContaining('Nuevo proveedor de notificaciones.'),
      findsOneWidget,
    );
  });
}
