import 'dart:typed_data';

import 'package:nexo/core/errors.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Módulo docente servido por la API de Nexo (`/teaching/*`, ver
/// `nexo-backend/docs/api-models.md`).
///
/// El backend une las dos listas de secciones de la universidad, da un id
/// propio a cada sección (`sec_…`) y se queda con los ids internos: para leer
/// o guardar basta el id de la sección y el código del alumno. Aquí se
/// traduce a los modelos que ya usan las pantallas, que siguen igual:
///
/// * [TeacherSubject.id] es el id de Nexo;
/// * `matriculaAsignaturaId` de un alumno es su código;
/// * `notaId` de una nota es su columna + 1 (0/null = columna nueva);
/// * una sesión de asistencia se reconoce por su fecha y hora.
class NexoTeacherRepository {
  NexoTeacherRepository(this._directory);

  final DirectoryService _directory;

  Future<T> _call<T>(Future<T> Function() fn) async {
    await _directory.ensureConnected();
    return fn();
  }

  /// Perfil del propio docente (`GET /teaching/me`).
  Future<TeacherInfo> me() async =>
      teacherInfoFromNexo(await _call(_directory.client.teachingMe));

  /// Hora oficial de la universidad, como hora de pared de Lima.
  Future<DateTime> serverTime() async {
    final body = await _call(_directory.client.teachingServerTime);
    return limaWallClock(_text(body['now'])) ?? DateTime.now();
  }

  /// Registro auxiliar de la sección en `pdf` o `xlsx`.
  Future<({Uint8List bytes, String filename})> report(
    TeacherSubject section, {
    required String format,
  }) async {
    final r = await _call(
      () => _directory.client.teachingReport(section.id, format),
    );
    final safe = section.shortName.replaceAll(RegExp(r'[^\w\- ]'), '').trim();
    return (
      bytes: r.bytes,
      filename:
          r.filename ?? 'Registro auxiliar $safe ${section.section}.$format',
    );
  }

  Future<List<TeacherSubject>> sections() async => (await _call(
    _directory.client.teachingSections,
  )).map(teacherSubjectFromNexo).toList();

  Future<List<TeacherStudent>> roster(String sectionId) async {
    final body = await _call(() => _directory.client.teachingRoster(sectionId));
    return _maps(body['students']).map(teacherStudentFromNexo).toList();
  }

  /// Unidades de notas con sus tipos de nota (una sola llamada).
  Future<List<({TeacherUnitCatalog unit, List<GradeType> types})>> gradeUnits(
    String sectionId,
  ) async {
    final rows = await _call(
      () => _directory.client.teachingGradeUnits(sectionId),
    );
    return [
      for (final u in rows)
        (
          unit: TeacherUnitCatalog(
            id: (u['unit_id'] as num?)?.toInt() ?? 0,
            name: _text(u['name']),
            enabled: u['open'] == true,
          ),
          types: _maps(u['types']).map(gradeTypeFromNexo).toList(),
        ),
    ];
  }

  Future<({AttendanceSheet sheet, List<TeacherUnitCatalog> units})> attendance(
    String sectionId,
  ) async {
    final body = await _call(
      () => _directory.client.teachingAttendance(sectionId),
    );
    return (
      sheet: attendanceSheetFromNexo(body),
      units: [
        for (final u in _maps(body['units']))
          TeacherUnitCatalog(
            id: (u['unit_id'] as num?)?.toInt() ?? 0,
            name: _text(u['name']),
            enabled: u['open'] == true,
          ),
      ],
    );
  }

  /// Guarda notas agrupadas por unidad y tipo. Lanza si alguna no se guardó.
  Future<String?> saveGrades(String sectionId, List<GradeWrite> rows) async {
    var saved = 0;
    final failed = <String>[];
    final groups = <(int, int), List<GradeWrite>>{};
    for (final r in rows) {
      groups.putIfAbsent((r.unidadId, r.tipoNotaId), () => []).add(r);
    }
    for (final MapEntry(key: (unit, type), value: list) in groups.entries) {
      final body = await _call(
        () => _directory.client.teachingWriteGrades(
          sectionId,
          gradeWriteBody(unit, type, list),
        ),
      );
      saved += (body['saved'] as num?)?.toInt() ?? 0;
      failed.addAll(_failures(body['failed']));
    }
    return _outcome(saved, failed, 'nota', 'notas');
  }

  /// Registra una sesión nueva; el backend toma la hora de la universidad.
  Future<String?> takeAttendance(
    String sectionId, {
    required int unidadId,
    required List<({AttendanceStudent student, int state})> marks,
  }) async {
    final body = await _call(
      () => _directory.client.teachingTakeAttendance(sectionId, {
        'unit_id': unidadId,
        'marks': [
          for (final m in marks)
            if (attendanceWord(m.state) case final state?)
              {'student': m.student.code, 'state': state},
        ],
      }),
    );
    return _outcome(
      (body['saved'] as num?)?.toInt() ?? 0,
      _failures(body['failed']),
      'marca',
      'marcas',
    );
  }

  /// Corrige marcas ya registradas, una llamada por sesión.
  Future<String?> correctAttendance(
    String sectionId,
    List<({AttendanceMark mark, AttendanceStudent student, int state})> changes,
  ) async {
    var saved = 0;
    final failed = <String>[];
    final bySession = <String, List<Map<String, String>>>{};
    for (final c in changes) {
      final state = attendanceWord(c.state);
      if (state == null) continue;
      bySession.putIfAbsent(sessionIdOf(c.mark.date), () => []).add({
        'student': c.student.code,
        'state': state,
      });
    }
    for (final MapEntry(key: session, value: marks) in bySession.entries) {
      final body = await _call(
        () => _directory.client.teachingCorrectAttendance(sectionId, session, {
          'marks': marks,
        }),
      );
      saved += (body['saved'] as num?)?.toInt() ?? 0;
      failed.addAll(_failures(body['failed']));
    }
    return _outcome(saved, failed, 'marca', 'marcas');
  }

  Future<List<VirtualClass>> virtualClasses() async => (await _call(
    _directory.client.teachingVirtualClasses,
  )).map(virtualClassFromNexo).toList();

  /// Marca entrada o salida; devuelve el mensaje con el formato de SIGMA
  /// (`"S - …"`) que ya interpreta la pantalla.
  Future<String?> punch(String classId) async {
    final body = await _call(() => _directory.client.teachingPunch(classId));
    final kind = switch (body['result']) {
      'ok' || 'success' => 'S',
      'info' => 'I',
      'error' => 'E',
      // Sin resultado la marca no está confirmada: no se da por hecha.
      _ => throw const BadRequestException(
        'La universidad no confirmó la marcación.',
        status: 200,
      ),
    };
    final message = _text(body['message']);
    if (kind == 'E') {
      throw BadRequestException(
        message.isEmpty ? 'No se pudo marcar.' : message,
        status: 200,
      );
    }
    return message.isEmpty ? null : '$kind - $message';
  }

  Future<List<TeacherPunch>> punches(DateTime from, DateTime to) async =>
      (await _call(
        () => _directory.client.teachingPunches(_ymd(from), _ymd(to)),
      )).map(teacherPunchFromNexo).toList();

  Future<List<TeacherClassCompliance>> compliance(
    DateTime from,
    DateTime to,
  ) async => (await _call(
    () => _directory.client.teachingCompliance(_ymd(from), _ymd(to)),
  )).map(complianceFromNexo).toList();
}

// --- Mapeos -------------------------------------------------------------------

/// `GET /teaching/me` → [TeacherInfo].
TeacherInfo teacherInfoFromNexo(Map<String, dynamic> json) => TeacherInfo(
  code: _text(json['code']),
  firstName: _text(json['first_name']),
  lastName: _text(json['last_name']),
  faculty: json['faculty']?.toString(),
  specialty: json['specialty']?.toString(),
);

/// `"2026-10-07T12:59:09-05:00"` → hora de pared de Lima, sin convertir a la
/// zona del dispositivo.
DateTime? limaWallClock(String raw) {
  final m = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(raw.trim());
  if (m == null) return null;
  final p = [for (var i = 1; i <= 6; i++) int.parse(m.group(i)!)];
  return DateTime(p[0], p[1], p[2], p[3], p[4], p[5]);
}

/// Clases de la semana del docente, sacadas de sus secciones.
List<ScheduleClass> teacherScheduleFromSubjects(List<TeacherSubject> subjects) {
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

const _dayNames = [
  '',
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String _dayName(Object? weekday) {
  final d = (weekday as num?)?.toInt() ?? 0;
  return d >= 1 && d <= 7 ? _dayNames[d] : '';
}

/// Una sección de `GET /teaching/sections` → [TeacherSubject].
TeacherSubject teacherSubjectFromNexo(Map<String, dynamic> json) {
  final course = _map(json['course']);
  final room = _map(json['room']);
  final elective = json['elective'] == true;
  return TeacherSubject(
    id: _text(json['id']),
    code: _text(course['code']),
    // Las pantallas reconocen la electiva por el sufijo de SIGMA.
    subject: '${_text(course['name'])}${elective ? ' (ELECTIVO)' : ''}',
    section: _text(json['section']),
    periodo: _text(json['term']),
    enrolledCount: (json['enrolled'] as num?)?.toInt(),
    nrc: _text(json['nrc']),
    carrera: _text(json['career']),
    modalidad: _modalityLabel(json['modality']),
    sede: _text(json['campus']),
    local: _text(room['building']),
    aula: [
      _text(room['building']),
      _text(room['name']),
      if (room['capacity'] != null) 'AFORO: ${room['capacity']}',
    ].where((p) => p.isNotEmpty).join(' - '),
    ciclo: _text(json['cycle']),
    blocks: [
      for (final b in _maps(json['schedule']))
        TeacherBlock(
          id: '',
          weekday: (b['weekday'] as num?)?.toInt() ?? 0,
          dayName: _dayName(b['weekday']),
          start: _text(b['start']),
          end: _text(b['end']),
          type: switch (b['kind']) {
            'practice' => 'P',
            'lab' => 'L',
            _ => 'T',
          },
        ),
    ],
  );
}

/// Un alumno de `GET /teaching/sections/{id}/students` → [TeacherStudent].
///
/// Se rearma con la forma de SIGMA para que el modelo (y su caché) quede
/// igual: el código ocupa el lugar del id de matrícula y cada nota lleva su
/// columna + 1 como `idNota`.
TeacherStudent teacherStudentFromNexo(Map<String, dynamic> json) {
  final code = _text(json['code']);
  return TeacherStudent.fromJson({
    'codigo': code,
    'nombreCompleto': _text(json['name']),
    'asistencia': json['attendance_percent']?.toString(),
    'notaFinal': json['final_grade']?.toString(),
    'matricula_asignatura_id': code,
    'observacion': json['suspended'] == true ? 'Suspensión' : '',
    'unidades': [
      for (final u in _maps(json['units']))
        {
          'unidadId': u['unit_id'],
          'nombre': _text(u['name']),
          'porcentaje': u['weight_percent'],
          'promedioUnidad': u['average'],
          'grupos': [
            for (final e in _maps(u['evaluations']))
              {
                'idTipoNota': e['type_id'],
                'tipoNotaAbr': _text(e['abbr']),
                'peso': e['weight_percent'],
                'promedio': _mean(e['grades']),
                'notas': [
                  for (final (i, g) in _list(e['grades']).indexed)
                    {'idNota': i + 1, 'valor': g},
                ],
              },
          ],
        },
    ],
  });
}

double? _mean(Object? grades) {
  final values = _list(grades).whereType<num>().toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

GradeType gradeTypeFromNexo(Map<String, dynamic> json) => GradeType(
  id: (json['type_id'] as num?)?.toInt() ?? 0,
  abbr: _text(json['abbr']),
  description: _text(json['name']),
  maxValue: (json['max'] as num?)?.toDouble() ?? 20,
  minPass: (json['passing'] as num?)?.toDouble() ?? 10.5,
  maxCount: (json['max_columns'] as num?)?.toInt() ?? 1,
  colorHex: _text(json['color']),
);

/// `GET /teaching/sections/{id}/attendance` → [AttendanceSheet], con la
/// forma de SIGMA que lee el modelo.
AttendanceSheet attendanceSheetFromNexo(Map<String, dynamic> json) {
  final unitOf = {
    for (final s in _maps(json['sessions'])) _text(s['id']): s['unit_id'],
  };
  return AttendanceSheet.fromJson([
    for (final s in _maps(json['students']))
      {
        'codigo': _text(s['code']),
        'nombreCompleto': _text(s['name']),
        'matricula_asignatura_id': _text(s['code']),
        'cod_cursal': '',
        'observacion': s['suspended'] == true ? 'Suspensión' : '',
        'asistencia': s['percent'],
        'detalle': [
          for (final m in _maps(s['marks']))
            {
              'asistencia_id': 0,
              'fecha_asistencia': _text(m['session']),
              'estado_asist_id': _attendanceCode(m['state']),
              'tipo_unidad_id': unitOf[_text(m['session'])],
            },
        ],
      },
  ]);
}

int _attendanceCode(Object? state) => switch (state) {
  'present' => AttendanceCode.present,
  'absent' => AttendanceCode.absent,
  'justified' => AttendanceCode.justified,
  'suspended' => AttendanceCode.suspended,
  _ => AttendanceCode.none,
};

/// Estado de la app → palabra de la API. Sin marca no se envía; un alumno
/// suspendido va como presente y el backend lo registra como suspendido.
String? attendanceWord(int state) => switch (state) {
  AttendanceCode.present || AttendanceCode.suspended => 'present',
  AttendanceCode.absent => 'absent',
  AttendanceCode.justified => 'justified',
  _ => null,
};

/// Fecha y hora de una sesión → su id en la API (`2026-10-29T14:41:00`).
String sessionIdOf(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}T'
      '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// Cuerpo de `PUT /teaching/sections/{id}/grades`: columna = `notaId - 1`
/// si la nota ya existe; sin columna, el backend usa la siguiente libre.
Map<String, dynamic> gradeWriteBody(
  int unit,
  int type,
  List<GradeWrite> rows,
) => {
  'unit_id': unit,
  'type_id': type,
  'grades': [
    for (final r in rows)
      {
        'student': r.matricula,
        'value': r.nota,
        if (r.isUpdate) 'column': r.notaId! - 1,
      },
  ],
};

VirtualClass virtualClassFromNexo(Map<String, dynamic> json) {
  final now = DateTime.now();
  return VirtualClass(
    code: _text(json['id']),
    subject: _text(json['course']),
    career: _text(json['career']),
    level: '',
    section: _text(json['section']),
    day: DateTime(now.year, now.month, now.day),
    start: _text(json['start']),
    end: _text(json['end']),
    toleranceStart:
        (_map(json['tolerance'])['before_minutes'] as num?)?.toInt() ?? 0,
    toleranceEnd:
        (_map(json['tolerance'])['after_minutes'] as num?)?.toInt() ?? 0,
    markIn: _text(json['checked_in_at']).ifEmptyThen('00:00:00'),
    markOut: _text(json['checked_out_at']).ifEmptyThen('00:00:00'),
  );
}

TeacherPunch teacherPunchFromNexo(Map<String, dynamic> json) {
  final date = DateTime.tryParse(_text(json['date'])) ?? DateTime.now();
  return TeacherPunch(
    date: DateTime(date.year, date.month, date.day),
    time: _text(json['time']),
    weekday: (json['weekday'] as num?)?.toInt() ?? date.weekday,
    dayName: _dayName(json['weekday'] ?? date.weekday),
    mode: _text(json['mode']),
    location: _text(json['location']),
  );
}

TeacherClassCompliance complianceFromNexo(Map<String, dynamic> json) {
  final date = DateTime.tryParse(_text(json['date'])) ?? DateTime.now();
  PunchStatus status(Object? s) => switch (s) {
    'marked' => PunchStatus.marked,
    'missing' => PunchStatus.missing,
    'pending' => PunchStatus.pending,
    _ => PunchStatus.unknown,
  };
  return TeacherClassCompliance(
    date: DateTime(date.year, date.month, date.day),
    weekday: (json['weekday'] as num?)?.toInt() ?? date.weekday,
    dayName: _dayName(json['weekday'] ?? date.weekday),
    startTime: _text(json['start']),
    endTime: _text(json['end']),
    subject: _text(json['course']),
    level: '',
    section: _text(json['section']),
    modality: _modalityLabel(json['modality']),
    start: status(json['check_in']),
    end: status(json['check_out']),
  );
}

// --- Auxiliares ---------------------------------------------------------------

const _reasons = {
  'not_in_section': 'no está en la sección',
  'invalid_value': 'valor fuera de rango',
  'invalid_column': 'columna no válida',
  'column_gap': 'faltan notas anteriores',
  'unit_closed': 'unidad cerrada',
  'invalid_state': 'estado no válido',
  'no_mark': 'sin marca en esa sesión',
  'rejected': 'la universidad no lo aceptó',
  'upstream_unavailable': 'la universidad no respondió',
};

List<String> _failures(Object? failed) => [
  for (final f in _maps(failed))
    '${_text(f['student'])} (${_reasons[f['reason']] ?? _text(f['reason'])})',
];

/// Mensaje de éxito, o error legible si algo no se guardó.
String? _outcome(int saved, List<String> failed, String one, String many) {
  if (failed.isNotEmpty) {
    final head = saved > 0 ? 'Se guardaron $saved; ' : '';
    throw BadRequestException(
      '${head}no se guardaron: ${failed.join(', ')}.',
      status: 200,
    );
  }
  return saved == 1 ? 'Se guardó 1 $one.' : 'Se guardaron $saved $many.';
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _modalityLabel(Object? code) => switch (code) {
  'in_person' => 'PRESENCIAL',
  'distance' => 'A DISTANCIA',
  'blended' => 'SEMIPRESENCIAL',
  'virtual' => 'VIRTUAL',
  null => '',
  final other => other.toString().toUpperCase(),
};

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

List<dynamic> _list(Object? value) => value is List ? value : const [];

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>())
    : const [];

String _text(Object? value) => value?.toString() ?? '';

extension on String {
  String ifEmptyThen(String fallback) => isEmpty ? fallback : this;
}
