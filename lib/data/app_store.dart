import 'dart:async';
import 'package:nexo/core/session_scope.dart';
import 'dart:convert';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:nexo/core/data/resolver.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/cache_manager.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/idiomas_repository.dart';
import 'package:nexo/domain/idiomas_models.dart';
import 'package:nexo/domain/grade_calculator.dart';
import 'package:nexo/domain/course_status.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/domain/dashboard_widget_config.dart';
import 'package:nexo/domain/data_freshness.dart';

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

class AppStore extends ChangeNotifier {
  AppStore(
    this._repo, {
    required CacheManager cache,
    required ErrorHandler errorHandler,
    required ConnectivityService connectivity,
    IntranetRepository? intranet,
    TeacherRepository? teacher,
    IdiomasRepository? idiomas,
    SessionScope? scope,
  }) : _scope = scope ?? SessionScope(),
       _cache = cache,
       _errorHandler = errorHandler,
       _connectivity = connectivity,
       _intranet = intranet,
       _teacher = teacher,
       _idiomas = idiomas {
    // El layout del dashboard debe cargarse SIEMPRE (no solo al hidratar):
    // tras un login fresco `hydrateFromCache` no corre y el Home quedaba con
    // spans por defecto rotos (tarjetas aplastadas en móvil).
    _loadDashboardLayout();
  }
  final SessionScope _scope;
  final _inFlight = <String, Future<Object?>>{};
  final _freshness = <String, DataFreshness>{};
  DataFreshness? freshnessOf(String operation) => _freshness[operation];

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

  DataSource<T> _sigma<T>(SourceId id, Future<T> Function() fn) => DataSource(
    id: id,
    fetch: () {
      _scope.check();
      return fn();
    },
  );
  List<DataSource<T>> _intra<T>(Future<T> Function(IntranetRepository) fn) {
    final r = _intranet;
    if (r == null) return const [];
    return [
      DataSource(
        id: 'intranet',
        available: () async {
          _scope.check();
          final s = AppStorage.instance;
          return s.credUser != null && s.credPass != null;
        },
        fetch: () async {
          _scope.check();
          final s = AppStorage.instance;
          final ok = await r.ensureSession(s.credUser!, s.credPass!);
          _scope.check();
          if (!ok) throw const NetworkException('Sesión Intranet falló.');
          return fn(r);
        },
      ),
    ];
  }

  static bool _emptyList(List l) => l.isEmpty;
  late final Resolver<Student> _studentRes = Resolver(
    sources: [
      ..._intra((r) async {
        final p = periodoActivo;
        final now = DateTime.now();
        final s = await r.infoEstudiante(
          year: p?.year ?? now.year,
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
  late final Resolver<List<Payment>> _cuotasRes = Resolver(
    sources: [..._intra((r) => r.pensionesPendientes())],
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
    isEmpty: _emptyList,
  );
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
    stopAfterFirst: true,
    isEmpty: _emptyList,
  );
  late final Resolver<List<PaymentRecord>> _historicoRes = Resolver(
    sources: [..._intra((r) => r.historicoPagos())],
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
    isEmpty: _emptyList,
  );
  late final Resolver<List<Fee>> _tasasRes = Resolver(
    sources: [..._intra((r) => r.tasasIntranet())],
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
    isEmpty: _emptyList,
  );
  late final Resolver<List<Term>> _periodosRes = Resolver(
    sources: [
      ..._intra((r) => r.periodosMatriculados()),
      _sigma('sigma', _repo.periodosEstudiante),
    ],
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
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
      _sigma('sigma', () => _repo.schedule()),
    ],
    merge: MergeStrategies.firstWins,
    stopAfterFirst: true,
    isEmpty: _emptyList,
  );
  final SigmaRepository _repo;
  final CacheManager _cache;
  final ErrorHandler _errorHandler;
  final ConnectivityService _connectivity;
  final IntranetRepository? _intranet;
  final TeacherRepository? _teacher;
  final IdiomasRepository? _idiomas;
  void Function(String course, String grade)? onGradeChange;

  /// Operaciones que resolvieron vía caché mientras el primer chequeo de
  /// conectividad aún no había terminado. `retryFailedEssentials` las
  /// reintenta cuando vuelve la conexión.
  final Set<String> _startupCacheOps = {};
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
    for (final (course, grade) in entries) {
      final before = prev[course] as String?;
      next[course] = grade;
      if (!firstTime && before != grade && onGradeChange != null) {
        onGradeChange!(course, grade);
      }
    }
    s.setGradeSnapshot(jsonEncode(next));
  }

  AsyncValue<Student> profile = const AsyncValue.idle();
  AsyncValue<List<Term>> periodos = const AsyncValue.idle();
  AsyncValue<List<IdiomasCourse>> idiomasMatricula = const AsyncValue.idle();
  AsyncValue<List<dynamic>> idiomasNotas = const AsyncValue.idle();
  AsyncValue<List<Payment>> cuotas = const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> _baseSchedule = const AsyncValue.idle();

  List<IdiomasCourse> get idiomasVigentes {
    final list = idiomasMatricula.value;
    if (list == null || list.isEmpty) return [];
    final now = DateTime.now();
    return list.where((c) => c.anio == now.year && c.mes == now.month).toList();
  }

  AsyncValue<List<ScheduleClass>> get schedule {
    final base = _baseSchedule;
    final idiomas = idiomasVigentes;
    if (idiomas.isEmpty) return base;

    final idiomasClasses = idiomas
        .expand((c) => c.toScheduleClasses())
        .toList();
    if (!base.hasValue) {
      if (base.loading) return const AsyncValue.loading();
      return AsyncValue.data(idiomasClasses);
    }

    final current = base.value ?? [];
    final filtered = current.where((s) => s.typeCode != 'I').toList();
    return AsyncValue.data([...filtered, ...idiomasClasses]);
  }

  @visibleForTesting
  void setBaseScheduleForTesting(AsyncValue<List<ScheduleClass>> value) {
    _baseSchedule = value;
  }

  AsyncValue<GradesSummary> resumen = const AsyncValue.idle();
  AsyncValue<List<TermAverage>> promedios = const AsyncValue.idle();
  AsyncValue<List<RecordCourse>> record = const AsyncValue.idle();
  AsyncValue<List<Payment>> pendingInstallments = const AsyncValue.idle();
  AsyncValue<List<Payment>> intranetInstallments = const AsyncValue.idle();
  AsyncValue<List<Fee>> tasas = const AsyncValue.idle();
  AsyncValue<List<PaymentRecord>> historico = const AsyncValue.idle();
  AsyncValue<EnrollmentCertificate> certificate = const AsyncValue.idle();
  AsyncValue<PaymentSchedule> paymentSchedule = const AsyncValue.idle();
  AsyncValue<List<Publication>> publications = const AsyncValue.idle();
  AsyncValue<WifiCredential> wifi = const AsyncValue.idle();
  AsyncValue<GradesCount> gradesCount = const AsyncValue.idle();
  AsyncValue<TeacherInfo> teacherInfo = const AsyncValue.idle();
  AsyncValue<List<TeacherSubject>> teacherSubjects = const AsyncValue.idle();
  AsyncValue<List<ScheduleClass>> teacherSchedule = const AsyncValue.idle();
  final Map<String, AsyncValue<List<TeacherStudent>>> _teacherStudents = {};
  AsyncValue<List<TeacherStudent>> alumnosDe(String cleAuto) =>
      _teacherStudents[cleAuto] ?? const AsyncValue.idle();
  final Map<String, AsyncValue<List<CourseGrade>>> _notasByPeriodo = {};
  AsyncValue<List<CourseGrade>> notasOf(int year, int periodo) =>
      _notasByPeriodo['$year-$periodo'] ?? const AsyncValue.idle();
  Term? get periodoActivo {
    final list = periodos.value;
    if (list == null) return null;
    try {
      return list.firstWhere((p) => p.isActive);
    } catch (_) {
      return null;
    }
  }

  /// Asignaturas del periodo activo que ya cerraron (talleres de medio ciclo).
  /// Se usa para no recordar clases de un curso que ya terminó.
  Set<String> get finishedSubjectsThisTerm {
    final p = periodoActivo;
    if (p == null) return const {};
    return finishedSubjects(boletaOf(p.year, p.number).value);
  }

  double? get promedioAcumulado {
    // Calculamos el promedio ponderado histórico real usando el récord académico
    final historial = record.value;
    if (historial != null && historial.isNotEmpty) {
      double sumaPonderada = 0;
      double sumaCreditos = 0;
      for (final c in historial) {
        final g = c.grade;
        // Ignorar cursos sin nota o sin créditos extraídos
        if (g == null || c.creditos <= 0) continue;
        sumaPonderada += g * c.creditos;
        sumaCreditos += c.creditos;
      }
      if (sumaCreditos > 0) return sumaPonderada / sumaCreditos;
    }

    // Fallback 1: Si no hay créditos en el récord, intentamos usar el oficial del resumen
    final oficial = resumen.value?.average;
    if (oficial != null && oficial > 0) return oficial;

    // Fallback 2: Promedio simple de todos los periodos (poco exacto)
    final list = promedios.value;
    if (list == null) return null;
    final activo = periodoActivo;
    return GradeCalculator.promedioAcumulado(
      list,
      activeYear: activo?.year,
      activeNumber: activo?.number,
    );
  }

  double? get promedioCicloActual {
    final activo = periodoActivo;
    if (activo == null) return null;
    if (isNewModel(activo.year, activo.number)) {
      final courses = boletaOf(activo.year, activo.number).value;
      if (courses == null) return null;
      // `realAverageOf` ya devuelve nota vigesimal (los talleres 0-100 caen a
      // su nota vigesimal oficial), así que se pueden promediar directamente.
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

  /// Promedio a mostrar para un curso de la boleta (modelo nuevo).
  /// El servidor redondea el promedio del curso (11.60 → 12); para cursos en
  /// proceso usamos el promedio real calculado desde sus unidades (si el
  /// detalle ya está cargado) para que lista y detalle muestren lo mismo.
  /// Los cursos cerrados conservan la nota oficial.
  /// Nota a mostrar (y a promediar) para un curso de la boleta, siempre en
  /// escala vigesimal. En proceso: promedio real desde las unidades si está en
  /// rango; cerrado o taller (0-100): la nota vigesimal oficial. Así lista,
  /// detalle y promedio del ciclo muestran exactamente lo mismo.
  double? realAverageOf(ReportCardCourse c) {
    if (c.inProgress) {
      final computed = _detalle[c.enrollmentSubjectId]?.value?.computedAverage;
      if (computed != null && computed >= 0 && computed <= 20.5)
        return computed;
    }
    return c.vigesimalAverage;
  }

  int? get approvedCredits {
    final p = profile.value?.creditsApproved;
    final r = resumen.value?.approvedCredits;
    if (p != null && p > 0) return p;
    if (r != null && r > 0) return r;
    return p ?? r;
  }

  int? get totalCredits => resumen.value?.totalCredits;
  void _notify() {
    if (_disposed || !_scope.isCurrent) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_disposed && _scope.isCurrent) notifyListeners();
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
            : DateTime.now();
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

  static const _ckResumen = 'resumen';
  Future<void> _setStorageCache(String key, Object data) {
    _scope.check();
    return AppStorage.instance.setCache(key, data);
  }

  static const List<DashboardWidgetConfig> _defaultDashboardLayout = [
    DashboardWidgetConfig(id: 'stats_promedio', span: 2),
    DashboardWidgetConfig(id: 'stats_creditos', span: 2),
    DashboardWidgetConfig(id: 'stats_clases_hoy', span: 2),
    DashboardWidgetConfig(id: 'stats_pagos', span: 2),
    DashboardWidgetConfig(id: 'next_class', span: 4),
    DashboardWidgetConfig(id: 'today_classes', span: 4),
    DashboardWidgetConfig(id: 'pending_payments', span: 4),
  ];
  List<DashboardWidgetConfig> dashboardLayout = [..._defaultDashboardLayout];

  void _loadDashboardLayout() {
    final s = AppStorage.instance.dashboardConfigJson;
    if (s != null) {
      try {
        final list = (jsonDecode(s) as List)
            .map(
              (e) => DashboardWidgetConfig.fromJson(e as Map<String, dynamic>),
            )
            .toList();
        if (list.isNotEmpty) {
          // Migración automática si existe stats_grid
          final i = list.indexWhere((e) => e.id == 'stats_grid');
          if (i >= 0) {
            list.removeAt(i);
            list.insertAll(i, [
              const DashboardWidgetConfig(id: 'stats_promedio', span: 1),
              const DashboardWidgetConfig(id: 'stats_creditos', span: 1),
              const DashboardWidgetConfig(id: 'stats_clases_hoy', span: 1),
              const DashboardWidgetConfig(id: 'stats_pagos', span: 1),
            ]);
          }
          // Validar que existan
          final defaults = [
            'stats_promedio',
            'stats_creditos',
            'stats_clases_hoy',
            'stats_pagos',
            'next_class',
            'today_classes',
            'pending_payments',
          ];
          for (final d in defaults) {
            if (!list.any((e) => e.id == d)) {
              list.add(
                DashboardWidgetConfig(
                  id: d,
                  span: d.startsWith('stats_') ? 2 : 4,
                ),
              );
            }
          }
          for (var i = 0; i < list.length; i++) {
            if (!list[i].id.startsWith('stats_') && list[i].span < 4) {
              list[i] = list[i].copyWith(span: 4);
            }
          }
          dashboardLayout = list;
          return;
        }
      } catch (_) {}
    }
    dashboardLayout = [..._defaultDashboardLayout];
  }

  void saveDashboardLayout() {
    final s = jsonEncode(dashboardLayout.map((e) => e.toJson()).toList());
    AppStorage.instance.setDashboardConfigJson(s);
    _notify();
  }

  String? editingDashboardWidgetId;
  void setEditingDashboardWidget(String? id) {
    editingDashboardWidgetId = id;
    _notify();
  }

  void reorderDashboard(String oldId, String newId, {bool save = true}) {
    final oldIndex = dashboardLayout.indexWhere((w) => w.id == oldId);
    int newIndex = dashboardLayout.indexWhere((w) => w.id == newId);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) return;

    final item = dashboardLayout.removeAt(oldIndex);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    dashboardLayout.insert(newIndex, item);

    if (save) saveDashboardLayout();
    _notify();
  }

  void setDashboardWidgetSpan(String id, int span) {
    final i = dashboardLayout.indexWhere((e) => e.id == id);
    if (i >= 0) {
      if (dashboardLayout[i].span != span) {
        dashboardLayout[i] = dashboardLayout[i].copyWith(span: span);
        saveDashboardLayout();
      }
    }
  }

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

  Future<void> hydrateFromCache() => _scope.run(() async {
    _loadDashboardLayout();
    await Future.wait([
      _hydrate(
        'loadProfile',
        _cache.getStudent,
        () => profile,
        (v) => profile = v,
      ),
      _hydrate(
        'loadPeriodos',
        _cache.getPeriodos,
        () => periodos,
        (v) => periodos = v,
      ),
      _hydrate(
        'loadHorarioActual',
        _cache.getHorario,
        () => _baseSchedule,
        (v) => _baseSchedule = v,
      ),
      _hydrate(
        'loadPromedios',
        _cache.getPromedios,
        () => promedios,
        (v) => promedios = v,
      ),
      _hydrate(
        'loadCuotasPendientes',
        _cache.getPagos,
        () => pendingInstallments,
        (v) => pendingInstallments = v,
      ),
    ]);
    if (_scope.isCurrent) PassingRule.resolveFrom(periodos.value);
  });

  Future<void> loadHomeEssentials() => _singleFlight<void>(
    'home',
    () => _scope.run(() async {
      // Los periodos van primero: `periodoActivo` alimenta al perfil, horario y
      // boleta. Cargarlos en paralelo provocaba que esas fuentes consultaran un
      // periodo adivinado por fecha y a veces volvieran vacías ("no aparecen
      // los datos hasta recargar").
      await loadPeriodos();
      if (!_scope.isCurrent) return;
      // La boleta no bloquea el refresco del inicio ni espera a pagos/idiomas.
      unawaited(checkActiveBoleta());
      Future<void> loadAcademicSummary() async {
        await loadProfile();
        if (!_scope.isCurrent) return;
        final p = profile.value;
        if (p != null && p.studyPlan.isNotEmpty && p.level.isNotEmpty) {
          await loadResumen(p.studyPlan, p.level);
        }
      }

      await Future.wait([
        loadAcademicSummary(),
        loadHorarioActual(),
        loadCuotasPendientes(),
        loadPromedios(),
        loadIdiomasMatricula(),
      ]);
    }),
  );

  /// Reintenta lo que falló, lo que nunca llegó a cargar, o lo que resolvió
  /// desde caché porque el primer chequeo de conectividad aún no había
  /// terminado (falso negativo de offline al arranque).
  Future<void> retryFailedEssentials() => _scope.run(() async {
    bool needs(AsyncValue s, [String? opName]) {
      if (s.loading) return false;
      if (!s.hasValue) return true;
      // Datos que vinieron de caché por un falso offline al arranque.
      if (opName != null && _startupCacheOps.contains(opName)) return true;
      return false;
    }

    if (needs(periodos, 'loadPeriodos')) await loadPeriodos();
    if (!_scope.isCurrent) return;
    final tasks = <Future<void>>[
      if (needs(profile, 'loadProfile')) loadProfile(),
      if (needs(schedule, 'loadHorarioActual')) loadHorarioActual(),
      if (needs(pendingInstallments, 'loadCuotasPendientes'))
        loadCuotasPendientes(),
      if (needs(promedios, 'loadPromedios')) loadPromedios(),
      if (needs(idiomasMatricula)) loadIdiomasMatricula(),
    ];
    // Limpiar marcas de caché por arranque: ya se está reintentando todo.
    _startupCacheOps.clear();
    if (tasks.isEmpty) return;
    await Future.wait(tasks);
    if (!_scope.isCurrent) return;
    final p = profile.value;
    if (needs(resumen) &&
        p != null &&
        p.studyPlan.isNotEmpty &&
        p.level.isNotEmpty) {
      await loadResumen(p.studyPlan, p.level);
    }
    if (!_scope.isCurrent) return;
    unawaited(checkActiveBoleta());
  });

  Future<void> checkActiveBoleta() => _scope.run(() async {
    final activo = periodoActivo;
    if (activo == null) return;
    if (isNewModel(activo.year, activo.number)) {
      await loadBoleta(activo.year, activo.number);
    } else {
      await loadBoletaLegacy(activo.year, activo.number);
    }
  });

  Future<Student?> loadProfile() => _wrap(
    () => _studentRes.load(),
    () => profile,
    (v) => profile = v,
    cached: _cache.getStudent,
    persist: _cache.saveStudent,
    operationName: 'loadProfile',
  );
  Future<List<Term>?> loadPeriodos() => _scope.run(() async {
    final result = await _wrap(
      () => _resolveOrEmpty(_periodosRes),
      () => periodos,
      (v) => periodos = v,
      cached: () => _cache.getPeriodos(),
      persist: (v) => _cache.savePeriodos(v),
      operationName: 'loadPeriodos',
    );
    if (!_scope.isCurrent) return null;
    // El periodo más antiguo es la cohorte de ingreso, y de ahí sale qué nota
    // aprueba para este estudiante.
    PassingRule.resolveFrom(periodos.value);
    return result;
  });

  Future<List<ScheduleClass>?> loadHorarioActual() => _wrap(
    () => _resolveOrEmpty(_horarioRes),
    () => _baseSchedule,
    (v) => _baseSchedule = v,
    cached: () => _cache.getHorario(),
    persist: (v) => _cache.saveHorario(v),
    operationName: 'loadHorarioActual',
  );

  /// Carga la matrícula del Centro de Idiomas y fusiona el horario.
  Future<void> loadIdiomasMatricula() => _scope.run(() async {
    final r = _idiomas;
    if (r == null) return;
    final s = AppStorage.instance;
    final user = s.credUser;
    final pass = s.credPass;
    if (user == null || pass == null) return;
    try {
      idiomasMatricula = const AsyncValue.loading();
      _notify();
      final loginResult = await r.login(user, pass);
      if (!_scope.isCurrent) return;
      if (loginResult == IdiomasLoginResult.invalidCredentials) {
        // Credenciales rechazadas: no es un error de red, simplemente
        // el estudiante no tiene cuenta de Idiomas o la contraseña difiere.
        idiomasMatricula = const AsyncValue.data([]);
        _notify();
        return;
      }
      if (loginResult == IdiomasLoginResult.networkError) {
        throw const NetworkException(
          'No se pudo conectar al Centro de Idiomas.',
        );
      }
      final courses = await r.getMatricula(user);
      if (!_scope.isCurrent) return;
      idiomasMatricula = AsyncValue.data(courses);

      // B8: Paralelizar las llamadas a getNotas por curso.
      if (courses.isNotEmpty) {
        final notasResults = await Future.wait(
          courses.map((c) => r.getNotas(c.detMatriculaId)),
        );
        if (!_scope.isCurrent) return;
        final allNotas = notasResults.expand((n) => n).toList();
        idiomasNotas = AsyncValue.data(allNotas);
      } else {
        idiomasNotas = const AsyncValue.data([]);
      }

      // La inyección en el horario ya no se hace aquí. El getter `schedule`
      // se encarga de combinar `_baseSchedule` y `idiomasVigentes` al vuelo.
      _notify();
    } catch (e) {
      if (!_scope.isCurrent) return;
      idiomasMatricula = AsyncValue.failure(e);
      idiomasNotas = AsyncValue.failure(e);
      _notify();
    }
  });

  Future<GradesSummary?> loadResumen(String pesId, String level) => _wrap(
    () => _repo
        .notasResumen(pesId, level)
        .then(
          (v) =>
              v ??
              const GradesSummary(
                average: 0,
                approvedCredits: 0,
                totalCredits: 0,
                enrollmentCount: 0,
              ),
        ),
    () => resumen,
    (v) => resumen = v,
    cached: () async {
      final raw = AppStorage.instance.getCache(_ckResumen);
      if (raw is Map)
        return GradesSummary.fromJson(raw.cast<String, dynamic>());
      return null;
    },
    persist: (v) => _setStorageCache(_ckResumen, v.toJson()),
    operationName: 'loadResumen:$pesId:$level',
  );
  Future<List<TermAverage>?> loadPromedios() => _wrap(
    _repo.promediosResumen,
    () => promedios,
    (v) => promedios = v,
    cached: () => _cache.getPromedios(),
    persist: (v) => _cache.savePromedios(v),
    operationName: 'loadPromedios',
  );
  final Map<String, AsyncValue<List<ReportCardCourse>>> _boleta = {};
  final Map<String, AsyncValue<CourseGradeDetail>> _detalle = {};
  final Map<String, AsyncValue<List<CourseGrade>>> _boletaLegacy = {};
  AsyncValue<List<ReportCardCourse>> boletaOf(int year, int periodo) =>
      _boleta['$year-$periodo'] ?? const AsyncValue.idle();
  AsyncValue<List<CourseGrade>> boletaLegacyOf(int year, int periodo) =>
      _boletaLegacy['$year-$periodo'] ?? const AsyncValue.idle();
  Future<void> loadBoletaLegacy(int year, int periodo) async {
    final key = '$year-$periodo';
    await _wrap<List<CourseGrade>>(
      () => Resolver<List<CourseGrade>>(
        sources: [
          ..._intra((r) => r.boletaLegacy(year, periodo)),
          _sigma('sigma', () => _repo.notasPeriodo(year, periodo)),
        ],
        merge: MergeStrategies.firstWins,
        stopAfterFirst: true,
        isEmpty: _emptyList,
      ).load(),
      () => boletaLegacyOf(year, periodo),
      (value) => _boletaLegacy[key] = value,
      cached: () => _cache.getBoletaLegacy(year.toString(), periodo.toString()),
      persist: (data) async {
        _checkGrades(data.map((n) => (n.subject, n.currentGradeText)));
        await _cache.saveBoletaLegacy(
          year.toString(),
          periodo.toString(),
          data,
        );
      },
      operationName: 'loadBoletaLegacy:$key',
    );
  }

  AsyncValue<CourseGradeDetail> detalleOf(String id) =>
      _detalle[id] ?? const AsyncValue.idle();
  Future<void> loadBoleta(int year, int periodo) async {
    final key = '$year-$periodo';
    await _wrap<List<ReportCardCourse>>(
      () => Resolver<List<ReportCardCourse>>(
        sources: _intra((r) => r.boleta(year, periodo)),
        merge: MergeStrategies.firstWins,
        stopAfterFirst: true,
        isEmpty: _emptyList,
      ).load(),
      () => boletaOf(year, periodo),
      (value) => _boleta[key] = value,
      cached: () => _cache.getBoleta(year.toString(), periodo.toString()),
      persist: (data) async {
        _checkGrades(data.map((c) => (c.name, c.promedioText)));
        await _cache.saveBoleta(year.toString(), periodo.toString(), data);
        if (_scope.isCurrent) unawaited(_prefetchDetalles(year, periodo, data));
      },
      operationName: 'loadBoleta:$key',
    );
  }

  Future<void> _prefetchDetalles(
    int year,
    int periodo,
    List<ReportCardCourse> courses,
  ) => _scope.run(() async {
    for (final c in courses.where((c) => c.inProgress)) {
      if (!_scope.isCurrent) return;
      if (_detalle[c.enrollmentSubjectId]?.hasValue ?? false) continue;
      await loadDetalle(year, periodo, c.enrollmentSubjectId);
    }
  });

  Future<void> loadDetalle(int year, int periodo, String enrollmentSubjectId) =>
      _scope.run(() async {
        final id = enrollmentSubjectId;
        if (_detalle[id]?.loading == true) return;
        _detalle[id] = AsyncValue.loading(_detalle[id]?.value);
        _notify();
        try {
          final data = await Resolver<CourseGradeDetail>(
            sources: _intra((r) => r.detalleCurso(year, periodo, id)),
            merge: MergeStrategies.firstWins,
            stopAfterFirst: true,
          ).load();
          if (!_scope.isCurrent) return;
          _detalle[id] = AsyncValue.data(data);
        } catch (e) {
          if (!_scope.isCurrent) return;
          _detalle[id] = AsyncValue.failure(e, _detalle[id]?.value);
        }
        _notify();
      });

  Future<List<RecordCourse>?> loadRecord() => _wrap<List<RecordCourse>>(
    () {
      final codest = profile.value?.id.isNotEmpty == true
          ? profile.value!.id
          : AppStorage.instance.credUser ?? '';
      return Resolver<List<RecordCourse>>(
        sources: _intra((r) => r.recordAcademico(codest)),
        merge: MergeStrategies.firstWins,
        stopAfterFirst: true,
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
    } on NoDataAvailableException catch (e) {
      if (e.cause == null) return const [];
      rethrow;
    }
  }

  Future<List<Payment>?> loadCuotasPendientes() => _wrap(
    () => _resolveOrEmpty(_cuotasRes),
    () => pendingInstallments,
    (v) => pendingInstallments = v,
    cached: () => _cache.getPagos(),
    persist: (v) => _cache.savePagos(v),
    operationName: 'loadCuotasPendientes',
  );
  Future<List<Payment>?> loadCuotasIntranet() => _wrap(
    () => _resolveOrEmpty(_vencidasRes),
    () => intranetInstallments,
    (v) => intranetInstallments = v,
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
  Future<EnrollmentCertificate?> loadCertificate({int? year, int? periodo}) {
    final p = periodoActivo;
    final a = year ?? p?.year ?? 0;
    final per = periodo ?? p?.number ?? 0;
    return _wrap(
      () => Resolver<EnrollmentCertificate>(
        sources: _intra((r) => r.constanciaMatricula(a, per)),
        merge: MergeStrategies.firstWins,
        stopAfterFirst: true,
      ).load(),
      () => certificate,
      (v) => certificate = v,
      operationName: 'loadCertificate:$a:$per',
    );
  }

  Future<PaymentSchedule?> loadPaymentSchedule() => _wrap(
    () => Resolver<PaymentSchedule>(
      sources: _intra((r) => r.cronogramaPagos()),
      merge: MergeStrategies.firstWins,
      stopAfterFirst: true,
    ).load(),
    () => paymentSchedule,
    (v) => paymentSchedule = v,
    operationName: 'loadPaymentSchedule',
  );
  Future<List<Publication>?> loadPublications() => _wrap(
    _repo.publications,
    () => publications,
    (v) => publications = v,
    operationName: 'loadPublications',
  );
  Future<WifiCredential?> loadWifi() => _wrap<WifiCredential>(
    () async {
      final w = await _repo.wifiCredencial();
      return w ?? const WifiCredential(username: '', password: '');
    },
    () => wifi,
    (v) => wifi = v,
    operationName: 'loadWifi',
  );
  Future<GradesCount?> loadGradesCount() async {
    final p = periodoActivo;
    if (p == null) return null;
    return _wrap<GradesCount>(
      () async {
        final c = await _repo.gradesCount(p.year, p.number);
        return c ??
            const GradesCount(
              approved: 0,
              disapproved: 0,
              pending: 0,
              total: 0,
            );
      },
      () => gradesCount,
      (v) => gradesCount = v,
      operationName: 'loadGradesCount:${p.year}:${p.number}',
    );
  }

  TeacherRepository _teacherReady() {
    final d = _teacher;
    if (d == null) {
      throw Exception('Teacher module is not available.');
    }
    return d;
  }

  Future<TeacherInfo?> loadTeacherInfo() => _wrap<TeacherInfo>(
    () async {
      final v = await _teacherReady().infoDocente();
      return v ?? const TeacherInfo(code: '', firstName: '', lastName: '');
    },
    () => teacherInfo,
    (v) => teacherInfo = v,
    cached: () => _cache.getDocenteInfo(),
    persist: (v) => _cache.saveDocenteInfo(v),
    operationName: 'loadTeacherInfo',
  );
  Future<List<TeacherSubject>?> loadTeacherSubjects() => _wrap(
    () => _teacherReady().asignaturas(),
    () => teacherSubjects,
    (v) => teacherSubjects = v,
    cached: () => _cache.getDocenteCursos(),
    persist: (v) => _cache.saveDocenteCursos(v),
    operationName: 'loadTeacherSubjects',
  );
  Future<List<ScheduleClass>?> loadDocenteHorario() => _wrap(
    () => _teacherReady().getHorario(),
    () => teacherSchedule,
    (v) => teacherSchedule = v,
    cached: () => _cache.getDocenteHorario(),
    persist: (v) => _cache.saveDocenteHorario(v),
    operationName: 'loadDocenteHorario',
  );
  Future<void> loadDocenteAlumnos(String cleAuto) => _scope.run(() async {
    _teacherStudents[cleAuto] = AsyncValue.loading(
      _teacherStudents[cleAuto]?.value,
    );
    _notify();
    try {
      final v = await _errorHandler.withFallback<List<TeacherStudent>>(
        remote: () => _teacherReady().estudiantesSeccion(cleAuto),
        cached: () => _cache.getDocenteAlumnos(cleAuto),
        operationName: 'loadDocenteAlumnos($cleAuto)',
      );
      if (!_scope.isCurrent) return;
      _teacherStudents[cleAuto] = AsyncValue.data(v);
      await _cache.saveDocenteAlumnos(cleAuto, v);
    } catch (e) {
      if (!_scope.isCurrent) return;
      _teacherStudents[cleAuto] = AsyncValue.failure(
        e,
        _teacherStudents[cleAuto]?.value,
      );
    }
    _notify();
  });

  Future<String?> updateDocenteNota({
    required String cleAuto,
    required String codigoAlumno,
    required String grade,
  }) => _scope.run(() async {
    try {
      await _teacherReady().updateNota(
        cleAuto: cleAuto,
        codigoAlumno: codigoAlumno,
        grade: grade,
      );
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      await loadDocenteAlumnos(cleAuto);
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return null;
    } catch (e) {
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return e.toString();
    }
  });

  Future<List<EvaluationGrade>> docenteNotasDetalle({
    required String cleAuto,
    required String codigoAlumno,
  }) => _scope.run(() async {
    final result = await _teacherReady().notasDetalle(
      cleAuto: cleAuto,
      codigoAlumno: codigoAlumno,
    );
    _scope.check();
    return result;
  });
  Future<String?> updateDocenteEvaluacion({
    required String cleAuto,
    required String codigoAlumno,
    required String codigoEvaluacion,
    required String grade,
  }) => _scope.run(() async {
    try {
      await _teacherReady().updateEvaluacion(
        cleAuto: cleAuto,
        codigoAlumno: codigoAlumno,
        codigoEvaluacion: codigoEvaluacion,
        grade: grade,
      );
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      await loadDocenteAlumnos(cleAuto);
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return null;
    } catch (e) {
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return e.toString();
    }
  });

  Future<List<DailyAttendance>> docenteAsistenciaAlumno({
    required String cleAuto,
    required String codigoAlumno,
  }) => _scope.run(() async {
    final result = await _teacherReady().asistenciaAlumno(
      cleAuto: cleAuto,
      codigoAlumno: codigoAlumno,
    );
    _scope.check();
    return result;
  });
  Future<Map<String, String>> docenteAsistenciaDia({
    required String cleAuto,
    required DateTime date,
  }) => _scope.run(() async {
    final result = await _teacherReady().asistenciaDelDia(
      cleAuto: cleAuto,
      date: date,
    );
    _scope.check();
    return result;
  });
  Future<String?> guardarAsistenciaDia({
    required String cleAuto,
    required DateTime date,
    required Map<String, String> estados,
  }) => _scope.run(() async {
    try {
      await _teacherReady().guardarAsistenciaDelDia(
        cleAuto: cleAuto,
        date: date,
        estados: estados,
      );
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return null;
    } catch (e) {
      if (!_scope.isCurrent) return const StaleSessionException().toString();
      return e.toString();
    }
  });

  bool get tieneDocente => _teacher != null;
  Future<void> changePassword(String actual, String nueva) =>
      _scope.run(() async {
        await _repo.changePassword(actual, nueva);
        _scope.check();
        final user = AppStorage.instance.credUser;
        if (user != null) await AppStorage.instance.setCredentials(user, nueva);
        _scope.check();
        _intranet?.invalidate();
        await AppStorage.instance.setIntranetSession(null, null);
      });
  Future<List<CourseGrade>?> loadNotas(int year, int periodo) =>
      _scope.run(() async {
        final key = '$year-$periodo';
        final prev = _notasByPeriodo[key]?.value;
        _notasByPeriodo[key] = AsyncValue.loading(prev);
        _notify();
        try {
          final v = await _errorHandler.withFallback<List<CourseGrade>>(
            remote: () => Resolver<List<CourseGrade>>(
              sources: [
                ..._intra((r) => r.boletaLegacy(year, periodo)),
                _sigma('sigma', () => _repo.notasPeriodo(year, periodo)),
              ],
              merge: MergeStrategies.firstWins,
              stopAfterFirst: true,
              isEmpty: _emptyList,
            ).load(),
            cached: () =>
                _cache.getBoletaLegacy(year.toString(), periodo.toString()),
            operationName: 'loadNotas($year, $periodo)',
          );
          if (!_scope.isCurrent) return null;
          _notasByPeriodo[key] = AsyncValue.data(v);
          _notify();
          await _cache.saveBoletaLegacy(year.toString(), periodo.toString(), v);
          return v;
        } catch (e) {
          if (!_scope.isCurrent) return null;
          _notasByPeriodo[key] = AsyncValue.failure(e, prev);
          _notify();
          return null;
        }
      });

  Future<void> clear({bool invalidateSession = true}) {
    if (invalidateSession) _scope.invalidate();
    _inFlight.clear();
    _freshness.clear();
    final cleared = _cache.clearAll();
    _startupCacheOps.clear();
    profile = const AsyncValue.idle();
    periodos = const AsyncValue.idle();
    // Otro estudiante puede tener otra regla de aprobación: no se hereda.
    PassingRule.current = PassingRule.standard;
    _baseSchedule = const AsyncValue.idle();
    resumen = const AsyncValue.idle();
    promedios = const AsyncValue.idle();
    pendingInstallments = const AsyncValue.idle();
    intranetInstallments = const AsyncValue.idle();
    tasas = const AsyncValue.idle();
    historico = const AsyncValue.idle();
    _notasByPeriodo.clear();
    _boleta.clear();
    _boletaLegacy.clear();
    _detalle.clear();
    record = const AsyncValue.idle();
    certificate = const AsyncValue.idle();
    idiomasMatricula = const AsyncValue.idle();
    idiomasNotas = const AsyncValue.idle();
    publications = const AsyncValue.idle();
    wifi = const AsyncValue.idle();
    gradesCount = const AsyncValue.idle();
    teacherInfo = const AsyncValue.idle();
    teacherSubjects = const AsyncValue.idle();
    teacherSchedule = const AsyncValue.idle();
    _teacherStudents.clear();
    _intranet?.invalidate();
    _idiomas?.invalidate();
    _notify();
    return cleared;
  }
}
