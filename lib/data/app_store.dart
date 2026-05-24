import 'dart:convert';

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'package:nexo/core/storage.dart';
import 'package:nexo/data/intranet_repository.dart';
import 'package:nexo/data/sigma_repository.dart';
import 'package:nexo/domain/models.dart';

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
  AppStore(this._repo, {IntranetRepository? intranet}) : _intranet = intranet;
  final SigmaRepository _repo;
  final IntranetRepository? _intranet;

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

  AsyncValue<StudentProfile> profile = const AsyncValue.idle();
  AsyncValue<List<Periodo>> periodos = const AsyncValue.idle();
  AsyncValue<List<ClaseHorario>> horario = const AsyncValue.idle();
  AsyncValue<NotasResumen> resumen = const AsyncValue.idle();
  AsyncValue<List<PromedioPeriodo>> promedios = const AsyncValue.idle();

  /// Record académico completo (fuente Intranet — SIGMA lo deja vacío).
  AsyncValue<List<RecordCurso>> record = const AsyncValue.idle();

  AsyncValue<List<Cuota>> cuotasPendientes = const AsyncValue.idle();
  AsyncValue<List<Cuota>> cuotasIntranet = const AsyncValue.idle();
  AsyncValue<List<Tasa>> tasas = const AsyncValue.idle();
  AsyncValue<List<PagoHistorico>> historico = const AsyncValue.idle();

  /// Notas por periodo: clave = "anio-periodoNum".
  final Map<String, AsyncValue<List<NotaAsignatura>>> _notasByPeriodo = {};

  AsyncValue<List<NotaAsignatura>> notasOf(int anio, int periodo) =>
      _notasByPeriodo['$anio-$periodo'] ?? const AsyncValue.idle();

  /// Periodo activo (matriculado) si está disponible.
  Periodo? get periodoActivo {
    final list = periodos.value;
    if (list == null) return null;
    try {
      return list.firstWhere((p) => p.activo);
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
      if (p.promedio == 0) return false;
      if (activo != null && p.anio == activo.anio && p.periodo == activo.periodo) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) {
        final byYear = a.anio.compareTo(b.anio);
        return byYear != 0 ? byYear : a.periodo.compareTo(b.periodo);
      });
    if (completados.isEmpty) return null;
    // Promedio simple de los periodos completados.
    final sum = completados.fold<double>(0, (a, b) => a + b.promedio);
    return sum / completados.length;
  }

  /// Créditos aprobados del estudiante (preferir perfil sobre resumen).
  int? get creditosAprobados {
    final p = profile.value?.creditoAprobado;
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
    Future<T> Function() loader,
    AsyncValue<T> Function() get,
    void Function(AsyncValue<T>) set, {
    void Function(T value)? persist,
  }) async {
    set(AsyncValue.loading(get().value));
    _notify();
    try {
      final v = await loader();
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

  void _cache(String key, Object data) =>
      AppStorage.instance.setCache(key, data);

  /// Rellena el estado con datos cacheados para mostrar algo al instante
  /// (incluso sin red o si la sesión se renueva). Se refresca en segundo plano.
  void hydrateFromCache() {
    final s = AppStorage.instance;

    final p = s.getCache(_ckProfile);
    if (p is Map) {
      profile = AsyncValue.data(
          StudentProfile.fromJson(p.cast<String, dynamic>()));
    }
    final per = s.getCache(_ckPeriodos);
    if (per is List) {
      periodos = AsyncValue.data(per
          .map((e) =>
              Periodo.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    final h = s.getCache(_ckHorario);
    if (h is List) {
      horario = AsyncValue.data(h
          .map((e) =>
              ClaseHorario.fromJson((e as Map).cast<String, dynamic>()))
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
              PromedioPeriodo.fromJson((e as Map).cast<String, dynamic>()))
          .toList());
    }
    final cp = s.getCache(_ckCuotasPend);
    if (cp is List) {
      cuotasPendientes = AsyncValue.data(cp
          .map((e) => Cuota.fromJson((e as Map).cast<String, dynamic>()))
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
    if (p != null && p.pesId.isNotEmpty && p.nivel.isNotEmpty) {
      await loadResumen(p.pesId, p.nivel);
    }
  }

  Future<StudentProfile?> loadProfile() => _wrap(
        _repo.infoEstudiante,
        () => profile,
        (v) => profile = v,
        persist: (v) => _cache(_ckProfile, v.toJson()),
      );

  Future<List<Periodo>?> loadPeriodos() => _wrap(
        _repo.periodosEstudiante,
        () => periodos,
        (v) => periodos = v,
        persist: (v) =>
            _cache(_ckPeriodos, v.map((e) => e.toJson()).toList()),
      );

  Future<List<ClaseHorario>?> loadHorarioActual() => _wrap(
        () => _repo.horario(),
        () => horario,
        (v) => horario = v,
        persist: (v) =>
            _cache(_ckHorario, v.map((e) => e.toJson()).toList()),
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
        persist: (v) => _cache(_ckResumen, v.toJson()),
      );

  Future<List<PromedioPeriodo>?> loadPromedios() => _wrap(
        _repo.promediosResumen,
        () => promedios,
        (v) => promedios = v,
        persist: (v) =>
            _cache(_ckPromedios, v.map((e) => e.toJson()).toList()),
      );

  /// Garantiza una sesión Intranet con las credenciales guardadas.
  Future<IntranetRepository> _intranetReady() async {
    final intranet = _intranet;
    if (intranet == null) throw Exception('Intranet no disponible.');
    final s = AppStorage.instance;
    final user = s.credUser;
    final pass = s.credPass;
    if (user == null || pass == null) {
      throw Exception('Inicia sesión para ver tus notas.');
    }
    final ok = await intranet.ensureSession(user, pass);
    if (!ok) throw Exception('No se pudo conectar con Intranet.');
    return intranet;
  }

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
      final intranet = await _intranetReady();
      final data = await intranet.boletaLegacy(anio, periodo);
      _boletaLegacy[key] = AsyncValue.data(data);
      _checkGrades(data.map((n) => (n.asignatura, n.notaActualText)));
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
      final intranet = await _intranetReady();
      final data = await intranet.boleta(anio, periodo);
      _boleta[key] = AsyncValue.data(data);
      _checkGrades(data.map((c) => (c.nombre, c.promedioText)));
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
      final intranet = await _intranetReady();
      _detalle[id] =
          AsyncValue.data(await intranet.detalleCurso(anio, periodo, id));
    } catch (e) {
      _detalle[id] = AsyncValue.failure(e, _detalle[id]?.value);
    }
    _notify();
  }

  /// Record histórico (plan de estudios) — opcional.
  Future<List<RecordCurso>?> loadRecord() {
    return _wrap<List<RecordCurso>>(
      () async {
        final intranet = await _intranetReady();
        final codest = profile.value?.estId.isNotEmpty == true
            ? profile.value!.estId
            : AppStorage.instance.credUser ?? '';
        return intranet.recordAcademico(codest);
      },
      () => record,
      (v) => record = v,
    );
  }

  Future<List<Cuota>?> loadCuotasPendientes() => _wrap(
        _repo.cuotasPendientes,
        () => cuotasPendientes,
        (v) => cuotasPendientes = v,
        persist: (v) =>
            _cache(_ckCuotasPend, v.map((e) => e.toJson()).toList()),
      );

  Future<List<Cuota>?> loadCuotasIntranet() => _wrap(
        _repo.cuotasIntranet,
        () => cuotasIntranet,
        (v) => cuotasIntranet = v,
      );

  Future<List<Tasa>?> loadTasas() => _wrap(
        _repo.tasas,
        () => tasas,
        (v) => tasas = v,
      );

  Future<List<PagoHistorico>?> loadHistorico() => _wrap(
        _repo.historicoPagos,
        () => historico,
        (v) => historico = v,
      );

  Future<List<NotaAsignatura>?> loadNotas(int anio, int periodo) async {
    final key = '$anio-$periodo';
    final prev = _notasByPeriodo[key]?.value;
    _notasByPeriodo[key] = AsyncValue.loading(prev);
    _notify();
    try {
      final v = await _repo.notasPeriodo(anio, periodo);
      _notasByPeriodo[key] = AsyncValue.data(v);
      _notify();
      return v;
    } catch (e) {
      _notasByPeriodo[key] = AsyncValue.failure(e, prev);
      _notify();
      return null;
    }
  }

  void clear() {
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
    _intranet?.invalidate();
    _notify();
  }
}
