import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/intranet_client.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/data/session.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/domain/unified_models.dart';

http.Response loginResponse(String user) => http.Response(
  jsonEncode({
    'success': true,
    'data': {
      'token': 'token-$user',
      'info': {'codigo': user},
    },
  }),
  200,
);

Student student(String user) =>
    Student.fromSigmaJson({'est_Id': user, 'estudiante': user});

class _Online extends Fake implements ConnectivityService {
  @override
  bool get hasInternet => true;
  @override
  bool get firstCheckCompleted => true;
}

class _ProfileRepo extends Fake implements SigmaRepository {
  final Completer<Student> response = Completer();
  final Completer<void> started = Completer();
  @override
  Future<Student> infoEstudiante() {
    started.complete();
    return response.future;
  }
}

class _Cache extends Fake implements CacheManager {
  Student? saved;
  @override
  Future<Student?> getStudent() async => saved;
  @override
  Future<void> saveStudent(Student value) async {
    saved = value;
  }

  @override
  Future<void> clearAll() async {
    saved = null;
  }
}

class _BrokenVault implements SecretStore {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String? value) async =>
      throw StateError('vault unavailable');
}

class _SlowVault extends MemorySecretStore {
  final started = Completer<void>();
  final release = Completer<void>();
  bool delayed = false;
  @override
  Future<void> write(String key, String? value) async {
    if (value != null && !delayed) {
      delayed = true;
      started.complete();
      await release.future;
    }
    await super.write(key, value);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
  });

  test(
    'migrates legacy secrets out of preferences and clears every session secret',
    () async {
      SharedPreferences.setMockInitialValues({
        'nexo.token': 'legacy-token',
        'nexo.cred.user': base64Encode(utf8.encode('A')),
        'nexo.cred.pass': base64Encode(utf8.encode('private-password')),
        'nexo.intranet.cookies': 'PHPSESSID=private-cookie',
        'nexo.intranet.user': 'A',
        'nexo.themeMode': 'dark',
      });
      final vault = MemorySecretStore();
      final storage = await AppStorage.init(secrets: vault);
      expect(storage.credPass, 'private-password');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {'nexo.themeMode'});
      final reloaded = await AppStorage.init(secrets: vault);
      expect(reloaded.token, 'legacy-token');
      expect(reloaded.intranetCookies, 'PHPSESSID=private-cookie');
      await reloaded.clear(keepCredentials: false);
      expect(vault.values, isEmpty);
      expect(reloaded.credPass, isNull);
      expect(reloaded.intranetCookies, isNull);
      expect(reloaded.intranetUser, isNull);
      expect(reloaded.themeMode, 'dark');
    },
  );

  test('vault failure never falls back to plaintext preferences', () async {
    SharedPreferences.setMockInitialValues({
      'nexo.cred.pass': base64Encode(utf8.encode('private-password')),
    });
    await expectLater(
      AppStorage.init(secrets: _BrokenVault()),
      throwsStateError,
    );
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('memory-only sessions cannot survive a browser reload', () async {
    await AppStorage.instance.setCredentials('A', 'password');
    await AppStorage.instance.setToken('token-A');
    final reloaded = await AppStorage.init(secrets: MemorySecretStore());
    expect(reloaded.token, isNull);
    expect(reloaded.hasCredentials, isFalse);
  });

  test('logout wins over an already pending secure-storage write', () async {
    final vault = _SlowVault();
    final storage = await AppStorage.init(secrets: vault);
    final saving = storage.setAuthenticatedSession(
      token: 'A',
      account: 'A',
      password: 'private',
    );
    await vault.started.future;
    final clearing = storage.clear(keepCredentials: false);
    expect(storage.token, isNull);
    vault.release.complete();
    await saving;
    await clearing;
    final reloaded = await AppStorage.init(secrets: vault);
    expect(reloaded.token, isNull);
    expect(reloaded.credPass, isNull);
    expect(vault.values, isEmpty);
  });

  test(
    'a pending profile cannot repopulate state or cache after logout',
    () async {
      final repo = _ProfileRepo();
      final cache = _Cache();
      final api = ApiClient();
      addTearDown(api.close);
      final session = SessionService(
        apiClient: api,
        repo: SigmaRepository(api),
      );
      final store = AppStore(
        repo,
        cache: cache,
        errorHandler: ErrorHandler(connectivity: _Online(), session: session),
        connectivity: _Online(),
        scope: api.scope,
      );
      addTearDown(store.dispose);
      final pending = store.loadProfile();
      await repo.started.future;
      await store.clear();
      repo.response.complete(student('A'));
      expect(await pending, isNull);
      expect(store.profile.value, isNull);
      expect(cache.saved, isNull);
    },
  );

  test('pending login cannot restore credentials after logout', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final api = ApiClient(
      transport: MockClient((_) {
        started.complete();
        return response.future;
      }),
    );
    addTearDown(api.close);
    final session = SessionService(apiClient: api, repo: SigmaRepository(api));
    final pending = session.login('A', 'password-A');
    final rejected = expectLater(
      pending,
      throwsA(isA<StaleSessionException>()),
    );
    await started.future;
    await session.logout();
    response.complete(loginResponse('A'));
    await rejected;
    expect(session.isAuthenticated, isFalse);
    expect(api.token, isNull);
    expect(AppStorage.instance.token, isNull);
    expect(AppStorage.instance.credPass, isNull);
  });

  test('reauthentication from A cannot replace an authenticated B', () async {
    final refreshing = Completer<void>();
    final oldResponse = Completer<http.Response>();
    int aLogins = 0;
    final api = ApiClient(
      transport: MockClient((request) async {
        if (request.url.path.endsWith('/Login/SesionV1')) {
          final user = (jsonDecode(request.body) as Map)['usuarioId'] as String;
          if (user == 'A' && ++aLogins == 2) {
            refreshing.complete();
            return oldResponse.future;
          }
          return loginResponse(user);
        }
        return http.Response('{}', 401);
      }),
    );
    addTearDown(api.close);
    final session = SessionService(apiClient: api, repo: SigmaRepository(api));
    await session.login('A', 'password-A');
    final pending = api.get<String>('profile', decode: (_) => 'old');
    final rejected = expectLater(
      pending,
      throwsA(isA<StaleSessionException>()),
    );
    await refreshing.future;
    await session.logout();
    await session.login('B', 'password-B');
    oldResponse.complete(loginResponse('A'));
    await rejected;
    expect(api.token, 'token-B');
    expect(session.user?.code, 'B');
    expect(AppStorage.instance.credUser, 'B');
    expect(AppStorage.instance.token, 'token-B');
  });

  test(
    'old 401 does not retry a teacher write with the new account token',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      int requests = 0;
      int refreshes = 0;
      final api = ApiClient(
        transport: MockClient((_) {
          requests++;
          started.complete();
          return response.future;
        }),
      );
      addTearDown(api.close);
      api.setToken('A');
      api.reauthenticate = () async {
        refreshes++;
        return ReauthOutcome.refreshed;
      };
      final pending = TeacherRepository(
        api,
      ).updateNota(cleAuto: 'c', codigoAlumno: 's', grade: '15');
      final rejected = expectLater(
        pending,
        throwsA(isA<StaleSessionException>()),
      );
      await started.future;
      api.scope.invalidate();
      api.setToken('B');
      response.complete(http.Response('{}', 401));
      await rejected;
      expect(requests, 1);
      expect(refreshes, 0);
      expect(api.token, 'B');
    },
  );

  test(
    'intranet logout discards late cookies and captured credentials',
    () async {
      final started = Completer<void>();
      final response = Completer<http.Response>();
      final client = IntranetClient(
        transport: MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      addTearDown(client.close);
      final repo = IntranetRepository(client);
      final pending = repo.ensureSession('A', 'password-A');
      final rejected = expectLater(
        pending,
        throwsA(isA<StaleSessionException>()),
      );
      await started.future;
      repo.invalidate();
      response.complete(
        http.Response('', 200, headers: {'set-cookie': 'PHPSESSID=old'}),
      );
      await rejected;
      expect(client.exportCookies(), isNull);
      expect(client.reauthenticate, isNull);
      expect(repo.currentUser, isNull);
      expect(AppStorage.instance.intranetCookies, isNull);
    },
  );

  for (final body in [
    '{"success":false,"mensaje":"rechazado"}',
    '{}',
    '',
    'invalid JSON',
  ]) {
    test('teacher mutations require explicit confirmation: $body', () async {
      final api = ApiClient(
        transport: MockClient((_) async => http.Response(body, 200)),
      );
      addTearDown(api.close);
      final repo = TeacherRepository(api);
      for (final operation in <Future<void> Function()>[
        () => repo.updateNota(cleAuto: 'c', codigoAlumno: 's', grade: '15'),
        () => repo.updateEvaluacion(
          cleAuto: 'c',
          codigoAlumno: 's',
          codigoEvaluacion: 'e',
          grade: '15',
        ),
        () => repo.guardarAsistenciaDelDia(
          cleAuto: 'c',
          date: DateTime(2026, 9, 25),
          estados: {'s': 'P'},
        ),
      ]) {
        await expectLater(operation(), throwsA(isA<BadRequestException>()));
      }
    });
  }

  test('a confirmed teacher write completes normally', () async {
    final api = ApiClient(
      transport: MockClient(
        (_) async => http.Response('{"success":true}', 200),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      TeacherRepository(
        api,
      ).updateNota(cleAuto: 'c', codigoAlumno: 's', grade: '15'),
      completes,
    );
  });
}
