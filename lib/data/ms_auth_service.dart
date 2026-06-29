import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/graph_client.dart';

enum MsAuthStatus { unknown, signedOut, connecting, authenticated }

class MsAuthService extends ChangeNotifier {
  MsAuthService(this._client) {
    _client.reauthenticate = _refresh;
    _client.onUnauthorized = _onAuthFailed;
  }
  final GraphClient _client;
  MsAuthStatus _status = MsAuthStatus.unknown;
  MsTokens? _tokens;
  DeviceCodeInfo? _deviceCode;
  String? _error;
  bool _cancelRequested = false;
  Future<bool>? _inFlightRefresh;
  MsAuthStatus get status => _status;
  bool get isAuthenticated => _status == MsAuthStatus.authenticated;
  bool get isConnecting => _status == MsAuthStatus.connecting;
  DeviceCodeInfo? get deviceCode => _deviceCode;
  String? get error => _error;
  bool get isConfigured => MsConfig.isConfigured;
  Future<void> bootstrap() async {
    final raw = AppStorage.instance.msSessionJson;
    if (raw == null) {
      _setStatus(MsAuthStatus.signedOut);
      return;
    }
    try {
      _tokens = MsTokens.fromStored(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      _tokens = null;
    }
    final t = _tokens;
    if (t == null) {
      _setStatus(MsAuthStatus.signedOut);
      return;
    }
    if (!t.isExpired) {
      _client.setToken(t.accessToken);
      _setStatus(MsAuthStatus.authenticated);
      return;
    }
    if (await _refresh()) {
      _setStatus(MsAuthStatus.authenticated);
    } else {
      _setStatus(MsAuthStatus.signedOut);
    }
  }

  Future<void> startSignIn() async {
    if (!MsConfig.isConfigured) {
      _error =
          'Falta configurar el client_id de Azure AD (ver MsConfig en config.dart).';
      _setStatus(MsAuthStatus.signedOut);
      return;
    }
    _error = null;
    _cancelRequested = false;
    _setStatus(MsAuthStatus.connecting);
    try {
      final info = await _client.requestDeviceCode();
      _deviceCode = info;
      notifyListeners();
      await _pollLoop(info);
    } on ApiException catch (e) {
      _failConnect(e.message);
    } catch (e) {
      _failConnect(e.toString());
    }
  }

  Future<void> _pollLoop(DeviceCodeInfo info) async {
    final deadline = DateTime.now().add(info.expiresIn);
    var interval = info.interval;
    while (!_cancelRequested && DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      if (_cancelRequested) break;
      final result = await _client.pollDeviceToken(info.deviceCode);
      switch (result.state) {
        case DevicePollState.success:
          await _persist(result.tokens!);
          _deviceCode = null;
          _setStatus(MsAuthStatus.authenticated);
          return;
        case DevicePollState.slowDown:
          interval += const Duration(seconds: 5);
        case DevicePollState.pending:
          break;
      }
    }
    if (!_cancelRequested) {
      _failConnect('El código expiró. Vuelve a intentarlo.');
    }
  }

  void cancelSignIn() {
    _cancelRequested = true;
    _deviceCode = null;
    _setStatus(
      _tokens != null && !_tokens!.isExpired
          ? MsAuthStatus.authenticated
          : MsAuthStatus.signedOut,
    );
  }

  Future<void> _persist(MsTokens tokens) async {
    _tokens = tokens;
    _client.setToken(tokens.accessToken);
    await AppStorage.instance.setMsSessionJson(jsonEncode(tokens.toJson()));
  }

  Future<bool> _refresh() {
    return _inFlightRefresh ??= _doRefresh()
      ..whenComplete(() => _inFlightRefresh = null);
  }

  Future<bool> _doRefresh() async {
    final rt = _tokens?.refreshToken;
    if (rt == null || rt.isEmpty) return false;
    try {
      final fresh = await _client.refreshTokens(rt);
      await _persist(
        MsTokens(
          accessToken: fresh.accessToken,
          refreshToken: fresh.refreshToken ?? rt,
          expiresAt: fresh.expiresAt,
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onAuthFailed() {
    scheduleMicrotask(signOut);
  }

  Future<void> signOut() async {
    _cancelRequested = true;
    _tokens = null;
    _deviceCode = null;
    _client.setToken(null);
    await AppStorage.instance.setMsSessionJson(null);
    _setStatus(MsAuthStatus.signedOut);
  }

  void _failConnect(String message) {
    _error = message;
    _deviceCode = null;
    _setStatus(MsAuthStatus.signedOut);
  }

  void _setStatus(MsAuthStatus s) {
    _status = s;
    notifyListeners();
  }
}
