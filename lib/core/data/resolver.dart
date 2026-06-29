/// Multi-source resource resolver.
library;

typedef SourceId = String;

class DataSource<T> {
  DataSource({required this.id, this.available, required this.fetch});
  final SourceId id;
  final Future<bool> Function()? available;
  final Future<T> Function() fetch;
  Future<bool> isAvailable() async => (await available?.call()) ?? true;
}

class Resolver<T> {
  Resolver({
    required this.sources,
    required this.merge,
    this.isEmpty,
    this.onSourceUsed,
  });
  final List<DataSource<T>> sources;
  final T Function(List<T>) merge;
  final bool Function(T)? isEmpty;
  final void Function(SourceId id, bool ok, Object? err)? onSourceUsed;

  Future<T> load() async {
    final results = <T>[];
    Object? lastError;
    StackTrace? lastStack;
    for (final s in sources) {
      bool av = false;
      try {
        av = await s.isAvailable();
      } catch (e, st) {
        lastError = e; lastStack = st;
        onSourceUsed?.call(s.id, false, e);
        continue;
      }
      if (!av) { onSourceUsed?.call(s.id, false, 'unavailable'); continue; }
      try {
        final v = await s.fetch();
        if (isEmpty?.call(v) ?? false) {
          onSourceUsed?.call(s.id, false, 'empty');
          continue;
        }
        results.add(v);
        onSourceUsed?.call(s.id, true, null);
      } catch (e, st) {
        lastError = e; lastStack = st;
        onSourceUsed?.call(s.id, false, e);
      }
    }
    if (results.isEmpty) {
      throw NoDataAvailableException(cause: lastError, stackTrace: lastStack);
    }
    return merge(results);
  }
}

class NoDataAvailableException implements Exception {
  const NoDataAvailableException({this.cause, this.stackTrace});
  final Object? cause;
  final StackTrace? stackTrace;
  @override
  String toString() => 'NoDataAvailableException(${cause ?? "ningún backend respondió"})';
}

class MergeStrategies {
  MergeStrategies._();
  static T firstWins<T>(List<T> xs) => xs.first;
  static T Function(List<T>) fold<T>(T Function(T, T) combine) =>
      (xs) => xs.reduce(combine);
  static List<T> Function(List<List<T>>) concat<T>() =>
      (xs) => xs.expand((e) => e).toList();
}
