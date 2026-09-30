import 'dart:async';
import 'package:nexo/core/session_scope.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:nexo/core/errors.dart';

class IntranetClient {
  IntranetClient({http.Client? transport, SessionScope? scope})
    : _http = transport ?? http.Client(),
      scope = scope ?? SessionScope();
  final SessionScope scope;
  int _cookieGeneration = 0;
  static const _base = 'https://intranet.upla.edu.pe';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Safari/537.36';
  static const _timeout = Duration(seconds: 30);
  final http.Client _http;
  final Map<String, String> _cookies = {};
  bool _loggedIn = false;
  Future<bool>? _reauthInFlight;
  bool get isLoggedIn => _loggedIn;
  Future<bool> Function()? reauthenticate;
  String? exportCookies() {
    if (_cookies.isEmpty) return null;
    return _cookies.entries.map((e) => '${e.key}=${e.value}').join(';');
  }

  void importCookies(String raw) {
    _cookies.clear();
    for (final part in raw.split(';')) {
      final i = part.indexOf('=');
      if (i > 0) {
        _cookies[part.substring(0, i).trim()] = part.substring(i + 1).trim();
      }
    }
    _loggedIn = _cookies.containsKey('PHPSESSID');
  }

  void invalidateSession() {
    _cookieGeneration++;
    _loggedIn = false;
    _cookies.clear();
  }

  void reset() {
    invalidateSession();
    reauthenticate = null;
    _reauthInFlight = null;
  }

  void _storeCookies(http.BaseResponse res) {
    final raw = res.headers['set-cookie'];
    if (raw == null) return;
    for (final part in raw.split(RegExp(r',(?=[^;]+=)'))) {
      final seg = part.split(';').first.trim();
      final i = seg.indexOf('=');
      if (i > 0) _cookies[seg.substring(0, i)] = seg.substring(i + 1);
    }
  }

  String get _cookieHeader =>
      _cookies.entries.map((e) => '${e.key}=${e.value}').join('; ');
  Map<String, String> _headers({String? referer, bool form = false}) => {
    'User-Agent': _ua,
    'Accept': form ? '*/*' : 'text/html,application/xhtml+xml,*/*;q=0.8',
    'Accept-Language': 'es-PE,es;q=0.9',
    'X-Requested-With': 'XMLHttpRequest',
    if (_cookieHeader.isNotEmpty) 'Cookie': _cookieHeader,
    if (referer != null) 'Referer': '$_base/$referer',
    if (form) 'Content-Type': 'application/x-www-form-urlencoded',
  };
  Future<http.Response> _send(http.BaseRequest req) => scope.run(() async {
    final generation = _cookieGeneration;
    try {
      final streamed = await _http.send(req).timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      scope.check();
      if (generation != _cookieGeneration) throw const StaleSessionException();
      _storeCookies(res);
      return res;
    } on StaleSessionException {
      rethrow;
    } on TimeoutException {
      throw const TimeoutException('Intranet no respondió a tiempo.');
    } catch (e) {
      throw NetworkException('Error de red (Intranet): $e');
    }
  });

  Future<http.Response> _get(String path, {String? referer}) {
    final req = http.Request('GET', Uri.parse('$_base/$path'))
      ..followRedirects = false
      ..headers.addAll(_headers(referer: referer));
    return _send(req);
  }

  Future<http.Response> _post(
    String path,
    Map<String, String> body, {
    String? referer,
  }) {
    final req = http.Request('POST', Uri.parse('$_base/$path'))
      ..followRedirects = false
      ..headers.addAll(_headers(referer: referer, form: true))
      ..bodyFields = body;
    return _send(req);
  }

  Future<bool> login(String username, String password) => scope.run(() async {
    _cookies.clear();
    _loggedIn = false;
    final generation = _cookieGeneration;
    await _get('');
    scope.check();
    if (generation != _cookieGeneration) throw const StaleSessionException();
    final res = await _post('login', {
      'usuario': username,
      'contrasena': password,
      'datosUsuario': 'dni,nomape',
      'captcha_modelo': '',
      'captcha_respuesta': '',
    }, referer: '');
    scope.check();
    if (generation != _cookieGeneration) throw const StaleSessionException();
    final loc = res.headers['location'] ?? '';
    _loggedIn = res.statusCode == 302 && loc.contains('inicio');
    if (_loggedIn) {
      await _get('inicio?filtro=noticias', referer: 'login');
    }
    return _loggedIn;
  });

  void _checkSession(http.Response res) {
    if (res.statusCode == 302 &&
        (res.headers['location'] ?? '').contains('sesion')) {
      invalidateSession();
      throw const SessionExpiredException('Sesión de Intranet expirada.');
    }
  }

  dynamic _decode(String body) {
    final t = body.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('<')) {
      invalidateSession();
      throw const SessionExpiredException('Sesión de Intranet expirada.');
    }
    try {
      return jsonDecode(t);
    } catch (_) {
      throw const ServerException('Respuesta no JSON de Intranet', status: 200);
    }
  }

  Future<bool> _reauthOnce() {
    scope.check();
    final existing = _reauthInFlight;
    if (existing != null) return existing;
    late final Future<bool> request;
    request = scope
        .run(() async {
          final cb = reauthenticate;
          if (cb == null) return false;
          return await cb();
        })
        .whenComplete(() {
          if (identical(_reauthInFlight, request)) _reauthInFlight = null;
        });
    return _reauthInFlight = request;
  }

  Future<List<dynamic>> getJsonList(String path, {String? referer}) =>
      _jsonListGet(path, referer: referer, isRetry: false);
  Future<List<dynamic>> _jsonListGet(
    String path, {
    String? referer,
    required bool isRetry,
  }) => scope.run(() async {
    final res = await _get(path, referer: referer);
    try {
      _checkSession(res);
      final data = _decode(res.body);
      return data is List ? data : const [];
    } on SessionExpiredException {
      if (isRetry || reauthenticate == null) rethrow;
      final ok = await _reauthOnce();
      scope.check();
      if (!ok) rethrow;
      return _jsonListGet(path, referer: referer, isRetry: true);
    }
  });

  Future<List<dynamic>> postJsonList(
    String path,
    Map<String, String> body, {
    String? referer,
  }) => _jsonListPost(path, body, referer: referer, isRetry: false);
  Future<List<dynamic>> _jsonListPost(
    String path,
    Map<String, String> body, {
    String? referer,
    required bool isRetry,
  }) => scope.run(() async {
    final res = await _post(path, body, referer: referer);
    try {
      _checkSession(res);
      final data = _decode(res.body);
      return data is List ? data : const [];
    } on SessionExpiredException {
      if (isRetry || reauthenticate == null) rethrow;
      final ok = await _reauthOnce();
      if (!ok) rethrow;
      return _jsonListPost(path, body, referer: referer, isRetry: true);
    }
  });

  void close() => _http.close();
}
