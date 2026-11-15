import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/services/session.dart';

class ErrorHandler {
  final ConnectivityService connectivity;
  final SessionService session;
  ErrorHandler({required this.connectivity, required this.session});

  /// Una petición falló por la red (sin conexión o timeout): `main` lo
  /// conecta a [ConnectivityService.reportNetworkError] para revisar el
  /// estado del servidor en ese momento en lugar de sondearlo seguido.
  void Function()? onNetworkError;
  Future<T> withFallback<T>({
    required Future<T> Function() remote,
    required Future<T?> Function() cached,
    required String operationName,
  }) async {
    try {
      if (!connectivity.hasInternet) {
        // Preferimos caché si existe, pero NO bloqueamos el intento remoto:
        // connectivity_plus da falsos negativos en desktop, y un token vencido
        // no implica falta de red. Si no hay caché, igual intentamos la red.
        final cachedResult = await cached();
        if (cachedResult != null) {
          debugPrint('ErrorHandler: offline flag for $operationName → cache');
          return cachedResult;
        }
        debugPrint(
          'ErrorHandler: offline flag for $operationName but no cache → intento remoto igualmente',
        );
      }
      return await _remoteWithRetry(remote, operationName);
    } on StaleSessionException {
      rethrow;
    } on SessionExpiredException {
      // El logout ya lo disparó BackendClient (onSessionInvalid), fuente única.
      // Aquí NO cerramos sesión otra vez: solo intentamos mostrar el caché
      // durante la transición a la pantalla de login.
      debugPrint('ErrorHandler: session expired in $operationName.');
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on AuthUnavailableException catch (e) {
      // Transitorio: no se pudo verificar la sesión (servidor de auth caído).
      // Conservamos la sesión y caemos al caché.
      debugPrint(
        'ErrorHandler: auth unavailable in $operationName: $e. Trying cache.',
      );
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on UnauthorizedException catch (e) {
      debugPrint(
        'ErrorHandler: Forbidden (403) in $operationName: $e. Keeping session, trying cache.',
      );
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on NetworkException catch (e) {
      debugPrint(
        'ErrorHandler: Network exception in $operationName: $e. Trying cache.',
      );
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on TimeoutException catch (e) {
      debugPrint('ErrorHandler: Timeout in $operationName: $e. Trying cache.');
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on ServerException catch (e) {
      debugPrint(
        'ErrorHandler: Server exception in $operationName: $e. Trying cache.',
      );
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } on DataParsingException catch (e) {
      debugPrint(
        'ErrorHandler: Data parsing exception in $operationName: $e. Trying cache.',
      );
      final cachedResult = await cached();
      if (cachedResult != null) return cachedResult;
      rethrow;
    } catch (e) {
      debugPrint(
        'ErrorHandler: Exception in $operationName: $e. Trying cache.',
      );
      try {
        final cachedResult = await cached();
        if (cachedResult != null) return cachedResult;
      } catch (cacheErr) {
        debugPrint(
          'ErrorHandler: Failed to read from cache for $operationName: $cacheErr',
        );
      }
      rethrow;
    }
  }

  /// Ejecuta la operación remota con, como mucho, 1 reintento ante fallos
  /// que no cargan al servidor: la petición no llegó (sin conexión) o el
  /// backend respondió un 5xx propio. NO se reintenta:
  /// - un timeout: el servidor sigue procesando la primera petición, y
  ///   repetirla duplica el trabajo justo cuando la universidad está lenta;
  /// - `503 upstream_unavailable` ni un 504: la universidad está caída o
  ///   saturada;
  /// - la sesión no verificable (`auth_unavailable`): ya se intentó renovar.
  /// El reintento espera con backoff exponencial y jitter, o lo que pida el
  /// servidor en `Retry-After` (si pide más de [maxRetryAfter], no se
  /// reintenta).
  Future<T> _remoteWithRetry<T>(
    Future<T> Function() remote,
    String operationName,
  ) async {
    var attempt = 0;
    while (true) {
      attempt++;
      try {
        return await remote();
      } on NetworkException {
        onNetworkError?.call();
        if (attempt >= maxAttempts) rethrow;
        await _wait(retryDelay(attempt), operationName, attempt);
      } on TimeoutException {
        onNetworkError?.call();
        rethrow;
      } on ServerException catch (e) {
        final wait = e.retryAfter ?? retryDelay(attempt);
        if (attempt >= maxAttempts ||
            !isRetryableServerError(e) ||
            wait > maxRetryAfter) {
          rethrow;
        }
        await _wait(wait, operationName, attempt);
      }
    }
  }

  static const maxAttempts = 2;
  static const maxRetryAfter = Duration(seconds: 10);
  static const _baseDelay = Duration(milliseconds: 500);
  static final _random = Random();

  /// Solo los 5xx del propio backend: ni la universidad caída
  /// (`upstream_unavailable`) ni el gateway que se cansó de esperar (504).
  static bool isRetryableServerError(ServerException e) =>
      e.status >= 500 && e.status != 504 && !e.isUpstreamUnavailable;

  /// Backoff exponencial (500 ms, 1 s, 2 s…) con jitter de ±50 % para que
  /// los clientes que fallaron a la vez no vuelvan todos juntos.
  static Duration retryDelay(int attempt, {Random? random}) {
    final base = _baseDelay.inMilliseconds * (1 << (attempt - 1));
    final factor = 0.5 + (random ?? _random).nextDouble();
    return Duration(milliseconds: (base * factor).round());
  }

  Future<void> _wait(Duration backoff, String operationName, int attempt) {
    debugPrint(
      'ErrorHandler: retry $attempt for $operationName in '
      '${backoff.inMilliseconds}ms',
    );
    return Future<void>.delayed(backoff);
  }
}
