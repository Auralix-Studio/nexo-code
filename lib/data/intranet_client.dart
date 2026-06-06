import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nexo/core/errors.dart';

/// Cliente del sistema antiguo Intranet UPLA (PHP, sesión por cookie).
///
/// A diferencia de SIGMA (JWT), Intranet usa `PHPSESSID`. Gestionamos la
/// cookie manualmente y emulamos el flujo de un navegador (GET / → login →
/// navegar) para esquivar su anti-bot.
class IntranetClient {
  IntranetClient({http.Client? transport})
      : _http = transport ?? http.Client();

  static const _base = 'https://intranet.upla.edu.pe';
  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Safari/537.36';
  static const _timeout = Duration(seconds: 30);

  final http.Client _http;
  final Map<String, String> _cookies = {};
  bool _loggedIn = false;

  bool get isLoggedIn => _loggedIn;

  void _storeCookies(http.BaseResponse res) {
    final raw = res.headers['set-cookie'];
    if (raw == null) return;
    // Puede venir varias cookies separadas por coma; tomamos pares k=v.
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

  Future<http.Response> _send(http.BaseRequest req) async {
    try {
      final streamed = await _http.send(req).timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      _storeCookies(res);
      return res;
    } on TimeoutException {
      throw const TimeoutException('Intranet no respondió a tiempo.');
    } catch (e) {
      throw NetworkException('Error de red (Intranet): $e');
    }
  }

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

  /// Inicia sesión con las credenciales (mismas que SIGMA).
  /// Devuelve true si la cookie quedó autenticada.
  Future<bool> login(String usuario, String contrasena) async {
    _cookies.clear();
    _loggedIn = false;

    // 1) GET / → PHPSESSID (sigue el 302 a `sesion`).
    await _get('');

    // 2) POST /login
    final res = await _post(
      'login',
      {
        'usuario': usuario,
        'contrasena': contrasena,
        'datosUsuario': 'dni,nomape',
        'captcha_modelo': '',
        'captcha_respuesta': '',
      },
      referer: '',
    );

    final loc = res.headers['location'] ?? '';
    _loggedIn = res.statusCode == 302 && loc.contains('inicio');
    if (_loggedIn) {
      // 3) "Aterrizar" en inicio para consolidar la sesión.
      await _get('inicio?filtro=noticias', referer: 'login');
    }
    return _loggedIn;
  }

  /// Decodifica el cuerpo (a veces con espacios/newline iniciales) a JSON.
  dynamic _decode(String body) {
    final t = body.trim();
    if (t.isEmpty) return null;
    if (t.startsWith('<')) {
      // Página anti-bot / sesión perdida.
      throw const SessionExpiredException('Sesión de Intranet expirada.');
    }
    try {
      return jsonDecode(t);
    } catch (_) {
      throw const ServerException('Respuesta no JSON de Intranet',
          status: 200);
    }
  }

  /// GET que devuelve JSON (array de arrays posicionales).
  Future<List<dynamic>> getJsonList(String path, {String? referer}) async {
    final res = await _get(path, referer: referer);
    final data = _decode(res.body);
    return data is List ? data : const [];
  }

  /// POST que devuelve JSON.
  Future<List<dynamic>> postJsonList(
    String path,
    Map<String, String> body, {
    String? referer,
  }) async {
    final res = await _post(path, body, referer: referer);
    final data = _decode(res.body);
    return data is List ? data : const [];
  }

  void close() => _http.close();
}
