/// Provenance of the value currently shown, independent of connectivity.
class DataFreshness {
  final DateTime? updatedAt;
  final bool fromCache;
  final bool refreshing;
  final bool failed;
  const DataFreshness({
    this.updatedAt,
    this.fromCache = false,
    this.refreshing = false,
    this.failed = false,
  });
}

/// Tiempo mínimo antes de volver a pedir un dato a la red. Por debajo de él
/// se muestra lo que ya hay (en memoria o en el caché local con su fecha);
/// el pull-to-refresh lo ignora. Periodos, perfil y horario cambian pocas
/// veces por semestre; notas y pagos, más seguido.
abstract final class FreshnessTtl {
  static const terms = Duration(hours: 3);
  static const profile = Duration(hours: 6);
  static const schedule = Duration(hours: 6);
  static const grades = Duration(minutes: 5);
  static const payments = Duration(minutes: 15);
  static const languages = Duration(hours: 1);
  static const teacherRoster = Duration(minutes: 3);

  /// [freshness] todavía vale para [ttl] en [now]: llegó bien (no es un
  /// fallo) y su fecha real de descarga es más reciente que [ttl].
  static bool isFresh(DataFreshness? freshness, Duration ttl, DateTime now) {
    final at = freshness?.updatedAt;
    if (freshness == null || at == null || freshness.failed) return false;
    final age = now.difference(at);
    return !age.isNegative && age < ttl;
  }
}
