import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:nexo/core/config.dart';
import 'package:nexo/core/errors.dart';

/// Respuesta de `POST /devicecode`: el alumno debe abrir [verificationUri]
/// e introducir [userCode] para autorizar la app.
class DeviceCodeInfo {
  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String message;
  final Duration expiresIn;
  final Duration interval;

  const DeviceCodeInfo({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.message,
    required this.expiresIn,
    required this.interval,
  });

  factory DeviceCodeInfo.fromJson(Map<String, dynamic> j) => DeviceCodeInfo(
        deviceCode: j['device_code'] as String? ?? '',
        userCode: j['user_code'] as String? ?? '',
        verificationUri: j['verification_uri'] as String? ?? '',
        message: j['message'] as String? ?? '',
        expiresIn: Duration(seconds: (j['expires_in'] as num?)?.toInt() ?? 900),
        interval: Duration(seconds: (j['interval'] as num?)?.toInt() ?? 5),
      );
}

/// Tokens devueltos por el endpoint de token de Azure AD.
class MsTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  const MsTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  factory MsTokens.fromJson(Map<String, dynamic> j) {
    final ttl = (j['expires_in'] as num?)?.toInt() ?? 3600;
    return MsTokens(
      accessToken: j['access_token'] as String? ?? '',
      refreshToken: j['refresh_token'] as String?,
      // Margen de 60 s para evitar usar un token a punto de caducar.
      expiresAt: DateTime.now().add(Duration(seconds: ttl - 60)),
    );
  }

  Map<String, dynamic> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory MsTokens.fromStored(Map<String, dynamic> j) => MsTokens(
        accessToken: j['access_token'] as String? ?? '',
        refreshToken: j['refresh_token'] as String?,
        expiresAt: DateTime.tryParse(j['expires_at'] as String? ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
      );

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// Estado intermedio del sondeo de Device Code Flow.
enum DevicePollState { pending, slowDown, success }

class DevicePollResult {
  final DevicePollState state;
  final MsTokens? tokens;
  const DevicePollResult(this.state, [this.tokens]);
}

/// Cliente HTTP propio para Microsoft (Azure AD + Graph). Sin SDK: usa
/// `package:http` solo como transporte, igual que [ApiClient]/[IntranetClient].
class GraphClient {
  GraphClient({http.Client? transport}) : _http = transport ?? http.Client();

  final http.Client _http;
  String? _token;

  /// Renueva el access token (refresh). Devuelve true si lo consiguió.
  Future<bool> Function()? reauthenticate;

  /// La sesión Microsoft dejó de ser válida (refresh falló).
  void Function()? onUnauthorized;

  String? get token => _token;
  void setToken(String? value) => _token = value;

  // ===== Azure AD: Device Code Flow =====

  /// Paso 1: solicita un código de dispositivo.
  Future<DeviceCodeInfo> requestDeviceCode() async {
    final res = await _form(MsConfig.deviceCodeUrl, {
      'client_id': MsConfig.clientId,
      'scope': MsConfig.scopeParam,
    });
    final body = _json(res);
    if (res.statusCode >= 400) {
      throw _authError(body, 'No se pudo iniciar el inicio de sesión.');
    }
    return DeviceCodeInfo.fromJson(body);
  }

  /// Paso 2: sondea una vez el endpoint de token con el [deviceCode].
  /// Devuelve `pending`/`slowDown` mientras el alumno no termina, o los
  /// tokens cuando autoriza. Lanza [AuthException] ante errores definitivos.
  Future<DevicePollResult> pollDeviceToken(String deviceCode) async {
    final res = await _form(MsConfig.tokenUrl, {
      'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
      'client_id': MsConfig.clientId,
      'device_code': deviceCode,
    });
    final body = _json(res);
    if (res.statusCode < 400) {
      return DevicePollResult(DevicePollState.success, MsTokens.fromJson(body));
    }
    final error = body['error'] as String? ?? '';
    switch (error) {
      case 'authorization_pending':
        return const DevicePollResult(DevicePollState.pending);
      case 'slow_down':
        return const DevicePollResult(DevicePollState.slowDown);
      default:
        throw _authError(body, 'No se pudo completar el inicio de sesión.');
    }
  }

  /// Renueva tokens con el refresh token.
  Future<MsTokens> refreshTokens(String refreshToken) async {
    final res = await _form(MsConfig.tokenUrl, {
      'grant_type': 'refresh_token',
      'client_id': MsConfig.clientId,
      'refresh_token': refreshToken,
      'scope': MsConfig.scopeParam,
    });
    final body = _json(res);
    if (res.statusCode >= 400) {
      throw _authError(body, 'Tu sesión de Microsoft expiró.');
    }
    return MsTokens.fromJson(body);
  }

  // ===== Microsoft Graph =====

  /// GET autorizado contra Graph. Reintenta una vez tras refrescar el token.
  Future<Map<String, dynamic>> get(String path, {bool isRetry = false}) async {
    final uri = Uri.parse('${MsConfig.graphBaseUrl}/$path');
    http.Response res;
    try {
      res = await _http.get(uri, headers: {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      }).timeout(AppConfig.httpTimeout);
    } on TimeoutException {
      throw const TimeoutException('Microsoft Graph no respondió a tiempo.');
    } catch (e) {
      throw NetworkException('Error de red (Graph): $e');
    }

    if (res.statusCode == 401) {
      if (!isRetry && reauthenticate != null && await reauthenticate!()) {
        return get(path, isRetry: true);
      }
      onUnauthorized?.call();
      throw const UnauthorizedException('Tu sesión de Microsoft expiró.');
    }
    if (res.statusCode == 403) {
      throw const AuthException(
        'Microsoft denegó el acceso a los datos de Teams Education. '
        'La cuenta o el tenant no tienen habilitada la API de educación.',
      );
    }
    if (res.statusCode >= 400) {
      final body = _safeJson(res);
      final msg = (body['error'] is Map)
          ? (body['error']['message'] as String?)
          : null;
      throw ServerException(msg ?? 'Error de Graph', status: res.statusCode);
    }
    return _json(res);
  }

  // ===== Helpers =====

  Future<http.Response> _form(String url, Map<String, String> fields) async {
    try {
      return await _http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: fields,
          )
          .timeout(AppConfig.httpTimeout);
    } on TimeoutException {
      throw const TimeoutException('Microsoft no respondió a tiempo.');
    } catch (e) {
      throw NetworkException('Error de red (Microsoft): $e');
    }
  }

  Map<String, dynamic> _json(http.Response res) {
    try {
      final p = jsonDecode(utf8.decode(res.bodyBytes));
      return p is Map<String, dynamic> ? p : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _safeJson(http.Response res) => _json(res);

  /// Convierte un error de Azure AD en un [AuthException] con mensaje claro.
  /// Detecta el caso "el tenant bloquea el consentimiento del usuario".
  AuthException _authError(Map<String, dynamic> body, String fallback) {
    final code = body['error'] as String? ?? '';
    final desc = body['error_description'] as String? ?? '';
    // AADSTS65001: falta consentimiento del usuario/recurso.
    // AADSTS90094: requiere consentimiento de un administrador.
    // AADSTS700016: la app no existe en el tenant.
    if (desc.contains('AADSTS65001') ||
        desc.contains('AADSTS90094') ||
        code == 'consent_required' ||
        code == 'access_denied') {
      return const AuthException(
        'Tu universidad requiere que un administrador autorice esta app '
        'para acceder a Teams. Pide al área de TI que apruebe el '
        'consentimiento (permisos EduRoster/EduAssignments).',
      );
    }
    if (desc.contains('AADSTS700016')) {
      return const AuthException(
        'La app no está registrada en el tenant de tu universidad. '
        'Verifica el client_id y el tenant en la configuración.',
      );
    }
    if (code == 'expired_token' || code == 'authorization_declined') {
      return const AuthException(
        'El inicio de sesión se canceló o expiró. Inténtalo de nuevo.',
      );
    }
    final detail = desc.isNotEmpty ? desc.split('\n').first : code;
    return AuthException(detail.isNotEmpty ? detail : fallback);
  }

  void close() => _http.close();
}
