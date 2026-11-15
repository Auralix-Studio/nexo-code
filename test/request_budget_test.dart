import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/data/services/grade_push_log.dart';
import 'package:nexo/data/services/session.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

import 'support/fake_nexo_api.dart';

/// JWT sin firma válida, solo con `exp` (la app no valida la firma).
String jwt(DateTime exp) {
  String part(Map<String, Object> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'none'})}.'
      '${part({'exp': exp.millisecondsSinceEpoch ~/ 1000})}.sig';
}

class _Online extends Fake implements ConnectivityService {
  @override
  bool get hasInternet => true;
  @override
  bool get firstCheckCompleted => true;
}

class _NoSession extends Fake implements SessionService {}

class _Wifi extends Fake implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];
}

/// Caché local vacío: todo lo que se pida sale de la red.
class _EmptyCache extends Fake implements CacheManager {
  @override
  Future<DateTime?> updatedAtFor(String operation) async => null;
  @override
  Future<Student?> getStudent() async => null;
  @override
  Future<void> saveStudent(Student value) async {}
  @override
  Future<List<Term>?> getPeriodos() async => null;
  @override
  Future<void> savePeriodos(List<Term> periodos) async {}
  @override
  Future<List<ScheduleClass>?> getHorario() async => null;
  @override
  Future<void> saveHorario(List<ScheduleClass> clases) async {}
  @override
  Future<List<TermAverage>?> getPromedios() async => null;
  @override
  Future<void> savePromedios(List<TermAverage> promedios) async {}
  @override
  Future<List<Payment>?> getPagos() async => null;
  @override
  Future<void> savePagos(List<Payment> pagos) async {}
  @override
  Future<List<ReportCardCourse>?> getBoleta(
    String year,
    String periodo,
  ) async => null;
  @override
  Future<void> saveBoleta(
    String year,
    String periodo,
    List<ReportCardCourse> boleta,
  ) async {}
  @override
  Future<void> clearAll() async {}
}

/// Respuestas mínimas del API para el inicio de un estudiante.
http.Response _home(http.Request req) => switch (req.url.path) {
  '/terms' => nexoOk([
    {'year': 2026, 'number': 2, 'label': '2026-2', 'active': true},
  ]),
  '/profile' => nexoOk({
    'code': 'A',
    'name': {'first': 'ANA', 'last': 'PEREZ'},
  }),
  '/grades' => nexoOk({'courses': []}),
  '/auth/login' => nexoOk(nexoSession('A')),
  _ => nexoOk({}),
};

Future<void> _settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
  });

  group('refresh token', () {
    test(
      'se guarda al iniciar sesión, rota al renovar y se borra al salir',
      () async {
        var refreshes = 0;
        final api = BackendClient(
          transport: MockClient((req) async {
            final auth = req.headers['Authorization'];
            switch (req.url.path) {
              case '/auth/login':
                return nexoOk(nexoSession('A'));
              case '/auth/refresh':
                refreshes++;
                final body = jsonDecode(req.body) as Map;
                expect(body['refresh_token'], 'ref-A');
                return nexoOk({
                  'access_token': 'tok-A2',
                  'refresh_token': 'ref-A2',
                });
              case '/auth/logout':
                return nexoOk({});
            }
            return auth == 'Bearer tok-A2'
                ? nexoOk({'code': 'A'})
                : nexoError('unauthorized', 401);
          }),
        );
        final session = SessionService(client: api);
        await session.login('A', 'pw');
        expect(AppStorage.instance.refreshToken, 'ref-A');

        await api.profile();
        expect(refreshes, 1);
        expect(AppStorage.instance.token, 'tok-A2');
        expect(AppStorage.instance.refreshToken, 'ref-A2');
        expect(AppStorage.instance.credPass, 'pw');

        await session.logout();
        expect(AppStorage.instance.refreshToken, isNull);
        expect(api.refreshToken, isNull);
      },
    );

    test('al cambiar de cuenta no queda el refresh token anterior', () async {
      final api = BackendClient(
        transport: MockClient((req) async {
          if (req.url.path == '/auth/login') {
            return nexoOk(nexoSession(loginBody(req).user));
          }
          return nexoOk({});
        }),
      );
      final session = SessionService(client: api);
      await session.login('A', 'pw-a');
      expect(AppStorage.instance.refreshToken, 'ref-A');
      await session.login('B', 'pw-b');
      expect(AppStorage.instance.refreshToken, 'ref-B');
      expect(api.refreshToken, 'ref-B');
    });

    test('401 simultáneos comparten una sola renovación', () async {
      var refreshes = 0;
      final release = Completer<void>();
      final api = BackendClient(
        transport: MockClient((req) async {
          if (req.url.path == '/auth/refresh') {
            refreshes++;
            await release.future;
            return nexoOk({'access_token': 'new', 'refresh_token': 'ref-2'});
          }
          return req.headers['Authorization'] == 'Bearer new'
              ? nexoOk({'ok': 1})
              : nexoError('unauthorized', 401);
        }),
      )..setToken('old', refresh: 'ref-1');
      var logins = 0;
      api.reauthenticate = () async {
        logins++;
        return ReauthOutcome.invalidCredentials;
      };

      final calls = [for (var i = 0; i < 7; i++) api.profile()];
      await _settle();
      release.complete();
      await Future.wait(calls);
      expect(refreshes, 1);
      expect(logins, 0, reason: 'ningún login completo');
      expect(api.accessToken, 'new');
      expect(api.refreshToken, 'ref-2');
    });

    test(
      'un 401 que llega después de renovar repite sin renovar otra vez',
      () async {
        var refreshes = 0;
        final late401 = Completer<http.Response>();
        var first = true;
        final api = BackendClient(
          transport: MockClient((req) async {
            if (req.url.path == '/auth/refresh') {
              refreshes++;
              return nexoOk({'access_token': 'new', 'refresh_token': 'ref-2'});
            }
            if (req.headers['Authorization'] == 'Bearer new') {
              return nexoOk({'ok': 1});
            }
            if (first) {
              first = false;
              return late401.future;
            }
            return nexoError('unauthorized', 401);
          }),
        )..setToken('old', refresh: 'ref-1');
        final slow = api.profile();
        await _settle();
        await api.profile();
        late401.complete(nexoError('unauthorized', 401));
        await slow;
        expect(refreshes, 1);
      },
    );

    group('arranque con el token de acceso vencido', () {
      Future<void> saveExpired() => AppStorage.instance.setAuthenticatedSession(
        token: jwt(DateTime.now().subtract(const Duration(hours: 1))),
        refreshToken: 'ref-A',
        account: 'A',
        password: 'pw',
      );

      test('usa /auth/refresh y no un login completo', () async {
        await saveExpired();
        final paths = <String>[];
        final api = BackendClient(
          transport: MockClient((req) async {
            paths.add(req.url.path);
            return nexoOk({'access_token': 'tok-new', 'refresh_token': 'r2'});
          }),
        );
        final session = SessionService(client: api);
        await session.bootstrap();
        expect(paths, ['/auth/refresh']);
        expect(session.isAuthenticated, isTrue);
        expect(AppStorage.instance.token, 'tok-new');
        expect(AppStorage.instance.refreshToken, 'r2');
      });

      test('sin red entra con el caché y no borra nada', () async {
        await saveExpired();
        final paths = <String>[];
        final api = BackendClient(
          transport: MockClient((req) async {
            paths.add(req.url.path);
            throw http.ClientException('sin red');
          }),
        );
        final session = SessionService(client: api);
        await session.bootstrap();
        expect(paths, ['/auth/refresh']);
        expect(session.isAuthenticated, isTrue);
        expect(AppStorage.instance.refreshToken, 'ref-A');
        expect(AppStorage.instance.credPass, 'pw');
      });

      test('refresh rechazado: login con las credenciales guardadas', () async {
        await saveExpired();
        final paths = <String>[];
        final api = BackendClient(
          transport: MockClient((req) async {
            paths.add(req.url.path);
            return req.url.path == '/auth/refresh'
                ? nexoError('invalid_refresh_token', 401)
                : nexoOk(nexoSession('A'));
          }),
        );
        final session = SessionService(client: api);
        await session.bootstrap();
        expect(paths, ['/auth/refresh', '/auth/login']);
        expect(session.isAuthenticated, isTrue);
        expect(AppStorage.instance.refreshToken, 'ref-A');
        expect(AppStorage.instance.token, 'tok-A');
      });

      test('credenciales rechazadas sí cierran la sesión', () async {
        await saveExpired();
        final api = BackendClient(
          transport: MockClient(
            (req) async => req.url.path == '/auth/refresh'
                ? nexoError('invalid_refresh_token', 401)
                : nexoError('invalid_credentials', 401),
          ),
        );
        final session = SessionService(client: api);
        await session.bootstrap();
        expect(session.isAuthenticated, isFalse);
      });
    });
  });

  group('reintentos', () {
    late ErrorHandler handler;
    setUp(() {
      handler = ErrorHandler(connectivity: _Online(), session: _NoSession());
    });

    Future<int> attemptsFor(Object error) async {
      var attempts = 0;
      await expectLater(
        handler.withFallback<int>(
          remote: () async {
            attempts++;
            throw error;
          },
          cached: () async => null,
          operationName: 'op',
        ),
        throwsA(anything),
      );
      return attempts;
    }

    test('timeout: no se reintenta y avisa al ping', () async {
      var reported = 0;
      handler.onNetworkError = () => reported++;
      expect(await attemptsFor(const TimeoutException('lento')), 1);
      expect(reported, 1);
    });

    test('503 upstream_unavailable: no se reintenta', () async {
      expect(
        await attemptsFor(
          const ServerException('u', status: 503, code: 'upstream_unavailable'),
        ),
        1,
      );
    });

    test('504 y auth_unavailable: no se reintentan', () async {
      expect(await attemptsFor(const ServerException('g', status: 504)), 1);
      expect(await attemptsFor(const AuthUnavailableException()), 1);
    });

    test('Retry-After largo: no se reintenta', () async {
      expect(
        await attemptsFor(
          const ServerException(
            'x',
            status: 503,
            retryAfter: Duration(seconds: 30),
          ),
        ),
        1,
      );
    });

    test('500 del backend: un reintento respetando Retry-After', () async {
      final watch = Stopwatch()..start();
      expect(
        await attemptsFor(
          const ServerException('x', status: 500, retryAfter: Duration.zero),
        ),
        2,
      );
      expect(watch.elapsed, lessThan(const Duration(milliseconds: 200)));
    });

    test('backoff exponencial con jitter', () {
      for (var seed = 0; seed < 50; seed++) {
        final r = Random(seed);
        final first = ErrorHandler.retryDelay(1, random: r).inMilliseconds;
        final second = ErrorHandler.retryDelay(2, random: r).inMilliseconds;
        expect(first, inInclusiveRange(250, 750));
        expect(second, inInclusiveRange(500, 1500));
      }
    });

    test('el cliente lee Retry-After y el código del 503', () async {
      final api = BackendClient(
        transport: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'ok': false,
              'error': {'code': 'upstream_unavailable', 'message': 'caída'},
            }),
            503,
            headers: const {
              'content-type': 'application/json',
              'retry-after': '7',
            },
          ),
        ),
      )..setToken('t');
      try {
        await api.profile();
        fail('debía fallar');
      } on BackendException catch (e) {
        expect(e.retryAfter, const Duration(seconds: 7));
        final mapped = apiErrorOf(e);
        expect(mapped, isA<ServerException>());
        expect((mapped as ServerException).isUpstreamUnavailable, isTrue);
      }
    });
  });

  group('inicio y TTL', () {
    late List<String> paths;
    late AppStore store;
    late DateTime now;

    setUp(() async {
      paths = [];
      now = DateTime(2026, 11, 15, 10);
      await AppStorage.instance.setAuthenticatedSession(
        token: 'tok-A',
        account: 'A',
        password: 'pw',
      );
      final api = BackendClient(
        transport: MockClient((req) async {
          paths.add(req.url.path);
          return _home(req);
        }),
      )..setToken('tok-A');
      store = AppStore(
        NexoRepository(DirectoryService(client: api), clock: () => now),
        cache: _EmptyCache(),
        errorHandler: ErrorHandler(
          connectivity: _Online(),
          session: _NoSession(),
        ),
        connectivity: _Online(),
      )..clock = () => now;
    });
    tearDown(() => store.dispose());

    Future<void> openHome({bool force = false}) async {
      await store.loadHomeEssentials(force: force);
      await _settle();
    }

    test('el inicio no pide /languages (el horario ya trae Idiomas)', () async {
      await openHome();
      expect(paths, isNot(contains('/languages')));
      expect(paths.toSet(), {
        '/terms',
        '/profile',
        '/grades/summary',
        '/schedule',
        '/payments',
        '/grades',
      });
      expect(paths, hasLength(6), reason: 'antes eran 7 (con /languages)');
    });

    test('volver al inicio dentro del TTL no va a la red', () async {
      await openHome();
      paths.clear();
      now = now.add(const Duration(minutes: 2));
      await openHome();
      expect(paths, isEmpty);
    });

    test('pasado el TTL de notas solo se piden las notas', () async {
      await openHome();
      paths.clear();
      now = now.add(const Duration(minutes: 6));
      await openHome();
      expect(paths.toSet(), {'/grades/summary', '/grades'});
      paths.clear();
      now = now.add(const Duration(minutes: 10));
      await openHome();
      expect(paths.toSet(), {'/grades/summary', '/grades', '/payments'});
    });

    test('pull-to-refresh fuerza la recarga', () async {
      await openHome();
      paths.clear();
      // Pasado el memo de 30 s del repositorio, que comparte respuestas
      // entre pantallas que piden lo mismo a la vez.
      now = now.add(const Duration(seconds: 31));
      await openHome(force: true);
      expect(paths, hasLength(6));
    });

    test('la boleta al volver a la app respeta su TTL', () async {
      await openHome();
      paths.clear();
      now = now.add(const Duration(minutes: 3));
      await store.checkActiveBoleta();
      expect(paths, isEmpty);
      now = now.add(const Duration(minutes: 3));
      await store.checkActiveBoleta();
      expect(paths, ['/grades']);
    });

    test('/languages se pide en Idiomas y respeta su TTL', () async {
      await store.loadIdiomasMatricula();
      await store.loadIdiomasMatricula();
      expect(paths.where((p) => p == '/languages'), hasLength(1));
      await store.loadIdiomasMatricula(force: true);
      expect(paths.where((p) => p == '/languages'), hasLength(2));
    });
  });

  group('push de notas y aviso local', () {
    test('un push reciente silencia el aviso local de ese curso', () {
      var now = DateTime(2026, 11, 15, 10);
      final log = GradePushLog(clock: () => now);
      log.record(code: 'MAT101', title: 'Nueva nota · Matemática I');
      expect(log.wasRecent(code: 'MAT101'), isTrue);
      expect(log.wasRecent(name: 'Matemática I'), isTrue);
      expect(log.wasRecent(code: 'FIS101', name: 'Física'), isFalse);
      now = now.add(GradePushLog.window);
      expect(log.wasRecent(code: 'MAT101'), isFalse);
    });
  });

  group('ping a /status', () {
    test(
      'cada 3 min, pausado en segundo plano, al volver y tras errores',
      () async {
        var now = DateTime(2026, 11, 15, 10);
        final pings = <String>[];
        final conn = ConnectivityService(
          connectivity: _Wifi(),
          httpClient: MockClient((req) async {
            pings.add(req.url.path);
            return http.Response('{}', 200);
          }),
          clock: () => now,
        );
        addTearDown(conn.dispose);
        expect(ConnectivityService.pingInterval, const Duration(minutes: 3));
        await conn.start();
        expect(pings, ['/status']);

        // Varios errores de red seguidos: un solo ping.
        now = now.add(const Duration(minutes: 1));
        conn.reportNetworkError();
        conn.reportNetworkError();
        await _settle();
        expect(pings, hasLength(2));

        // En segundo plano (Windows minimizada = hidden) no se sondea.
        conn.handleLifecycle(AppLifecycleState.inactive);
        expect(conn.isForeground, isTrue);
        conn.handleLifecycle(AppLifecycleState.hidden);
        expect(conn.isForeground, isFalse);
        now = now.add(const Duration(minutes: 5));
        conn.reportNetworkError();
        await _settle();
        expect(pings, hasLength(2));

        // Al volver: un ping en el acto.
        conn.handleLifecycle(AppLifecycleState.resumed);
        await _settle();
        expect(pings, hasLength(3));
      },
    );
  });
}
