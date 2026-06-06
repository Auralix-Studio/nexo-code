/// Errores tipados de la capa de red.
sealed class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

class TimeoutException extends ApiException {
  const TimeoutException(super.message);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message);
}

class SessionExpiredException extends UnauthorizedException {
  const SessionExpiredException([String? message]) : super(message ?? 'La sesión ha expirado');
}

class DataParsingException implements Exception {
  final String model;
  final String? field;
  final dynamic rawData;
  final Object? innerError;

  const DataParsingException({
    required this.model,
    this.field,
    this.rawData,
    this.innerError,
  });

  @override
  String toString() => 'DataParsingException: Error al parsear el modelo $model'
      '${field != null ? " en el campo $field" : ""}. Error interno: $innerError';
}

class BadRequestException extends ApiException {
  final int status;
  final Map<String, dynamic>? payload;
  const BadRequestException(super.message, {required this.status, this.payload});
}

class ServerException extends ApiException {
  final int status;
  const ServerException(super.message, {required this.status});
}

class AuthException extends ApiException {
  const AuthException(super.message);
}

/// Convierte cualquier excepción en un mensaje **legible para el usuario**.
///
/// Cubre los casos cripticos típicos (HandshakeException, SocketException,
/// stack traces de .NET, etc.) y devuelve algo accionable. Usar siempre en
/// la UI en lugar de `error.toString()`.
String humanizeError(Object? error) {
  if (error == null) return 'Ocurrió un error desconocido.';
  final s = error.toString();

  // TLS / certificado — el caso que disparó esto.
  if (s.contains('HandshakeException') ||
      s.contains('CERTIFICATE_VERIFY_FAILED') ||
      s.contains('unable to get local issuer') ||
      s.contains('SSL') ||
      s.contains('TLS')) {
    return 'No se pudo establecer una conexión segura con el servidor. '
        'Verifica que tu fecha y hora del dispositivo sean correctas. '
        'Si persiste, actualiza Nexo o reporta al área de TI.';
  }
  // Sin red.
  if (s.contains('SocketException') ||
      s.contains('No route to host') ||
      s.contains('Failed host lookup') ||
      s.contains('Network is unreachable')) {
    return 'Sin conexión. Revisa tu Wi-Fi o datos móviles.';
  }
  // Timeout.
  if (error is TimeoutException || s.contains('TimeoutException')) {
    return 'El servidor está tardando demasiado en responder. '
        'Intenta de nuevo en unos segundos.';
  }
  // 5xx.
  if (error is ServerException) {
    return 'El servidor reportó un error (${error.status}). '
        'No es algo que tú hiciste mal; reintenta más tarde.';
  }
  // 401/403.
  if (error is UnauthorizedException) {
    return error.message.isNotEmpty
        ? error.message
        : 'Tu sesión expiró. Vuelve a iniciar sesión.';
  }
  if (error is AuthException) return error.message;
  // 4xx.
  if (error is BadRequestException) {
    return error.message.isNotEmpty
        ? error.message
        : 'La solicitud fue rechazada por el servidor.';
  }
  if (error is DataParsingException) {
    return 'Error al procesar los datos recibidos del servidor. Mostrando copia local.';
  }
  // Cualquier ApiException restante.
  if (error is ApiException) {
    return error.message.isNotEmpty
        ? error.message
        : 'Error de comunicación.';
  }
  // Fallback genérico, recortado para no mostrar stacktraces gigantes.
  final clean = s.replaceFirst(RegExp(r'^Exception:\s*'), '');
  return clean.length > 220 ? '${clean.substring(0, 220)}…' : clean;
}
