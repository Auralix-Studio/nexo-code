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
