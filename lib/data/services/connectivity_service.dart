import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:nexo/core/config.dart';

enum ServerStatus { online, offline, degraded }

/// Estado de la red y de la API de Nexo.
///
/// El ping a `/status` es barato pero gasta cuota del limitador por IP del
/// backend, así que se hace poco: cada [pingInterval] y solo con la app en
/// primer plano, al volver de segundo plano y tras un error de red.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService({
    Connectivity? connectivity,
    http.Client? httpClient,
    DateTime Function()? clock,
  }) : _connectivity = connectivity ?? Connectivity(),
       _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient = httpClient == null,
       _clock = clock ?? DateTime.now;

  /// Cada cuánto se revisa la API con la app en primer plano.
  static const pingInterval = Duration(minutes: 3);

  /// Separación mínima entre pings fuera del intervalo (al volver o tras un
  /// error de red), para que varias fallas a la vez no disparen varios.
  static const minPingGap = Duration(seconds: 20);

  final Connectivity _connectivity;
  final DateTime Function() _clock;
  bool _foreground = true;
  bool _started = false;
  DateTime? _lastPing;
  AppLifecycleListener? _lifecycle;
  int _pings = 0;

  /// Pings a `/status` hechos (para pruebas).
  @visibleForTesting
  int get pingCount => _pings;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _disposed = false;
  int _healthRevision = 0;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _hasInternet = false;
  ServerStatus _apiStatus = ServerStatus.offline;

  /// Completer que se resuelve cuando el primer health-check termina.
  /// Se mantiene separado de networkReady para distinguir el diagnóstico
  /// completo de la disponibilidad inicial de una interfaz de red.
  final Completer<void> _firstCheckCompleter = Completer<void>();
  final Completer<void> _networkReadyCompleter = Completer<void>();

  /// La interfaz de red ya fue consultada; los diagnósticos HTTP pueden seguir
  /// pendientes. Permite cargar datos sin esperar al servidor más lento.
  Future<void> get networkReady => _networkReadyCompleter.future;

  /// Future que se resuelve al completar el primer chequeo de conectividad.
  Future<void> get firstCheckDone => _firstCheckCompleter.future;

  /// `true` una vez que el primer health-check haya terminado.
  bool get firstCheckCompleted => _firstCheckCompleter.isCompleted;

  bool get hasInternet => _hasInternet;

  /// Estado de la API de Nexo, el único servidor con el que habla la app
  /// (ella consulta a la universidad).
  ServerStatus get apiStatus => _apiStatus;
  bool get isFullyOnline => _hasInternet && _apiStatus == ServerStatus.online;
  bool _isChecking = false;
  bool get isChecking => _isChecking;
  Future<void> start() async {
    if (_disposed) return;
    await _subscription?.cancel();
    if (_disposed) return;
    _timer?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
    try {
      final initialResults = await _connectivity.checkConnectivity();
      await _handleConnectivityChange(initialResults);
    } finally {
      // Un fallo del plugin tampoco debe dejar el inicio esperando para siempre.
      if (!_networkReadyCompleter.isCompleted) {
        _networkReadyCompleter.complete();
      }
      if (!_firstCheckCompleter.isCompleted) {
        _firstCheckCompleter.complete();
      }
    }
    if (_disposed) return;
    _started = true;
    _startTimer();
  }

  /// Escucha el ciclo de vida de la app para pausar el ping en segundo
  /// plano (minimizada en Windows incluida). Lo llama `main`.
  void bindLifecycle() {
    _lifecycle ??= AppLifecycleListener(onStateChange: handleLifecycle);
  }

  /// `inactive` sigue siendo visible (en Windows, la ventana sin foco); solo
  /// `hidden`/`paused`/`detached` cuentan como segundo plano.
  void handleLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        setForeground(true);
      case AppLifecycleState.inactive:
        break;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        setForeground(false);
    }
  }

  bool get isForeground => _foreground;

  /// En segundo plano se detiene el ping; al volver se revisa en el acto y
  /// se reanuda el intervalo.
  void setForeground(bool foreground) {
    if (_disposed || foreground == _foreground) return;
    _foreground = foreground;
    if (!foreground) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    if (!_started) return;
    _startTimer();
    _pingSoon();
  }

  /// Una petición falló por la red: se revisa el estado ahora (con un
  /// mínimo de [minPingGap] entre revisiones).
  void reportNetworkError() {
    if (_disposed || !_started || !_foreground) return;
    _pingSoon();
  }

  void _pingSoon() {
    final last = _lastPing;
    if (last != null && _clock().difference(last) < minPingGap) return;
    unawaited(_healthCheck());
  }

  void _startTimer() {
    _timer?.cancel();
    if (!_foreground) return;
    _timer = Timer.periodic(pingInterval, (_) {
      if (_hasInternet) _healthCheck();
    });
  }

  Future<void> checkNow() async {
    if (_disposed || _isChecking) return;
    _isChecking = true;
    notifyListeners();
    try {
      final results = await _connectivity.checkConnectivity();
      if (_disposed) return;
      _hasInternet =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      await _healthCheck();
    } finally {
      _isChecking = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    if (_disposed) return;
    final hasNet =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    _hasInternet = hasNet;
    if (!_networkReadyCompleter.isCompleted) {
      _networkReadyCompleter.complete();
    }
    await _healthCheck();
  }

  Future<void> _healthCheck() async {
    if (_disposed) return;
    final revision = ++_healthRevision;
    if (!_hasInternet) {
      _apiStatus = ServerStatus.offline;
      notifyListeners();
      return;
    }
    _lastPing = _clock();
    _pings++;
    final status = await _pingServer(
      Uri.parse('${BackendConfig.baseUrl}/status'),
    );
    // Una respuesta de la red anterior no debe reactivar la conexión después
    // de perderla, ni notificar a un servicio que ya fue destruido.
    if (_disposed || revision != _healthRevision) return;
    _apiStatus = status;
    if (status != ServerStatus.offline) _hasInternet = true;
    notifyListeners();
  }

  Future<ServerStatus> _pingServer(Uri uri) async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _httpClient
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));
      stopwatch.stop();
      if (response.statusCode >= 500) return ServerStatus.offline;
      if (stopwatch.elapsedMilliseconds > 3000) return ServerStatus.degraded;
      return ServerStatus.online;
    } catch (_) {
      return ServerStatus.offline;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _healthRevision++;
    _subscription?.cancel();
    _timer?.cancel();
    _lifecycle?.dispose();
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }
}
