part of '../app_store.dart';

/// Infraestructura común de [AppStore]: dependencias, single-flight,
/// traducción de errores de la API, caché con frescura y notificación.
abstract class _StoreBase extends ChangeNotifier {
  _StoreBase(
    NexoRepository nexo, {
    required CacheManager cache,
    required ErrorHandler errorHandler,
    required ConnectivityService connectivity,
    SessionScope? scope,
  }) : _nexo = nexo,
       _scope = scope ?? SessionScope(),
       _cache = cache,
       _errorHandler = errorHandler,
       _connectivity = connectivity;

  final NexoRepository _nexo;
  final CacheManager _cache;
  final ErrorHandler _errorHandler;
  final ConnectivityService _connectivity;
  final SessionScope _scope;

  final _inFlight = <String, Future<Object?>>{};
  final _freshness = <String, DataFreshness>{};
  DataFreshness? freshnessOf(String operation) => _freshness[operation];

  /// Reloj de las marcas de frescura (las pruebas lo adelantan).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// [operation] tiene datos en pantalla descargados hace menos de [ttl].
  bool _isFresh(String operation, Duration? ttl, {bool hasValue = true}) =>
      ttl != null &&
      hasValue &&
      FreshnessTtl.isFresh(_freshness[operation], ttl, clock());

  /// Operaciones que resolvieron vía caché mientras el primer chequeo de
  /// conectividad aún no había terminado. `retryFailedEssentials` las
  /// reintenta cuando vuelve la conexión.
  final Set<String> _startupCacheOps = {};

  void _resetBase() {
    _inFlight.clear();
    _freshness.clear();
    _startupCacheOps.clear();
  }

  Future<T> _singleFlight<T>(String key, Future<T> Function() action) {
    _scope.check();
    final existing = _inFlight[key];
    if (existing != null) return existing.then((value) => value as T);
    final completer = Completer<T>();
    final future = completer.future;
    _inFlight[key] = future;
    () async {
      try {
        completer.complete(await action());
      } catch (e, stack) {
        completer.completeError(e, stack);
      } finally {
        if (identical(_inFlight[key], future)) _inFlight.remove(key);
      }
    }();
    return future;
  }

  Future<DateTime?> _savedUpdate(String operation) async {
    try {
      final stamp = await _cache.updatedAtFor(operation);
      if (stamp != null) return stamp;
    } catch (_) {}
    final value = AppStorage.instance.getCache('updated:$operation');
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  /// Llama a la API de Nexo y traduce sus errores a los que entienden
  /// [ErrorHandler] y las pantallas (red → caché, sesión vencida → login).
  Future<T> _call<T>(Future<T> Function() fn) async {
    _scope.check();
    try {
      return await fn();
    } on BackendException catch (e) {
      throw apiErrorOf(e);
    }
  }

  /// La API de Nexo como fuente de un [Resolver]: solo disponible con una
  /// sesión guardada.
  List<DataSource<T>> _api<T>(Future<T> Function(NexoRepository) fn) => [
    DataSource(
      id: 'nexo',
      available: () async {
        _scope.check();
        final s = AppStorage.instance;
        return s.credUser != null && s.credPass != null;
      },
      fetch: () => _call(() => fn(_nexo)),
    ),
  ];

  /// Pide [fn] a la API; sin sesión o con respuesta vacía según [isEmpty]
  /// falla con [NoDataAvailableException].
  Future<T> _fetch<T>(
    Future<T> Function(NexoRepository) fn, {
    bool Function(T)? isEmpty,
  }) => Resolver<T>(
    sources: _api(fn),
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
    isEmpty: isEmpty,
  ).load();

  /// Como [_fetch], pero sin sesión devuelve una lista vacía en vez de fallar.
  Future<List<T>> _fetchOrEmpty<T>(
    Future<List<T>> Function(NexoRepository) fn,
  ) async {
    try {
      return await _fetch(fn);
    } on NoDataAvailableException catch (e) {
      if (e.cause == null) return const [];
      rethrow;
    }
  }

  Future<void> _setStorageCache(String key, Object data) {
    _scope.check();
    return AppStorage.instance.setCache(key, data);
  }

  bool _disposed = false;
  bool _notifyQueued = false;

  /// Agrupa en una sola notificación todos los cambios hechos en el mismo
  /// ciclo del event loop: el inicio lanza varias cargas a la vez y cada
  /// notificación reconstruye las pantallas y vuelve a sincronizar widgets y
  /// recordatorios. Los cambios de una sesión ya cerrada no notifican.
  void _notify() {
    if (_disposed || !_scope.isCurrent || _notifyQueued) return;
    _notifyQueued = true;
    scheduleMicrotask(() {
      _notifyQueued = false;
      if (_disposed) return;
      final phase = SchedulerBinding.instance.schedulerPhase;
      if (phase == SchedulerPhase.persistentCallbacks ||
          phase == SchedulerPhase.midFrameMicrotasks) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed) notifyListeners();
        });
      } else {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Carga remota con respaldo en caché, single-flight por [operationName],
  /// marca de frescura y persistencia de lo que llegó de la red.
  ///
  /// Con [ttl], si lo que hay se descargó hace menos de eso (también si vino
  /// del caché local con su fecha real) no se va a la red; [force] (el
  /// pull-to-refresh) lo ignora.
  Future<T?> _wrap<T>(
    Future<T> Function() remote,
    AsyncValue<T> Function() get,
    void Function(AsyncValue<T>) set, {
    Future<T?> Function()? cached,
    Future<void> Function(T value)? persist,
    required String operationName,
    Duration? ttl,
    bool force = false,
  }) {
    final current = get();
    if (!force &&
        !current.loading &&
        _isFresh(operationName, ttl, hasValue: current.hasValue)) {
      return Future.value(current.value);
    }
    return _load(
      remote,
      get,
      set,
      cached: cached,
      persist: persist,
      operationName: operationName,
    );
  }

  Future<T?> _load<T>(
    Future<T> Function() remote,
    AsyncValue<T> Function() get,
    void Function(AsyncValue<T>) set, {
    Future<T?> Function()? cached,
    Future<void> Function(T value)? persist,
    required String operationName,
  }) => _singleFlight(
    operationName,
    () => _scope.run(() async {
      final previous = _freshness[operationName];
      _freshness[operationName] = DataFreshness(
        updatedAt: previous?.updatedAt,
        fromCache: previous?.fromCache ?? false,
        refreshing: true,
      );
      set(AsyncValue.loading(get().value));
      _notify();
      try {
        var fromCache = false;
        final v = await _errorHandler.withFallback<T>(
          remote: remote,
          cached: () async {
            final result = await cached?.call();
            if (result != null) fromCache = true;
            return result;
          },
          operationName: operationName,
        );
        if (!_scope.isCurrent) return null;
        // Si el primer chequeo de conectividad aún no terminó y los datos
        // vinieron del caché (hasInternet era false prematuramente), marcamos
        // la operación para que `retryFailedEssentials` la reintente luego.
        if (!_connectivity.firstCheckCompleted && !_connectivity.hasInternet) {
          _startupCacheOps.add(operationName);
        }
        final updatedAt = fromCache
            ? await _savedUpdate(operationName)
            : clock();
        if (!_scope.isCurrent) return null;
        _freshness[operationName] = DataFreshness(
          updatedAt: updatedAt,
          fromCache: fromCache,
        );
        set(AsyncValue.data(v));
        _notify();
        if (!_scope.isCurrent) return null;
        if (!fromCache && persist != null) {
          await persist(v);
          _scope.check();
          await _setStorageCache(
            'updated:$operationName',
            updatedAt!.millisecondsSinceEpoch,
          );
        }
        if (!_scope.isCurrent) return null;
        return v;
      } catch (e) {
        if (!_scope.isCurrent) return null;
        _freshness[operationName] = DataFreshness(
          updatedAt: _freshness[operationName]?.updatedAt,
          fromCache: true,
          failed: true,
        );
        set(AsyncValue.failure(e, get().value));
        _notify();
        return null;
      }
    }),
  );

  /// Muestra lo guardado en caché mientras no haya nada cargado ni cargando.
  Future<void> _hydrate<T>(
    String operation,
    Future<T?> Function() read,
    AsyncValue<T> Function() get,
    void Function(AsyncValue<T>) set,
  ) async {
    final previous = get();
    if (previous.hasValue || previous.loading) return;
    try {
      final value = await read();
      if (!_scope.isCurrent || !identical(previous, get()) || value == null) {
        return;
      }
      final updatedAt = await _savedUpdate(operation);
      if (!_scope.isCurrent || !identical(previous, get())) return;
      set(AsyncValue.data(value));
      _freshness[operation] = DataFreshness(
        updatedAt: updatedAt,
        fromCache: true,
      );
      _notify();
    } catch (_) {
      // An unavailable cache must not prevent the subsequent remote load.
    }
  }
}
