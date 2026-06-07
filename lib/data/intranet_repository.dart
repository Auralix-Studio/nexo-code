import 'package:nexo/core/storage.dart';
import 'package:nexo/data/intranet_client.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Mapea endpoints de Intranet → modelos. Usa las credenciales guardadas
/// (mismas que SIGMA) para abrir su propia sesión por cookie.
class IntranetRepository {
  IntranetRepository(this._client);
  final IntranetClient _client;

  bool _ready = false;
  Future<bool>? _loginInFlight;
  String? _currentUser;

  // ─── Memoización con TTL ───
  // Varios sources piden la misma data (constancia desde profile + horario,
  // tasas desde tab Tasas + tab Vencidas, etc.). Cacheamos la respuesta
  // cruda durante 60s para evitar hits duplicados a Intranet PHP.
  static const _cacheTtl = Duration(seconds: 60);
  final Map<String, _Cached> _cache = {};

  Future<List<dynamic>> _memoPostList(
    String path,
    Map<String, String> body, {
    String? referer,
  }) {
    final key = '$path?${body.entries.map((e) => "${e.key}=${e.value}").join("&")}';
    final cached = _cache[key];
    final now = DateTime.now();
    if (cached != null && now.difference(cached.at) < _cacheTtl) {
      return cached.future;
    }
    final future = _client.postJsonList(path, body, referer: referer);
    _cache[key] = _Cached(future, now);
    // Si la llamada falla, invalidar para que el próximo intento reintente
    future.catchError((_) {
      _cache.remove(key);
      return <dynamic>[];
    });
    return future;
  }

  Future<List<dynamic>> _memoGetList(String path, {String? referer}) {
    final key = 'GET:$path';
    final cached = _cache[key];
    final now = DateTime.now();
    if (cached != null && now.difference(cached.at) < _cacheTtl) {
      return cached.future;
    }
    final future = _client.getJsonList(path, referer: referer);
    _cache[key] = _Cached(future, now);
    future.catchError((_) {
      _cache.remove(key);
      return <dynamic>[];
    });
    return future;
  }

  /// Invalida la caché — usar después de operaciones que modifiquen estado
  /// (logout, refresh manual del usuario, etc.).
  void clearCache() => _cache.clear();

  /// Código del estudiante autenticado — usado por endpoints que requieren
  /// `codEst=...` en el body (estado de deuda, pensiones, tasas, etc.).
  String? get currentUser => _currentUser;

  /// Asegura una sesión Intranet activa. Si varios sources llaman a la vez
  /// (caso típico cuando AppStore hace `Future.wait([...])` cargando todo),
  /// comparten el MISMO login future en lugar de pisarse cookies. En cold
  /// start intenta primero rehidratar la cookie persistida — solo hace el
  /// POST /login si el server marca la sesión como caducada (HTML response).
  Future<bool> ensureSession(String usuario, String contrasena) async {
    if (_ready && _client.isLoggedIn && _currentUser == usuario) return true;
    final inFlight = _loginInFlight;
    if (inFlight != null) return inFlight;

    // Intento 1: restaurar cookies persistidas (PHPSESSID) sin re-login.
    final s = AppStorage.instance;
    final savedCookies = s.intranetCookies;
    final savedUser = s.intranetUser;
    if (savedCookies != null && savedUser == usuario && !_client.isLoggedIn) {
      _client.importCookies(savedCookies);
      _currentUser = usuario;
      _ready = true;
      return true;
    }

    // Intento 2: login fresco.
    final future = _client.login(usuario, contrasena);
    _loginInFlight = future;
    try {
      _ready = await future;
      if (_ready) {
        _currentUser = usuario;
        await s.setIntranetSession(_client.exportCookies(), usuario);
      }
      return _ready;
    } finally {
      _loginInFlight = null;
    }
  }

  /// Boleta de notas del periodo (modelo nuevo 2026-1+).
  /// `consultarconstanciaNotasDetallado` → lista de cursos.
  Future<List<BoletaCurso>> boleta(int anio, int periodo) async {
    final rows = await _memoPostList(
      'consultarconstanciaNotasDetallado',
      {'anio': '$anio', 'periodo': '$periodo'},
      referer: 'repRankingPromocionalEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 11) // descarta legacy/errores
        .map(BoletaCurso.fromRow)
        .where((c) => c.nombre.isNotEmpty && c.matriculaAsignaturaId.isNotEmpty)
        .toList();
  }

  /// Boleta legacy (≤2025): el mismo endpoint devuelve filas de 50 columnas
  /// posicionales, idénticas al modelo de 2 parciales.
  Future<List<NotaAsignatura>> boletaLegacy(int anio, int periodo) async {
    final rows = await _memoPostList(
      'consultarconstanciaNotasDetallado',
      {'anio': '$anio', 'periodo': '$periodo'},
      referer: 'repRankingPromocionalEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 24) // legacy ~50 cols
        .map(NotaAsignatura.fromLegacyRow)
        .where((n) => n.asignatura.isNotEmpty)
        .toList();
  }

  /// Horario real (Intranet `verhorariomatriz-matriculados3EstudianteEstudiante`).
  /// Matriz tiempo×día: cada fila = franja horaria, cols 3-9 = Lun-Dom.
  /// Cada celda contiene cadenas `_`-separadas con info de la clase. Cuando
  /// hay clases solapadas en la misma celda, los campos vienen `,`-separados.
  /// Combina con docentes de `verhorarioseleccion-detalleEstudiante`.
  Future<List<ScheduleClass>> horarioMatriculados(int anio, int periodo) async {
    final rows = await _memoPostList(
      'verhorariomatriz-matriculados3EstudianteEstudiante',
      {'periodo': '$anio-$periodo'},
      referer: 'reportesDelEstudiante',
    );

    // Mapa de docentes (codigo curso → docente) desde el detalle
    final docentesByCurso = <String, String>{};
    try {
      final det = await _memoPostList(
        'verhorarioseleccion-detalleEstudiante',
        {'periodo': '$anio-$periodo'},
        referer: 'reportesDelEstudiante',
      );
      for (final r in det.whereType<List<dynamic>>()) {
        if (r.length < 10) continue;
        final nombre = r[0]?.toString().trim() ?? '';
        final docente = r[9]?.toString().trim() ?? '';
        if (nombre.isNotEmpty && docente.isNotEmpty) {
          docentesByCurso[nombre] = docente;
        }
      }
    } catch (_) {/* docente opcional */}

    final seenIds = <String>{};
    final result = <ScheduleClass>[];

    for (final row in rows.whereType<List<dynamic>>()) {
      // Cols 3..9 = días 1..7 (Lun..Dom)
      for (var dayIdx = 3; dayIdx < 10 && dayIdx < row.length; dayIdx++) {
        final raw = row[dayIdx]?.toString().trim() ?? '';
        if (raw.isEmpty) continue;
        final weekday = dayIdx - 2; // 3→1=Lun, 9→7=Dom

        // Cada celda puede contener 1+ clases solapadas. Las dividimos por
        // el ancho de comas: si los campos críticos (id, código) traen comas,
        // hay N clases en la celda.
        final fields = raw.split('_');
        if (fields.length < 13) continue;
        final ids = fields[0].split(',');
        final n = ids.length;

        for (var i = 0; i < n; i++) {
          String at(int f) {
            if (f >= fields.length) return '';
            final v = fields[f].split(',');
            return (i < v.length ? v[i] : v.last).trim();
          }
          final id = at(0);
          if (id.isEmpty || seenIds.contains(id)) continue;
          seenIds.add(id);
          final tipo = at(13).toLowerCase();
          final subject = at(2);
          // at(12) = "PABELLON I - I 302 - AFORO: 50" → descomponer
          final loc = ScheduleClass.parseLocation(at(12));
          result.add(ScheduleClass(
            id: id,
            nrc: at(1),
            subject: subject,
            section: at(10),
            weekday: weekday,
            dayName: const ['', 'Lunes', 'Martes', 'Miércoles', 'Jueves',
                'Viernes', 'Sábado', 'Domingo'][weekday],
            startTime: at(8),
            endTime: at(9),
            campus: at(11),       // "CAMPUS UNIVERSITARIO"
            building: loc.building, // "PABELLON I"
            room: loc.room,        // "I 302"
            capacity: loc.capacity, // 50
            teacher: docentesByCurso[subject] ?? '',
            typeCode: tipo.startsWith('p') ? 'P' : 'T',
            modality: '',
            level: '',
            note: '',
          ));
        }
      }
    }

    return result;
  }

  /// Detalle por unidad/evidencia de un curso.
  /// `consultarDetalleBoletaNotas` → unidades + evidencias + promedios.
  Future<CursoDetalleNotas> detalleCurso(
    int anio,
    int periodo,
    String matriculaAsignaturaId,
  ) async {
    final rows = await _memoPostList(
      'consultarDetalleBoletaNotas',
      {
        'anio': '$anio',
        'periodo': '$periodo',
        'matricula_asignatura_id': matriculaAsignaturaId,
      },
      referer: 'repRankingPromocionalEst',
    );
    return CursoDetalleNotas.fromRows(rows);
  }

  /// Record histórico consolidado (plan de estudios, todas las notas finales).
  Future<List<RecordCurso>> recordAcademico(String codest) async {
    final rows = await _memoPostList(
      'consultarProgresoCurricular',
      {'codest': codest},
      referer: 'repProgresoCurricularEst',
    );
    return rows
        .whereType<List<dynamic>>()
        .map(RecordCurso.fromRow)
        .where((c) => c.nombre.isNotEmpty)
        .toList();
  }

  /// Constancia de matrícula del periodo indicado.
  /// `consultarConstanciaMatriculaEstudiante` (POST, body `periodo=YYYY-P`).
  Future<ConstanciaMatricula> constanciaMatricula(int anio, int periodo) async {
    final rows = await _memoPostList(
      'consultarConstanciaMatriculaEstudiante',
      {'periodo': '$anio-$periodo'},
      referer: 'pg_reportesDelEstudiante',
    );
    return ConstanciaMatricula.fromRows(rows);
  }

  /// Cronograma de cuotas del periodo activo.
  /// `consultarCuotasEstudiante` (GET, query `cuotas=N`).
  Future<CronogramaPagos> cronogramaPagos({int cuotas = 5}) async {
    final rows = await _memoGetList(
      'consultarCuotasEstudiante?cuotas=$cuotas',
      referer: 'pg_reportesDelEstudiante',
    );
    return CronogramaPagos.fromRows(rows);
  }

  // ═══════════════════════════════════════════════════════════════
  //  Endpoints para el sistema híbrido SIGMA↔Intranet
  //
  //  SIGMA API se quedó como cascarón: muchos endpoints devuelven
  //  HTML del SPA en vez de JSON (verificado 2026-06 con probe).
  //  Toda la data académica/financiera vive ahora en Intranet PHP.
  //  Estos métodos exponen esos endpoints en la forma que esperan
  //  las pantallas existentes — sin cambiar UI ni modelos de dominio.
  // ═══════════════════════════════════════════════════════════════

  /// Cronograma teórico (inicial) — no la deuda real. Lo dejo por
  /// si algún módulo lo necesita. Para la deuda usar
  /// `pensionesPendientes/Vencidas/Tasas` que vienen de `consultaEstadoDeuda_Estudiante`.
  Future<List<Payment>> cuotasPagosLista({
    int cuotas = 30,
    String? termLabel,
  }) async {
    final rows = await _memoGetList(
      'consultarCuotasEstudiante?cuotas=$cuotas',
      referer: 'pg_reportesDelEstudiante',
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 5)
        .where((r) =>
            !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map((r) => Payment.fromIntranetRow(r, termLabel: termLabel))
        .toList();
  }

  // ─── Estado real de deuda (consultaEstadoDeuda_Estudiante) ───
  // Todos requieren body `codEst=USER` y referer `consultaEstadoDeuda_Estudiante`.

  Map<String, String> _deudaBody() {
    final u = _currentUser ?? '';
    return {'codEst': u};
  }

  static const _deudaRef = 'consultaEstadoDeuda_Estudiante';

  /// Cuotas pendientes (futuras) — `consultarPensiones`.
  /// Fila: `[descripcion, fechaVenc dd-MM-yyyy, currency, importe, mora, total, observacion]`
  Future<List<Payment>> pensionesPendientes() async {
    final rows = await _memoPostList(
      'consultarPensiones', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 6)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map(Payment.fromDebtRow)
        .toList();
  }

  /// Cuotas VENCIDAS — `consultartotalPensiones` (el nombre engaña).
  Future<List<Payment>> pensionesVencidas() async {
    final rows = await _memoPostList(
      'consultartotalPensiones', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 6)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map(Payment.fromDebtRow)
        .toList();
  }

  /// Tasas vencidas — `consultarTasas`.
  /// Fila: `[descripcion, currency, importe, observacion]`
  Future<List<Fee>> tasasIntranet() async {
    final rows = await _memoPostList(
      'consultarTasas', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 3)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map((r) {
      String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
      return Fee(
        description: at(0),
        currency: at(1),
        amount: double.tryParse(at(2)) ?? 0,
        note: at(3),
      );
    }).toList();
  }

  /// Matrícula vencida — `consultarMatricula`.
  Future<List<Payment>> matriculaVencida() async {
    final rows = await _memoPostList(
      'consultarMatricula', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 3)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .where((r) => r[0]?.toString().trim() != '--')
        .map((r) {
      String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
      final monto = double.tryParse(at(2)) ?? 0;
      return Payment(
        description: at(0),
        currency: at(1),
        amount: monto,
        lateFee: 0,
        total: monto,
        note: 'Matrícula vencida',
        dueDateRaw: '',
      );
    }).toList();
  }

  /// Histórico completo de pagos (`consultarUltimasOperaciones` con codEst).
  /// Sin `codEst` el endpoint solo devuelve 2 pagos antiguos. Con codEst
  /// devuelve los 30+ pagos reales del estudiante.
  Future<List<PaymentRecord>> historicoPagos() async {
    final rows = await _memoPostList(
      'consultarUltimasOperaciones', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 9)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map(PaymentRecord.fromIntranetRow)
        .toList();
  }

  /// Total acumulado de pensiones (Intranet `consultartotalPensiones`).
  /// Devuelve resumen — un solo número o varias filas con totales.
  Future<double> totalPensiones() async {
    final rows = await _memoPostList(
      'consultartotalPensiones', const {}, referer: 'inicio',
    );
    final r = rows.whereType<List<dynamic>>().firstWhere(
          (r) => r.isNotEmpty &&
              !(r[0]?.toString().toLowerCase().contains('no hay') ?? false),
          orElse: () => const [],
        );
    if (r.isEmpty) return 0;
    return double.tryParse(r.first?.toString().trim() ?? '') ?? 0;
  }

  /// Periodos en los que el estudiante está/estuvo matriculado.
  /// `consultarPeriodosMatriculados` — fila: `[anio, periodo]`.
  /// El último de la lista es el más reciente → lo marcamos como activo.
  Future<List<Term>> periodosMatriculados() async {
    final rows = await _memoPostList(
      'consultarPeriodosMatriculados', const {}, referer: 'inicio',
    );
    final valid = rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 2)
        .where((r) =>
            !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .toList();
    return List.generate(valid.length, (i) {
      final t = Term.fromIntranetRow(valid[i]);
      if (i != valid.length - 1) return t;
      return Term(
        id: t.id,
        label: t.label,
        year: t.year,
        number: t.number,
        isActive: true,
      );
    });
  }

  /// Reducción de deuda / beneficios aplicados (Intranet `consultarReduccionDeuda`).
  Future<List<Payment>> reduccionDeuda() async {
    final rows = await _memoPostList(
      'consultarReduccionDeuda', _deudaBody(), referer: _deudaRef,
    );
    return rows
        .whereType<List<dynamic>>()
        .where((r) => r.length >= 3)
        .where((r) => !(r[0]?.toString().toLowerCase().contains('no hay') ?? false))
        .map((r) {
      String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
      final monto = double.tryParse(at(2)) ?? 0;
      return Payment(
        description: at(1).isNotEmpty ? at(1) : 'Descuento',
        currency: 'S/.',
        amount: -monto,
        lateFee: 0,
        total: -monto,
        note: at(3),
        dueDateRaw: at(0),
      );
    }).toList();
  }

  /// Estudiante reconstruido desde Intranet: `datosEstudianteMatriculado`
  /// (IDs) + 1ª fila de `consultarConstanciaMatriculaEstudiante` (nombres
  /// legibles + nivel + modalidad).
  Future<Student?> infoEstudiante({
    required int anio,
    required int periodo,
  }) async {
    List<dynamic> basico = const [];
    try {
      final rows = await _memoGetList(
        'datosEstudianteMatriculado',
        referer: 'inicio',
      );
      if (rows.isNotEmpty && rows.first is List) basico = rows.first as List;
    } catch (_) {}

    final constancia = await constanciaMatricula(anio, periodo);
    if (constancia.codigo.isEmpty && basico.isEmpty) return null;
    return Student.fromIntranetData(datosBasico: basico, constancia: constancia);
  }

  void invalidate() {
    _ready = false;
    _cache.clear();
  }
}

class _Cached {
  _Cached(this.future, this.at);
  final Future<List<dynamic>> future;
  final DateTime at;
}
