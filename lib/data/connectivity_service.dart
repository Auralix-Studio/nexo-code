import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nexo/core/config.dart';

enum ServerStatus { online, offline, degraded }

class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity, http.Client? httpClient})
    : _connectivity = connectivity ?? Connectivity(),
      _httpClient = httpClient ?? http.Client(),
      _ownsHttpClient = httpClient == null;
  final Connectivity _connectivity;
  final http.Client _httpClient;
  final bool _ownsHttpClient;
  bool _disposed = false;
  int _healthRevision = 0;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _hasInternet = false;
  ServerStatus _sigmaStatus = ServerStatus.offline;
  ServerStatus _intranetStatus = ServerStatus.offline;
  ServerStatus _idiomasAuthStatus = ServerStatus.offline;
  ServerStatus _idiomasApiStatus = ServerStatus.offline;

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
  ServerStatus get sigmaStatus => _sigmaStatus;
  ServerStatus get intranetStatus => _intranetStatus;
  ServerStatus get idiomasAuthStatus => _idiomasAuthStatus;
  ServerStatus get idiomasApiStatus => _idiomasApiStatus;
  bool get isFullyOnline =>
      _hasInternet &&
      _sigmaStatus == ServerStatus.online &&
      _intranetStatus == ServerStatus.online;
  bool get isSigmaOnline => _hasInternet && _sigmaStatus == ServerStatus.online;
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
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasInternet) {
        _healthCheck();
      }
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
      _sigmaStatus = ServerStatus.offline;
      _intranetStatus = ServerStatus.offline;
      _idiomasAuthStatus = ServerStatus.offline;
      _idiomasApiStatus = ServerStatus.offline;
      notifyListeners();
      return;
    }
    final sigmaFuture = _pingServer(Uri.parse(AppConfig.apiBaseUrl));
    final intranetFuture = _pingServer(
      Uri.parse('https://intranet.upla.edu.pe'),
    );
    final idiomasAuthFuture = _pingServer(
      Uri.parse('https://services.upla.edu.pe'),
    );
    final idiomasApiFuture = _pingServer(
      Uri.parse('https://apidiomas.upla.edu.pe'),
    );
    final results = await Future.wait([
      sigmaFuture,
      intranetFuture,
      idiomasAuthFuture,
      idiomasApiFuture,
    ]);
    // Una respuesta de la red anterior no debe reactivar la conexión después
    // de perderla, ni notificar a un servicio que ya fue destruido.
    if (_disposed || revision != _healthRevision) return;
    _sigmaStatus = results[0];
    _intranetStatus = results[1];
    _idiomasAuthStatus = results[2];
    _idiomasApiStatus = results[3];

    if (results.any((s) => s != ServerStatus.offline)) {
      _hasInternet = true;
    }
    notifyListeners();
  }

  Future<ServerStatus> _pingServer(Uri uri) async {
    final stopwatch = Stopwatch()..start();
    const browserUa =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/130.0 Safari/537.36';
    try {
      final response = await _httpClient
          .get(uri, headers: const {'User-Agent': browserUa})
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
    if (_ownsHttpClient) _httpClient.close();
    super.dispose();
  }
}
