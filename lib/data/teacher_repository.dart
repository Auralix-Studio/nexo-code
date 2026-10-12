import 'package:flutter/foundation.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Acceso al módulo docente de SIGMA. El contrato de cada endpoint (ruta,
/// parámetros y forma de los envíos) está tomado del cliente oficial
/// (`sigma.upla.edu.pe`, bundle `assets/index-*.js`); ver
/// docs/evaluacion-endpoints-docente.md.
class TeacherRepository {
  TeacherRepository(this._api);
  final ApiClient _api;

  /// Unidades que SIGMA oculta en la pantalla de asistencia.
  static const _attendanceHiddenUnits = {212, 214, 215, 115, 116};

  Future<TeacherInfo?> infoDocente() async {
    // El perfil del propio docente sale de `Login/GetDatosEntidad`.
    // `Docente/GetInfoDocenteV1` es administrativo y exige `?filtro=`.
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

  /// Secciones a cargo. Combina `GetAsignaturaDocente?modo=Notas` (ids para
  /// notas) con `modo=Asistencia` (ids de horario para asistencia, horario,
  /// aula, modalidad). Si la segunda falla, las secciones siguen sirviendo para
  /// notas.
  Future<List<TeacherSubject>> asignaturas() async {
    final notasF = _api.get<List<Map<String, dynamic>>>(
      'Docente/GetAsignaturaDocente',
      query: const {'modo': 'Notas'},
      decode: _maps,
    );
    final asisF = _api
        .get<List<Map<String, dynamic>>>(
          'Docente/GetAsignaturaDocente',
          query: const {'modo': 'Asistencia'},
          decode: _maps,
        )
        .then((r) => r.data ?? const <Map<String, dynamic>>[])
        .catchError((_) => const <Map<String, dynamic>>[]);
    final notas = (await notasF).data ?? const [];
    final asis = await asisF;
    return mergeAsignaturas(notas, asis);
  }

  static List<Map<String, dynamic>> _maps(Object? raw) => raw is List
      ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
      : const [];

  /// Cruza cada sección de `modo=Notas` con su par de `modo=Asistencia` por
  /// NRC; si hay varias con el mismo NRC, desempata por sección y carrera.
  @visibleForTesting
  static List<TeacherSubject> mergeAsignaturas(
    List<Map<String, dynamic>> notas,
    List<Map<String, dynamic>> asistencia,
  ) {
    String norm(Object? v) => (v ?? '').toString().trim().toUpperCase();
    final used = <int>{};
    final out = <TeacherSubject>[];
    for (final n in notas) {
      final base = TeacherSubject.fromJson(n);
      var best = -1;
      var bestScore = -1;
      for (var i = 0; i < asistencia.length; i++) {
        if (used.contains(i)) continue;
        final a = asistencia[i];
        if (norm(a['nrc']) != norm(n['nrc'])) continue;
        var score = 0;
        if (norm(a['seccion']) == norm(n['seccion'])) score += 2;
        if (norm(a['carrera']).startsWith(norm(n['carrera']))) score += 1;
        if (score > bestScore) {
          best = i;
          bestScore = score;
        }
      }
      if (best >= 0) {
        used.add(best);
        out.add(base.mergeAttendance(asistencia[best]));
      } else {
        out.add(base);
      }
    }
    return out;
  }

  /// Horario del docente. SIGMA no tiene un endpoint propio (y
  /// `Schedule/getListaHorario` no existe): cada asignatura de
  /// `GetAsignaturaDocente?modo=Asistencia` trae su `horario` como texto, que
  /// [asignaturas] ya convierte en [TeacherSubject.blocks]. Se arma desde ahí
  /// para no volver a pedir la misma lista.
  static List<ScheduleClass> scheduleFromSubjects(
    List<TeacherSubject> subjects,
  ) {
    final out = <ScheduleClass>[];
    for (final c in subjects) {
      final loc = ScheduleClass.parseLocation(c.aula);
      for (final b in c.blocks) {
        out.add(
          ScheduleClass(
            id: c.nrc,
            nrc: c.nrc,
            subject: c.displayName,
            modality: c.modalidad,
            section: c.section,
            level: c.ciclo,
            campus: c.sede,
            building: loc.building.isNotEmpty ? loc.building : c.local,
            room: loc.room,
            capacity: loc.capacity,
            note: c.carrera,
            teacher: '',
            weekday: b.weekday,
            dayName: b.dayName,
            startTime: b.start,
            endTime: b.end,
            typeCode: b.type,
          ),
        );
      }
    }
    return out;
  }

  /// Roster de la sección con notas. `Docente/ListarEstudianteComple` devuelve
  /// `[]` con cuenta real; la lista real sale de `NotasEstudianteResumenV1`.
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
      decode: (raw) => _maps(raw).map(TeacherStudent.fromJson).toList(),
    );
    return res.data ?? const [];
  }

  // ── Catálogos ────────────────────────────────────────────────────────────

  Future<List<TeacherUnitCatalog>> _unidades({
    required int tipoCalif,
    required String cursal,
    required String asiId,
    required String cleAuto,
  }) async {
    final res = await _api.get<List<TeacherUnitCatalog>>(
      'Asignatura/getTipoUnidadesV2',
      query: {
        'tipoCalif': '${tipoCalif == 0 ? 12 : tipoCalif}',
        'cursal': cursal,
        'asi_id': asiId,
        'cle_auto': cleAuto,
      },
      decode: (raw) => _maps(
        raw,
      ).map(TeacherUnitCatalog.fromJson).where((u) => u.id != 0).toList(),
    );
    return res.data ?? const [];
  }

  /// Unidades para registrar notas (pantalla "Listado de notas" de SIGMA:
  /// `cursal=0`, `asi_id=nrc`, `cle_auto=id`).
  Future<List<TeacherUnitCatalog>> unidadesNotas(TeacherSubject c) => _unidades(
    tipoCalif: c.tipoCalif,
    cursal: '0',
    asiId: c.nrc,
    cleAuto: c.id,
  );

  /// Unidades para asistencia (pantalla "Listado de asistencia": `cursal` =
  /// primer id de horario, `cle_auto=0`, sin las unidades especiales).
  Future<List<TeacherUnitCatalog>> unidadesAsistencia(TeacherSubject c) async {
    final list = await _unidades(
      tipoCalif: c.tipoCalif,
      cursal: c.attendanceCodSaltem.split(',').first.trim(),
      asiId: c.nrc,
      cleAuto: '0',
    );
    return list.where((u) => !_attendanceHiddenUnits.contains(u.id)).toList();
  }

  /// Tipos de nota (EV/DE/PR…) de una unidad, con escala y máximo de columnas.
  Future<List<GradeType>> tiposNota(int unidadId) async {
    final res = await _api.get<List<GradeType>>(
      'Asignatura/getTipoNota',
      query: {'tipoUnidad': '$unidadId'},
      decode: (raw) =>
          _maps(raw).map(GradeType.fromJson).where((t) => t.id != 0).toList(),
    );
    return res.data ?? const [];
  }

  /// Hora del servidor de SIGMA (hora de Lima). Se usa para la hora de la
  /// asistencia, igual que el cliente oficial. Si falla, hora local.
  Future<DateTime> horaServidor() async {
    try {
      final res = await _api.get<String>(
        'Docente/GetHora',
        decode: (raw) => raw?.toString() ?? '',
      );
      return parseServerTime(res.data ?? '') ?? DateTime.now();
    } catch (_) {
      return DateTime.now();
    }
  }

  /// `"2026-10-07T12:59:09.9331277-05:00"` → hora de pared de Lima, sin
  /// convertir a la zona del dispositivo.
  @visibleForTesting
  static DateTime? parseServerTime(String raw) {
    final m = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})',
    ).firstMatch(raw.trim());
    if (m == null) return null;
    final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
    return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
  }

  // ── Asistencia de alumnos ────────────────────────────────────────────────

  /// Hoja de asistencia de la sección. SIGMA:
  /// `GetAsistencia?plan=&codSaltem=<id de modo=Asistencia>&asignID=<nrc>`.
  Future<AttendanceSheet> asistencia(TeacherSubject c) async {
    final res = await _api.get<AttendanceSheet>(
      'Docente/GetAsistencia',
      query: {
        'plan': c.plan,
        'codSaltem': c.attendanceCodSaltem,
        'asignID': c.nrc,
      },
      decode: AttendanceSheet.fromJson,
    );
    return res.data ?? const AttendanceSheet([]);
  }

  /// Registra la asistencia de una sesión para todos los alumnos.
  Future<String?> registrarAsistencia({
    required DateTime fecha,
    required int unidadId,
    required List<({AttendanceStudent student, int state})> marks,
  }) async {
    final res = await _api.post<void>(
      'Docente/InsertaRegistroAsistencia',
      body: buildAttendanceInsert(
        fecha: fecha,
        unidadId: unidadId,
        marks: marks,
      ),
      decode: (_) {},
    );
    _requireSaved(res);
    return res.mensaje;
  }

  /// Forma exacta del cliente oficial:
  /// `{fecha_asistencia: "YYYY-MM-DD H:m:s", asistencia: [{matricula_asignatura_id,
  /// estado_asist_id, cod_cursal, tipo_unidad_id}]}`. Los alumnos con matrícula
  /// suspendida siempre van con estado 4.
  @visibleForTesting
  static Map<String, dynamic> buildAttendanceInsert({
    required DateTime fecha,
    required int unidadId,
    required List<({AttendanceStudent student, int state})> marks,
  }) {
    String two(int v) => v.toString().padLeft(2, '0');
    // SIGMA arma la hora sin ceros a la izquierda (`${h}:${m}:${s}`).
    final f =
        '${fecha.year}-${two(fecha.month)}-${two(fecha.day)} '
        '${fecha.hour}:${fecha.minute}:${fecha.second}';
    return {
      'fecha_asistencia': f,
      'asistencia': [
        for (final m in marks)
          {
            'matricula_asignatura_id': m.student.matriculaAsignaturaId,
            'estado_asist_id': m.student.isSuspended
                ? AttendanceCode.suspended
                : m.state,
            'cod_cursal': m.student.firstCodCursal,
            'tipo_unidad_id': unidadId,
          },
      ],
    };
  }

  /// Corrige marcas ya registradas. Forma del cliente oficial (edición por
  /// celda): `{asistencia: [{asistencia_id, matricula_asignatura_id,
  /// estado_asist_id}]}`; "Faltantes hoy" añade `cod_cursal` (id de horario).
  Future<String?> actualizarAsistencia(
    List<({AttendanceMark mark, AttendanceStudent student, int state})>
    changes, {
    String? codCursal,
  }) async {
    final res = await _api.post<void>(
      'Docente/ActualizarRegistroAsistencia',
      body: buildAttendanceUpdate(changes, codCursal: codCursal),
      decode: (_) {},
    );
    _requireSaved(res);
    return res.mensaje;
  }

  @visibleForTesting
  static Map<String, dynamic> buildAttendanceUpdate(
    List<({AttendanceMark mark, AttendanceStudent student, int state})>
    changes, {
    String? codCursal,
  }) => {
    'asistencia': [
      for (final c in changes)
        {
          'asistencia_id': c.mark.asistenciaId,
          'matricula_asignatura_id': c.student.matriculaAsignaturaId,
          'cod_cursal': ?codCursal,
          'estado_asist_id': c.state,
        },
    ],
  };

  // ── Notas ────────────────────────────────────────────────────────────────

  /// Inserta notas nuevas (una columna). Forma del cliente oficial:
  /// `{Notas: [{matricula_asignatura_id, tipo_unidad_id, tipo_nota_id, nota}]}`.
  Future<String?> insertarNotas(List<GradeWrite> rows) async {
    final res = await _api.post<void>(
      'Docente/InsertarNotas',
      body: {
        'Notas': [for (final r in rows) r.toInsertJson()],
      },
      decode: (_) {},
    );
    _requireSaved(res);
    return res.mensaje;
  }

  /// Modifica notas existentes (`nota_id` = `idNota`).
  Future<String?> actualizarNotas(List<GradeWrite> rows) async {
    final res = await _api.post<void>(
      'Docente/UpdateNota',
      body: {
        'Notas': [for (final r in rows) r.toUpdateJson()],
      },
      decode: (_) {},
    );
    _requireSaved(res);
    return res.mensaje;
  }

  /// Registro auxiliar de la sección (`Docente/GetReporteAuxiliar`), en
  /// `pdf` o `xlsx`, como los botones de "Listado de notas" de SIGMA.
  Future<({Uint8List bytes, String filename})> reporteAuxiliar(
    TeacherSubject c, {
    required String tipo,
  }) async {
    final r = await _api.getBytes(
      'Docente/GetReporteAuxiliar',
      query: {
        'codSaltem': c.id,
        'plan': c.plan,
        'asignID': c.nrc,
        'tipo': tipo,
        'tipoCalif': '${c.tipoCalif}',
      },
    );
    final safe = c.shortName.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return (
      bytes: r.bytes,
      filename: r.filename ?? 'Registro auxiliar $safe ${c.section}.$tipo',
    );
  }

  // ── Marcación del propio docente ─────────────────────────────────────────

  /// Clases del día pendientes de marcación virtual.
  Future<List<VirtualClass>> clasesVirtuales() async {
    final res = await _api.get<List<VirtualClass>>(
      'Docente/getAsistenciaDocente',
      decode: (raw) => _maps(raw).map(VirtualClass.fromJson).toList(),
    );
    return res.data ?? const [];
  }

  /// Marca entrada o salida (SIGMA decide cuál según el estado de la clase).
  /// Devuelve el mensaje de SIGMA ("S - …", "I - …", "E - …").
  Future<String?> marcarVirtual(String codigo) async {
    final res = await _api.post<void>(
      'Docente/InsertaRegistroAsistenciaDocente',
      query: {'codigo': codigo},
      decode: (_) {},
    );
    _requireSaved(res);
    return res.mensaje;
  }

  /// Historial de marcación del docente (huella/virtual), tipado.
  Future<List<TeacherPunch>> historialMarcacion({
    required DateTime inicio,
    required DateTime fin,
    int pagina = 1,
  }) async {
    final res = await _api.get<List<TeacherPunch>>(
      'Docente/getHistorialMarcacion',
      query: {
        'fechaInicio': _ymd(inicio),
        'fechaFin': _ymd(fin),
        'pagina': '$pagina',
      },
      decode: (raw) => _maps(raw).map(TeacherPunch.fromJson).toList(),
    );
    return res.data ?? const [];
  }

  /// Clases programadas del docente con el estado de marcación de entrada y
  /// salida. SIGMA: `Docente/getAsistenciaDiaria`.
  Future<List<TeacherClassCompliance>> cumplimiento({
    required DateTime inicio,
    required DateTime fin,
    int pagina = 1,
  }) async {
    final res = await _api.get<List<TeacherClassCompliance>>(
      'Docente/getAsistenciaDiaria',
      query: {
        'fechaInicio': _ymd(inicio),
        'fechaFin': _ymd(fin),
        'pagina': '$pagina',
      },
      decode: (raw) => _maps(raw).map(TeacherClassCompliance.fromJson).toList(),
    );
    return res.data ?? const [];
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _requireSaved(ApiEnvelope<void> result) {
    if (!result.success) {
      throw BadRequestException(
        result.mensaje ?? 'El servidor no confirmó el guardado.',
        status: 200,
      );
    }
  }
}
