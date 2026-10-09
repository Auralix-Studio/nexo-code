/// Modelos del módulo docente derivados del cliente oficial de SIGMA
/// (`sigma.upla.edu.pe`, bundle `assets/index-*.js`). Cada clase indica el
/// endpoint y la pantalla de SIGMA que replica.
library;

int? _int(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

double? _double(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.').trim());
}

String _str(Object? v) => v?.toString() ?? '';

/// Palabras que van en minúscula dentro de un nombre ("Base de Datos I").
const _minorWords = {
  'a',
  'al',
  'con',
  'de',
  'del',
  'e',
  'el',
  'en',
  'la',
  'las',
  'lo',
  'los',
  'o',
  'para',
  'por',
  'sin',
  'sobre',
  'su',
  'sus',
  'u',
  'y',
};

final _roman = RegExp(r'^(I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII)$');

String _capitalizeWord(String w) {
  final lower = w.toLowerCase();
  return lower.isEmpty
      ? lower
      : '${lower[0].toUpperCase()}${lower.substring(1)}';
}

/// Nombre legible de una asignatura o carrera de SIGMA: sin los paréntesis
/// ("(2026-2)", "(ELECTIVO)") y en mayúsculas y minúsculas, con los números
/// romanos intactos. "BASE DE DATOS I (2026-2)" → "Base de Datos I".
String readableName(String raw) {
  final clean = raw
      .replaceAll(RegExp(r'\s*\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final words = clean.split(' ');
  return [
    for (var i = 0; i < words.length; i++)
      if (_roman.hasMatch(words[i].toUpperCase()))
        words[i].toUpperCase()
      else if (i > 0 && _minorWords.contains(words[i].toLowerCase()))
        words[i].toLowerCase()
      else
        // "TEORÍA-PRÁCTICA" → "Teoría-Práctica".
        words[i].split('-').map(_capitalizeWord).join('-'),
  ].join(' ');
}

/// Día de SIGMA → `DateTime.weekday` (lunes = 1 … domingo = 7).
const _weekdays = {
  'LUNES': 1,
  'MARTES': 2,
  'MIERCOLES': 3,
  'MIÉRCOLES': 3,
  'JUEVES': 4,
  'VIERNES': 5,
  'SABADO': 6,
  'SÁBADO': 6,
  'DOMINGO': 7,
};

int weekdayFromSigma(String day) => _weekdays[day.trim().toUpperCase()] ?? 0;

/// Bloque de horario de una sección, con el id de horario que SIGMA usa como
/// `cod_cursal` al corregir asistencia.
///
/// Replica `MT()` + `a2n()` del frontend: el texto `horario` se agrupa por día
/// (ordenado domingo → sábado) y los ids de `id` ("419329, 419321") se asignan
/// por índice de día, no por bloque.
class TeacherBlock {
  final String id;
  final int weekday;
  final String dayName;
  final String start;
  final String end;

  /// `T` teoría, `P` práctica.
  final String type;
  const TeacherBlock({
    required this.id,
    required this.weekday,
    required this.dayName,
    required this.start,
    required this.end,
    required this.type,
  });

  static String _hm(String t) {
    final p = t.trim().split(':');
    return p.length >= 2 ? '${p[0].padLeft(2, '0')}:${p[1]}' : t.trim();
  }

  static int _minutes(String hm) {
    final p = hm.split(':');
    if (p.length < 2) return -1;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  /// La clase está en curso en [now] (mismo día y hora dentro del bloque).
  bool isOngoing(DateTime now) {
    if (now.weekday != weekday) return false;
    final m = now.hour * 60 + now.minute;
    return m >= _minutes(start) && m <= _minutes(end);
  }

  /// Parsea `"Jueves 11:30:00 13:00:00 P, Miércoles 10:45:00 11:30:00 T"`
  /// junto con `ids` = `"419329, 419321"`.
  static List<TeacherBlock> parse(String? horario, String ids) {
    if (horario == null || horario.trim().isEmpty) return const [];
    final idList = ids.split(',').map((e) => e.trim()).toList();
    // Orden de SIGMA (`Cot`): Domingo=1 … Sábado=7.
    int sigmaOrder(int wd) => wd == 7 ? 1 : wd + 1;
    final byDay = <int, List<List<String>>>{};
    final dayNames = <int, String>{};
    for (final part in horario.split(',')) {
      final t = part.trim().split(RegExp(r'\s+'));
      if (t.length < 3) continue;
      final wd = weekdayFromSigma(t[0]);
      if (wd == 0) continue;
      dayNames[wd] = t[0];
      byDay.putIfAbsent(wd, () => []).add(t);
    }
    final days = byDay.keys.toList()
      ..sort((a, b) => sigmaOrder(a).compareTo(sigmaOrder(b)));
    final out = <TeacherBlock>[];
    for (var i = 0; i < days.length; i++) {
      final wd = days[i];
      final blocks = byDay[wd]!..sort((a, b) => a[1].compareTo(b[1]));
      for (final t in blocks) {
        out.add(
          TeacherBlock(
            id: i < idList.length ? idList[i] : '',
            weekday: wd,
            dayName: dayNames[wd]!,
            start: _hm(t[1]),
            end: _hm(t[2]),
            type: t.length > 3 ? t[3].toUpperCase() : '',
          ),
        );
      }
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'weekday': weekday,
    'dia': dayName,
    'ini': start,
    'fin': end,
    'tipo': type,
  };

  factory TeacherBlock.fromJson(Map<String, dynamic> j) => TeacherBlock(
    id: _str(j['id']),
    weekday: _int(j['weekday']) ?? 0,
    dayName: _str(j['dia']),
    start: _str(j['ini']),
    end: _str(j['fin']),
    type: _str(j['tipo']),
  );
}

/// Catálogo de estados de asistencia de SIGMA (`estado_asist_id`).
abstract final class AttendanceCode {
  static const none = 0;
  static const present = 1;
  static const absent = 2;
  static const justified = 3;
  static const suspended = 4;
}

/// Una marca de asistencia registrada (`GetAsistencia` → `detalle[]`).
class AttendanceMark {
  final int asistenciaId;

  /// Fecha y hora de la sesión tal como la guardó SIGMA.
  final DateTime date;
  final int state;
  final int tipoUnidadId;
  const AttendanceMark({
    required this.asistenciaId,
    required this.date,
    required this.state,
    required this.tipoUnidadId,
  });

  DateTime get day => DateTime(date.year, date.month, date.day);

  factory AttendanceMark.fromJson(Map<String, dynamic> j) {
    final raw = _str(j['fecha_asistencia'] ?? j['fecha']);
    return AttendanceMark(
      asistenciaId: _int(j['asistencia_id']) ?? 0,
      date: DateTime.tryParse(raw.replaceFirst(' ', 'T')) ?? DateTime(1970),
      state: _int(j['estado_asist_id'] ?? j['estado']) ?? 0,
      tipoUnidadId: _int(j['tipo_unidad_id']) ?? 0,
    );
  }
}

/// Alumno en la hoja de asistencia (`Docente/GetAsistencia`).
class AttendanceStudent {
  final String code;
  final String name;
  final String matriculaAsignaturaId;

  /// `cod_cursal` del alumno (puede venir como lista "a, b"; SIGMA usa el 1.º).
  final String codCursal;
  final String observacion;

  /// Porcentaje de asistencia acumulado que calcula SIGMA.
  final double? percent;
  final List<AttendanceMark> marks;
  const AttendanceStudent({
    required this.code,
    required this.name,
    required this.matriculaAsignaturaId,
    required this.codCursal,
    required this.observacion,
    required this.percent,
    required this.marks,
  });

  /// Matrícula suspendida: SIGMA la registra siempre con estado 4.
  bool get isSuspended {
    final o = observacion.trim().toLowerCase();
    return o == 'suspensión' || o == 'suspension';
  }

  /// SIGMA resalta en rojo a quien tiene ≤ 70 % de asistencia.
  bool get atRisk => percent != null && percent! <= 70;

  String get firstCodCursal => codCursal.split(',').first.trim();

  List<AttendanceMark> marksOn(DateTime day) => marks
      .where(
        (m) =>
            m.date.year == day.year &&
            m.date.month == day.month &&
            m.date.day == day.day,
      )
      .toList();

  factory AttendanceStudent.fromJson(Map<String, dynamic> j) {
    final det = j['detalle'];
    final marks = det is List
        ? det
              .whereType<Map>()
              .map((e) => AttendanceMark.fromJson(e.cast<String, dynamic>()))
              .toList()
        : <AttendanceMark>[];
    marks.sort((a, b) => a.date.compareTo(b.date));
    return AttendanceStudent(
      code: _str(j['codigo']),
      name: _str(j['nombreCompleto'] ?? j['nombre_completo']).trim(),
      matriculaAsignaturaId: _str(
        j['matricula_asignatura_id'] ?? j['matriculaAsignaturaId'],
      ),
      codCursal: _str(j['cod_cursal']),
      observacion: _str(j['observacion']).trim(),
      percent: _double(j['asistencia']),
      marks: marks,
    );
  }
}

/// Hoja de asistencia de una sección.
class AttendanceSheet {
  final List<AttendanceStudent> students;
  const AttendanceSheet(this.students);

  /// Sesiones registradas en la unidad [tipoUnidadId] (o todas si es null),
  /// tomando como referencia al primer alumno como hace SIGMA. Cada sesión es
  /// la marca con su fecha/hora exacta.
  List<DateTime> sessions({int? tipoUnidadId}) {
    final set = <DateTime>{};
    for (final s in students) {
      for (final m in s.marks) {
        if (tipoUnidadId == null || m.tipoUnidadId == tipoUnidadId) {
          set.add(m.date);
        }
      }
    }
    return set.toList()..sort();
  }

  /// Hay asistencia registrada en [day] (cualquier unidad).
  bool hasRecordsOn(DateTime day) =>
      students.any((s) => s.marksOn(day).isNotEmpty);

  ({int present, int absent, int justified, int total}) totals() {
    var p = 0, a = 0, j = 0, t = 0;
    for (final s in students) {
      for (final m in s.marks) {
        t++;
        if (m.state == AttendanceCode.present) p++;
        if (m.state == AttendanceCode.absent) a++;
        if (m.state == AttendanceCode.justified) j++;
      }
    }
    return (present: p, absent: a, justified: j, total: t);
  }

  factory AttendanceSheet.fromJson(Object? raw) {
    if (raw is! List) return const AttendanceSheet([]);
    return AttendanceSheet(
      raw
          .whereType<Map>()
          .map((e) => AttendanceStudent.fromJson(e.cast<String, dynamic>()))
          .where((s) => s.code.isNotEmpty)
          .toList(),
    );
  }
}

/// Tipo de nota de una unidad (`Asignatura/getTipoNota?tipoUnidad=`).
class GradeType {
  final int id;
  final String abbr;
  final String description;
  final double maxValue;
  final double minPass;

  /// Cuántas columnas de este tipo admite la unidad (`tipo_nota_cant_max`).
  final int maxCount;
  final String colorHex;
  const GradeType({
    required this.id,
    required this.abbr,
    required this.description,
    required this.maxValue,
    required this.minPass,
    required this.maxCount,
    required this.colorHex,
  });

  /// `tipo_nota_escala` viene como "0 - 20    "; SIGMA toma el máximo.
  static double parseMax(String escala) {
    final nums = RegExp(r'\d+(?:[.,]\d+)?')
        .allMatches(escala)
        .map((m) => double.tryParse(m.group(0)!.replaceAll(',', '.')))
        .whereType<double>()
        .toList();
    return nums.isEmpty ? 20 : nums.last;
  }

  factory GradeType.fromJson(Map<String, dynamic> j) => GradeType(
    id: _int(j['tipo_nota_id']) ?? 0,
    abbr: _str(j['tipo_nota_abr']).trim(),
    description: _str(j['tipo_nota_desc']).trim(),
    maxValue: parseMax(_str(j['tipo_nota_escala'])),
    minPass: _double(j['minimo_aprob']) ?? 10.5,
    maxCount: _int(j['tipo_nota_cant_max']) ?? 1,
    colorHex: _str(j['tipo_nota_color']),
  );
}

/// Una nota individual registrada (`NotasEstudianteResumenV1` →
/// `unidades[].grupos[].notas[]`).
class GradeCell {
  final int unidadId;
  final int tipoNotaId;

  /// Posición de la nota dentro de su grupo (columna 0, 1…).
  final int ordinal;
  final int notaId;
  final double? value;
  const GradeCell({
    required this.unidadId,
    required this.tipoNotaId,
    required this.ordinal,
    required this.notaId,
    required this.value,
  });

  static List<GradeCell> fromUnidades(Object? unidades) {
    final out = <GradeCell>[];
    if (unidades is! List) return out;
    for (final u in unidades.whereType<Map>()) {
      final unidadId = _int(u['unidadId']) ?? 0;
      final grupos = u['grupos'];
      if (grupos is! List) continue;
      for (final g in grupos.whereType<Map>()) {
        final tipo = _int(g['idTipoNota']) ?? 0;
        final notas = g['notas'];
        if (notas is! List) continue;
        var i = 0;
        for (final n in notas.whereType<Map>()) {
          out.add(
            GradeCell(
              unidadId: unidadId,
              tipoNotaId: tipo,
              ordinal: i++,
              notaId: _int(n['idNota']) ?? 0,
              value: _double(n['valor']),
            ),
          );
        }
      }
    }
    return out;
  }
}

/// Una nota a enviar a `Docente/InsertarNotas` (sin [notaId]) o
/// `Docente/UpdateNota` (con [notaId]).
class GradeWrite {
  final String matricula;
  final int unidadId;
  final int tipoNotaId;
  final int? notaId;
  final double nota;
  const GradeWrite({
    required this.matricula,
    required this.unidadId,
    required this.tipoNotaId,
    required this.nota,
    this.notaId,
  });

  bool get isUpdate => notaId != null && notaId != 0;

  Map<String, dynamic> toInsertJson() => {
    'matricula_asignatura_id': matricula,
    'tipo_unidad_id': unidadId,
    'tipo_nota_id': tipoNotaId,
    'nota': nota,
  };

  Map<String, dynamic> toUpdateJson() => {
    'matricula_asignatura_id': matricula,
    'nota_id': notaId,
    'tipo_unidad_id': unidadId,
    'tipo_nota_id': tipoNotaId,
    'nota': nota,
  };
}

/// Clase del día para marcación virtual (`Docente/getAsistenciaDocente`).
class VirtualClass {
  final String code;
  final String subject;
  final String career;
  final String level;
  final String section;
  final DateTime? day;
  final String start;
  final String end;
  final int toleranceStart;
  final int toleranceEnd;

  /// `00:00:00` si aún no marcó.
  final String markIn;
  final String markOut;
  const VirtualClass({
    required this.code,
    required this.subject,
    required this.career,
    required this.level,
    required this.section,
    required this.day,
    required this.start,
    required this.end,
    required this.toleranceStart,
    required this.toleranceEnd,
    required this.markIn,
    required this.markOut,
  });

  static bool _empty(String t) => t.trim().isEmpty || t.trim() == '00:00:00';
  bool get hasIn => !_empty(markIn);
  bool get hasOut => !_empty(markOut);
  bool get canMarkIn => !hasIn;
  bool get canMarkOut => hasIn && !hasOut;

  factory VirtualClass.fromJson(Map<String, dynamic> j) => VirtualClass(
    code: _str(j['codigo']),
    subject: _str(j['asignatura']).trim(),
    career: _str(j['car_Id']).trim(),
    level: _str(j['nivel']).trim(),
    section: _str(j['seccion']).trim(),
    day: DateTime.tryParse(_str(j['dia_marcado'])),
    start: _str(j['hora_ini']),
    end: _str(j['hora_fin']),
    toleranceStart: _int(j['tol_ini']) ?? 0,
    toleranceEnd: _int(j['tol_fin']) ?? 0,
    markIn: _str(j['marc_entrada']),
    markOut: _str(j['marc_salida']),
  );
}

/// Respuesta de SIGMA a una marcación: `mensaje` = "S - texto" (éxito),
/// "I - texto" (informativo) o "E - texto" (error).
({String kind, String text}) parseSigmaMessage(String? mensaje) {
  final m = (mensaje ?? '').trim();
  final i = m.indexOf(' - ');
  if (i > 0 && i <= 2) {
    return (kind: m.substring(0, i).trim(), text: m.substring(i + 3).trim());
  }
  return (kind: '', text: m);
}

/// Resultado de una escritura en SIGMA: [error] legible si falló, o el
/// [message] de confirmación que devolvió SIGMA.
typedef SaveResult = ({String? error, String? message});
