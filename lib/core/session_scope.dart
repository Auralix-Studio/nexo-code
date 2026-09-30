import 'dart:async';

/// Carries the originating session through retries and asynchronous fallbacks.
/// A late operation must never adopt the credentials of a newer session.
class SessionScope {
  final Object _zoneKey = Object();
  int _generation = 0;

  void invalidate() => _generation++;
  bool get isCurrent =>
      (Zone.current[_zoneKey] as int? ?? _generation) == _generation;

  void check() {
    if (!isCurrent) throw const StaleSessionException();
  }

  Future<T> run<T>(Future<T> Function() action) {
    final generation = Zone.current[_zoneKey] as int? ?? _generation;
    return runZoned(() async {
      check();
      return await action();
    }, zoneValues: {_zoneKey: generation});
  }

  Future<T> runFresh<T>(Future<T> Function() action) =>
      runZoned(() => run(action), zoneValues: {_zoneKey: _generation});
}

class StaleSessionException implements Exception {
  const StaleSessionException();
  @override
  String toString() => 'La sesión cambió. La operación fue descartada.';
}
