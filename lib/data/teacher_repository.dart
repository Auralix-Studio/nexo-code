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
        final ini = _normHm(
          s(h['horaInicio'] ?? h['startTime'] ?? h['horaIni']),
        );
        final fin = _normHm(s(h['horaFin'] ?? h['endTime']));
        final dia = s(h['dia'] ?? h['diaSemana']);
        var idDia = i(h['idDia'] ?? h['diaSemanaID'] ?? h['dia']);
        // Si SIGMA manda el día solo como nombre ("LUNES"), lo traducimos;
        // con 0 la clase nunca aparecía en "Hoy" ni en su día del horario.
        if (idDia < 1 || idDia > 7) idDia = _diaDesdeNombre(dia);
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

  /// "8:0" / "8:00:00" → "08:00:00"-compatible "HH:MM[:SS]" con ceros a la
  /// izquierda, para que ordenar y comparar horas como texto sea correcto.
  static String _normHm(String raw) {
    final t = raw.trim();
    final p = t.split(':');
    if (p.length < 2) return t;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return t;
    final base = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
    return p.length > 2 ? '$base:${p[2].padLeft(2, '0')}' : base;
  }

  static int _diaDesdeNombre(String nombre) {
    final n = nombre
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i');
    if (n.isEmpty) return 0;
    const dias = ['lu', 'ma', 'mi', 'ju', 'vi', 'sa', 'do'];
    for (var k = 0; k < dias.length; k++) {
      if (n.startsWith(dias[k])) return k + 1;
    }
    return 0;
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

  /// Registra o corrige una nota en SIGMA con la forma real del cliente
  /// oficial (ver docs/evaluacion-endpoints-docente.md §9):
  ///
  /// ```json
  /// { "Notas": [ { "matricula_asignatura_id", "tipo_unidad_id",
  ///                "tipo_nota_id", "nota_id" (solo UpdateNota), "nota" } ] }
  /// ```
  ///
  /// - Sin `nota_id` previo → `Docente/InsertarNotas`.
  /// - Con `nota_id` → `Docente/UpdateNota`.
  ///
  /// Se niega a enviar nada si falta algún id o si el componente agrupa más de
  /// una nota (su valor es un promedio y escribirlo pisaría notas reales).
  Future<void> guardarNota({
    required String? matriculaAsignaturaId,
    required EvaluationGrade evaluacion,
    required double nota,
  }) async {
    final matricula = int.tryParse((matriculaAsignaturaId ?? '').trim());
    final unidad = evaluacion.tipoUnidadId;
    final tipoNota = evaluacion.tipoNotaId;
    if (matricula == null || unidad == null || tipoNota == null) {
      throw const BadRequestException(
        'Faltan datos de SIGMA para registrar esta nota. '
        'Actualiza la lista de alumnos e inténtalo de nuevo.',
        status: 422,
      );
    }
    if (evaluacion.noteCount > 1) {
      throw const BadRequestException(
        'Este componente tiene varias notas; su valor es un promedio. '
        'Edítalo desde SIGMA para no sobrescribir notas individuales.',
        status: 422,
      );
    }
    if (nota.isNaN || nota < 0 || nota > 20) {
      throw const BadRequestException(
        'La nota debe estar entre 0 y 20.',
        status: 422,
      );
    }
    final notaId = evaluacion.notaId;
    final item = <String, Object>{
      'matricula_asignatura_id': matricula,
      'tipo_unidad_id': unidad,
      'tipo_nota_id': tipoNota,
      if (notaId != null) 'nota_id': notaId,
      'nota': nota,
    };
    final result = await _api.post<void>(
      notaId == null ? 'Docente/InsertarNotas' : 'Docente/UpdateNota',
      body: {
        'Notas': [item],
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

  /// ⚠ NO IMPLEMENTADO con datos verificados. El guardado real de asistencia
  /// (`Docente/InsertaRegistroAsistencia`) tiene la forma:
  ///   { fecha_asistencia, asistencia: [ { matricula_asignatura_id,
  ///     estado_asist_id, cod_cursal, tipo_unidad_id } ] }
  /// Requiere el catálogo numérico de estados (`estado_asist_id`), el
  /// `tipo_unidad_id` y el `cod_cursal`, que solo se obtienen de respuestas
  /// reales (GetAsistencia + getTipoUnidadesV2). Enviar una forma adivinada
  /// podría registrar asistencia incorrecta, así que se bloquea a propósito.
  /// Ver docs/evaluacion-endpoints-docente.md.
  Future<void> guardarAsistenciaDelDia({
    required String cleAuto,
    required DateTime date,
    required Map<String, String> estados,
  }) async {
    throw const BadRequestException(
      'El registro de asistencia desde la app aún no está disponible: '
      'requiere verificar el catálogo de estados de SIGMA.',
      status: 501,
    );
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
}
