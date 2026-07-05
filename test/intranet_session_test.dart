import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/intranet_client.dart';

/// Mock de transporte que entiende el flujo cookie de Intranet PHP y simula
/// la firma REAL de sesión caducada confirmada por `probe_session_expiry`
/// (2026-06-11): los endpoints de datos responden `302 Location: sesion`
/// con cuerpo vacío cuando el `PHPSESSID` no está logueado server-side.
class _IntranetMock extends http.BaseClient {
  /// El server solo considera la sesión válida tras un POST /login.
  bool serverLoggedIn = false;
  int dataHits = 0;
  int loginHits = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path; // p.ej. "/login", "/consultarPeriodos..."
    http.Response res;

    if (path == '/login') {
      loginHits++;
      serverLoggedIn = true;
      res = http.Response('', 302, headers: {
        'location': 'inicio?filtro=noticias',
        'set-cookie': 'PHPSESSID=fresh-valid-cookie',
      });
    } else if (path == '/' || path.contains('inicio')) {
      // GET inicial / aterrizaje: entrega cookie pero aún sin login.
      res = http.Response('', 302, headers: {
        'location': 'sesion',
        'set-cookie': 'PHPSESSID=anon-cookie',
      });
    } else {
      // Endpoint de datos.
      dataHits++;
      if (serverLoggedIn) {
        res = http.Response('[["2025","1"],["2025","2"],["2026","1"]]', 200);
      } else {
        // Sesión caducada → 302 a la página de login, cuerpo vacío.
        res = http.Response('', 302, headers: {'location': 'sesion'});
      }
    }

    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      request: request,
      headers: res.headers,
    );
  }
}

void main() {
  group('IntranetClient — detección de sesión caducada (302→sesion)', () {
    test('re-loguea de forma transparente y devuelve los datos', () async {
      final mock = _IntranetMock();
      final client = IntranetClient(transport: mock);

      // Cold start: rehidratamos una cookie persistida que ya caducó
      // server-side (el server aún NO está logueado).
      client.importCookies('PHPSESSID=stale-cookie');
      expect(client.isLoggedIn, isTrue,
          reason: 'importCookies marca logueado por la presencia de PHPSESSID');

      // El repo arma este callback con las credenciales guardadas.
      client.reauthenticate = () => client.login('U01025B', 'secret');

      final data = await client.postJsonList(
        'consultarPeriodosMatriculados',
        const {},
        referer: 'inicio',
      );

      // Antes del fix esto devolvía [] (el 302 con cuerpo vacío se leía como
      // "sin datos"). Ahora detecta la caducidad, re-loguea y reintenta.
      expect(data, isNotEmpty);
      expect(data.length, 3);
      expect(data.first, ['2025', '1']);
      expect(mock.loginHits, 1, reason: 're-login disparado una sola vez');
      expect(mock.dataHits, 2,
          reason: 'firstTerm hit caduca (302), reintento tras login devuelve 200');
    });

    test('sin callback de re-login, propaga SessionExpiredException '
        '(no devuelve lista vacía silenciosa)', () async {
      final mock = _IntranetMock();
      final client = IntranetClient(transport: mock);
      client.importCookies('PHPSESSID=stale-cookie');
      // reauthenticate queda en null.

      await expectLater(
        client.postJsonList('consultarPeriodosMatriculados', const {},
            referer: 'inicio'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(client.isLoggedIn, isFalse,
          reason: 'la sesión caducada se invalida');
    });

    test('una respuesta 200 vacía SÍ es "sin datos" (no caducidad)', () async {
      // Garantiza que no confundimos un 200 legítimamente vacío con caducidad.
      final client = IntranetClient(transport: _Always200Empty());
      final data = await client.getJsonList('consultarCuotasEstudiante');
      expect(data, isEmpty);
    });
  });
}

class _Always200Empty extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(const <int>[]),
      200,
      request: request,
    );
  }
}
