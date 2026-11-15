part of '../app_store.dart';

/// Módulo docente: secciones, horario, marcaciones, asistencia y notas.
mixin _TeacherStore on _StoreBase {
  AsyncValue<TeacherInfo> teacherInfo = const AsyncValue.idle();
  AsyncValue<List<TeacherSubject>> teacherSubjects = const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> teacherSchedule = const AsyncValue.idle();
  AsyncValue<List<TeacherPunch>> teacherMarcacion = const AsyncValue.idle();
  AsyncValue<List<TeacherClassCompliance>> teacherCumplimiento =
      const AsyncValue.idle();
  AsyncValue<List<VirtualClass>> teacherVirtual = const AsyncValue.idle();
  final Map<String, Future<List<TeacherUnitCatalog>>> _teacherUnits = {};
  final Map<String, Future<List<TeacherUnitCatalog>>> _teacherAttUnits = {};
  final Map<int, Future<List<GradeType>>> _gradeTypes = {};
  final Map<String, AsyncValue<List<TeacherStudent>>> _teacherStudents = {};
  final Map<String, AsyncValue<AttendanceSheet>> _attendance = {};

  /// Cuándo llegó de la red el roster / la hoja de cada sección: el tablero
  /// no los vuelve a pedir antes de [FreshnessTtl.teacherRoster].
  final Map<String, DateTime> _rosterAt = {};
  final Map<String, DateTime> _attendanceAt = {};
  bool _resumenLoading = false;

  NexoTeacherRepository get _nexoTeacher => _nexo.teacher;

  void _clearTeacher() {
    teacherInfo = const AsyncValue.idle();
    teacherSubjects = const AsyncValue.idle();
    teacherSchedule = const AsyncValue.idle();
    teacherMarcacion = const AsyncValue.idle();
    teacherCumplimiento = const AsyncValue.idle();
    teacherVirtual = const AsyncValue.idle();
    _teacherUnits.clear();
    _teacherAttUnits.clear();
    _gradeTypes.clear();
    _attendance.clear();
    _teacherStudents.clear();
    _rosterAt.clear();
    _attendanceAt.clear();
  }

  bool _sectionFresh(Map<String, DateTime> loadedAt, String section) {
    final at = loadedAt[section];
    return at != null && clock().difference(at) < FreshnessTtl.teacherRoster;
  }

  AsyncValue<List<TeacherStudent>> alumnosDe(String cleAuto) =>
      _teacherStudents[cleAuto] ?? const AsyncValue.idle();

  /// Hoja de asistencia de la sección (estado compartido por las pestañas).
  AsyncValue<AttendanceSheet> asistenciaDe(String courseId) =>
      _attendance[courseId] ?? const AsyncValue.idle();

  /// Hojas de asistencia ya cargadas, por sección.
  Map<String, AttendanceSheet> get docenteHojas => {
    for (final e in _attendance.entries)
      if (e.value.value != null) e.key: e.value.value!,
  };

  /// Rosters (con notas y % de asistencia) ya cargados, por sección.
  Map<String, List<TeacherStudent>> get docenteRosters => {
    for (final e in _teacherStudents.entries)
      if (e.value.value != null) e.key: e.value.value!,
  };

  Future<TeacherInfo?> loadTeacherInfo() => _wrap<TeacherInfo>(
    () => _call(_nexoTeacher.me),
    () => teacherInfo,
    (v) => teacherInfo = v,
    cached: () => _cache.getDocenteInfo(),
    persist: (v) => _cache.saveDocenteInfo(v),
    operationName: 'loadTeacherInfo',
  );

  Future<List<TeacherSubject>?> loadTeacherSubjects() => _wrap(
    () => _fetch((r) => r.teacher.sections()),
    () => teacherSubjects,
    (v) => teacherSubjects = v,
    cached: () => _cache.getDocenteCursos(),
    persist: (v) => _cache.saveDocenteCursos(v),
    operationName: 'loadTeacherSubjects',
  );

  /// El horario sale de las mismas secciones: se reutiliza su carga (y su
  /// single-flight) en vez de volver a pedirlas.
  Future<List<ScheduleClass>?> loadDocenteHorario() => _wrap(
    () async {
      final subjects = await loadTeacherSubjects();
      // Sin asignaturas (ni en caché): el horario cae a su propio caché.
      if (subjects == null) {
        throw teacherSubjects.error ??
            const NetworkException('Sin asignaturas del docente.');
      }
      return teacherScheduleFromSubjects(subjects);
    },
    () => teacherSchedule,
    (v) => teacherSchedule = v,
    cached: () => _cache.getDocenteHorario(),
    persist: (v) => _cache.saveDocenteHorario(v),
    operationName: 'loadDocenteHorario',
  );

  /// Marcaciones de los últimos 30 días.
  Future<List<TeacherPunch>?> loadTeacherMarcacion() => _wrap(
    () {
      final now = DateTime.now();
      final inicio = now.subtract(const Duration(days: 30));
      return _fetch((r) => r.teacher.punches(inicio, now));
    },
    () => teacherMarcacion,
    (v) => teacherMarcacion = v,
    operationName: 'loadTeacherMarcacion',
  );

  /// Clases programadas de las últimas dos semanas con su estado de marcación
  /// (entrada/salida). La API ya recorre las páginas y quita repetidos.
  Future<List<TeacherClassCompliance>?> loadTeacherCumplimiento() => _wrap(
    () {
      final now = DateTime.now();
      final inicio = now.subtract(const Duration(days: 14));
      return _fetch((r) => r.teacher.compliance(inicio, now));
    },
    () => teacherCumplimiento,
    (v) => teacherCumplimiento = v,
    operationName: 'loadTeacherCumplimiento',
  );

  /// Clases del día para marcación virtual.
  Future<List<VirtualClass>?> loadTeacherVirtual() => _wrap(
    () => _fetch((r) => r.teacher.virtualClasses()),
    () => teacherVirtual,
    (v) => teacherVirtual = v,
    operationName: 'loadTeacherVirtual',
  );

  /// Marca entrada/salida virtual y recarga las clases del día.
  Future<SaveResult> marcarVirtual(String codigo) async {
    final res = await _save(() => _nexoTeacher.punch(codigo));
    await loadTeacherVirtual();
    return res;
  }

  /// Memoiza un catálogo por clave durante la sesión; si la carga falla se
  /// descarta para reintentar en la próxima llamada.
  Future<T> _memo<K, T>(
    Map<K, Future<T>> cache,
    K key,
    Future<T> Function() load,
  ) {
    final hit = cache[key];
    if (hit != null) return hit;
    final fut = _scope.run(() async {
      final r = await load();
      _scope.check();
      return r;
    });
    cache[key] = fut;
    fut.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(cache[key], fut)) cache.remove(key);
      },
    );
    return fut;
  }

  /// Unidades de notas desde la API; sus tipos de nota quedan memorizados.
  Future<List<TeacherUnitCatalog>> _nexoGradeUnits(String sectionId) async {
    final list = await _call(() => _nexoTeacher.gradeUnits(sectionId));
    for (final u in list) {
      _gradeTypes[u.unit.id] = Future.value(u.types);
    }
    return [for (final u in list) u.unit];
  }

  /// Unidades de la sección para registrar notas.
  Future<List<TeacherUnitCatalog>> docenteUnidades(TeacherSubject course) =>
      _memo(_teacherUnits, course.id, () => _nexoGradeUnits(course.id));

  /// Unidades de la sección para registrar asistencia.
  Future<List<TeacherUnitCatalog>> docenteUnidadesAsistencia(
    TeacherSubject course,
  ) => _memo(
    _teacherAttUnits,
    course.id,
    () async => (await _call(() => _nexoTeacher.attendance(course.id))).units,
  );

  /// Tipos de nota (EV/DE/PR…) de una unidad. Llegan con las unidades de
  /// la sección ([docenteUnidades]), que se cargan antes.
  Future<List<GradeType>> docenteTiposNota(int unidadId) =>
      _gradeTypes[unidadId] ??
      Future.error(
        const BadRequestException(
          'Vuelve a abrir la sección para cargar sus tipos de nota.',
          status: 409,
        ),
      );

  /// Carga (o recarga) la hoja de asistencia completa de la sección.
  Future<void> loadDocenteAsistencia(
    TeacherSubject course,
  ) => _scope.run(() async {
    _attendance[course.id] = AsyncValue.loading(_attendance[course.id]?.value);
    _notify();
    try {
      final r = (await _call(() => _nexoTeacher.attendance(course.id))).sheet;
      if (!_scope.isCurrent) return;
      _attendance[course.id] = AsyncValue.data(r);
      _attendanceAt[course.id] = clock();
    } catch (e) {
      if (!_scope.isCurrent) return;
      _attendance[course.id] = AsyncValue.failure(
        e,
        _attendance[course.id]?.value,
      );
    }
    _notify();
  });

  /// Hora oficial de la universidad (para la hora de la sesión de
  /// asistencia). Sin respuesta, la hora del dispositivo.
  Future<DateTime> docenteHoraServidor() => _scope.run(() async {
    try {
      return await _call(_nexoTeacher.serverTime);
    } on StaleSessionException {
      rethrow;
    } catch (_) {
      return DateTime.now();
    }
  });

  Future<SaveResult> _save(
    Future<String?> Function() op,
  ) => _scope.run(() async {
    try {
      final msg = await _call(op);
      if (!_scope.isCurrent) {
        return (error: const StaleSessionException().toString(), message: null);
      }
      return (error: null, message: msg);
    } catch (e) {
      if (!_scope.isCurrent) {
        return (error: const StaleSessionException().toString(), message: null);
      }
      return (error: humanizeError(e), message: null);
    }
  });

  /// Registra la asistencia de una sesión (todos los alumnos). La hora de la
  /// sesión la pone el reloj de la universidad.
  Future<SaveResult> registrarAsistencia(
    TeacherSubject course, {
    required DateTime fecha,
    required int unidadId,
    required List<({AttendanceStudent student, int state})> marks,
  }) async {
    final res = await _save(
      () => _nexoTeacher.takeAttendance(
        course.id,
        unidadId: unidadId,
        marks: marks,
      ),
    );
    await loadDocenteAsistencia(course);
    return res;
  }

  /// Corrige marcas de asistencia ya registradas.
  Future<SaveResult> actualizarAsistencia(
    TeacherSubject course,
    List<({AttendanceMark mark, AttendanceStudent student, int state})> changes,
  ) async {
    final res = await _save(
      () => _nexoTeacher.correctAttendance(course.id, changes),
    );
    await loadDocenteAsistencia(course);
    return res;
  }

  /// Guarda notas (el backend decide insertar o actualizar por alumno) y
  /// recarga el roster.
  Future<SaveResult> guardarNotas(
    TeacherSubject course,
    List<GradeWrite> rows,
  ) async {
    final res = await _save(() => _nexoTeacher.saveGrades(course.id, rows));
    // Aunque una parte falle, la otra pudo guardarse: siempre recargar.
    await loadDocenteAlumnos(course.id, tipoCalif: course.tipoCalif);
    return res;
  }

  /// Registro auxiliar de la sección en `pdf` o `xlsx`.
  Future<({Uint8List bytes, String filename})> docenteReporteAuxiliar(
    TeacherSubject course, {
    required String tipo,
  }) => _scope.run(() async {
    final r = await _call(() => _nexoTeacher.report(course, format: tipo));
    _scope.check();
    return r;
  });

  /// Roster de la sección con notas y % de asistencia. [tipoCalif] se
  /// conserva por compatibilidad: la API ya resuelve la escala.
  Future<void> loadDocenteAlumnos(
    String cleAuto, {
    int tipoCalif = 0,
  }) => _scope.run(() async {
    _teacherStudents[cleAuto] = AsyncValue.loading(
      _teacherStudents[cleAuto]?.value,
    );
    _notify();
    try {
      var fromNetwork = false;
      final v = await _errorHandler.withFallback<List<TeacherStudent>>(
        remote: () async {
          final roster = await _call(() => _nexoTeacher.roster(cleAuto));
          fromNetwork = true;
          return roster;
        },
        // Un roster vacío no sirve de caché: así se intenta la red aunque el
        // arranque crea que no hay internet.
        cached: () async {
          final c = await _cache.getDocenteAlumnos(cleAuto);
          return (c == null || c.isEmpty) ? null : c;
        },
        operationName: 'loadDocenteAlumnos($cleAuto)',
      );
      if (!_scope.isCurrent) return;
      _teacherStudents[cleAuto] = AsyncValue.data(v);
      if (fromNetwork) _rosterAt[cleAuto] = clock();
      if (v.isNotEmpty) await _cache.saveDocenteAlumnos(cleAuto, v);
    } catch (e) {
      if (!_scope.isCurrent) return;
      _teacherStudents[cleAuto] = AsyncValue.failure(
        e,
        _teacherStudents[cleAuto]?.value,
      );
    }
    _notify();
  });

  /// Hay secciones del resumen docente cargándose.
  bool get docenteResumenLoading => _resumenLoading;

  /// Roster y hoja de asistencia de todas las secciones, para el tablero
  /// (agenda, clases sin asistencia y alumnos en riesgo). De a dos secciones a
  /// la vez para no saturar la API. Al abrir el tablero solo se pide lo que
  /// falta o lo descargado hace más de [FreshnessTtl.teacherRoster];
  /// [force] (pull-to-refresh) recarga todo.
  Future<void> loadDocenteResumen({bool force = false}) async {
    if (_resumenLoading) return;
    final courses = teacherSubjects.value ?? await loadTeacherSubjects();
    if (courses == null || courses.isEmpty) return;
    _resumenLoading = true;
    _notify();
    try {
      final queue = [...courses];
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final c = queue.removeAt(0);
          await Future.wait([
            if (force ||
                !alumnosDe(c.id).hasValue ||
                !_sectionFresh(_rosterAt, c.id))
              loadDocenteAlumnos(c.id, tipoCalif: c.tipoCalif),
            if (force ||
                !asistenciaDe(c.id).hasValue ||
                !_sectionFresh(_attendanceAt, c.id))
              loadDocenteAsistencia(c),
          ]);
        }
      }

      await Future.wait([worker(), worker()]);
    } finally {
      _resumenLoading = false;
      _notify();
    }
  }
}
