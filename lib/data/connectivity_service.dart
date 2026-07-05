import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:nexo/core/config.dart';

enum ServerStatus { online, offline, degraded }

class ConnectivityService extends ChangeNotifier {
  ConnectivityService({Connectivity? connectivity, http.Client? httpClient})
    : _connectivity = connectivity ?? Connectivity(),
      _httpClient = httpClient ?? http.Client();
  final Connectivity _connectivity;
  final http.Client _httpClient;
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  bool _hasInternet = false;
  ServerStatus _sigmaStatus = ServerStatus.offline;
  ServerStatus _intranetStatus = ServerStatus.offline;
  bool get hasInternet => _hasInternet;
  ServerStatus get sigmaStatus => _sigmaStatus;
  ServerStatus get intranetStatus => _intranetStatus;
  bool get isFullyOnline =>
      _hasInternet &&
      _sigmaStatus == ServerStatus.online &&
      _intranetStatus == ServerStatus.online;
  bool get isSigmaOnline => _hasInternet && _sigmaStatus == ServerStatus.online;
  bool _isChecking = false;
  bool get isChecking => _isChecking;
  Future<void> start() async {
    await _subscription?.cancel();
    _timer?.cancel();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });
    final initialResults = await _connectivity.checkConnectivity();
    await _handleConnectivityChange(initialResults);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_hasInternet) {
        _healthCheck();
      }
    });
  }

  Future<void> checkNow() async {
    if (_isChecking) return;
    _isChecking = true;
    notifyListeners();
    try {
      final results = await _connectivity.checkConnectivity();
      final hasNet =
          results.isNotEmpty && !results.contains(ConnectivityResult.none);
      _hasInternet = hasNet;
      if (_hasInternet) {
        await _healthCheck();
      } else {
        _sigmaStatus = ServerStatus.offline;
        _intranetStatus = ServerStatus.offline;
      }
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _handleConnectivityChange(
    List<ConnectivityResult> results,
  ) async {
    final hasNet =
        results.isNotEmpty && !results.contains(ConnectivityResult.none);
    if (_hasInternet != hasNet) {
      _hasInternet = hasNet;
      if (_hasInternet) {
        await _healthCheck();
      } else {
        _sigmaStatus = ServerStatus.offline;
        _intranetStatus = ServerStatus.offline;
        notifyListeners();
      }
    }
  }

  Future<void> _healthCheck() async {
    final sigmaFuture = _pingServer(Uri.parse(AppConfig.apiBaseUrl));
    final intranetFuture = _pingServer(
      Uri.parse('https://intranet.upla.edu.pe'),
    );
    final results = await Future.wait([sigmaFuture, intranetFuture]);
    _sigmaStatus = results[0];
    _intranetStatus = results[1];
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
    _subscription?.cancel();
    _timer?.cancel();
    _httpClient.close();
    super.dispose();
  }
}
