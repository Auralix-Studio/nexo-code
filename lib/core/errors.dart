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
