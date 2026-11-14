/// Estado de una carga: valor previo (si lo hay), si está cargando y el
/// último error.
class AsyncValue<T> {
  final T? value;
  final bool loading;
  final Object? error;
  const AsyncValue.idle() : value = null, loading = false, error = null;
  const AsyncValue.loading([T? prev])
    : value = prev,
      loading = true,
      error = null;
  const AsyncValue.data(T data) : value = data, loading = false, error = null;
  const AsyncValue.failure(Object e, [T? prev])
    : value = prev,
      loading = false,
      error = e;
  bool get hasValue => value != null;

  /// Aún no se inició ninguna carga: sin valor, sin error y sin loading.
  /// La UI debe tratarlo como "cargando" (esqueleto), no como vacío.
  bool get isIdle => !loading && value == null && error == null;

  /// La UI debe mostrar esqueleto: cargando o todavía sin iniciar.
  bool get showSkeleton => (loading || isIdle) && value == null;
}
