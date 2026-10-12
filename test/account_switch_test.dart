import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/saved_account.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SIGMA falso: acepta las contraseñas de [valid] y devuelve el perfil.
({SessionService session, List<String> logins}) _buildSession(
  Map<String, String> valid, {
  bool offline = false,
}) {
  final logins = <String>[];
  final api = ApiClient(
    transport: MockClient((req) async {
      if (offline) throw http.ClientException('sin red');
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      final user = body['usuarioId'] as String;
      final pass = utf8.decode(base64.decode(body['clave'] as String));
      logins.add(user);
      if (valid[user] != pass) {
        return http.Response(
          jsonEncode({'success': false, 'mensaje': 'Clave incorrecta'}),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'token': 'tok-$user',
            'info': {
              'codigo': user,
              'nombres': 'NOMBRE $user',
              'apellidos': 'APELLIDO',
              'isDocente': user.startsWith('D'),
            },
          },
        }),
        200,
      );
    }),
  );
  return (
    session: SessionService(apiClient: api, repo: SigmaRepository(api)),
    logins: logins,
  );
}

void main() {
  late MemorySecretStore vault;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    vault = MemorySecretStore();
    await AppStorage.init(secrets: vault);
  });

  group('SavedAccount', () {
    test('serializa sin perder datos y tolera basura', () {
      const a = SavedAccount(
        user: 'U001',
        password: 'x',
        displayName: 'Ana María Quispe Rojas',
        isTeacher: true,
        lastUsedMs: 5,
      );
      final back = SavedAccount.fromJson(jsonDecode(jsonEncode(a.toJson())))!;
      expect(back.user, 'U001');
      expect(back.password, 'x');
      expect(back.isTeacher, isTrue);
      expect(back.initials, 'AQ');
      expect(SavedAccount.fromJson('basura'), isNull);
      expect(SavedAccount.fromJson({'u': ''}), isNull);
    });
  });

  group('AppStorage cuentas', () {
    test('recuerda, ordena por uso y persiste en el almacén seguro', () async {
      final s = AppStorage.instance;
      await s.rememberAccount(user: 'u001', password: 'a');
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await s.rememberAccount(user: 'D002', password: 'b', isTeacher: true);
      expect(s.savedAccounts.map((a) => a.user), ['D002', 'U001']);

      // Otra instancia leyendo el mismo almacén ve lo mismo.
      final again = await AppStorage.init(secrets: vault);
      expect(again.savedAccounts.map((a) => a.user), ['D002', 'U001']);
      expect(again.savedAccount('d002')!.isTeacher, isTrue);
    });

    test('nunca guarda más del máximo: olvida la menos usada', () async {
      final s = AppStorage.instance;
      for (var i = 0; i < AppStorage.maxSavedAccounts + 2; i++) {
        await s.rememberAccount(user: 'U$i', password: 'p');
        await Future<void>.delayed(const Duration(milliseconds: 2));
      }
      expect(s.savedAccounts.length, AppStorage.maxSavedAccounts);
      expect(s.savedAccount('U0'), isNull);
      expect(s.savedAccount('U1'), isNull);
    });

    test('limpiar la sesión activa no borra las cuentas', () async {
      final s = AppStorage.instance;
      await s.rememberAccount(user: 'U001', password: 'a');
      await s.clear(keepCredentials: false);
      expect(s.savedAccount('U001'), isNotNull);
    });

    test('cambiar la contraseña actualiza la cuenta guardada', () async {
      final s = AppStorage.instance;
      await s.rememberAccount(user: 'U001', password: 'vieja');
      await s.setCredentials('U001', 'nueva');
      expect(s.savedAccount('U001')!.password, 'nueva');
    });
  });

  group('SessionService cambio de cuenta', () {
    test('cada login queda recordado y se cambia sin contraseña', () async {
      final b = _buildSession({'U001': 'a', 'D002': 'b'});
      await b.session.login('U001', 'a');
      await b.session.logout(forget: false); // "Agregar otra cuenta"
      await b.session.login('D002', 'b');
      expect(b.session.savedAccounts.map((a) => a.user).toSet(), {
        'U001',
        'D002',
      });
      expect(b.session.user!.isTeacher, isTrue);

      await b.session.switchTo('U001');
      expect(b.session.isAuthenticated, isTrue);
      expect(b.session.currentAccount, 'U001');
      expect(b.session.user!.isTeacher, isFalse);
      expect(b.session.switchingTo, isNull);
      expect(b.logins.last, 'U001');
    });

    test('contraseña cambiada en SIGMA: queda en la lista y pide clave', () async {
      final valid = {'U001': 'a', 'D002': 'b'};
      final b = _buildSession(valid);
      await b.session.login('U001', 'a');
      await b.session.logout(forget: false);
      await b.session.login('D002', 'b');
      valid['U001'] = 'otra';

      await b.session.switchTo('U001');
      expect(b.session.isAuthenticated, isFalse);
      final failure = b.session.takeSwitchFailure();
      expect(failure?.user, 'U001');
      expect(failure?.message, isNotEmpty);
      final saved = AppStorage.instance.savedAccount('U001')!;
      expect(saved.canQuickSwitch, isFalse);
      // La otra cuenta sigue lista para volver.
      expect(AppStorage.instance.savedAccount('D002')!.canQuickSwitch, isTrue);
    });

    test('cerrar sesión olvida la cuenta; agregar otra no', () async {
      final b = _buildSession({'U001': 'a'});
      await b.session.login('U001', 'a');
      await b.session.logout(forget: false);
      expect(AppStorage.instance.savedAccount('U001'), isNotNull);

      await b.session.login('U001', 'a');
      await b.session.logout();
      // El borrado de la cuenta no bloquea el cierre de sesión.
      await Future<void>.delayed(Duration.zero);
      expect(AppStorage.instance.savedAccount('U001'), isNull);
    });

    test('sin red al cambiar: avisa y no borra nada', () async {
      await AppStorage.instance.rememberAccount(user: 'U001', password: 'a');
      final b = _buildSession({'U001': 'a'}, offline: true);
      await b.session.switchTo('U001');
      expect(b.session.isAuthenticated, isFalse);
      expect(b.session.takeSwitchFailure()?.user, 'U001');
      expect(AppStorage.instance.savedAccount('U001')!.canQuickSwitch, isTrue);
    });

    test('sesión de una versión anterior entra a la lista al arrancar', () async {
      await AppStorage.instance.setCredentials('U009', 'p');
      final b = _buildSession({'U009': 'p'});
      await b.session.bootstrap();
      expect(AppStorage.instance.savedAccount('U009'), isNotNull);
    });
  });
}
