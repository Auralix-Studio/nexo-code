import 'dart:async';
import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:nexo/core/data/resolver.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/docente_repository.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/data/teams_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Estado tipado de una porción de datos cargados desde el API.
class AsyncValue<T> {
  final T? value;
  final bool loading;
  final Object? error;

  const AsyncValue.idle()
      : value = null,
        loading = false,
        error = null;
  const AsyncValue.loading([T? prev])
      : value = prev,
        loading = true,
        error = null;
  const AsyncValue.data(T data)
      : value = data,
        loading = false,
        error = null;
  const AsyncValue.failure(Object e, [T? prev])
      : value = prev,
        loading = false,
        error = e;

  bool get hasValue => value != null;
}

/// Store reactivo central — cachea datos cargados y los expone vía
/// [ChangeNotifier], evitando recargas innecesarias entre pantallas.
class AppStore extends ChangeNotifier {
  AppStore(
    this._repo, {
    required CacheManager cache,
    required ErrorHandler errorHandler,
    IntranetRepository? intranet,
    TeamsRepository? teams,
    DocenteRepository? docente,
  })  : _cache = cache,
        _errorHandler = errorHandler,
        _intranet = intranet,
        _teams = teams,
        _docente = docente;

  // ─── Fábricas de DataSource — un sitio para toda la ceremonia ───

  DataSource<T> _sigma<T>(SourceId id, Future<T> Function() fn) =>
      DataSource(id: id, fetch: fn);

  List<DataSource<T>> _intra<T>(Future<T> Function(IntranetRepository) fn) {
    final r = _intranet;
    if (r == null) return const [];
    return [
      DataSource(
        id: 'intranet',
        available: () async {
          final s = AppStorage.instance;
          return s.credUser != null && s.credPass != null;
        },
        fetch: () async {
          final s = AppStorage.instance;
          final ok = await r.ensureSession(s.credUser!, s.credPass!);
          if (!ok) throw const NetworkException('Sesión Intranet falló.');
          return fn(r);
        },
      ),
    ];
  }

  static bool _emptyList(List l) => l.isEmpty;

  // ─── Resolvers persistentes (recursos sin parámetros) ───

  // ─── Estrategia híbrida: Intranet es PRINCIPAL, SIGMA es respaldo ───
  // SIGMA está caído (Core_ERP DB inaccesible). Intranet PHP tiene toda
  // la data académica/financiera. SIGMA queda como segunda opción para
  // cuando vuelva. `mergeWith` rellena campos faltantes en el primary
  // con los del secondary.

  late final Resolver<Student> _studentRes = Resolver(
    sources: [
      ..._intra((r) async {
        final p = periodoActivo;
        final now = DateTime.now();
        final s = await r.infoEstudiante(
          anio: p?.year ?? now.year,
          periodo: p?.number ?? (now.month <= 7 ? 1 : 2),
        );
        if (s == null) throw const NetworkException('Intranet sin perfil.');
        return s;
      }),
      _sigma('sigma', _repo.infoEstudiante),
    ],
    merge: MergeStrategies.fold<Student>((a, b) => a.mergeWith(b)),
    isEmpty: (s) => s.id.isEmpty && s.fullName.isEmpty,
  );

  // SIGMA's Core_ERP DB is down → todos los endpoints de pagos en SIGMA
  // devuelven [] o fallan. Pagos viene 100% de Intranet PHP. Concat para
  // mergear cronograma + pensiones adicionales en una sola lista.
  // PENDIENTES = `consultarPensiones` (cuotas futuras desdobladas).
  late final Resolver<List<Payment>> _cuotasRes = Resolver(
    sources: [..._intra((r) => r.pensionesPendientes())],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );

  // VENCIDAS = solo cuotas/matrícula que TIENEN fecha de vencimiento.
  // Las tasas (seguro, etc.) no tienen fecha y van solo al tab Tasas.
  late final Resolver<List<Payment>> _vencidasRes = Resolver(
    sources: [
      ..._intra((r) async {
        final results = await Future.wait([
          r.pensionesVencidas(),
          r.matriculaVencida(),
        ]);
        return results.expand((e) => e).toList();
      }),
    ],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );

  late final Resolver<List<PaymentRecord>> _historicoRes = Resolver(
    sources: [..._intra((r) => r.historicoPagos())],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );

  late final Resolver<List<Fee>> _tasasRes = Resolver(
    sources: [..._intra((r) => r.tasasIntranet())],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );

  late final Resolver<List<Term>> _periodosRes = Resolver(
    sources: [
      ..._intra((r) => r.periodosMatriculados()),
      _sigma('sigma', _repo.periodosEstudiante),
    ],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );

  late final Resolver<List<ScheduleClass>> _horarioRes = Resolver(
    sources: [
      ..._intra((r) {
        final p = periodoActivo;
        final now = DateTime.now();
        return r.horarioMatriculados(
          p?.year ?? now.year,
          p?.number ?? (now.month <= 7 ? 1 : 2),
        );
      }),
      _sigma('sigma', () => _repo.horario()),
    ],
    merge: MergeStrategies.firstWins,
    isEmpty: _emptyList,
  );
  final SigmaRepository _repo;
  final CacheManager _cache;
  final ErrorHandler _errorHandler;
  final IntranetRepository? _intranet;
  final TeamsRepository? _teams;
  final DocenteRepository? _docente;

  /// Llamado cuando se detecta una nota nueva o cambiada (curso, nota).
  void Function(String curso, String nota)? onGradeChange;

  /// Compara las notas actuales con el snapshot guardado; notifica cambios
  /// y actualiza el snapshot. No notifica en la primera carga (sin snapshot).
  void _checkGrades(Iterable<(String, String)> items) {
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
    for (final (curso, nota) in entries) {
      final before = prev[curso] as String?;
      next[curso] = nota;
      if (!firstTime && before != nota && onGradeChange != null) {
        onGradeChange!(curso, nota);
      }
    }
    s.setGradeSnapshot(jsonEncode(next));
  }

  AsyncValue<Student> profile = const AsyncValue.idle();
  AsyncValue<List<Term>> periodos = const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> horario = const AsyncValue.idle();
  AsyncValue<NotasResumen> resumen = const AsyncValue.idle();
  AsyncValue<List<TermAverage>> promedios = const AsyncValue.idle();

  /// Record académico completo (fuente Intranet — SIGMA lo deja vacío).
  AsyncValue<List<RecordCurso>> record = const AsyncValue.idle();

  AsyncValue<List<Payment>> cuotasPendientes = const AsyncValue.idle();
  AsyncValue<List<Payment>> cuotasIntranet = const AsyncValue.idle();
  AsyncValue<List<Fee>> tasas = const AsyncValue.idle();
  AsyncValue<List<PaymentRecord>> historico = const AsyncValue.idle();

  /// Microsoft Teams (Graph Education) — independiente de SIGMA/Intranet.
  AsyncValue<List<TeamsClass>> teamsClasses = const AsyncValue.idle();
  AsyncValue<List<TeamsAssignment>> teamsAssignments = const AsyncValue.idle();

  /// Documentos descargables (Intranet) — generados como PDF en cliente.
  AsyncValue<ConstanciaMatricula> constancia = const AsyncValue.idle();
  AsyncValue<CronogramaPagos> cronograma = const AsyncValue.idle();

  /// Recursos institucionales (SIGMA).
  AsyncValue<List<Publicacion>> publicaciones = const AsyncValue.idle();
  AsyncValue<WifiCredencial> wifi = const AsyncValue.idle();
  AsyncValue<ConteoNotas> conteoNotas = const AsyncValue.idle();

  /// Lado docente — solo se carga si el usuario es docente.
  AsyncValue<DocenteInfo> docenteInfo = const AsyncValue.idle();
  AsyncValue<List<DocenteAsignatura>> docenteAsignaturas =
      const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> docenteHorario = const AsyncValue.idle();
  final Map<String, AsyncValue<List<DocenteAlumno>>> _docenteAlumnos = {};

  AsyncValue<List<DocenteAlumno>> alumnosDe(String cleAuto) =>
      _docenteAlumnos[cleAuto] ?? const AsyncValue.idle();

  /// Notas por periodo: clave = "anio-periodoNum".
  final Map<String, AsyncValue<List<NotaAsignatura>>> _notasByPeriodo = {};

  AsyncValue<List<NotaAsignatura>> notasOf(int anio, int periodo) =>
      _notasByPeriodo['$anio-$periodo'] ?? const AsyncValue.idle();

  /// Periodo activo (matriculado) si está disponible.
  Term? get periodoActivo {
    final list = periodos.value;
    if (list == null) return null;
    try {
      return list.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Promedio académico significativo:
  ///   - El último periodo completado con promedio > 0 (excluye el activo en curso).
  ///   - Si no hay datos, null.
  double? get promedioAcumulado {
    final list = promedios.value;
    if (list == null || list.isEmpty) return null;
    final activo = periodoActivo;
    final completados = list.where((p) {
      if (p.average == 0) return false;
      if (activo != null && p.year == activo.year && p.number == activo.number) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byYear = a.year.compareTo(b.year);
        return byYear != 0 ? byYear : a.number.compareTo(b.number);
      });
    if (completados.isEmpty) return null;
    final sum = completados.fold<double>(0, (a, b) => a + b.average);
    return sum / completados.length;
  }

  /// Créditos aprobados del estudiante (preferir perfil sobre resumen).
  int? get creditosAprobados {
    final p = profile.value?.creditsApproved;
    final r = resumen.value?.creditosAprobados;
    if (p != null && p > 0) return p;
    if (r != null && r > 0) return r;
    return p ?? r;
  }

  /// Créditos totales de la carrera.
  int? get creditosTotales => resumen.value?.creditosTotales;

  /// Notifica de forma segura: si estamos en plena fase de build/layout
  /// (p.ej. llamado desde initState), difiere al siguiente frame para no
  /// disparar `setState() called during build`.
  void _notify() {
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) notifyListeners();
      });
    } else {
      notifyListeners();
    }
  }

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<T?> _wrap<T>(
    Future<T> Function() remote,
    AsyncValue<T> Function() get,
    void Function(AsyncValue<T>) set, {
    Future<T?> Function()? cached,
    void Function(T value)? persist,
    required String operationName,
  }) async {
    set(AsyncValue.loading(get().value));
    _notify();
    try {
      final v = await _errorHandler.withFallback<T>(
        remote: remote,
        cached: cached ?? () => Future.value(null),
        operationName: operationName,
      );
      set(AsyncValue.data(v));
      _notify();
      persist?.call(v);
      return v;
    } catch (e) {
      set(AsyncValue.failure(e, get().value));
      _notify();
      return null;
    }
  }

  // === Caché persistente ===
  static const _ckProfile = 'profile';
  static const _ckPeriodos = 'periodos';
  static const _ckHorario = 'horario';
  static const _ckResumen = 'resumen';
  static const _ckPromedios = 'promedios';
  static const _ckCuotasPend = 'cuotasPend';

  void _setStorageCache(String key, Object data) =>
      AppStorage.instance.setCache(key, data);

  /// Rellena el estado con datos cacheados para mostrar algo al instante
  /// (incluso sin red o si la sesión se renueva). Se refresca en segundo plano.
  /// Async porque algunos caches viven en sqlite (sqflite), no shared_prefs.
  Future<void> hydrateFromCache() async {
    final s = AppStorage.instance;

    // Profile vive en sqlite (cache_manager.unified_student) — lo leemos
    // primero para pintar el header del home de inmediato.
    try {
      final cached = await _cache.getStudent();
      if (cached != null) {
        profile = AsyncValue.data(cached);
        _notify();
      }
    } catch (_) {}

    final p = s.getCache(_ckProfile);
    if (p is Map && profile.value == null) {
      profile = AsyncValue.data(Student.fromJson(p.cast<String, dynamic>()));
    }
    final per = s.getCache(_ckPeriodos);
    if (per is List) {
      periodos = AsyncValue.data(per
          .map((e) =>
              Term.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    final h = s.getCache(_ckHorario);
    if (h is List) {
      horario = AsyncValue.data(h
          .map((e) =>
              ScheduleClass.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    final r = s.getCache(_ckResumen);
    if (r is Map) {
      resumen =
          AsyncValue.data(NotasResumen.fromJson(r.cast<String, dynamic>()));
    }
    final pr = s.getCache(_ckPromedios);
    if (pr is List) {
      promedios = AsyncValue.data(pr
          .map((e) =>
              TermAverage.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    final cp = s.getCache(_ckCuotasPend);
    if (cp is List) {
      cuotasPendientes = AsyncValue.data(cp
          .map((e) => Payment.fromSigmaJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    if (profile.hasValue ||
        horario.hasValue ||
        cuotasPendientes.hasValue) {
      _notify();
    }
  }

  // === Loaders ===

  Future<void> loadHomeEssentials() async {
    await Future.wait([
      loadProfile(),
      loadHorarioActual(),
      loadCuotasPendientes(),
      loadPeriodos(),
      loadPromedios(),
    ]);
    final p = profile.value;
    if (p != null && p.studyPlan.isNotEmpty && p.level.isNotEmpty) {
      await loadResumen(p.studyPlan, p.level);
    }
    // Refresca la boleta del periodo activo en segundo plano para detectar
    // notas nuevas y disparar la notificación correspondiente. Sin esto,
    // las notas solo se chequean al entrar manualmente a la pestaña Notas.
    unawaited(checkActiveBoleta());
  }

  /// Refresca la boleta del periodo activo si hay credenciales de Intranet.
  /// Es seguro llamarla desde el ciclo de vida (resumed); el [_wrap] interno
  /// de los loaders absorbe errores sin romper el flujo de UI.
  Future<void> checkActiveBoleta() async {
    final activo = periodoActivo;
    if (activo == null) return;
    if (esModeloNuevo(activo.year, activo.number)) {
      await loadBoleta(activo.year, activo.number);
    } else {
      await loadBoletaLegacy(activo.year, activo.number);
    }
  }

  Future<Student?> loadProfile() => _wrap(
        // Profile + periodos en paralelo. Si periodos aún no está, el source
        // de Intranet usa fallback (year+month-based). En el segundo render
        // (cuando periodos termine) el merge usa el periodoActivo correcto.
        () => _studentRes.load(),
        () => profile,
        (v) => profile = v,
        cached: _cache.getStudent,
        persist: _cache.saveStudent,
        operationName: 'loadProfile',
      );

  Future<List<Term>?> loadPeriodos() => _wrap(
        () => _resolveOrEmpty(_periodosRes),
        () => periodos,
        (v) => periodos = v,
        cached: () => _cache.getPeriodos(),
        persist: (v) => _cache.savePeriodos(v),
        operationName: 'loadPeriodos',
      );

  Future<List<ScheduleClass>?> loadHorarioActual() => _wrap(
        () => _resolveOrEmpty(_horarioRes),
        () => horario,
        (v) => horario = v,
        cached: () => _cache.getHorario(),
        persist: (v) => _cache.saveHorario(v),
        operationName: 'loadHorarioActual',
      );

  Future<NotasResumen?> loadResumen(String pesId, String nivel) => _wrap(
        () => _repo.notasResumen(pesId, nivel).then((v) =>
            v ??
            const NotasResumen(
              promedio: 0,
              creditosAprobados: 0,
              creditosTotales: 0,
              cantMatricula: 0,
            )),
        () => resumen,
        (v) => resumen = v,
        cached: () async {
          final raw = AppStorage.instance.getCache(_ckResumen);
          if (raw is Map) return NotasResumen.fromJson(raw.cast<String, dynamic>());
          return null;
        },
        persist: (v) => _setStorageCache(_ckResumen, v.toJson()),
        operationName: 'loadResumen',
      );

  Future<List<TermAverage>?> loadPromedios() => _wrap(
        _repo.promediosResumen,
        () => promedios,
        (v) => promedios = v,
        cached: () => _cache.getPromedios(),
        persist: (v) => _cache.savePromedios(v),
        operationName: 'loadPromedios',
      );

  // ===== Boleta de notas (Intranet, modelo nuevo) =====

  final Map<String, AsyncValue<List<BoletaCurso>>> _boleta = {};
  final Map<String, AsyncValue<CursoDetalleNotas>> _detalle = {};
  final Map<String, AsyncValue<List<NotaAsignatura>>> _boletaLegacy = {};

  AsyncValue<List<BoletaCurso>> boletaOf(int anio, int periodo) =>
      _boleta['$anio-$periodo'] ?? const AsyncValue.idle();

  AsyncValue<List<NotaAsignatura>> boletaLegacyOf(int anio, int periodo) =>
      _boletaLegacy['$anio-$periodo'] ?? const AsyncValue.idle();

  Future<void> loadBoletaLegacy(int anio, int periodo) async {
    final key = '$anio-$periodo';
    _boletaLegacy[key] = AsyncValue.loading(_boletaLegacy[key]?.value);
    _notify();
    try {
      final data = await _errorHandler.withFallback<List<NotaAsignatura>>(
        remote: () => Resolver<List<NotaAsignatura>>(
          sources: [
            ..._intra((r) => r.boletaLegacy(anio, periodo)),
            _sigma('sigma', () => _repo.notasPeriodo(anio, periodo)),
          ],
          merge: MergeStrategies.firstWins,
          isEmpty: _emptyList,
        ).load(),
        cached: () => _cache.getBoletaLegacy(anio.toString(), periodo.toString()),
        operationName: 'loadBoletaLegacy($anio, $periodo)',
      );
      _boletaLegacy[key] = AsyncValue.data(data);
      _checkGrades(data.map((n) => (n.asignatura, n.notaActualText)));
      await _cache.saveBoletaLegacy(anio.toString(), periodo.toString(), data);
    } catch (e) {
      _boletaLegacy[key] = AsyncValue.failure(e, _boletaLegacy[key]?.value);
    }
    _notify();
  }

  AsyncValue<CursoDetalleNotas> detalleOf(String id) =>
      _detalle[id] ?? const AsyncValue.idle();

  Future<void> loadBoleta(int anio, int periodo) async {
    final key = '$anio-$periodo';
    _boleta[key] = AsyncValue.loading(_boleta[key]?.value);
    _notify();
    try {
      final data = await _errorHandler.withFallback<List<BoletaCurso>>(
        remote: () => Resolver<List<BoletaCurso>>(
          sources: _intra((r) => r.boleta(anio, periodo)),
          merge: MergeStrategies.firstWins,
          isEmpty: _emptyList,
        ).load(),
        cached: () => _cache.getBoleta(anio.toString(), periodo.toString()),
        operationName: 'loadBoleta($anio, $periodo)',
      );
      _boleta[key] = AsyncValue.data(data);
      _checkGrades(data.map((c) => (c.nombre, c.promedioText)));
      await _cache.saveBoleta(anio.toString(), periodo.toString(), data);
    } catch (e) {
      _boleta[key] = AsyncValue.failure(e, _boleta[key]?.value);
    }
    _notify();
  }

  Future<void> loadDetalle(
    int anio,
    int periodo,
    String matriculaAsignaturaId,
  ) async {
    final id = matriculaAsignaturaId;
    if (_detalle[id]?.loading == true) return;
    _detalle[id] = AsyncValue.loading(_detalle[id]?.value);
    _notify();
    try {
      final data = await Resolver<CursoDetalleNotas>(
        sources: _intra((r) => r.detalleCurso(anio, periodo, id)),
        merge: MergeStrategies.firstWins,
      ).load();
      _detalle[id] = AsyncValue.data(data);
    } catch (e) {
      _detalle[id] = AsyncValue.failure(e, _detalle[id]?.value);
    }
    _notify();
  }

  Future<List<RecordCurso>?> loadRecord() => _wrap<List<RecordCurso>>(
        () {
          final codest = profile.value?.id.isNotEmpty == true
              ? profile.value!.id
              : AppStorage.instance.credUser ?? '';
          return Resolver<List<RecordCurso>>(
            sources: _intra((r) => r.recordAcademico(codest)),
            merge: MergeStrategies.firstWins,
            isEmpty: _emptyList,
          ).load();
        },
        () => record,
        (v) => record = v,
        operationName: 'loadRecord',
      );

  Future<List<T>> _resolveOrEmpty<T>(Resolver<List<T>> r) async {
    try {
      return await r.load();
    } on NoDataAvailableException {
      return const [];
    }
  }

  Future<List<Payment>?> loadCuotasPendientes() => _wrap(
        () => _resolveOrEmpty(_cuotasRes),
        () => cuotasPendientes,
        (v) => cuotasPendientes = v,
        cached: () => _cache.getPagos(),
        persist: (v) => _cache.savePagos(v),
        operationName: 'loadCuotasPendientes',
      );

  Future<List<Payment>?> loadCuotasIntranet() => _wrap(
        () => _resolveOrEmpty(_vencidasRes),
        () => cuotasIntranet,
        (v) => cuotasIntranet = v,
        operationName: 'loadCuotasIntranet',
      );

  Future<List<Fee>?> loadTasas() => _wrap(
        () => _resolveOrEmpty(_tasasRes),
        () => tasas,
        (v) => tasas = v,
        operationName: 'loadTasas',
      );

  Future<List<PaymentRecord>?> loadHistorico() => _wrap(
        () => _resolveOrEmpty(_historicoRes),
        () => historico,
        (v) => historico = v,
        operationName: 'loadHistorico',
      );

  // ===== Microsoft Teams (Graph Education) =====

  TeamsRepository _teamsReady() {
    final teams = _teams;
    if (teams == null) {
      throw Exception('La integración con Teams no está disponible.');
    }
    return teams;
  }

  /// Carga clases y tareas del alumno en paralelo (POC de validación).
  Future<void> loadTeams() async {
    await Future.wait([loadTeamsClasses(), loadTeamsAssignments()]);
  }

  Future<List<TeamsClass>?> loadTeamsClasses() => _wrap(
        () => _teamsReady().classes(),
        () => teamsClasses,
        (v) => teamsClasses = v,
        operationName: 'loadTeamsClasses',
      );

  Future<List<TeamsAssignment>?> loadTeamsAssignments() => _wrap(
        () => _teamsReady().assignments(),
        () => teamsAssignments,
        (v) => teamsAssignments = v,
        operationName: 'loadTeamsAssignments',
      );

  /// Limpia solo el estado de Teams (al cerrar la sesión Microsoft).
  void clearTeams() {
    teamsClasses = const AsyncValue.idle();
    teamsAssignments = const AsyncValue.idle();
    _notify();
  }

  // ===== Documentos descargables (Intranet) =====

  Future<ConstanciaMatricula?> loadConstancia({int? anio, int? periodo}) {
    final p = periodoActivo;
    final a = anio ?? p?.year ?? 0;
    final per = periodo ?? p?.number ?? 0;
    return _wrap(
      () => Resolver<ConstanciaMatricula>(
        sources: _intra((r) => r.constanciaMatricula(a, per)),
        merge: MergeStrategies.firstWins,
      ).load(),
      () => constancia,
      (v) => constancia = v,
      operationName: 'loadConstancia',
    );
  }

  Future<CronogramaPagos?> loadCronograma() => _wrap(
        () => Resolver<CronogramaPagos>(
          sources: _intra((r) => r.cronogramaPagos()),
          merge: MergeStrategies.firstWins,
        ).load(),
        () => cronograma,
        (v) => cronograma = v,
        operationName: 'loadCronograma',
      );

  // ===== Recursos institucionales =====

  Future<List<Publicacion>?> loadPublicaciones() => _wrap(
        _repo.publicaciones,
        () => publicaciones,
        (v) => publicaciones = v,
        operationName: 'loadPublicaciones',
      );

  Future<WifiCredencial?> loadWifi() => _wrap<WifiCredencial>(
        () async {
          final w = await _repo.wifiCredencial();
          return w ?? const WifiCredencial(usuario: '', contrasena: '');
        },
        () => wifi,
        (v) => wifi = v,
        operationName: 'loadWifi',
      );

  Future<ConteoNotas?> loadConteoNotas() async {
    final p = periodoActivo;
    if (p == null) return null;
    return _wrap<ConteoNotas>(
      () async {
        final c = await _repo.conteoNotas(p.year, p.number);
        return c ??
            const ConteoNotas(
                aprobados: 0, desaprobados: 0, pendientes: 0, total: 0);
      },
      () => conteoNotas,
      (v) => conteoNotas = v,
      operationName: 'loadConteoNotas',
    );
  }

  // ===== Docente =====

  DocenteRepository _docenteReady() {
    final d = _docente;
    if (d == null) {
      throw Exception('Módulo docente no disponible.');
    }
    return d;
  }

  Future<DocenteInfo?> loadDocenteInfo() => _wrap<DocenteInfo>(
        () async {
          final v = await _docenteReady().infoDocente();
          return v ?? const DocenteInfo(codigo: '', nombres: '', apellidos: '');
        },
        () => docenteInfo,
        (v) => docenteInfo = v,
        cached: () => _cache.getDocenteInfo(),
        persist: (v) => _cache.saveDocenteInfo(v),
        operationName: 'loadDocenteInfo',
      );

  Future<List<DocenteAsignatura>?> loadDocenteAsignaturas() => _wrap(
        () => _docenteReady().asignaturas(),
        () => docenteAsignaturas,
        (v) => docenteAsignaturas = v,
        cached: () => _cache.getDocenteCursos(),
        persist: (v) => _cache.saveDocenteCursos(v),
        operationName: 'loadDocenteAsignaturas',
      );

  Future<List<ScheduleClass>?> loadDocenteHorario() => _wrap(
        () => _docenteReady().getHorario(),
        () => docenteHorario,
        (v) => docenteHorario = v,
        cached: () => _cache.getDocenteHorario(),
        persist: (v) => _cache.saveDocenteHorario(v),
        operationName: 'loadDocenteHorario',
      );

  Future<void> loadDocenteAlumnos(String cleAuto) async {
    _docenteAlumnos[cleAuto] =
        AsyncValue.loading(_docenteAlumnos[cleAuto]?.value);
    _notify();
    try {
      final v = await _errorHandler.withFallback<List<DocenteAlumno>>(
        remote: () => _docenteReady().estudiantesSeccion(cleAuto),
        cached: () => _cache.getDocenteAlumnos(cleAuto),
        operationName: 'loadDocenteAlumnos($cleAuto)',
      );
      _docenteAlumnos[cleAuto] = AsyncValue.data(v);
      await _cache.saveDocenteAlumnos(cleAuto, v);
    } catch (e) {
      _docenteAlumnos[cleAuto] =
          AsyncValue.failure(e, _docenteAlumnos[cleAuto]?.value);
    }
    _notify();
  }

  /// Edita la nota promedio de un alumno y refresca.
  /// Retorna `null` si todo bien, o el error como string.
  Future<String?> updateDocenteNota({
    required String cleAuto,
    required String codigoAlumno,
    required String nota,
  }) async {
    try {
      await _docenteReady().updateNota(
        cleAuto: cleAuto,
        codigoAlumno: codigoAlumno,
        nota: nota,
      );
      await loadDocenteAlumnos(cleAuto);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Trae notas detalladas por evaluación de un alumno.
  Future<List<NotaEvaluacion>> docenteNotasDetalle({
    required String cleAuto,
    required String codigoAlumno,
  }) =>
      _docenteReady()
          .notasDetalle(cleAuto: cleAuto, codigoAlumno: codigoAlumno);

  /// Actualiza una evaluación específica del alumno y refresca.
  Future<String?> updateDocenteEvaluacion({
    required String cleAuto,
    required String codigoAlumno,
    required String codigoEvaluacion,
    required String nota,
  }) async {
    try {
      await _docenteReady().updateEvaluacion(
        cleAuto: cleAuto,
        codigoAlumno: codigoAlumno,
        codigoEvaluacion: codigoEvaluacion,
        nota: nota,
      );
      await loadDocenteAlumnos(cleAuto);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<List<AsistenciaDia>> docenteAsistenciaAlumno({
    required String cleAuto,
    required String codigoAlumno,
  }) =>
      _docenteReady()
          .asistenciaAlumno(cleAuto: cleAuto, codigoAlumno: codigoAlumno);

  Future<Map<String, String>> docenteAsistenciaDia({
    required String cleAuto,
    required DateTime fecha,
  }) =>
      _docenteReady().asistenciaDelDia(cleAuto: cleAuto, fecha: fecha);

  Future<String?> guardarAsistenciaDia({
    required String cleAuto,
    required DateTime fecha,
    required Map<String, String> estados,
  }) async {
    try {
      await _docenteReady().guardarAsistenciaDelDia(
        cleAuto: cleAuto,
        fecha: fecha,
        estados: estados,
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Conveniente: ¿este AppStore puede operar el módulo docente?
  bool get tieneDocente => _docente != null;

  /// Cambia la contraseña del usuario autenticado vía SIGMA.
  Future<void> changePassword(String actual, String nueva) =>
      _repo.changePassword(actual, nueva);

  Future<List<NotaAsignatura>?> loadNotas(int anio, int periodo) async {
    final key = '$anio-$periodo';
    final prev = _notasByPeriodo[key]?.value;
    _notasByPeriodo[key] = AsyncValue.loading(prev);
    _notify();
    try {
      final v = await _errorHandler.withFallback<List<NotaAsignatura>>(
        remote: () => Resolver<List<NotaAsignatura>>(
          sources: [
            _sigma('sigma', () => _repo.notasPeriodo(anio, periodo)),
            ..._intra((r) => r.boletaLegacy(anio, periodo)),
          ],
          merge: MergeStrategies.firstWins,
          isEmpty: _emptyList,
        ).load(),
        cached: () => _cache.getBoletaLegacy(anio.toString(), periodo.toString()),
        operationName: 'loadNotas($anio, $periodo)',
      );
      _notasByPeriodo[key] = AsyncValue.data(v);
      _notify();
      await _cache.saveBoletaLegacy(anio.toString(), periodo.toString(), v);
      return v;
    } catch (e) {
      _notasByPeriodo[key] = AsyncValue.failure(e, prev);
      _notify();
      return null;
    }
  }

  void clear() {
    unawaited(_cache.clearAll());
    profile = const AsyncValue.idle();
    periodos = const AsyncValue.idle();
    horario = const AsyncValue.idle();
    resumen = const AsyncValue.idle();
    promedios = const AsyncValue.idle();
    cuotasPendientes = const AsyncValue.idle();
    cuotasIntranet = const AsyncValue.idle();
    tasas = const AsyncValue.idle();
    historico = const AsyncValue.idle();
    _notasByPeriodo.clear();
    _boleta.clear();
    _boletaLegacy.clear();
    _detalle.clear();
    record = const AsyncValue.idle();
    teamsClasses = const AsyncValue.idle();
    teamsAssignments = const AsyncValue.idle();
    constancia = const AsyncValue.idle();
    cronograma = const AsyncValue.idle();
    publicaciones = const AsyncValue.idle();
    wifi = const AsyncValue.idle();
    conteoNotas = const AsyncValue.idle();
    docenteInfo = const AsyncValue.idle();
    docenteAsignaturas = const AsyncValue.idle();
    docenteHorario = const AsyncValue.idle();
    _docenteAlumnos.clear();
    _intranet?.invalidate();
    _notify();
  }
}
