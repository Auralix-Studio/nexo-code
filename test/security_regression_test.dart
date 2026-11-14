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
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/data/services/session.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

import 'support/fake_nexo_api.dart';

http.Response loginResponse(String user) =>
    nexoOk(nexoSession(user, token: 'token-$user'));

Student student(String user) => Student(
  id: user,
  fullName: user,
  career: '',
  faculty: '',
  campus: '',
  level: '',
  studyPlan: '',
  modality: '',
  isEnrolled: false,
);

class _Online extends Fake implements ConnectivityService {
  @override
  bool get hasInternet => true;
  @override
  bool get firstCheckCompleted => true;
}

class _ProfileRepo extends Fake implements NexoRepository {
  final Completer<Student> response = Completer();
  final Completer<void> started = Completer();
  @override
  Future<Student> profile() {
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

const _gw = GradeWrite(matricula: 'm', unidadId: 121, tipoNotaId: 11, nota: 15);

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
      // The old Intranet cookie moved into the vault too, and is wiped below.
      expect(vault.values.values.join(), contains('PHPSESSID=private-cookie'));
      await reloaded.clear(keepCredentials: false);
      expect(vault.values, isEmpty);
      expect(reloaded.credPass, isNull);
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
      await AppStorage.instance.setCredentials('A', 'password-A');
      final repo = _ProfileRepo();
      final cache = _Cache();
      final api = BackendClient(transport: MockClient((_) async => nexoOk({})));
      final session = SessionService(client: api);
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
    final api = BackendClient(
      transport: MockClient((req) {
        if (req.url.path == '/auth/logout') return Future.value(nexoOk({}));
        started.complete();
        return response.future;
      }),
    );
    final session = SessionService(client: api);
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
    expect(api.accessToken, isNull);
    expect(AppStorage.instance.token, isNull);
    expect(AppStorage.instance.credPass, isNull);
  });

  test('reauthentication from A cannot replace an authenticated B', () async {
    final refreshing = Completer<void>();
    final oldResponse = Completer<http.Response>();
    int aLogins = 0;
    final api = BackendClient(
      transport: MockClient((request) async {
        switch (request.url.path) {
          case '/auth/login':
            final user = loginBody(request).user;
            if (user == 'A' && ++aLogins == 2) {
              refreshing.complete();
              return oldResponse.future;
            }
            return loginResponse(user);
          case '/auth/logout':
            return nexoOk({});
          case '/auth/refresh':
            return nexoError('invalid_refresh_token', 401);
        }
        return nexoError('unauthorized', 401);
      }),
    );
    final session = SessionService(client: api);
    await session.login('A', 'password-A');
    final pending = api.profile();
    final rejected = expectLater(
      pending,
      throwsA(isA<StaleSessionException>()),
    );
    await refreshing.future;
    await session.logout();
    await session.login('B', 'password-B');
    oldResponse.complete(loginResponse('A'));
    await rejected;
    expect(api.accessToken, 'token-B');
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
      final api = BackendClient(
        transport: MockClient((_) {
          requests++;
          started.complete();
          return response.future;
        }),
      );
      api.setToken('A');
      api.reauthenticate = () async {
        refreshes++;
        return ReauthOutcome.refreshed;
      };
      final pending = _teacher(api).saveGrades('sec_1', [_gw]);
      final rejected = expectLater(
        pending,
        throwsA(isA<StaleSessionException>()),
      );
      await started.future;
      api.scope.invalidate();
      api.setToken('B');
      response.complete(nexoError('unauthorized', 401));
      await rejected;
      expect(requests, 1);
      expect(refreshes, 0);
      expect(api.accessToken, 'B');
    },
  );

  for (final body in [
    '{"ok":false,"error":{"code":"rejected"}}',
    '{"ok":true,"data":{"saved":0,"failed":[{"student":"s","reason":"rejected"}]}}',
    '{"ok":true,"data":{"result":"error","message":"Fuera de horario"}}',
    '{}',
    '',
    'invalid JSON',
  ]) {
    test('teacher mutations require explicit confirmation: $body', () async {
      final api = BackendClient(
        transport: MockClient((_) async => http.Response(body, 200)),
      )..setToken('t');
      final repo = _teacher(api);
      const student = AttendanceStudent(
        code: 's',
        name: 'S',
        matriculaAsignaturaId: 'm',
        codCursal: '1',
        observacion: '',
        percent: null,
        marks: [],
      );
      final mark = AttendanceMark(
        asistenciaId: 1,
        date: DateTime(2026, 9, 25, 10),
        state: 2,
        tipoUnidadId: 121,
      );
      final punch = body.contains('result');
      for (final operation in <Future<void> Function()>[
        if (!punch) ...[
          () => repo.saveGrades('sec_1', [_gw]),
          () => repo.saveGrades('sec_1', [
            const GradeWrite(
              matricula: 'm',
              unidadId: 121,
              tipoNotaId: 11,
              notaId: 9,
              nota: 15,
            ),
          ]),
          () => repo.takeAttendance(
            'sec_1',
            unidadId: 121,
            marks: [(student: student, state: 1)],
          ),
          () => repo.correctAttendance('sec_1', [
            (mark: mark, student: student, state: 3),
          ]),
        ],
        () => repo.punch('123'),
      ]) {
        await expectLater(
          operation(),
          throwsA(anyOf(isA<BadRequestException>(), isA<BackendException>())),
        );
      }
    });
  }

  test('a confirmed teacher write completes normally', () async {
    final api = BackendClient(
      transport: MockClient((_) async => nexoOk({'saved': 1, 'failed': []})),
    )..setToken('t');
    await expectLater(_teacher(api).saveGrades('sec_1', [_gw]), completes);
  });
}

/// Módulo docente sobre un cliente ya conectado (no vuelve a iniciar sesión).
NexoTeacherRepository _teacher(BackendClient api) =>
    NexoTeacherRepository(DirectoryService(client: api));
