import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:nexo/core/error_handler.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/session_scope.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/local/cache_manager.dart';
import 'package:nexo/data/remote/backend_client.dart'
    show BackendException, apiErrorOf;
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/data/resolver.dart';
import 'package:nexo/data/services/connectivity_service.dart';
import 'package:nexo/data/store/async_value.dart';
import 'package:nexo/domain/course_status.dart';
import 'package:nexo/domain/dashboard_widget_config.dart';
import 'package:nexo/domain/data_freshness.dart';
import 'package:nexo/domain/grade_calculator.dart';
import 'package:nexo/domain/grade_paste.dart';
import 'package:nexo/domain/idiomas_models.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/domain/unified_models.dart';

export 'package:nexo/data/store/async_value.dart';

part 'store/store_base.dart';
part 'store/dashboard_store.dart';
part 'store/student_store.dart';
part 'store/payments_store.dart';
part 'store/teacher_store.dart';
part 'store/teacher_drafts_store.dart';

/// Estado de la app para las pantallas. Todos los datos vienen de la API de
/// Nexo ([NexoRepository]).
///
/// Cada área vive en su propio archivo de `store/`: infraestructura común
/// ([_StoreBase]), tablero, estudiante, pagos, docente y borradores del
/// docente. Aquí queda lo que las coordina: arranque, reintentos y cierre de
/// sesión.
class AppStore extends _StoreBase
    with
        _DashboardStore,
        _StudentStore,
        _PaymentsStore,
        _TeacherStore,
        _TeacherDraftsStore {
  AppStore(
    super.nexo, {
    required super.cache,
    required super.errorHandler,
    required super.connectivity,
    super.scope,
  }) {
    // El layout del dashboard debe cargarse SIEMPRE (no solo al hidratar):
    // tras un login fresco `hydrateFromCache` no corre y el Home quedaba con
    // spans por defecto rotos (tarjetas aplastadas en móvil).
    _loadDashboardLayout();
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
      // Los periodos van primero: `periodoActivo` alimenta al horario y a la
      // boleta. Cargarlos en paralelo provocaba que esas fuentes consultaran
      // un periodo adivinado por fecha y a veces volvieran vacías.
      await loadPeriodos();
      if (!_scope.isCurrent) return;
      // La boleta no bloquea el refresco del inicio ni espera a pagos/idiomas.
      unawaited(checkActiveBoleta());
      await Future.wait([
        loadProfile(),
        loadResumen(),
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
      if (needs(resumen, 'loadResumen')) loadResumen(),
      // El horario propio, no el combinado: las clases de Idiomas no deben
      // ocultar que el de la universidad falló.
      if (needs(_baseSchedule, 'loadHorarioActual')) loadHorarioActual(),
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
    unawaited(checkActiveBoleta());
  });

  /// Cambia la contraseña de la universidad a través de la API de Nexo y
  /// guarda la nueva solo en el dispositivo, para los reingresos.
  Future<void> changePassword(String actual, String nueva) =>
      _scope.run(() async {
        await _call(() => _nexo.changePassword(actual, nueva));
        _scope.check();
        final user = AppStorage.instance.credUser;
        if (user != null) await AppStorage.instance.setCredentials(user, nueva);
      });

  Future<void> clear({bool invalidateSession = true}) {
    if (invalidateSession) _scope.invalidate();
    _resetBase();
    final cleared = _cache.clearAll();
    _clearStudent();
    _clearPayments();
    _clearTeacher();
    editingDashboardWidgetId = null;
    _notify();
    return cleared;
  }
}
