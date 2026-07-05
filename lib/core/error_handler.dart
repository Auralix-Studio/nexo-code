import 'package:flutter/foundation.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/session.dart';

class ErrorHandler {
  final ConnectivityService connectivity;
  final SessionService session;
  ErrorHandler({required this.connectivity, required this.session});
  Future<T> withFallback<T>({
    required Future<T> Function() remote,
    required Future<T?> Function() cached,
    required String operationName,
  }) async {
    try {
      if (!connectivity.hasInternet) {
        debugPrint(
          'ErrorHandler: No internet for $operationName, falling back to cache',
        );
        final cachedResult = await cached();
        if (cachedResult != null) return cachedResult;
        throw const NetworkException(
          'Sin conexión a internet y no hay datos locales de respaldo.',
        );
      }
      final result = await remote();
      return result;
    } on SessionExpiredException {
      debugPrint(
        'ErrorHandler: Session expired in $operationName. Logging out.',
      );
      await session.logout();
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
}
