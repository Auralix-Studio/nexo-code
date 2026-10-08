import 'package:nexo/data/api_client.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class TeacherRepository {
  TeacherRepository(this._api);
  final ApiClient _api;
  Future<TeacherInfo?> infoDocente() async {
    // El perfil del propio docente sale de `Login/GetDatosEntidad`.
    // `Docente/GetInfoDocenteV1` es administrativo y exige `?filtro=` (400 sin él).
    // GetDatosEntidad trae: codigo, nombres, apellidos, isDocente y un objeto
    // `dependencia` con facultad/cargo/condicion/correoInstitucional.
    final res = await _api.get<TeacherInfo>(
      'Login/GetDatosEntidad',
      decode: (raw) {
        if (raw is! Map) {
          return const TeacherInfo(code: '', firstName: '', lastName: '');
        }
        final j = raw.cast<String, dynamic>();
        final dep = j['dependencia'];
        final depMap = dep is Map ? dep.cast<String, dynamic>() : const {};
        return TeacherInfo(
          code: (j['codigo'] ?? '').toString(),
          firstName: (j['nombres'] ?? '').toString().trim(),
          lastName: (j['apellidos'] ?? '').toString().trim(),
          faculty: (depMap['facultad'])?.toString(),
          specialty: (depMap['cargo'] ?? depMap['condicion'])?.toString(),
        );
      },
    );
    return res.data;
  }

  Future<List<TeacherSubject>> asignaturas() async {
    // SIGMA real: `Docente/GetAsignaturaDocente?modo=Notas|Asistencia`.
    // `GetAsignaturaDocenteV1?filtro=` es del módulo administrativo, no del
    // propio docente. Cada ítem trae plan/id(codSaltem)/nrc(asignID)/horario[].
    final res = await _api.get<List<TeacherSubject>>(
      'Docente/GetAsignaturaDocente',
      query: const {'modo': 'Notas'},
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
    // `Schedule/getListaHorario` NO existe en SIGMA. El horario del docente se
    // deriva del arreglo `horario[]` que trae cada asignatura de
    // `Docente/GetAsignaturaDocente`. Ver docs/evaluacion-endpoints-docente.md.
    //
    // Adaptador tolerante: aplana los bloques de cada asignatura a
    // `ScheduleClass`, probando variantes de nombre de campo. Si la respuesta
    // real difiere, degrada a vacío (nunca genera filas basura). ⚠ Los nombres
    // exactos de los campos del bloque deben confirmarse con una respuesta real.
    final res = await _api.get<List<ScheduleClass>>(
      'Docente/GetAsignaturaDocente',
      query: const {'modo': 'Asistencia'},
      decode: (raw) => _flattenHorario(raw),
    );
    return res.data ?? const [];
  }

  /// Aplana las asignaturas del docente (`GetAsignaturaDocente`) en bloques de
  /// horario individuales. Solo emite un `ScheduleClass` por bloque que tenga
  /// día y hora reconocibles.
  List<ScheduleClass> _flattenHorario(Object? raw) {
    if (raw is! List) return const <ScheduleClass>[];
    String s(Object? v) => v?.toString() ?? '';
    int i(Object? v) =>
        v is int ? v : (v is num ? v.toInt() : int.tryParse(s(v)) ?? 0);
    final out = <ScheduleClass>[];
    for (final asg in raw.whereType<Map>()) {
      final a = asg.cast<String, dynamic>();
      final bloques = (a['horario'] ?? a['horarios'] ?? a['horarioSelect']);
      if (bloques is! List) continue;
      for (final b in bloques.whereType<Map>()) {
        final h = b.cast<String, dynamic>();
        final ini = s(h['horaInicio'] ?? h['startTime'] ?? h['horaIni']);
        final fin = s(h['horaFin'] ?? h['endTime']);
        final dia = s(h['dia'] ?? h['diaSemana']);
        final idDia = i(h['idDia'] ?? h['diaSemanaID'] ?? h['dia']);
        if (ini.isEmpty && dia.isEmpty && idDia == 0) continue;
        out.add(
          ScheduleClass(
            id: s(a['id'] ?? a['cleAuto'] ?? a['saltemId']),
            nrc: s(a['nrc'] ?? a['asignID'] ?? a['asignaturaId']),
            subject: s(a['asignatura'] ?? a['nombreAsignatura']),
            modality: s(h['modalidad'] ?? h['idModalidad']),
            section: s(a['seccion']),
            level: s(a['nivel']),
            campus: s(a['sede']),
            building: s(h['local'] ?? a['local']),
            room: s(h['aula'] ?? a['aula']),
            capacity: i(a['capacidad'] ?? a['capacity']),
            note: s(a['observacion']),
            teacher: s(a['docente'] ?? a['teacher']),
            weekday: idDia,
            dayName: dia,
            startTime: ini,
            endTime: fin,
            typeCode: s(h['idTipo'] ?? h['tipo']),
          ),
        );
      }
    }
    return out;
  }

  /// Roster de la sección. OJO: `Docente/ListarEstudianteComple` devuelve `[]`
  /// con cuenta real; la lista real de alumnos (con nombre, nota final,
  /// asistencia y `matriculaAsignaturaId`) sale de `NotasEstudianteResumenV1`.
  /// Por eso el roster se obtiene de ahí, usando el `tipoCalif` de la sección.
  Future<List<TeacherStudent>> estudiantesSeccion({
    required String cleAuto,
    required int tipoCalif,
  }) {
    return notasResumen(
      tipoCalificacion: tipoCalif == 0 ? '12' : tipoCalif.toString(),
      cleAuto: cleAuto,
    );
  }

  Future<List<TeacherStudent>> notasResumen({
    required String tipoCalificacion,
    required String cleAuto,
  }) async {
    final res = await _api.get<List<TeacherStudent>>(
      'Docente/NotasEstudianteResumenV1',
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
    final result = await _api.post<void>(
      'Docente/UpdateNota',
      body: {'cleAuto': cleAuto, 'codigoAlumno': codigoAlumno, 'nota': grade},
      decode: (_) {},
    );
    _requireSaved(result);
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
    required String matriculaAsignaturaId,
    required int tipoUnidadId,
    required int tipoNotaId,
    required int? notaId,
    required String grade,
  }) async {
    final endpoint = notaId == null ? 'Docente/InsertarNotas' : 'Docente/UpdateNota';
    final result = await _api.post<void>(
      endpoint,
      body: {
        'Notas': [
          {
            'matricula_asignatura_id': matriculaAsignaturaId,
            'tipo_unidad_id': tipoUnidadId,
            'tipo_nota_id': tipoNotaId,
            'nota_id': ?notaId,
            'nota': num.tryParse(grade) ?? grade,
          }
        ]
      },
      decode: (_) {},
    );
    _requireSaved(result);
  }

  /// Lista de asistencias registradas (historial) de un alumno en la sección.
  /// SIGMA real: `Docente/GetAsistencia?plan=&codSaltem=&asignID=` devuelve la
  /// lista de alumnos; cada uno con un `detalle[]` de marcas por fecha.
  Future<List<DailyAttendance>> asistenciaAlumno({
    required String plan,
    required String codSaltem,
    required String asignID,
    required String codigoAlumno,
  }) async {
    final res = await _api.get<List<dynamic>>(
      'Docente/GetAsistencia',
      query: {'plan': plan, 'codSaltem': codSaltem, 'asignID': asignID},
      decode: (raw) => raw is List ? raw : const [],
    );
    final list = res.data ?? const [];
    for (final e in list.whereType<Map>()) {
      final cod = _codigoDe(e);
      if (cod != codigoAlumno) continue;
      final detalle = _detalleDe(e);
      return detalle
          .map((d) {
            final date = _parseFecha(_fechaDe(d));
            if (date == null) return null;
            return DailyAttendance(date: date, state: _estadoDe(d));
          })
          .whereType<DailyAttendance>()
          .toList();
    }
    return const [];
  }

  /// Estados de asistencia de todos los alumnos para una fecha concreta.
  /// Devuelve `codigo → estado`. Filtra el `detalle[]` de cada alumno por fecha.
  Future<Map<String, String>> asistenciaDelDia({
    required String plan,
    required String codSaltem,
    required String asignID,
    required DateTime date,
  }) async {
    final res = await _api.get<List<dynamic>>(
      'Docente/GetAsistencia',
      query: {'plan': plan, 'codSaltem': codSaltem, 'asignID': asignID},
      decode: (raw) => raw is List ? raw : const [],
    );
    final list = res.data ?? const [];
    final map = <String, String>{};
    for (final e in list.whereType<Map>()) {
      final cod = _codigoDe(e);
      if (cod.isEmpty) continue;
      for (final d in _detalleDe(e)) {
        final f = _parseFecha(_fechaDe(d));
        if (f != null && _mismoDia(f, date)) {
          map[cod] = _estadoDe(d);
          break;
        }
      }
    }
    return map;
  }

  Future<void> guardarAsistenciaDelDia({
    required String cleAuto,
    required DateTime date,
    required Map<String, String> estados,
    required List<TeacherStudent> students,
    required int? tipoUnidadId,
  }) async {
    final payload = {
      'fecha_asistencia': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} 00:00:00',
      'asistencia': students.where((s) => estados.containsKey(s.code)).map((s) {
        final stateCode = estados[s.code]!;
        int estadoId = 1;
        if (stateCode == 'F' || stateCode == '2') estadoId = 2;
        if (stateCode == 'T' || stateCode == '3') estadoId = 3;

        return {
          'matricula_asignatura_id': s.matriculaAsignaturaId ?? '',
          'estado_asist_id': estadoId,
          'cod_cursal': cleAuto,
          'tipo_unidad_id': tipoUnidadId ?? 121,
        };
      }).toList(),
    };
    final result = await _api.post<void>(
      'Docente/InsertaRegistroAsistencia',
      body: payload,
      decode: (_) {},
    );
    _requireSaved(result);
  }

  // ── Helpers de parseo del detalle de asistencia ──────────────────────────
  String _codigoDe(Map e) =>
      (e['codigo'] ?? e['est_Id'] ?? e['codigoAlumno'] ?? '').toString();

  List<Map> _detalleDe(Map e) {
    final d = e['detalle'] ?? e['detalles'] ?? e['asistencia'];
    return d is List ? d.whereType<Map>().toList() : const <Map>[];
  }

  String _fechaDe(Map d) =>
      (d['fecha_asistencia'] ?? d['fecha'] ?? d['fechaAsistencia'] ?? '')
          .toString();

  String _estadoDe(Map d) =>
      (d['estado'] ?? d['estado_asist_id'] ?? d['estadoAsistId'] ?? '')
          .toString();

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Acepta `YYYY-MM-DD[ hh:mm:ss]` y `DD-MM-YYYY`.
  DateTime? _parseFecha(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final datePart = s.split(' ').first;
    final p = datePart.split(RegExp(r'[-/]'));
    if (p.length != 3) return null;
    final a = int.tryParse(p[0]);
    final b = int.tryParse(p[1]);
    final c = int.tryParse(p[2]);
    if (a == null || b == null || c == null) return null;
    // Si el primer campo tiene 4 dígitos es YYYY-MM-DD; si no, DD-MM-YYYY.
    try {
      return p[0].length == 4
          ? DateTime(a, b, c)
          : DateTime(c, b, a);
    } catch (_) {
      return null;
    }
  }

  void _requireSaved(ApiEnvelope<void> result) {
    if (!result.success) {
      throw BadRequestException(
        result.mensaje ?? 'El servidor no confirmó el guardado.',
        status: 200,
      );
    }
  }

  // ── Marcación del propio docente ──────────────────────────

  Future<dynamic> getAsistenciaDocente() async {
    final res = await _api.get<dynamic>('Docente/getAsistenciaDocente', decode: (j) => j);
    return res.data;
  }

  Future<void> marcarAsistenciaDocente(String codigo) async {
    final result = await _api.post<void>(
      'Docente/InsertaRegistroAsistenciaDocente?codigo=$codigo',
      body: {},
      decode: (_) {},
    );
    _requireSaved(result);
  }

  Future<dynamic> getAsistenciaDiariaDocente(DateTime inicio, DateTime fin, int pagina) async {
    final i = '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
    final f = '${fin.year}-${fin.month.toString().padLeft(2, '0')}-${fin.day.toString().padLeft(2, '0')}';
    final res = await _api.get<dynamic>(
      'Docente/getAsistenciaDiaria?fechaInicio=$i&fechaFin=$f&pagina=$pagina',
      decode: (j) => j,
    );
    return res.data;
  }

  Future<dynamic> getHistorialMarcacionDocente(DateTime inicio, DateTime fin, int pagina) async {
    final i = '${inicio.year}-${inicio.month.toString().padLeft(2, '0')}-${inicio.day.toString().padLeft(2, '0')}';
    final f = '${fin.year}-${fin.month.toString().padLeft(2, '0')}-${fin.day.toString().padLeft(2, '0')}';
    final res = await _api.get<dynamic>(
      'Docente/getHistorialMarcacion?fechaInicio=$i&fechaFin=$f&pagina=$pagina',
      decode: (j) => j,
    );
    return res.data;
  }

  /// Historial de marcación del docente (huella/virtual), tipado.
  Future<List<TeacherPunch>> historialMarcacion({
    required DateTime inicio,
    required DateTime fin,
    int pagina = 1,
  }) async {
    String f(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final res = await _api.get<List<TeacherPunch>>(
      'Docente/getHistorialMarcacion',
      query: {
        'fechaInicio': f(inicio),
        'fechaFin': f(fin),
        'pagina': '$pagina',
      },
      decode: (raw) {
        if (raw is! List) return const <TeacherPunch>[];
        return raw
            .whereType<Map>()
            .map((e) => TeacherPunch.fromJson(e.cast<String, dynamic>()))
            .toList();
      },
    );
    return res.data ?? const [];
  }

  Future<dynamic> getHoraServer() async {
    final res = await _api.get<dynamic>('Docente/GetHora', decode: (j) => j);
    return res.data;
  }
}
