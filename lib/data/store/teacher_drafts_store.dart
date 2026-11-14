part of '../app_store.dart';

/// Lo que el docente deja a medias en el dispositivo: borradores de
/// asistencia y de notas, y las clases sin asistencia que descartó. Todo se
/// borra con el resto del caché al cerrar sesión.
mixin _TeacherDraftsStore on _StoreBase, _TeacherStore {
  static const _ckDismissed = 'tch.dismissedMissing';

  /// Clases sin asistencia que el docente marcó como "no hubo clase".
  Set<String> get docenteClasesDescartadas {
    final raw = AppStorage.instance.getCache(_ckDismissed);
    return raw is List ? raw.map((e) => '$e').toSet() : <String>{};
  }

  Future<void> descartarClaseSinAsistencia(String key) async {
    // Solo importan las últimas semanas: se guardan las 60 más recientes.
    final keys = [...docenteClasesDescartadas, key]..sort();
    final keep = keys.length > 60 ? keys.sublist(keys.length - 60) : keys;
    await _setStorageCache(_ckDismissed, keep);
    _notify();
  }

  // ── Borradores de asistencia ────────────────────────────────────────────
  // Lo marcado se guarda mientras se pasa lista: si la app se cierra o el
  // wifi del aula falla al enviar, nada se pierde. Se borra al registrar con
  // éxito.

  static String _draftKey(String courseId, DateTime day, int unitId) =>
      'tch.draftAtt.$courseId.${day.year}-${day.month}-${day.day}.$unitId';

  Map<String, int> docenteBorradorAsistencia(
    String courseId,
    DateTime day,
    int unitId,
  ) {
    final raw = AppStorage.instance.getCache(
      _draftKey(courseId, day, unitId),
      maxAge: const Duration(days: 2),
    );
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if (e.value is int) '${e.key}': e.value as int,
    };
  }

  Future<void> guardarBorradorAsistencia(
    String courseId,
    DateTime day,
    int unitId,
    Map<String, int> marks,
  ) {
    final key = _draftKey(courseId, day, unitId);
    if (marks.isEmpty) return AppStorage.instance.removeCache(key);
    return _setStorageCache(key, marks);
  }

  Future<void> borrarBorradorAsistencia(
    String courseId,
    DateTime day,
    int unitId,
  ) => AppStorage.instance.removeCache(_draftKey(courseId, day, unitId));

  // ── Borradores de notas ─────────────────────────────────────────────────
  // Las notas escritas o pegadas desde Excel se guardan por evaluación
  // (curso + unidad + tipo de nota + columna) mientras el docente califica:
  // puede avanzar en varios momentos, salir sin perder cambios o reintentar
  // si el guardado falla. Se limpia al publicar o descartar.

  static String _gradeDraftKey(
    String courseId,
    int unitId,
    int tipoNotaId,
    int ordinal,
  ) => 'tch.draftGrade.$courseId.$unitId.$tipoNotaId.$ordinal';

  Map<String, String> docenteBorradorNotas(
    String courseId,
    int unitId,
    int tipoNotaId, [
    int ordinal = 0,
  ]) {
    final raw = AppStorage.instance.getCache(
      _gradeDraftKey(courseId, unitId, tipoNotaId, ordinal),
      maxAge: const Duration(days: 30),
    );
    if (raw is! Map) return {};
    return {
      for (final e in raw.entries)
        if ('${e.value}'.trim().isNotEmpty) '${e.key}': '${e.value}'.trim(),
    };
  }

  /// Cantidad de alumnos con nota en borrador (distinta de la registrada)
  /// para una evaluación.
  int docenteCambiosBorradorNotas(
    String courseId,
    int unitId,
    int tipoNotaId, {
    int ordinal = 0,
    double maxValue = 20,
  }) {
    final draft = docenteBorradorNotas(courseId, unitId, tipoNotaId, ordinal);
    if (draft.isEmpty) return 0;
    final roster = alumnosDe(courseId).value;
    if (roster == null || roster.isEmpty) return draft.length;
    final byCode = {for (final s in roster) s.code: s};
    var count = 0;
    for (final e in draft.entries) {
      final s = byCode[e.key];
      if (s == null) continue;
      final orig = s.cellFor(unitId, tipoNotaId, ordinal)?.value;
      final v = parseGradeValue(e.value, maxValue);
      if (v == null || v != orig) count++;
    }
    return count;
  }

  Future<void> guardarBorradorNotas(
    String courseId,
    int unitId,
    int tipoNotaId,
    Map<String, String> grades, {
    int ordinal = 0,
  }) async {
    final key = _gradeDraftKey(courseId, unitId, tipoNotaId, ordinal);
    if (grades.isEmpty) {
      await AppStorage.instance.removeCache(key);
    } else {
      await _setStorageCache(key, grades);
    }
    _notify();
  }

  Future<void> borrarBorradorNotas(
    String courseId,
    int unitId,
    int tipoNotaId, [
    int ordinal = 0,
  ]) async {
    await AppStorage.instance.removeCache(
      _gradeDraftKey(courseId, unitId, tipoNotaId, ordinal),
    );
    _notify();
  }
}
