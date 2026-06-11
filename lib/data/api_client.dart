import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nexo/core/config.dart';
import 'package:nexo/core/errors.dart';

/// Sobre estándar de las respuestas SIGMA: `{ success, mensaje, codigo, data }`.
class ApiEnvelope<T> {
  final bool success;
  final String? mensaje;
  final int? codigo;
  final T? data;

  const ApiEnvelope({
    required this.success,
    this.mensaje,
    this.codigo,
    this.data,
  });

  factory ApiEnvelope.fromJson(
    Map<String, dynamic> json,
    T Function(Object? raw) decode,
  ) {
    // SIGMA mezcla tipos: `success` puede venir como bool, int (0/1) o
    // string ("true"/"false"/"1"). Antes `as bool?` lanzaba TypeError y
    // hacía caer la petición entera, mostrando error rojo aunque el
    // servidor respondiera 200 con datos.
    return ApiEnvelope(
      success: _envBool(json['success']),
      mensaje: json['mensaje']?.toString(),
      codigo: _envInt(json['codigo']),
      data: json.containsKey('data') ? decode(json['data']) : null,
    );
  }
}

bool _envBool(Object? v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    return t == 'true' || t == '1' || t == 's' || t == 'si';
  }
  return false;
}

int? _envInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

/// Cliente HTTP con manejo manual de token, headers y errores.
/// Reutiliza `package:http` solo como transporte multiplataforma.
class ApiClient {
  ApiClient({http.Client? transport}) : _http = transport ?? http.Client();

  final http.Client _http;
  String? _token;

  /// Llamado cuando una petición autorizada recibe 401 y no se pudo
  /// re-autenticar. Útil para forzar logout.
  void Function()? onUnauthorized;

  /// Intenta re-autenticar (re-login con credenciales guardadas).
  /// Debe devolver `true` si renovó el token correctamente.
  Future<bool> Function()? reauthenticate;

  String? get token => _token;
  void setToken(String? value) => _token = value;

  Future<ApiEnvelope<T>> get<T>(
    String path, {
    Map<String, String>? query,
    bool authorize = true,
    required T Function(Object? raw) decode,
  }) =>
      _send<T>('GET', path,
          query: query, authorize: authorize, decode: decode);

  Future<ApiEnvelope<T>> post<T>(
    String path, {
    Object? body,
    bool authorize = true,
    required T Function(Object? raw) decode,
  }) =>
      _send<T>('POST', path,
          body: body, authorize: authorize, decode: decode);

  Future<ApiEnvelope<T>> _send<T>(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    bool authorize = true,
    required T Function(Object? raw) decode,
    bool isRetry = false,
  }) async {
    final uri = _buildUri(path, query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
      'User-Agent': AppConfig.userAgent,
    };
    if (authorize && _token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) {
        req.body = jsonEncode(body);
      }
      final streamed = await _http
          .send(req)
          .timeout(AppConfig.httpTimeout);
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const TimeoutException('El servidor no respondió a tiempo.');
    } catch (e) {
      throw NetworkException('Error de red: $e');
    }

    Map<String, dynamic>? payload;
    final bodyText = utf8.decode(res.bodyBytes, allowMalformed: true);

    // Si SIGMA devuelve HTML con 200 OK puede ser una de dos cosas:
    //   (a) el token expiró y el SPA está sirviendo su shell (caso común
    //       cuando el middleware de auth no devuelve 401 sino que redirige
    //       al login del front);
    //   (b) la ruta del API ya no existe y el SPA está sirviendo su
    //       catch-all genuino.
    // No podemos distinguirlos por el cuerpo. Resolución: si es endpoint
    // autorizado y aún no reintentamos, intentamos reauth+retry. Si tras
    // el retry seguimos viendo HTML, es realmente endpoint movido (caso b)
    // y lanzamos `ServerException`.
    final trimmedHead = bodyText.trimLeft();
    final isHtml = res.statusCode < 400 &&
        (trimmedHead.startsWith('<!doctype') ||
            trimmedHead.startsWith('<!DOCTYPE') ||
            trimmedHead.startsWith('<html'));
    if (isHtml) {
      if (authorize && !isRetry && reauthenticate != null) {
        final ok = await reauthenticate!();
        if (ok) {
          return _send<T>(
            method,
            path,
            query: query,
            body: body,
            authorize: authorize,
            decode: decode,
            isRetry: true,
          );
        }
      }
      throw ServerException(
        'Endpoint movido o no disponible (SIGMA respondió con HTML del SPA): $path',
        status: res.statusCode,
      );
    }

    try {
      final parsed = jsonDecode(bodyText);
      if (parsed is Map<String, dynamic>) payload = parsed;
    } catch (_) {
      // respuesta no JSON
    }

    if (res.statusCode == 401) {
      // Intento transparente de re-autenticación + reintento (una vez).
      if (authorize && !isRetry && reauthenticate != null) {
        final ok = await reauthenticate!();
        if (ok) {
          return _send<T>(
            method,
            path,
            query: query,
            body: body,
            authorize: authorize,
            decode: decode,
            isRetry: true,
          );
        }
      }
      onUnauthorized?.call();
      throw SessionExpiredException(
          payload?['mensaje'] as String? ?? 'Sesión expirada.');
    }
    if (res.statusCode == 403) {
      throw UnauthorizedException(
          payload?['mensaje'] as String? ?? 'Acceso denegado.');
    }
    if (res.statusCode >= 500) {
      throw ServerException(
        payload?['mensaje'] as String? ?? 'Error del servidor',
        status: res.statusCode,
      );
    }
    if (res.statusCode >= 400) {
      throw BadRequestException(
        payload?['mensaje'] as String? ?? 'Petición rechazada',
        status: res.statusCode,
        payload: payload,
      );
    }

    if (payload == null) {
      return ApiEnvelope<T>(success: true, data: decode(null));
    }
    return ApiEnvelope<T>.fromJson(payload, decode);
  }

  Uri _buildUri(String path, Map<String, String>? query) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    final base = Uri.parse('${AppConfig.apiBaseUrl}/$cleanPath');
    if (query == null || query.isEmpty) return base;
    return base.replace(
      queryParameters: {...base.queryParameters, ...query},
    );
  }

  void close() => _http.close();
}
