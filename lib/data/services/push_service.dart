import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/services/grade_push_log.dart';

/// Mensaje push ya separado de Firebase: lo que la app necesita de él.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});
  final String? title;
  final String? body;
  final Map<String, String> data;

  /// El backend lo envía cuando un docente guarda una nota.
  bool get isGrade => data['type'] == 'grade';
}

/// Lo que PushService usa del SDK de mensajería. La implementación real
/// (Firebase) vive en `push_firebase.dart`; los tests usan una falsa.
abstract interface class PushTransport {
  /// Inicializa el SDK. Si falla, el push queda desactivado.
  Future<void> initialize();

  /// Pide permiso para mostrar notificaciones (POST_NOTIFICATIONS en
  /// Android 13+).
  Future<bool> requestPermission();
  Future<String?> getToken();
  Stream<String> get onTokenRefresh;

  /// Mensajes recibidos con la app en primer plano.
  Stream<PushMessage> get onForegroundMessage;

  /// Notificación tocada con la app en segundo plano.
  Stream<PushMessage> get onMessageOpened;

  /// Notificación que abrió la app estando cerrada.
  Future<PushMessage?> initialMessage();
}

/// Muestra en el dispositivo lo que llega en primer plano.
abstract interface class PushPresenter {
  Future<void> createChannel();
  Future<void> show(PushMessage message);
}

/// Push de notas (FCM) para estudiantes.
///
/// Solo funciona en Android: en el resto de plataformas, o si Firebase no
/// arranca, [available] queda en `false` y nada de esto se ejecuta. Docentes
/// y apoderados no registran el dispositivo.
class PushService extends ChangeNotifier {
  PushService({
    required BackendClient client,
    required PushTransport transport,
    required PushPresenter presenter,
    bool? supported,
  }) : _client = client,
       _transport = transport,
       _presenter = presenter,
       _supported = supported ?? _isAndroid;

  /// La instancia de la app (la crea `main`); `null` en tests y donde no
  /// se configuró.
  static PushService? instance;

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  final BackendClient _client;
  final PushTransport _transport;
  final PushPresenter _presenter;
  final bool _supported;

  /// Se llama al tocar una notificación de notas.
  void Function()? onOpenGrades;

  bool _available = false;
  bool _initializing = false;
  String? _student;
  String? _token;
  String? _registeredFor;
  String? _registeredToken;
  final List<StreamSubscription<Object?>> _subscriptions = [];

  /// Firebase arrancó en este dispositivo.
  bool get available => _available;

  /// Hay un estudiante con sesión y el push funciona: se puede mostrar el
  /// interruptor de Configuración.
  bool get canManage => _available && _student != null;

  @visibleForTesting
  String? get registeredFor => _registeredFor;

  Future<void> init() async {
    if (!_supported || _available || _initializing) return;
    _initializing = true;
    try {
      await _transport.initialize();
      await _presenter.createChannel().catchError((Object e) {
        debugPrint('Push: no se pudo crear el canal ($e)');
      });
      _subscriptions
        ..add(_transport.onTokenRefresh.listen(_onTokenRefresh))
        ..add(_transport.onForegroundMessage.listen(_onForeground))
        ..add(_transport.onMessageOpened.listen(_onOpened));
      _available = true;
      notifyListeners();
      final initial = await _transport.initialMessage();
      if (initial != null) _onOpened(initial);
      // Sin esperar: el registro va por red y no debe frenar el arranque.
      unawaited(_register());
    } catch (e) {
      debugPrint('Push: no disponible ($e)');
      await _cancelSubscriptions();
      _available = false;
    } finally {
      _initializing = false;
    }
  }

  /// La sesión cambió: [studentAccount] es la cuenta del estudiante con
  /// sesión, o `null` si no hay sesión o no es estudiante.
  void sessionChanged({required String? studentAccount}) {
    final account = (studentAccount?.isEmpty ?? true) ? null : studentAccount;
    if (account == _student) return;
    _student = account;
    notifyListeners();
    if (account != null && _available) unawaited(_register());
  }

  /// Cierre de sesión: da de baja el token con la sesión que se va. Se llama
  /// antes de que el cliente suelte el token de acceso; no espera.
  void signingOut() {
    final token = _registeredToken;
    final registered = _registeredFor != null;
    _registeredFor = null;
    _registeredToken = null;
    if (_student != null) {
      _student = null;
      notifyListeners();
    }
    if (!registered || token == null) return;
    unawaited(
      _client.unregisterDevice(token).catchError((Object e) {
        // El servidor también borra los dispositivos en /auth/logout.
        debugPrint('Push: no se pudo dar de baja el dispositivo ($e)');
      }),
    );
  }

  /// Si la cuenta recibe push de notas (`GET /me/notifications`).
  Future<bool> gradesEnabled() async =>
      (await _client.notificationSettings()).grades;

  /// Activa o desactiva el push de notas; devuelve lo que guardó el servidor.
  Future<bool> setGradesEnabled(bool enabled) async =>
      (await _client.setNotificationSettings(grades: enabled)).grades;

  Future<void> _register() async {
    final account = _student;
    if (account == null || !_available) return;
    try {
      await _transport.requestPermission();
      final token = _token ??= await _transport.getToken();
      if (token == null || token.isEmpty) return;
      if (_registeredFor == account && _registeredToken == token) return;
      await _client.registerDevice(token);
      // La sesión pudo cambiar mientras tanto.
      if (_student == account && _token == token) {
        _registeredFor = account;
        _registeredToken = token;
      }
    } catch (e) {
      debugPrint('Push: no se pudo registrar el dispositivo ($e)');
    }
  }

  void _onTokenRefresh(String token) {
    if (token.isEmpty || token == _token) return;
    _token = token;
    unawaited(_register());
  }

  void _onForeground(PushMessage message) {
    if (_student == null) return;
    _remember(message);
    final title = message.title;
    final body = message.body;
    if (title == null && body == null) return;
    unawaited(
      _presenter.show(message).catchError((Object e) {
        debugPrint('Push: no se pudo mostrar ($e)');
      }),
    );
  }

  void _onOpened(PushMessage message) {
    _remember(message);
    if (message.isGrade) onOpenGrades?.call();
  }

  /// El aviso local de la boleta no repite lo que ya avisó este push.
  void _remember(PushMessage message) {
    if (!message.isGrade) return;
    GradePushLog.instance.record(
      code: message.data['course'],
      title: message.title,
    );
  }

  Future<void> _cancelSubscriptions() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    unawaited(_cancelSubscriptions());
    super.dispose();
  }
}
