import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/session.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import 'support/fake_nexo_api.dart';

// Simple Mocks for test isolation

class MockConnectivity implements Connectivity {
  MockConnectivity({required this.result});
  final List<ConnectivityResult> result;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => result;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream.value(result);
}

class MockHttpClient extends http.BaseClient {
  MockHttpClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      request: request,
      headers: response.headers,
    );
  }
}

class MockSessionService extends Fake implements SessionService {
  bool loggedOut = false;

  @override
  Future<void> logout({bool forget = true}) async {
    loggedOut = true;
  }
}

void main() {
  group('ErrorHandler Tests', () {
    test('withFallback executes remote action if online', () async {
      final conn = ConnectivityService(
        connectivity: MockConnectivity(result: [ConnectivityResult.wifi]),
        httpClient: MockHttpClient((req) async => http.Response('', 200)),
      );
      await conn.checkNow();

      final handler = ErrorHandler(
        connectivity: conn,
        session: MockSessionService(),
      );

      var remoteCalled = false;
      var cacheCalled = false;

      final res = await handler.withFallback<String>(
        remote: () async {
          remoteCalled = true;
          return 'success';
        },
        cached: () async {
          cacheCalled = true;
          return 'cached';
        },
        operationName: 'test_op',
      );

      expect(res, 'success');
      expect(remoteCalled, true);
      expect(cacheCalled, false);
    });

    test('withFallback falls back to cache on network failure', () async {
      final conn = ConnectivityService(
        connectivity: MockConnectivity(result: [ConnectivityResult.none]),
        httpClient: MockHttpClient((req) async => http.Response('', 500)),
      );
      await conn.checkNow();

      final handler = ErrorHandler(
        connectivity: conn,
        session: MockSessionService(),
      );

      var remoteCalled = false;
      var cacheCalled = false;

      final res = await handler.withFallback<String>(
        remote: () async {
          remoteCalled = true;
          throw const NetworkException('Server down');
        },
        cached: () async {
          cacheCalled = true;
          return 'cached_data';
        },
        operationName: 'test_op',
      );

      expect(res, 'cached_data');
      expect(remoteCalled, false); // No internet check skip calling remote
      expect(cacheCalled, true);
    });

    test(
      'session expired serves cache and does NOT log out (logout is ApiClient\'s job)',
      () async {
        final conn = ConnectivityService(
          connectivity: MockConnectivity(result: [ConnectivityResult.wifi]),
          httpClient: MockHttpClient((req) async => http.Response('', 200)),
        );
        await conn.checkNow();

        final session = MockSessionService();
        final handler = ErrorHandler(connectivity: conn, session: session);

        // Con caché disponible: se sirve el caché, sin lanzar.
        final res = await handler.withFallback<String>(
          remote: () async => throw const SessionExpiredException(),
          cached: () async => 'cached',
          operationName: 'test_op',
        );

        expect(res, 'cached');
        // El logout lo dispara BackendClient.onSessionInvalid (fuente única). El
        // ErrorHandler NUNCA debe cerrar sesión: eso causaba el doble-logout.
        expect(session.loggedOut, false);
      },
    );

    test('session expired rethrows when there is no cache', () async {
      final conn = ConnectivityService(
        connectivity: MockConnectivity(result: [ConnectivityResult.wifi]),
        httpClient: MockHttpClient((req) async => http.Response('', 200)),
      );
      await conn.checkNow();
      final session = MockSessionService();
      final handler = ErrorHandler(connectivity: conn, session: session);

      await expectLater(
        handler.withFallback<String>(
          remote: () async => throw const SessionExpiredException(),
          cached: () async => null,
          operationName: 'test_op',
        ),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(session.loggedOut, false);
    });

    test(
      'AuthUnavailable is transient: serves cache and keeps the session',
      () async {
        final conn = ConnectivityService(
          connectivity: MockConnectivity(result: [ConnectivityResult.wifi]),
          httpClient: MockHttpClient((req) async => http.Response('', 200)),
        );
        await conn.checkNow();
        final session = MockSessionService();
        final handler = ErrorHandler(connectivity: conn, session: session);

        final res = await handler.withFallback<String>(
          remote: () async => throw const AuthUnavailableException(),
          cached: () async => 'cached',
          operationName: 'test_op',
        );

        expect(res, 'cached');
        expect(session.loggedOut, false);
      },
    );

    test('retries once on a transient failure, then succeeds', () async {
      final conn = ConnectivityService(
        connectivity: MockConnectivity(result: [ConnectivityResult.wifi]),
        httpClient: MockHttpClient((req) async => http.Response('', 200)),
      );
      await conn.checkNow();
      final handler = ErrorHandler(
        connectivity: conn,
        session: MockSessionService(),
      );

      var attempts = 0;
      final res = await handler.withFallback<String>(
        remote: () async {
          attempts++;
          // Primer hit falla (servidor "frío" tras inactividad); el reintento
          // recupera. Este es justo el caso que rompía antes.
          if (attempts == 1) throw const NetworkException('cold start');
          return 'success';
        },
        cached: () async => null,
        operationName: 'test_op',
      );

      expect(res, 'success');
      expect(attempts, 2);
    });
  });

  group('BackendClient auth challenge (regresión rebote-al-login)', () {
    test('401 persistente tras renovar la sesión NO cierra sesión', () async {
      // El token vencido se renueva bien, pero la ruta sigue respondiendo
      // 401. Antes esto hacía logout y rebotaba al usuario al login.
      final api = BackendClient(
        transport: MockHttpClient(
          (req) async => nexoError('unauthorized', 401),
        ),
      );
      var loggedOut = false;
      api.onSessionInvalid = () => loggedOut = true;
      api.reauthenticate = () async => ReauthOutcome.refreshed; // creds válidas
      api.setToken('tok');

      await expectLater(
        api.profile(),
        throwsA(
          isA<BackendException>().having(
            apiErrorOf,
            'como error de la app',
            isA<AuthUnavailableException>(),
          ),
        ),
      );
      expect(
        loggedOut,
        false,
        reason:
            'un 401 persistente con credenciales válidas no debe cerrar sesión',
      );
    });

    test('credenciales rechazadas al reautenticar SÍ cierra sesión', () async {
      final api = BackendClient(
        transport: MockHttpClient(
          (req) async => nexoError('unauthorized', 401),
        ),
      );
      var loggedOut = false;
      api.onSessionInvalid = () => loggedOut = true;
      api.reauthenticate = () async => ReauthOutcome.invalidCredentials;
      api.setToken('tok');

      await expectLater(
        api.profile(),
        throwsA(
          isA<BackendException>().having(
            apiErrorOf,
            'como error de la app',
            isA<SessionExpiredException>(),
          ),
        ),
      );
      expect(loggedOut, true);
    });

    test('sin red es un error de red (va al caché, no al login)', () async {
      final api = BackendClient(
        transport: MockHttpClient(
          (req) async => throw http.ClientException('sin red'),
        ),
      );
      await expectLater(
        api.profile(),
        throwsA(
          isA<BackendException>().having(
            apiErrorOf,
            'como error de la app',
            isA<NetworkException>(),
          ),
        ),
      );
    });
  });

  group('Arranque (regresión ventana en blanco de la Store)', () {
    SessionService build() {
      final api = BackendClient(
        transport: MockHttpClient((_) async => nexoOk({})),
      );
      return SessionService(client: api);
    }

    test('un arranque que no decide acaba en login, no en el splash', () {
      final session = build();
      expect(session.status, SessionStatus.unknown);

      // Es lo que hace `main` si `bootstrap` falla o tarda demasiado.
      session.resolveUnknownAsUnauthenticated();

      expect(session.status, SessionStatus.unauthenticated);
    });

    test('limpiar un caché sin abrir no revienta', () async {
      // Al arrancar, la sesión puede resolverse antes de que el caché exista y
      // el store intenta limpiarlo. Eso pasaba y tumbaba el arranque.
      final cache = CacheManager();
      expect(cache.isReady, isFalse);
      await expectLater(cache.clearAll(), completes);
    });

    test('no pisa una sesión ya resuelta', () async {
      final session = build();
      session.resolveUnknownAsUnauthenticated();
      expect(session.status, SessionStatus.unauthenticated);

      // Segunda llamada: sigue igual, no reabre nada.
      session.resolveUnknownAsUnauthenticated();
      expect(session.status, SessionStatus.unauthenticated);
    });
  });
}
