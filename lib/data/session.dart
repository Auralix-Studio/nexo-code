import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/models.dart';

/// Estados posibles de la sesión.
enum SessionStatus { unknown, authenticated, unauthenticated }

/// Servicio central de autenticación + sesión persistida con
/// re-login automático mediante credenciales guardadas.
class SessionService extends ChangeNotifier {
  SessionService({required ApiClient apiClient, required SigmaRepository repo})
      : _api = apiClient,
        _repo = repo {
    _api.onUnauthorized = _onAuthFailed;
    _api.reauthenticate = _reauthenticate;
  }

  final ApiClient _api;
  final SigmaRepository _repo;

  SessionStatus _status = SessionStatus.unknown;
  UserInfo? _user;
  Future<bool>? _inFlightReauth;

  SessionStatus get status => _status;
  UserInfo? get user => _user;
  bool get isAuthenticated => _status == SessionStatus.authenticated;

  /// Arranque: usa el token guardado; si no hay, intenta re-login
  /// automático con las credenciales persistidas.
  Future<void> bootstrap() async {
    final storage = AppStorage.instance;
    final tok = storage.token;
    if (tok != null && tok.isNotEmpty) {
      _api.setToken(tok);
      final raw = storage.userJson;
      if (raw != null) {
        try {
          _user = UserInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        } catch (_) {}
      }
      _setStatus(SessionStatus.authenticated);
      return;
    }
    // Sin token: probar auto-login.
    if (storage.hasCredentials) {
      final ok = await _reauthenticate();
      if (ok) {
        _setStatus(SessionStatus.authenticated);
        return;
      }
    }
    _setStatus(SessionStatus.unauthenticated);
  }

  /// Login manual: autentica y **persiste credenciales** para auto-login.
  Future<void> login(String usuarioId, String password) async {
    final result = await _repo.login(usuarioId, password);
    await _persistSession(result);
    await AppStorage.instance.setCredentials(usuarioId, password);
    _setStatus(SessionStatus.authenticated);
  }

  Future<void> _persistSession(LoginResult result) async {
    await AppStorage.instance.setToken(result.token);
    if (result.info != null) {
      await AppStorage.instance.setUserJson(jsonEncode(result.info!.toJson()));
      _user = result.info;
    }
  }

  /// Re-autenticación transparente (deduplicada si hay varias en vuelo).
  Future<bool> _reauthenticate() {
    return _inFlightReauth ??= _doReauth()
      ..whenComplete(() => _inFlightReauth = null);
  }

  Future<bool> _doReauth() async {
    final s = AppStorage.instance;
    final u = s.credUser;
    final p = s.credPass;
    if (u == null || p == null || u.isEmpty || p.isEmpty) return false;
    try {
      final result = await _repo.login(u, p);
      await _persistSession(result);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Cierre de sesión explícito por el usuario: olvida credenciales.
  Future<void> logout() async {
    await AppStorage.instance.clear(keepCredentials: false);
    _api.setToken(null);
    _user = null;
    _setStatus(SessionStatus.unauthenticated);
  }

  /// Fallo de auth irrecuperable (re-login también falló).
  void _onAuthFailed() {
    scheduleMicrotask(() async {
      await AppStorage.instance.clear(keepCredentials: false);
      _api.setToken(null);
      _user = null;
      _setStatus(SessionStatus.unauthenticated);
    });
  }

  void _setStatus(SessionStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }
}
