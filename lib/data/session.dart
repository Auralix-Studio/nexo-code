import 'dart:async';
import 'package:nexo/core/session_scope.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/models.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionService extends ChangeNotifier {
  SessionService({required ApiClient apiClient, required SigmaRepository repo})
    : _api = apiClient,
      _repo = repo {
    _api.onUnauthorized = _onAuthFailed;
    _api.reauthenticate = _reauthenticate;
  }
  final ApiClient _api;
  final SigmaRepository _repo;
  SessionScope get scope => _api.scope;
  Future<void> Function()? onSessionEnded;
  Future<void> Function(String account)? onAccountReady;
  Future<void> _cleanup = Future.value();
  SessionStatus _status = SessionStatus.unknown;
  UserProfile? _user;
  Future<ReauthOutcome>? _inFlightReauth;
  SessionStatus get status => _status;
  UserProfile? get user => _user;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  Future<void> bootstrap() => scope.run(() async {
    final storage = AppStorage.instance;
    _loadUserFromStorage(storage);
    final account = storage.credUser ?? _user?.code;
    if (account != null && account.isNotEmpty) {
      await onAccountReady?.call(account);
      scope.check();
    }
    final tok = account == null || account.isEmpty ? null : storage.token;
    final hasToken = tok != null && tok.isNotEmpty;
    if (hasToken) {
      _api.setToken(tok);
      _loadUserFromStorage(storage);
      // Token presente y todavía vigente → sesión válida sin tocar la red.
      if (!_isJwtExpired(tok)) {
        _setStatus(SessionStatus.authenticated);
        return;
      }
    }
    // Token ausente o vencido: intentar reautenticar si hay credenciales.
    if (storage.hasCredentials) {
      final outcome = await _reauthenticate();
      scope.check();
      if (outcome == ReauthOutcome.refreshed) {
        _setStatus(SessionStatus.authenticated);
        return;
      }
      // Fallo TRANSITORIO al arrancar (p.ej. sin red / SIGMA frío): entramos de
      // forma optimista y mostramos el caché en vez de expulsar a login. Un 401
      // posterior o un refresh manual reintentarán. Solo credenciales
      // confirmadas inválidas caen a la pantalla de login.
      if (outcome == ReauthOutcome.unavailable) {
        _setStatus(SessionStatus.authenticated);
        return;
      }
    }
    await logout();
  });

  void _loadUserFromStorage(AppStorage storage) {
    final raw = storage.userJson;
    if (raw == null) return;
    try {
      _user = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Lee el `exp` del JWT (sin validar firma — solo para decidir si conviene
  /// reautenticar proactivamente al arrancar). Ante cualquier duda devuelve
  /// `false` (no vencido) para no forzar reautenticaciones innecesarias.
  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final exp = payload['exp'];
      if (exp is! int) return false;
      final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      // Margen de 30 s: no usamos un token a punto de morir.
      return DateTime.now().isAfter(
        expiry.subtract(const Duration(seconds: 30)),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> login(String usuarioId, String password) {
    _reset();
    return scope.runFresh(() async {
      await _cleanup;
      scope.check();
      final result = await _repo.login(usuarioId, password);
      scope.check();
      await onAccountReady?.call(usuarioId);
      scope.check();
      await _persistSession(result, usuarioId, password);
      scope.check();
      _setStatus(SessionStatus.authenticated);
    });
  }

  Future<void> _persistSession(
    LoginResult result,
    String user,
    String pass,
  ) async {
    scope.check();
    await AppStorage.instance.setAuthenticatedSession(
      token: result.token,
      account: user,
      password: pass,
      userJson: result.info == null ? null : jsonEncode(result.info!.toJson()),
    );
    scope.check();
    _api.setToken(result.token);
    _user = result.info;
  }

  Future<ReauthOutcome> _reauthenticate() {
    scope.check();
    final existing = _inFlightReauth;
    if (existing != null) return existing;
    late final Future<ReauthOutcome> request;
    request = scope.run(_doReauth).whenComplete(() {
      if (identical(_inFlightReauth, request)) _inFlightReauth = null;
    });
    return _inFlightReauth = request;
  }

  Future<ReauthOutcome> _doReauth() async {
    final s = AppStorage.instance;
    final u = s.credUser;
    final p = s.credPass;
    if (u == null || p == null || u.isEmpty || p.isEmpty) {
      return ReauthOutcome.invalidCredentials;
    }
    try {
      final result = await _repo.login(u, p);
      scope.check();
      await _persistSession(result, u, p);
      return ReauthOutcome.refreshed;
    } on StaleSessionException {
      rethrow;
    } on InvalidCredentialsException {
      return ReauthOutcome.invalidCredentials;
    } catch (_) {
      return ReauthOutcome.unavailable;
    }
  }

  void _reset() {
    scope.invalidate();
    _inFlightReauth = null;
    _api.setToken(null);
    _user = null;
    _setStatus(SessionStatus.unauthenticated);
    final previous = _cleanup.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    _cleanup = scope.runFresh(
      () => Future.wait<void>([
        previous,
        AppStorage.instance.clear(keepCredentials: false),
        if (onSessionEnded != null) onSessionEnded!(),
      ]).then((_) {}),
    );
    // Report failures to logout/login callers without an unhandled microtask.
    unawaited(
      _cleanup.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
  }

  Future<void> logout() {
    _reset();
    return _cleanup;
  }

  /// Cierra el arranque cuando `bootstrap` no pudo decidir —falló o tardó
  /// demasiado—. Sin esto la app se quedaría en el splash para siempre; la
  /// pantalla de login siempre es recuperable, así que es el destino seguro.
  void resolveUnknownAsUnauthenticated() {
    if (_status == SessionStatus.unknown) {
      // The timed-out bootstrap future is still running: revoke its writes.
      scope.invalidate();
      _api.setToken(null);
      _user = null;
      _setStatus(SessionStatus.unauthenticated);
    }
  }

  void _onAuthFailed() {
    // ApiClient calls this in the originating scope; stale 401s cannot logout B.
    if (!scope.isCurrent) return;
    _reset();
  }

  void _setStatus(SessionStatus s) {
    if (_status == s) return;
    _status = s;
    notifyListeners();
  }
}
