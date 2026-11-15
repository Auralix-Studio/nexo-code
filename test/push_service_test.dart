import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/services/push_service.dart';

import 'support/fake_nexo_api.dart';

/// Backend falso que anota cada petición y responde según la ruta.
class _Backend {
  final requests = <http.Request>[];
  bool grades = true;
  int status = 200;

  late final client = BackendClient(
    transport: MockClient((req) async {
      requests.add(req);
      if (status != 200) return nexoError('upstream_unavailable', status);
      final path = req.url.path;
      if (path == '/me/devices' && req.method == 'POST') {
        return nexoOk({
          'registered': true,
          'notifications': {'grades': grades},
        }, status: 201);
      }
      if (path.startsWith('/me/devices/') && req.method == 'DELETE') {
        return nexoOk({'registered': false});
      }
      if (path == '/me/notifications') {
        if (req.method == 'PUT') {
          grades = (jsonDecode(req.body) as Map)['grades'] as bool;
        }
        return nexoOk({'grades': grades, 'devices': 2});
      }
      return nexoError('not_found', 404);
    }),
  )..setToken('access-A');

  Iterable<http.Request> where(String method, String prefix) => requests.where(
    (r) => r.method == method && r.url.path.startsWith(prefix),
  );
}

class _FakeTransport implements PushTransport {
  bool fail = false;
  String? token = 'fcm-token-1';
  PushMessage? initial;
  int permissionRequests = 0;
  final refresh = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();

  @override
  Future<void> initialize() async {
    if (fail) throw Exception('firebase down');
  }

  @override
  Future<bool> requestPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Stream<String> get onTokenRefresh => refresh.stream;

  @override
  Stream<PushMessage> get onForegroundMessage => foreground.stream;

  @override
  Stream<PushMessage> get onMessageOpened => opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;
}

class _FakePresenter implements PushPresenter {
  int channels = 0;
  final shown = <PushMessage>[];

  @override
  Future<void> createChannel() async => channels++;

  @override
  Future<void> show(PushMessage message) async => shown.add(message);
}

const _grade = PushMessage(
  title: 'Nueva nota · Cálculo I',
  body: 'Unidad 1 · Práctica: 15',
  data: {'type': 'grade', 'term': '2026-2', 'course': 'MAT101'},
);

void main() {
  group('BackendClient push', () {
    test(
      'registerDevice envía token y plataforma y lee las preferencias',
      () async {
        final backend = _Backend()..grades = false;
        final settings = await backend.client.registerDevice('tok');
        final req = backend.requests.single;
        expect(req.method, 'POST');
        expect(req.url.path, '/me/devices');
        expect(req.headers['Authorization'], 'Bearer access-A');
        expect(jsonDecode(req.body), {'token': 'tok', 'platform': 'android'});
        expect(settings.grades, isFalse);
      },
    );

    test('unregisterDevice codifica el token en la ruta', () async {
      final backend = _Backend();
      await backend.client.unregisterDevice('a:b/c d');
      final req = backend.requests.single;
      expect(req.method, 'DELETE');
      expect(req.url.toString(), endsWith('/me/devices/a%3Ab%2Fc%20d'));
    });

    test('unregisterDevice conserva el token de acceso si se suelta '
        'enseguida', () async {
      final backend = _Backend();
      final pending = backend.client.unregisterDevice('tok');
      backend.client.setToken(null);
      await pending;
      expect(
        backend.requests.single.headers['Authorization'],
        'Bearer access-A',
      );
    });

    test('GET y PUT /me/notifications', () async {
      final backend = _Backend();
      final current = await backend.client.notificationSettings();
      expect(current.grades, isTrue);
      expect(current.devices, 2);
      final saved = await backend.client.setNotificationSettings(grades: false);
      expect(saved.grades, isFalse);
      final put = backend.where('PUT', '/me/notifications').single;
      expect(jsonDecode(put.body), {'grades': false});
    });

    test('PushSettings tolera campos ausentes', () {
      final s = PushSettings.fromJson(const {});
      expect(s.grades, isFalse);
      expect(s.devices, isNull);
    });
  });

  group('PushService', () {
    late _Backend backend;
    late _FakeTransport transport;
    late _FakePresenter presenter;

    PushService build({bool supported = true}) => PushService(
      client: backend.client,
      transport: transport,
      presenter: presenter,
      supported: supported,
    );

    setUp(() {
      backend = _Backend();
      transport = _FakeTransport();
      presenter = _FakePresenter();
    });

    test('fuera de Android no hace nada', () async {
      final push = build(supported: false);
      push.sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      expect(push.available, isFalse);
      expect(push.canManage, isFalse);
      expect(backend.requests, isEmpty);
      expect(presenter.channels, 0);
    });

    test('si Firebase falla queda desactivado sin lanzar', () async {
      transport.fail = true;
      final push = build()..sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      expect(push.available, isFalse);
      expect(push.canManage, isFalse);
      expect(backend.requests, isEmpty);
    });

    test('registra al estudiante que ya tenía sesión al arrancar', () async {
      final push = build()..sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      expect(presenter.channels, 1);
      expect(transport.permissionRequests, 1);
      final post = backend.where('POST', '/me/devices').single;
      expect(jsonDecode(post.body)['token'], 'fcm-token-1');
      expect(push.registeredFor, 'A');
      expect(push.canManage, isTrue);
    });

    test(
      'registra al iniciar sesión y no repite para la misma cuenta',
      () async {
        final push = build();
        await push.init();
        await pumpEventQueue();
        expect(backend.requests, isEmpty);
        push.sessionChanged(studentAccount: 'A');
        await pumpEventQueue();
        push.sessionChanged(studentAccount: 'A');
        await pumpEventQueue();
        expect(backend.where('POST', '/me/devices'), hasLength(1));
      },
    );

    test('docentes y sesiones cerradas no registran', () async {
      final push = build();
      await push.init();
      push.sessionChanged(studentAccount: null);
      push.sessionChanged(studentAccount: '');
      await pumpEventQueue();
      expect(backend.requests, isEmpty);
      expect(push.canManage, isFalse);
    });

    test('vuelve a registrar cuando FCM renueva el token', () async {
      final push = build()..sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      transport.refresh.add('fcm-token-2');
      await pumpEventQueue();
      final posts = backend.where('POST', '/me/devices').toList();
      expect(posts, hasLength(2));
      expect(jsonDecode(posts.last.body)['token'], 'fcm-token-2');
    });

    test('al cerrar sesión da de baja el token registrado', () async {
      final push = build()..sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      push.signingOut();
      backend.client.setToken(null);
      await pumpEventQueue();
      final delete = backend.where('DELETE', '/me/devices/').single;
      expect(delete.url.path, '/me/devices/fcm-token-1');
      expect(delete.headers['Authorization'], 'Bearer access-A');
      expect(push.registeredFor, isNull);
      expect(push.canManage, isFalse);
    });

    test('cerrar sesión sin registro no llama al backend', () async {
      final push = build();
      await push.init();
      push.signingOut();
      await pumpEventQueue();
      expect(backend.requests, isEmpty);
    });

    test('un fallo al registrar no rompe y se reintenta en el próximo '
        'inicio de sesión', () async {
      backend.status = 503;
      final push = build()..sessionChanged(studentAccount: 'A');
      await push.init();
      await pumpEventQueue();
      expect(push.registeredFor, isNull);
      backend.status = 200;
      push
        ..signingOut()
        ..sessionChanged(studentAccount: 'A');
      await pumpEventQueue();
      expect(push.registeredFor, 'A');
    });

    test('muestra en primer plano solo con un estudiante con sesión', () async {
      final push = build();
      await push.init();
      transport.foreground.add(_grade);
      await pumpEventQueue();
      expect(presenter.shown, isEmpty);
      push.sessionChanged(studentAccount: 'A');
      transport.foreground.add(_grade);
      transport.foreground.add(const PushMessage(data: {'type': 'grade'}));
      await pumpEventQueue();
      expect(presenter.shown.single.title, 'Nueva nota · Cálculo I');
    });

    test('tocar un push de notas abre la pantalla de notas', () async {
      var opened = 0;
      transport.initial = _grade;
      final push = build()..onOpenGrades = () => opened++;
      await push.init();
      expect(opened, 1);
      transport.opened.add(_grade);
      transport.opened.add(const PushMessage(data: {'type': 'other'}));
      await pumpEventQueue();
      expect(opened, 2);
    });

    test('lee y cambia la preferencia de notas', () async {
      final push = build();
      expect(await push.gradesEnabled(), isTrue);
      expect(await push.setGradesEnabled(false), isFalse);
      expect(await push.gradesEnabled(), isFalse);
    });
  });
}
