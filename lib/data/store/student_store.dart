part of '../app_store.dart';

/// Datos académicos del estudiante: perfil, periodos, horario (con Idiomas),
/// resumen y promedios, boletas y documentos. Cada carga respeta su
/// [FreshnessTtl] salvo con `force` (pull-to-refresh).
mixin _StudentStore on _StoreBase {
  static const _ckResumen = 'resumen';

  AsyncValue<Student> profile = const AsyncValue.idle();
  AsyncValue<List<Term>> periodos = const AsyncValue.idle();
  AsyncValue<List<IdiomasCourse>> idiomasMatricula = const AsyncValue.idle();
  AsyncValue<List<dynamic>> idiomasNotas = const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> _baseSchedule = const AsyncValue.idle();
  AsyncValue<GradesSummary> resumen = const AsyncValue.idle();
  AsyncValue<List<TermAverage>> promedios = const AsyncValue.idle();
  AsyncValue<EnrollmentCertificate> certificate = const AsyncValue.idle();
  AsyncValue<WifiCredential> wifi = const AsyncValue.idle();
  final Map<String, AsyncValue<List<ReportCardCourse>>> _boleta = {};
  final Map<String, AsyncValue<CourseGradeDetail>> _detalle = {};
  final Map<String, AsyncValue<List<CourseGrade>>> _boletaLegacy = {};

  void Function(String course, String grade)? onGradeChange;

  void _clearStudent() {
    profile = const AsyncValue.idle();
    periodos = const AsyncValue.idle();
    // Otro estudiante puede tener otra regla de aprobación: no se hereda.
    PassingRule.current = PassingRule.standard;
    _baseSchedule = const AsyncValue.idle();
    _idiomasLoadedAt = null;
    resumen = const AsyncValue.idle();
    promedios = const AsyncValue.idle();
    _boleta.clear();
    _boletaLegacy.clear();
    _detalle.clear();
    certificate = const AsyncValue.idle();
    idiomasMatricula = const AsyncValue.idle();
    idiomasNotas = const AsyncValue.idle();
    wifi = const AsyncValue.idle();
  }

  /// Avisa localmente de las notas que cambiaron desde la última boleta. Si
  /// el push de ese curso acaba de llegar ([GradePushLog]), no se repite el
  /// aviso. Cada item es (curso, nota, código del curso).
  void _checkGrades(Iterable<(String, String, String)> items) {
    final entries = items.where((e) => e.$2.isNotEmpty && e.$2 != '—');
    if (entries.isEmpty) return;
    final s = AppStorage.instance;
    Map<String, dynamic> prev = {};
    final raw = s.gradeSnapshot;
    final firstTime = raw == null;
    if (raw != null) {
      try {
        prev = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }
    final next = Map<String, dynamic>.from(prev);
    for (final (course, grade, code) in entries) {
      final before = prev[course] as String?;
      next[course] = grade;
      if (!firstTime &&
          before != grade &&
          onGradeChange != null &&
          !GradePushLog.instance.wasRecent(code: code, name: course)) {
        onGradeChange!(course, grade);
      }
    }
    s.setGradeSnapshot(jsonEncode(next));
  }

  // ── Horario ─────────────────────────────────────────────────────────────

  List<IdiomasCourse> get idiomasVigentes {
    final list = idiomasMatricula.value;
    if (list == null || list.isEmpty) return [];
    final now = DateTime.now();
    return list.where((c) => c.anio == now.year && c.mes == now.month).toList();
  }

  /// Horario de la universidad. `/schedule` ya trae las clases del Centro
  /// de Idiomas, así que no se combina nada en la app.
  AsyncValue<List<ScheduleClass>> get schedule => _baseSchedule;

  @visibleForTesting
  void setBaseScheduleForTesting(AsyncValue<List<ScheduleClass>> value) {
    _baseSchedule = value;
  }

  // ── Periodo activo y promedios ──────────────────────────────────────────

  Term? get periodoActivo {
    final list = periodos.value;
    if (list == null) return null;
    for (final p in list) {
      if (p.isActive) return p;
    }
    return null;
  }

  /// Asignaturas del periodo activo que ya cerraron (talleres de medio ciclo).
  /// Se usa para no recordar clases de un curso que ya terminó.
  Set<String> get finishedSubjectsThisTerm {
    final p = periodoActivo;
    if (p == null) return const {};
    return finishedSubjects(boletaOf(p.year, p.number).value);
  }

  /// Promedio ponderado acumulado que calcula la API (resumen de notas; si
  /// aún no llegó, el del perfil).
  double? get promedioAcumulado {
    final oficial = resumen.value?.average;
    if (oficial != null && oficial > 0) return oficial;
    return profile.value?.gpa;
  }

  /// La boleta del ciclo activo aún está cargando por primera vez (el
  /// promedio del ciclo sale de ella).
  bool get promedioCicloLoading {
    final activo = periodoActivo;
    if (activo == null) return periodos.showSkeleton;
    return isNewModel(activo.year, activo.number)
        ? boletaOf(activo.year, activo.number).showSkeleton
        : boletaLegacyOf(activo.year, activo.number).showSkeleton;
  }

  double? get promedioCicloActual {
    final activo = periodoActivo;
    if (activo == null) return null;
    if (isNewModel(activo.year, activo.number)) {
      final courses = boletaOf(activo.year, activo.number).value;
      if (courses == null) return null;
      return GradeCalculator.promedioPonderadoBoleta(
        courses,
        gradeOf: realAverageOf,
      );
    }
    final courses = boletaLegacyOf(activo.year, activo.number).value;
    if (courses == null) return null;
    return GradeCalculator.promedioPonderadoLegacy(
      courses,
      activeYear: activo.year,
      activeNumber: activo.number,
    );
  }

  /// Nota a mostrar (y a promediar) para un curso de la boleta, siempre en
  /// escala vigesimal. La API ya entrega el promedio real con decimales
  /// (`grade.current`), el mismo que trae el detalle, así que lista, detalle
  /// y promedio del ciclo coinciden sin recalcular nada.
  double? realAverageOf(ReportCardCourse c) => c.vigesimalAverage;

  int? get approvedCredits {
    final p = profile.value?.creditsApproved;
    final r = resumen.value?.approvedCredits;
    if (p != null && p > 0) return p;
    if (r != null && r > 0) return r;
    return p ?? r;
  }

  int? get totalCredits => resumen.value?.totalCredits;

  // ── Cargas ──────────────────────────────────────────────────────────────

  Future<Student?> loadProfile({bool force = false}) => _wrap(
    () => _fetch(
      (r) => r.profile(),
      isEmpty: (s) => s.id.isEmpty && s.fullName.isEmpty,
    ),
    () => profile,
    (v) => profile = v,
    cached: _cache.getStudent,
    persist: _cache.saveStudent,
    operationName: 'loadProfile',
    ttl: FreshnessTtl.profile,
    force: force,
  );

  Future<List<Term>?> loadPeriodos({bool force = false}) => _scope.run(
    () async {
      final result = await _wrap(
        () => _fetchOrEmpty((r) => r.terms()),
        () => periodos,
        (v) => periodos = v,
        cached: () => _cache.getPeriodos(),
        persist: (v) => _cache.savePeriodos(v),
        operationName: 'loadPeriodos',
        ttl: FreshnessTtl.terms,
        force: force,
      );
      if (!_scope.isCurrent) return null;
      // El periodo más antiguo es la cohorte de ingreso, y de ahí sale qué nota
      // aprueba para este estudiante.
      PassingRule.resolveFrom(periodos.value);
      return result;
    },
  );

  Future<List<ScheduleClass>?> loadHorarioActual({bool force = false}) => _wrap(
    () => _fetchOrEmpty((r) {
      final p = periodoActivo;
      return r.schedule(year: p?.year, number: p?.number);
    }),
    () => _baseSchedule,
    (v) => _baseSchedule = v,
    cached: () => _cache.getHorario(),
    persist: (v) => _cache.saveHorario(v),
    operationName: 'loadHorarioActual',
    ttl: FreshnessTtl.schedule,
    force: force,
  );

  DateTime? _idiomasLoadedAt;

  /// Cursos del Centro de Idiomas con sus notas (`/languages`). Solo los
  /// pide la sección de Idiomas (en Notas): el horario ya los trae en
  /// `/schedule`. Un estudiante sin cuenta de Idiomas recibe una lista
  /// vacía. Mientras recarga o si falla, se conserva lo anterior.
  Future<void> loadIdiomasMatricula({bool force = false}) =>
      _scope.run(() async {
        final s = AppStorage.instance;
        if (s.credUser == null || s.credPass == null) return;
        if (idiomasMatricula.loading) return;
        final at = _idiomasLoadedAt;
        if (!force &&
            idiomasMatricula.hasValue &&
            idiomasMatricula.error == null &&
            at != null &&
            clock().difference(at) < FreshnessTtl.languages) {
          return;
        }
        try {
          idiomasMatricula = AsyncValue.loading(idiomasMatricula.value);
          _notify();
          final result = await _call(_nexo.languages);
          if (!_scope.isCurrent) return;
          idiomasMatricula = AsyncValue.data(result.courses);
          idiomasNotas = AsyncValue.data(result.grades);
          _idiomasLoadedAt = clock();
          _notify();
        } catch (e) {
          if (!_scope.isCurrent) return;
          idiomasMatricula = AsyncValue.failure(e, idiomasMatricula.value);
          idiomasNotas = AsyncValue.failure(e, idiomasNotas.value);
          _notify();
        }
      });

  /// Promedio acumulado y créditos. Comparte la respuesta de
  /// `/grades/summary` con [loadPromedios].
  Future<GradesSummary?> loadResumen({bool force = false}) => _wrap(
    () => _call(_nexo.gradesSummary),
    () => resumen,
    (v) => resumen = v,
    cached: () async {
      final raw = AppStorage.instance.getCache(_ckResumen);
      if (raw is Map) {
        return GradesSummary.fromJson(raw.cast<String, dynamic>());
      }
      return null;
    },
    persist: (v) => _setStorageCache(_ckResumen, v.toJson()),
    operationName: 'loadResumen',
    ttl: FreshnessTtl.grades,
    force: force,
  );

  Future<List<TermAverage>?> loadPromedios({bool force = false}) => _wrap(
    () => _call(_nexo.termAverages),
    () => promedios,
    (v) => promedios = v,
    cached: () => _cache.getPromedios(),
    persist: (v) => _cache.savePromedios(v),
    operationName: 'loadPromedios',
    // Right after login the server is still computing past terms: an empty
    // history is asked again after 45 s instead of waiting the full TTL.
    ttl: (promedios.value?.isEmpty ?? false)
        ? const Duration(seconds: 45)
        : FreshnessTtl.grades,
    force: force,
  );

  /// Carga la boleta del periodo activo con el modelo que le corresponde.
  Future<void> checkActiveBoleta({bool force = false}) => _scope.run(() async {
    final activo = periodoActivo;
    if (activo == null) return;
    if (isNewModel(activo.year, activo.number)) {
      await loadBoleta(activo.year, activo.number, force: force);
    } else {
      await loadBoletaLegacy(activo.year, activo.number, force: force);
    }
  });

  AsyncValue<List<ReportCardCourse>> boletaOf(int year, int periodo) =>
      _boleta['$year-$periodo'] ?? const AsyncValue.idle();
  AsyncValue<List<CourseGrade>> boletaLegacyOf(int year, int periodo) =>
      _boletaLegacy['$year-$periodo'] ?? const AsyncValue.idle();
  AsyncValue<CourseGradeDetail> detalleOf(String id) =>
      _detalle[id] ?? const AsyncValue.idle();

  Future<void> loadBoletaLegacy(
    int year,
    int periodo, {
    bool force = false,
  }) async {
    final key = '$year-$periodo';
    await _wrap<List<CourseGrade>>(
      () => _fetch((r) => r.legacyGrades(year, periodo)),
      () => boletaLegacyOf(year, periodo),
      (value) => _boletaLegacy[key] = value,
      cached: () => _cache.getBoletaLegacy(year.toString(), periodo.toString()),
      persist: (data) async {
        _checkGrades(data.map((n) => (n.subject, n.currentGradeText, n.code)));
        await _cache.saveBoletaLegacy(
          year.toString(),
          periodo.toString(),
          data,
        );
      },
      operationName: 'loadBoletaLegacy:$key',
      ttl: FreshnessTtl.grades,
      force: force,
    );
  }

  /// Boleta del modelo por competencias. El detalle de los cursos en proceso
  /// llega en la misma respuesta; el resto se pide al abrir cada curso.
  Future<void> loadBoleta(int year, int periodo, {bool force = false}) async {
    final key = '$year-$periodo';
    await _wrap<List<ReportCardCourse>>(
      () => _fetch((r) async {
        final card = await r.reportCard(year, periodo);
        card.details.forEach(
          (id, detail) => _detalle[id] = AsyncValue.data(detail),
        );
        return card.courses;
      }),
      () => boletaOf(year, periodo),
      (value) => _boleta[key] = value,
      cached: () => _cache.getBoleta(year.toString(), periodo.toString()),
      persist: (data) async {
        _checkGrades(data.map((c) => (c.name, c.promedioText, c.code)));
        await _cache.saveBoleta(year.toString(), periodo.toString(), data);
      },
      operationName: 'loadBoleta:$key',
      ttl: FreshnessTtl.grades,
      force: force,
    );
  }

  Future<void> loadDetalle(int year, int periodo, String enrollmentSubjectId) =>
      _scope.run(() async {
        final id = enrollmentSubjectId;
        if (_detalle[id]?.loading == true) return;
        _detalle[id] = AsyncValue.loading(_detalle[id]?.value);
        _notify();
        try {
          final data = await _fetch((r) => r.courseDetail(year, periodo, id));
          if (!_scope.isCurrent) return;
          _detalle[id] = AsyncValue.data(data);
        } catch (e) {
          if (!_scope.isCurrent) return;
          _detalle[id] = AsyncValue.failure(e, _detalle[id]?.value);
        }
        _notify();
      });

  Future<EnrollmentCertificate?> loadCertificate({int? year, int? periodo}) {
    final p = periodoActivo;
    final a = year ?? p?.year ?? 0;
    final per = periodo ?? p?.number ?? 0;
    return _wrap(
      () => _fetch((r) => r.enrollment(year: a, number: per)),
      () => certificate,
      (v) => certificate = v,
      operationName: 'loadCertificate:$a:$per',
    );
  }

  Future<WifiCredential?> loadWifi() => _wrap<WifiCredential>(
    () => _call(_nexo.wifi),
    () => wifi,
    (v) => wifi = v,
    operationName: 'loadWifi',
  );
}
