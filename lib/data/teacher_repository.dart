import 'package:nexo/data/api_client.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class TeacherRepository {
  TeacherRepository(this._api);
  final ApiClient _api;
  Future<TeacherInfo?> infoDocente() async {
    final res = await _api.get<TeacherInfo>(
      'Teacher/GetInfoDocenteV1',
      decode: (raw) {
        if (raw is Map) {
          return TeacherInfo.fromJson(raw.cast<String, dynamic>());
        }
        return const TeacherInfo(code: '', firstName: '', lastName: '');
      },
    );
    return res.data;
  }

  Future<List<TeacherSubject>> asignaturas() async {
    final res = await _api.get<List<TeacherSubject>>(
      'Teacher/GetAsignaturaDocenteV1',
      decode: (raw) {
        if (raw is! List) return const <TeacherSubject>[];
        return raw
            .whereType<Map>()
            .map((e) => TeacherSubject.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  Future<List<ScheduleClass>> getHorario() async {
    final res = await _api.get<List<ScheduleClass>>(
      'Schedule/getListaHorario',
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

  Future<List<TeacherStudent>> estudiantesSeccion(String codSaltem) async {
    final res = await _api.get<List<TeacherStudent>>(
      'Teacher/ListarEstudianteComple',
      query: {'codSaltem': codSaltem},
      decode: (raw) {
        if (raw is! List) return const <TeacherStudent>[];
        return raw
            .whereType<Map>()
            .map((e) => TeacherStudent.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  Future<List<TeacherStudent>> notasResumen({
    required String tipoCalificacion,
    required String cleAuto,
  }) async {
    final res = await _api.get<List<TeacherStudent>>(
      'Teacher/NotasEstudianteResumenV1',
      query: {'tipoCalificacion': tipoCalificacion, 'cleAuto': cleAuto},
      decode: (raw) {
        if (raw is! List) return const <TeacherStudent>[];
        return raw
            .whereType<Map>()
            .map((e) => TeacherStudent.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  Future<void> updateNota({
    required String cleAuto,
    required String codigoAlumno,
    required String grade,
  }) async {
    await _api.post<void>(
      'Teacher/UpdateNota',
      body: {'cleAuto': cleAuto, 'codigoAlumno': codigoAlumno, 'nota': grade},
      decode: (_) {},
    );
  }

  Future<List<EvaluationGrade>> notasDetalle({
    required String cleAuto,
    required String codigoAlumno,
  }) async {
    List<EvaluationGrade> tipos = [];
    try {
      final t1 = await _getTipoNota('1');
      final t2 = await _getTipoNota('2');
      tipos = [...t1, ...t2];
    } catch (_) {}
    if (tipos.isEmpty) {
      tipos = const [
        EvaluationGrade(
          code: 'U1-P1',
          description: 'Práctica calificada 1',
          weight: 10.0,
        ),
        EvaluationGrade(
          code: 'U1-P2',
          description: 'Práctica calificada 2',
          weight: 10.0,
        ),
        EvaluationGrade(
          code: 'U1-EX',
          description: 'Examen parcial 1',
          weight: 20.0,
        ),
        EvaluationGrade(
          code: 'U2-P1',
          description: 'Práctica calificada 3',
          weight: 10.0,
        ),
        EvaluationGrade(
          code: 'U2-P2',
          description: 'Práctica calificada 4',
          weight: 10.0,
        ),
        EvaluationGrade(
          code: 'U2-PY',
          description: 'Proyecto integrador',
          weight: 15.0,
        ),
        EvaluationGrade(
          code: 'U2-EX',
          description: 'Examen final',
          weight: 25.0,
        ),
      ];
    }
    String? notaU1;
    String? notaU2;
    try {
      final res1 = await notasResumen(tipoCalificacion: '1', cleAuto: cleAuto);
      final alu1 = res1.firstWhere((a) => a.code == codigoAlumno);
      notaU1 = alu1.grade;
    } catch (_) {}
    try {
      final res2 = await notasResumen(tipoCalificacion: '2', cleAuto: cleAuto);
      final alu2 = res2.firstWhere((a) => a.code == codigoAlumno);
      notaU2 = alu2.grade;
    } catch (_) {}
    return tipos.map((t) {
      if (t.code.startsWith('U1') || t.code.contains('1')) {
        return t.copyWith(grade: notaU1);
      } else {
        return t.copyWith(grade: notaU2);
      }
    }).toList();
  }

  Future<List<EvaluationGrade>> _getTipoNota(String tipoUnidad) async {
    final res = await _api.get<List<EvaluationGrade>>(
      'Asignatura/getTipoNota',
      query: {'tipoUnidad': tipoUnidad},
      decode: (raw) {
        if (raw is! List) return const [];
        return raw.whereType<Map>().map((e) {
          return EvaluationGrade(
            code: (e['codigo'] ?? e['id'] ?? '').toString(),
            description: (e['descripcion'] ?? e['nombre'] ?? '').toString(),
            weight: double.tryParse((e['peso'] ?? '').toString()) ?? 0.0,
          );
        }).toList();
      },
    );
    return res.data ?? const [];
  }

  Future<void> updateEvaluacion({
    required String cleAuto,
    required String codigoAlumno,
    required String codigoEvaluacion,
    required String grade,
  }) async {
    await _api.post<void>(
      'Teacher/InsertarNotas',
      body: {
        'cleAuto': cleAuto,
        'codigoAlumno': codigoAlumno,
        'codigoEvaluacion': codigoEvaluacion,
        'nota': grade,
      },
      decode: (_) {},
    );
  }

  Future<List<DailyAttendance>> asistenciaAlumno({
    required String cleAuto,
    required String codigoAlumno,
  }) async {
    final res = await _api.get<List<DailyAttendance>>(
      'Teacher/GetAsistencia',
      query: {'cleAuto': cleAuto, 'codigoAlumno': codigoAlumno},
      decode: (raw) {
        if (raw is! List) return const [];
        return raw.whereType<Map>().map((e) {
          final fStr = e['fecha']?.toString() ?? '';
          DateTime? date;
          try {
            final parts = fStr.split('-');
            if (parts.length == 3) {
              date = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            }
          } catch (_) {}
          return DailyAttendance(
            date: date ?? DateTime.now(),
            state: e['estado']?.toString() ?? 'P',
          );
        }).toList();
      },
    );
    return res.data ?? const [];
  }

  Future<Map<String, String>> asistenciaDelDia({
    required String cleAuto,
    required DateTime date,
  }) async {
    final res = await _api.get<List<dynamic>>(
      'Teacher/GetAsistencia',
      query: {'cleAuto': cleAuto},
      decode: (raw) => raw is List ? raw : const [],
    );
    final list = res.data ?? const [];
    final map = <String, String>{};
    final targetFmt =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
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

  Future<void> guardarAsistenciaDelDia({
    required String cleAuto,
    required DateTime date,
    required Map<String, String> estados,
  }) async {
    final targetFmt =
        '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    final payload = estados.entries
        .map(
          (entry) => {
            'cleAuto': cleAuto,
            'fecha': targetFmt,
            'codigoAlumno': entry.key,
            'estado': entry.value,
          },
        )
        .toList();
    await _api.post<void>(
      'Teacher/InsertaRegistroAsistencia',
      body: payload,
      decode: (_) {},
    );
  }
}
