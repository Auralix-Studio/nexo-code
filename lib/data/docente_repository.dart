import 'package:nexo/data/api_client.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Mapea endpoints SIGMA del módulo Docente → modelos de dominio.
///
/// **Scaffold sin verificar con cuenta real.** El catálogo viene del bundle
/// JS del frontend SIGMA. Cuando un docente pruebe, ajustar los nombres de
/// campos en [DocenteInfo], [DocenteAsignatura] y [DocenteAlumno] si no
/// coinciden — los decodificadores son tolerantes a varios alias.
class DocenteRepository {
  DocenteRepository(this._api);
  final ApiClient _api;

  /// Perfil del docente autenticado.
  Future<DocenteInfo?> infoDocente() async {
    final res = await _api.get<DocenteInfo>(
      'Docente/GetInfoDocenteV1',
      decode: (raw) {
        if (raw is Map) {
          return DocenteInfo.fromJson(raw.cast<String, dynamic>());
        }
        return const DocenteInfo(codigo: '', nombres: '', apellidos: '');
      },
    );
    return res.data;
  }

  /// Asignaturas que dicta el docente en el periodo activo.
  Future<List<DocenteAsignatura>> asignaturas() async {
    final res = await _api.get<List<DocenteAsignatura>>(
      'Docente/GetAsignaturaDocenteV1',
      decode: (raw) {
        if (raw is! List) return const <DocenteAsignatura>[];
        return raw
            .whereType<Map>()
            .map((e) =>
                DocenteAsignatura.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  /// Horario de clases del docente.
  /// Real: `Horario/getListaHorario` (GET).
  Future<List<ScheduleClass>> getHorario() async {
    final res = await _api.get<List<ScheduleClass>>(
      'Horario/getListaHorario',
      decode: (raw) {
        if (raw is! List) return const <ScheduleClass>[];
        return raw
            .whereType<Map>()
            .map((e) => ScheduleClass.fromSigmaJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  /// Estudiantes inscritos en una sección del docente.
  /// [codSaltem] = identificador de la sección (visto en el bundle JS como
  /// `cleAuto` o `saltemId`).
  Future<List<DocenteAlumno>> estudiantesSeccion(String codSaltem) async {
    final res = await _api.get<List<DocenteAlumno>>(
      'Docente/ListarEstudianteComple',
      query: {'codSaltem': codSaltem},
      decode: (raw) {
        if (raw is! List) return const <DocenteAlumno>[];
        return raw
            .whereType<Map>()
            .map((e) => DocenteAlumno.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  /// Notas resumen de estudiantes para un tipo de calificación.
  /// `tipoCalificacion` = "1" parcial, "2" sustitutorio… (verificar).
  Future<List<DocenteAlumno>> notasResumen({
    required String tipoCalificacion,
    required String cleAuto,
  }) async {
    final res = await _api.get<List<DocenteAlumno>>(
      'Docente/NotasEstudianteResumenV1',
      query: {'tipoCalificacion': tipoCalificacion, 'cleAuto': cleAuto},
      decode: (raw) {
        if (raw is! List) return const <DocenteAlumno>[];
        return raw
            .whereType<Map>()
            .map((e) => DocenteAlumno.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  /// Registra/actualiza la nota CUMULATIVA de un alumno.
  /// Real: `Docente/UpdateNota` (POST).
  Future<void> updateNota({
    required String cleAuto,
    required String codigoAlumno,
    required String nota,
  }) async {
    await _api.post<void>(
      'Docente/UpdateNota',
      body: {
        'cleAuto': cleAuto,
        'codigoAlumno': codigoAlumno,
        'nota': nota,
      },
      decode: (_) {},
    );
  }

  /// Notas detalladas por evaluación de un alumno en una sección.
  /// Real: combina `Asignatura/getTipoNota?tipoUnidad=1` (y 2) con `Docente/NotasEstudianteResumenV1`.
  Future<List<NotaEvaluacion>> notasDetalle({
    required String cleAuto,
    required String codigoAlumno,
  }) async {
    List<NotaEvaluacion> tipos = [];
    try {
      final t1 = await _getTipoNota('1');
      final t2 = await _getTipoNota('2');
      tipos = [...t1, ...t2];
    } catch (_) {}

    if (tipos.isEmpty) {
      tipos = const [
        NotaEvaluacion(codigo: 'U1-P1', descripcion: 'Práctica calificada 1', peso: 10.0),
        NotaEvaluacion(codigo: 'U1-P2', descripcion: 'Práctica calificada 2', peso: 10.0),
        NotaEvaluacion(codigo: 'U1-EX', descripcion: 'Examen parcial 1', peso: 20.0),
        NotaEvaluacion(codigo: 'U2-P1', descripcion: 'Práctica calificada 3', peso: 10.0),
        NotaEvaluacion(codigo: 'U2-P2', descripcion: 'Práctica calificada 4', peso: 10.0),
        NotaEvaluacion(codigo: 'U2-PY', descripcion: 'Proyecto integrador', peso: 15.0),
        NotaEvaluacion(codigo: 'U2-EX', descripcion: 'Examen final', peso: 25.0),
      ];
    }

    String? notaU1;
    String? notaU2;
    try {
      final res1 = await notasResumen(tipoCalificacion: '1', cleAuto: cleAuto);
      final alu1 = res1.firstWhere((a) => a.codigo == codigoAlumno);
      notaU1 = alu1.nota;
    } catch (_) {}

    try {
      final res2 = await notasResumen(tipoCalificacion: '2', cleAuto: cleAuto);
      final alu2 = res2.firstWhere((a) => a.codigo == codigoAlumno);
      notaU2 = alu2.nota;
    } catch (_) {}

    return tipos.map((t) {
      if (t.codigo.startsWith('U1') || t.codigo.contains('1')) {
        return t.copyWith(nota: notaU1);
      } else {
        return t.copyWith(nota: notaU2);
      }
    }).toList();
  }

  Future<List<NotaEvaluacion>> _getTipoNota(String tipoUnidad) async {
    final res = await _api.get<List<NotaEvaluacion>>(
      'Asignatura/getTipoNota',
      query: {'tipoUnidad': tipoUnidad},
      decode: (raw) {
        if (raw is! List) return const [];
        return raw.whereType<Map>().map((e) {
          return NotaEvaluacion(
            codigo: (e['codigo'] ?? e['id'] ?? '').toString(),
            descripcion: (e['descripcion'] ?? e['nombre'] ?? '').toString(),
            peso: double.tryParse((e['peso'] ?? '').toString()) ?? 0.0,
          );
        }).toList();
      },
    );
    return res.data ?? const [];
  }

  /// Actualiza una evaluación específica del alumno.
  /// Real: `Docente/InsertarNotas` o `Docente/UpdateNota`.
  Future<void> updateEvaluacion({
    required String cleAuto,
    required String codigoAlumno,
    required String codigoEvaluacion,
    required String nota,
  }) async {
    await _api.post<void>(
      'Docente/InsertarNotas',
      body: {
        'cleAuto': cleAuto,
        'codigoAlumno': codigoAlumno,
        'codigoEvaluacion': codigoEvaluacion,
        'nota': nota,
      },
      decode: (_) {},
    );
  }

  /// Histórico de asistencia de un alumno en una sección.
  /// Real: `Docente/GetAsistencia`.
  Future<List<AsistenciaDia>> asistenciaAlumno({
    required String cleAuto,
    required String codigoAlumno,
  }) async {
    final res = await _api.get<List<AsistenciaDia>>(
      'Docente/GetAsistencia',
      query: {'cleAuto': cleAuto, 'codigoAlumno': codigoAlumno},
      decode: (raw) {
        if (raw is! List) return const [];
        return raw.whereType<Map>().map((e) {
          final fStr = e['fecha']?.toString() ?? '';
          DateTime? fecha;
          try {
            final parts = fStr.split('-');
            if (parts.length == 3) {
              fecha = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (_) {}
          return AsistenciaDia(
            fecha: fecha ?? DateTime.now(),
            estado: e['estado']?.toString() ?? 'P',
          );
        }).toList();
      },
    );
    return res.data ?? const [];
  }

  /// Lista la asistencia del día indicado para todos los alumnos de la sección.
  /// Real: `Docente/GetAsistencia` filtrado por fecha.
  Future<Map<String, String>> asistenciaDelDia({
    required String cleAuto,
    required DateTime fecha,
  }) async {
    final res = await _api.get<List<dynamic>>(
      'Docente/GetAsistencia',
      query: {'cleAuto': cleAuto},
      decode: (raw) => raw is List ? raw : const [],
    );
    final list = res.data ?? const [];
    final map = <String, String>{};
    final targetFmt = '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}';
    for (final e in list) {
      if (e is Map) {
        final fStr = e['fecha']?.toString() ?? '';
        if (fStr == targetFmt) {
          final cod = (e['codigoAlumno'] ?? e['est_Id'] ?? '').toString();
          final est = (e['estado'] ?? 'P').toString();
          if (cod.isNotEmpty) {
            map[cod] = est;
          }
        }
      }
    }
    return map;
  }

  /// Guarda la asistencia del día (codigo → estado).
  /// Real: `Docente/InsertaRegistroAsistencia`.
  Future<void> guardarAsistenciaDelDia({
    required String cleAuto,
    required DateTime fecha,
    required Map<String, String> estados,
  }) async {
    final targetFmt = '${fecha.day.toString().padLeft(2, '0')}-${fecha.month.toString().padLeft(2, '0')}-${fecha.year}';
    final payload = estados.entries.map((entry) => {
      'cleAuto': cleAuto,
      'fecha': targetFmt,
      'codigoAlumno': entry.key,
      'estado': entry.value,
    }).toList();

    await _api.post<void>(
      'Docente/InsertaRegistroAsistencia',
      body: payload,
      decode: (_) {},
    );
  }
}
