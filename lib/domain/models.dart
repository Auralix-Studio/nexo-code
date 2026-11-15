import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/domain/teacher_models.dart';

export 'package:nexo/domain/teacher_models.dart';

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _toStr(Object? v) => v?.toString() ?? '';
bool _toBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t.isEmpty) return fallback;
    if (t == 'true' ||
        t == '1' ||
        t == 's' ||
        t == 'si' ||
        t == 'sí' ||
        t == 'y' ||
        t == 'yes') {
      return true;
    }
    if (t == 'false' || t == '0' || t == 'n' || t == 'no') {
      return false;
    }
  }
  return fallback;
}

double? parseGrade(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty || t == '-' || t == '--') return null;
  return double.tryParse(t);
}

bool isNewModel(int year, int periodo) =>
    year > 2026 || (year == 2026 && periodo >= 1);
String formatGrade(String? raw) {
  final n = parseGrade(raw);
  if (n == null) return '—';
  return n.toStringAsFixed(2);
}

class LoginResult {
  final String token;
  final String? refreshToken;
  final UserProfile? info;
  const LoginResult({required this.token, this.refreshToken, this.info});
}

class UserProfile {
  final String? code;
  final String? firstName;
  final String? lastName;
  final String? imagen;
  final bool isTeacher;
  const UserProfile({
    this.code,
    this.firstName,
    this.lastName,
    this.imagen,
    this.isTeacher = false,
  });
  String get displayName {
    final n = (firstName ?? '').trim();
    final a = (lastName ?? '').trim();
    return [n, a].where((s) => s.isNotEmpty).join(' ');
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    code: j['codigo'] as String?,
    firstName: j['nombres'] as String?,
    lastName: j['apellidos'] as String?,
    imagen: j['imagen'] as String?,
    isTeacher: _toBool(j['isDocente']),
  );
  Map<String, dynamic> toJson() => {
    'codigo': code,
    'nombres': firstName,
    'apellidos': lastName,
    'imagen': imagen,
    'isDocente': isTeacher,
  };
}

class GradesSummary {
  final double average;
  final int approvedCredits;
  final int totalCredits;
  const GradesSummary({
    required this.average,
    required this.approvedCredits,
    required this.totalCredits,
  });
  factory GradesSummary.fromJson(Map<String, dynamic> j) => GradesSummary(
    average: _toDouble(j['promedio']) ?? 0,
    approvedCredits: _toInt(j['creditosAprobados']) ?? 0,
    totalCredits: _toInt(j['creditosTotales']) ?? 0,
  );
  Map<String, dynamic> toJson() => {
    'promedio': average,
    'creditosAprobados': approvedCredits,
    'creditosTotales': totalCredits,
  };
}

class CourseGrade {
  final String code;
  final String subject;
  final String section;
  final String cycle;
  final double credit;
  final String? attendance;
  final String subjectType;
  final int year;
  final int periodNum;
  final String pf;
  final String pfp;
  final String complementary;
  final String cc;
  final String rank;
  final String pF1;
  final String pF2;
  final TermGrades firstTerm;
  final TermGrades secondTerm;
  const CourseGrade({
    required this.code,
    required this.subject,
    required this.section,
    required this.cycle,
    required this.credit,
    required this.attendance,
    required this.subjectType,
    required this.year,
    required this.periodNum,
    required this.pf,
    required this.pfp,
    required this.complementary,
    required this.cc,
    required this.rank,
    required this.pF1,
    required this.pF2,
    required this.firstTerm,
    required this.secondTerm,
  });
  factory CourseGrade.fromJson(Map<String, dynamic> j) => CourseGrade(
    code: _toStr(j['codigo']),
    subject: _toStr(j['asignatura']),
    section: _toStr(j['seccion']),
    cycle: _toStr(j['ciclo']),
    credit: _toDouble(j['credito']) ?? 0,
    attendance: j['asistencia'] == null ? null : _toStr(j['asistencia']),
    subjectType: _toStr(j['tipoAsignatura']),
    year: _toInt(j['mtr_Anio']) ?? 0,
    periodNum: _toInt(j['mtr_Periodo']) ?? 0,
    pf: _toStr(j['pf']).trim(),
    pfp: _toStr(j['pfp']).trim(),
    complementary: _toStr(j['complementario']).trim(),
    cc: _toStr(j['cc']),
    rank: _toStr(j['puesto']).trim(),
    pF1: _toStr(j['pF1']).trim(),
    pF2: _toStr(j['pF2']).trim(),
    firstTerm: TermGrades.fromJson(j, prefix: ''),
    secondTerm: TermGrades.fromJson(j, prefix: '_2'),
  );
  double? get currentGradeNum {
    for (final c in [pf, pfp]) {
      final n = parseGrade(c);
      if (n != null) return n;
    }
    return null;
  }

  String get currentGradeText {
    for (final c in [pf, pfp]) {
      if (parseGrade(c) != null) return formatGrade(c);
    }
    return '—';
  }

  bool get isApproved => PassingRule.current.passes(currentGradeNum);

  int? get asistenciaPct {
    final a = attendance;
    if (a == null) return null;
    return int.tryParse(a.trim());
  }

  bool get isClosed => cc.toLowerCase() == 'true';
}

class TermGrades {
  final List<String> practices;
  final String practicesAverage;
  final String researchWork;
  final String project;
  final String researchProjectAverage;
  final String exam;
  const TermGrades({
    required this.practices,
    required this.practicesAverage,
    required this.researchWork,
    required this.project,
    required this.researchProjectAverage,
    required this.exam,
  });
  factory TermGrades.fromJson(
    Map<String, dynamic> j, {
    required String prefix,
  }) {
    String f(String key) => _toStr(j[key]).trim();
    final pPrefix = prefix.isEmpty ? 'p' : '${prefix}P';
    final ntaPrefix = prefix.isEmpty ? 'nta' : '${prefix}Nta';
    return TermGrades(
      practices: [for (var i = 1; i <= 4; i++) f('$pPrefix$i')],
      practicesAverage: f('${ntaPrefix}P1'),
      researchWork: f('${ntaPrefix}TI1'),
      project: f('${ntaPrefix}PY1'),
      researchProjectAverage: f('${ntaPrefix}PromTiPy'),
      exam: f('${ntaPrefix}Parcial1'),
    );
  }

  double? get predictedPracticesAverage {
    final valid = practices
        .map((p) => parseGrade(p))
        .where((g) => g != null && g > 0)
        .toList();
    if (valid.isEmpty) return parseGrade(practicesAverage);

    final sum = valid.fold<double>(0, (a, b) => a + b!);
    return sum / valid.length;
  }

  String get displayPracticesAverage {
    final p = predictedPracticesAverage;
    if (p != null) return formatGrade(p.toStringAsFixed(2));
    return formatGrade(practicesAverage);
  }

  bool get isEmpty =>
      practices.every((p) => p.isEmpty) &&
      practicesAverage.isEmpty &&
      researchWork.isEmpty &&
      project.isEmpty &&
      exam.isEmpty;
}

class ReportCardCourse {
  final String enrollmentSubjectId;
  final String plan;
  final String code;
  final String name;
  final String section;
  final double credit;
  final String rawAttendance;
  final String rawAverage;
  // Nota vigesimal oficial (col. 9 de la boleta). El promedio crudo de algunos
  // cursos (talleres) viene en escala 0-100; esta columna siempre es vigesimal.
  final String rawVigesimal;
  final String state;
  const ReportCardCourse({
    required this.enrollmentSubjectId,
    required this.plan,
    required this.code,
    required this.name,
    required this.section,
    required this.rawAttendance,
    required this.rawAverage,
    required this.state,
    this.rawVigesimal = '',
    this.credit = 0,
  });
  factory ReportCardCourse.fromJson(Map<String, dynamic> j) => ReportCardCourse(
    enrollmentSubjectId: _toStr(j['matriculaAsignaturaId']),
    plan: _toStr(j['plan']),
    code: _toStr(j['codigo']),
    name: _toStr(j['nombre']),
    section: _toStr(j['seccion']),
    credit: _toDouble(j['credito']) ?? 0,
    rawAttendance: _toStr(j['asistenciaRaw']),
    rawAverage: _toStr(j['promedioRaw']),
    rawVigesimal: _toStr(j['notaVigesimalRaw']),
    state: _toStr(j['estado']),
  );
  Map<String, dynamic> toJson() => {
    'matriculaAsignaturaId': enrollmentSubjectId,
    'plan': plan,
    'codigo': code,
    'nombre': name,
    'seccion': section,
    'credito': credit,
    'asistenciaRaw': rawAttendance,
    'promedioRaw': rawAverage,
    'notaVigesimalRaw': rawVigesimal,
    'estado': state,
  };

  /// Promedio crudo del curso tal como aparece en la boleta (col. 8). Puede
  /// venir en escala 0-100 para talleres.
  double? get average => parseGrade(rawAverage);
  String get promedioText => formatGrade(rawAverage);

  /// Nota siempre en escala vigesimal: usa el promedio crudo si ya está en
  /// rango; si no (talleres 0-100), cae a la nota vigesimal oficial (col. 9).
  /// Es la que debe promediarse para el promedio del ciclo.
  double? get vigesimalAverage {
    final raw = parseGrade(rawAverage);
    if (raw != null && raw >= 0 && raw <= 20.5) return raw;
    return parseGrade(rawVigesimal);
  }

  int? get attendance => int.tryParse(rawAttendance.trim());
  bool get inProgress => state.toLowerCase().startsWith('dsp');
}

class EvidenceGrade {
  final String type;
  final String rawWeight;
  final String rawGrade;
  const EvidenceGrade({
    required this.type,
    required this.rawWeight,
    required this.rawGrade,
  });
  double? get grade => parseGrade(rawGrade);
  String get notaText => formatGrade(rawGrade);
}

class UnitGrades {
  final String name;
  final String rawWeight;
  final List<EvidenceGrade> evidences;
  final String rawAverage;
  const UnitGrades({
    required this.name,
    required this.rawWeight,
    required this.evidences,
    required this.rawAverage,
    this.serverAverage,
  });

  /// Promedio ya calculado por la API de Nexo (ponderado por evidencias).
  final double? serverAverage;
  double? get weight => parseGrade(rawWeight);

  double? get average => serverAverage ?? parseGrade(rawAverage);

  String get promedioText {
    final p = average;
    if (p != null) return formatGrade(p.toStringAsFixed(2));
    return formatGrade(rawAverage);
  }
}

class CourseGradeDetail {
  final List<UnitGrades> units;
  final String rawSubstitute;
  final String rawFinalAverage;
  final String state;
  const CourseGradeDetail({
    required this.units,
    required this.rawSubstitute,
    required this.rawFinalAverage,
    required this.state,
    this.serverAverage,
  });

  /// Promedio real del curso (con decimales) calculado por la API de Nexo.
  final double? serverAverage;
  bool get hasSubstitute => parseGrade(rawSubstitute) != null;
}

class EnrollmentCourse {
  final String code;
  final String subject;
  final String cycle;
  final String section;
  final String creditos;
  const EnrollmentCourse({
    required this.code,
    required this.subject,
    required this.cycle,
    required this.section,
    required this.creditos,
  });
  double get creditosNum => double.tryParse(creditos.trim()) ?? 0;
}

class EnrollmentCertificate {
  final String code;
  final String student;
  final String faculty;
  final String career;
  final String specialty;
  final String studyPlan;
  final String level;
  final int year;
  final int periodo;
  final String modality;
  final String photoUrl;
  final String careerLabel;
  final List<EnrollmentCourse> courses;
  final double totalCredits;
  const EnrollmentCertificate({
    required this.code,
    required this.student,
    required this.faculty,
    required this.career,
    required this.specialty,
    required this.studyPlan,
    required this.level,
    required this.year,
    required this.periodo,
    required this.modality,
    required this.photoUrl,
    required this.careerLabel,
    required this.courses,
    required this.totalCredits,
  });
  String get periodLabel =>
      '$year-${periodo == 1
          ? 'I'
          : periodo == 2
          ? 'II'
          : periodo}';
}

class PaymentInstallment {
  final String number;
  final double amount;
  final String rawDueDate;
  const PaymentInstallment({
    required this.number,
    required this.amount,
    required this.rawDueDate,
  });
  DateTime? get dueDate {
    final p = rawDueDate.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
}

class WifiCredential {
  final String username;
  final String password;
  const WifiCredential({required this.username, required this.password});
}

class TeacherInfo {
  final String code;
  final String firstName;
  final String lastName;
  final String? faculty;
  final String? specialty;
  const TeacherInfo({
    required this.code,
    required this.firstName,
    required this.lastName,
    this.faculty,
    this.specialty,
  });
  factory TeacherInfo.fromJson(Map<String, dynamic> j) => TeacherInfo(
    code: _toStr(j['codigo'] ?? j['doc_Id']),
    firstName: _toStr(j['nombres']),
    lastName: _toStr(j['apellidos']),
    faculty: j['facultad'] as String?,
    specialty: j['especialidad'] as String?,
  );
  String get displayName =>
      [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ').trim();
}

class TeacherSubject {
  /// Identificador de la sección (codSaltem en SIGMA). Es el handle que usan
  /// `ListarEstudianteComple?codSaltem=` y la vista de detalle del curso.
  final String id;
  final String code;
  final String subject;
  final String section;
  final String periodo;
  final int? enrolledCount;

  /// Plan de estudios de la sección. Requerido por
  /// `Docente/GetAsistencia?plan=&codSaltem=&asignID=`.
  final String plan;

  /// Id de asignatura (asignID). Requerido por `Docente/GetAsistencia`.
  final String nrc;

  /// Tipo de calificación de la sección (p. ej. 12). Es el `tipoCalificacion`
  /// que piden `NotasEstudianteResumenV1` y `getTipoUnidadesV2`.
  final int tipoCalif;

  /// `id` de la misma sección en `GetAsignaturaDocente?modo=Asistencia`
  /// ("419329, 419321"). Es el `codSaltem` que SIGMA manda a
  /// `Docente/GetAsistencia`; el `id` de `modo=Notas` devuelve una lista vacía.
  final String asistenciaId;
  final String carrera;
  final String modalidad;
  final String sede;
  final String local;
  final String aula;
  final String ciclo;
  final List<TeacherBlock> blocks;
  const TeacherSubject({
    required this.id,
    required this.code,
    required this.subject,
    required this.section,
    required this.periodo,
    this.enrolledCount,
    this.plan = '',
    this.nrc = '',
    this.tipoCalif = 0,
    this.asistenciaId = '',
    this.carrera = '',
    this.modalidad = '',
    this.sede = '',
    this.local = '',
    this.aula = '',
    this.ciclo = '',
    this.blocks = const [],
  });

  /// Alias semántico: en SIGMA la sección se identifica como `codSaltem`.
  String get codSaltem => id;

  /// Nombre sin el periodo final, p. ej. "BASE DE DATOS I".
  String get shortName =>
      subject.replaceAll(RegExp(r'\s*\([^)]*\d{4}[^)]*\)\s*$'), '').trim();

  /// Nombre para mostrar al docente: sin paréntesis y fácil de leer,
  /// p. ej. "Base de Datos I". Ver [readableName].
  String get displayName => readableName(subject);

  /// SIGMA marca las electivas en el nombre: "INTERNET DE LAS COSAS (ELECTIVO)".
  bool get isElective =>
      RegExp(r'\(\s*ELECTIV', caseSensitive: false).hasMatch(subject);

  /// Carrera sin la modalidad que SIGMA le añade al final
  /// ("… - PRESENCIAL"), legible.
  String get careerName => readableName(
    carrera.replaceAll(
      RegExp(
        r'\s*-\s*(PRESENCIAL|DISTANCIA|SEMIPRESENCIAL|VIRTUAL)\s*$',
        caseSensitive: false,
      ),
      '',
    ),
  );

  /// Ciclo sin ceros a la izquierda ("04" → "4").
  String get cycleLabel => '${int.tryParse(ciclo.trim()) ?? ciclo.trim()}';

  /// Bloque en curso ahora, si lo hay.
  TeacherBlock? ongoingBlock(DateTime now) {
    for (final b in blocks) {
      if (b.isOngoing(now)) return b;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'cleAuto': id,
    'codigo': code,
    'asignatura': subject,
    'seccion': section,
    'periodo': periodo,
    'matriculados': enrolledCount,
    'plan': plan,
    'nrc': nrc,
    'tipoCalif': tipoCalif,
    'asistenciaId': asistenciaId,
    'carrera': carrera,
    'modalidad': modalidad,
    'sede': sede,
    'local': local,
    'aula': aula,
    'ciclo': ciclo,
    'blocks': [for (final b in blocks) b.toJson()],
  };

  factory TeacherSubject.fromJson(Map<String, dynamic> j) {
    final asignatura = _toStr(j['asignatura'] ?? j['nombreAsignatura']);
    final nrc = _toStr(
      j['nrc'] ?? j['asignID'] ?? j['asignaturaId'] ?? j['asi_id'],
    );
    // SIGMA no manda un código corto ni el periodo como campo propio: el código
    // cae al NRC y el periodo se extrae del nombre, p. ej. "… (2026-2)".
    final periodo = _toStr(j['periodo'] ?? j['descripcionPeriodo']);
    final m = RegExp(r'\(([^)]*\d{4}[^)]*)\)').firstMatch(asignatura);
    return TeacherSubject(
      id: _toStr(
        j['cleAuto'] ?? j['id'] ?? j['codSaltem'] ?? j['saltemId'] ?? j['nrc'],
      ),
      code: _toStr(j['codigo'] ?? j['asg_Id']).ifEmpty(nrc),
      subject: asignatura,
      section: _toStr(j['seccion']),
      periodo: periodo.isNotEmpty ? periodo : (m?.group(1)?.trim() ?? ''),
      enrolledCount: _toInt(j['matriculados'] ?? j['cantMatriculados']),
      plan: _toStr(j['plan'] ?? j['planId'] ?? j['planEstId'] ?? j['codPlan']),
      nrc: nrc,
      tipoCalif: _toInt(j['tipoCalif'] ?? j['tipoCalificacion']) ?? 0,
      asistenciaId: _toStr(j['asistenciaId']),
      carrera: _toStr(j['carrera']),
      modalidad: _toStr(j['modalidad']),
      sede: _toStr(j['sede']),
      local: _toStr(j['local']),
      aula: _toStr(j['aula']),
      ciclo: _toStr(j['ciclo']),
      blocks: j['blocks'] is List
          ? (j['blocks'] as List)
                .whereType<Map>()
                .map((e) => TeacherBlock.fromJson(e.cast<String, dynamic>()))
                .toList()
          : const [],
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => trim().isEmpty ? fallback : this;
}

class EvaluationGrade {
  final String code;
  final String description;
  final double weight;
  final String? grade;
  final int? tipoUnidadId;
  final int? tipoNotaId;
  final int? notaId;

  const EvaluationGrade({
    required this.code,
    required this.description,
    required this.weight,
    this.grade,
    this.tipoUnidadId,
    this.tipoNotaId,
    this.notaId,
  });
  EvaluationGrade copyWith({String? grade}) => EvaluationGrade(
    code: code,
    description: description,
    weight: weight,
    grade: grade ?? this.grade,
    tipoUnidadId: tipoUnidadId,
    tipoNotaId: tipoNotaId,
    notaId: notaId,
  );
  double? get gradeNum =>
      double.tryParse((grade ?? '').replaceAll(',', '.').trim());
}

class TeacherUnit {
  final String name;
  final double weight;
  final double? average;
  final int? tipoUnidadId;
  final List<EvaluationGrade> grades;
  const TeacherUnit({
    required this.name,
    required this.weight,
    this.average,
    this.tipoUnidadId,
    required this.grades,
  });
  factory TeacherUnit.fromJson(Map<String, dynamic> j) {
    final groups = j['grupos'];
    final gradesList = <EvaluationGrade>[];
    if (groups is List) {
      for (final g in groups.whereType<Map>()) {
        final notasArr = g['notas'] as List?;
        final notaIdObj = (notasArr != null && notasArr.isNotEmpty)
            ? notasArr.first['idNota']
            : null;
        final isPending = notasArr == null || notasArr.isEmpty;
        gradesList.add(
          EvaluationGrade(
            code: _toStr(g['tipoNotaAbr']),
            description: _toStr(g['tipoNotaAbr']) == 'EV'
                ? 'Evidencia de Conocimiento'
                : _toStr(g['tipoNotaAbr']) == 'DE'
                ? 'Evidencia de Desempeño'
                : _toStr(g['tipoNotaAbr']) == 'PR'
                ? 'Evidencia de Producto'
                : _toStr(g['tipoNotaAbr']),
            weight: _toDouble(g['peso']) ?? 0,
            grade: isPending ? null : g['promedio']?.toString(),
            tipoUnidadId: _toInt(j['unidadId']),
            tipoNotaId: _toInt(g['idTipoNota']),
            notaId: _toInt(notaIdObj),
          ),
        );
      }
    }
    // Ordenar: EV, DE, PR
    gradesList.sort((a, b) {
      const order = {'EV': 1, 'DE': 2, 'PR': 3};
      final o1 = order[a.code] ?? 99;
      final o2 = order[b.code] ?? 99;
      return o1.compareTo(o2);
    });
    return TeacherUnit(
      name: _toStr(j['nombre']),
      weight: _toDouble(j['porcentaje']) ?? 0,
      average: _toDouble(j['promedioUnidad']),
      tipoUnidadId: _toInt(j['unidadId']),
      grades: gradesList,
    );
  }
}

class TeacherStudent {
  final String code;
  final String firstName;
  final String lastName;

  /// Nombre completo tal cual lo manda SIGMA (`nombreCompleto`, ya "APELLIDOS
  /// NOMBRES"). `NotasEstudianteResumenV1` no separa nombres/apellidos.
  final String? fullName;
  final String? attendance;
  final String? grade;

  /// Id de matrícula-asignatura del alumno en la sección. Es la clave que piden
  /// los guardados reales de notas y asistencia (`matricula_asignatura_id`).
  /// Ver docs/evaluacion-endpoints-docente.md.
  final String? matriculaAsignaturaId;

  /// Observación/estado de riesgo que devuelve SIGMA (p. ej. propenso).
  final String? observacion;
  final List<TeacherUnit> units;

  /// Cada nota registrada con su `idNota`, para editar/insertar por columna.
  final List<GradeCell> cells;

  /// `unidades` crudas de SIGMA; se guardan para reconstruir todo offline.
  final List<dynamic> rawUnits;

  const TeacherStudent({
    required this.code,
    required this.firstName,
    required this.lastName,
    this.fullName,
    this.attendance,
    this.grade,
    this.matriculaAsignaturaId,
    this.observacion,
    this.units = const [],
    this.cells = const [],
    this.rawUnits = const [],
  });

  /// Nota registrada en la columna dada, si existe.
  GradeCell? cellFor(int unidadId, int tipoNotaId, [int ordinal = 0]) {
    for (final c in cells) {
      if (c.unidadId == unidadId &&
          c.tipoNotaId == tipoNotaId &&
          c.ordinal == ordinal) {
        return c;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'codigo': code,
    'nombres': firstName,
    'apellidos': lastName,
    'nombreCompleto': fullName,
    'asistencia': attendance,
    'notaFinal': grade,
    'matriculaAsignaturaId': matriculaAsignaturaId,
    'observacion': observacion,
    'unidades': rawUnits,
  };

  factory TeacherStudent.fromJson(Map<String, dynamic> j) {
    final notaFinal = j['notaFinal'] ?? j['nota'] ?? j['promedio'];
    final unids = j['unidades'];
    final unitsList = <TeacherUnit>[];
    if (unids is List) {
      for (final u in unids.whereType<Map>()) {
        unitsList.add(TeacherUnit.fromJson(u.cast<String, dynamic>()));
      }
    }
    return TeacherStudent(
      code: _toStr(j['codigo'] ?? j['est_Id']),
      firstName: _toStr(j['nombres']),
      lastName: _toStr(j['apellidos']),
      fullName: (j['nombreCompleto'] ?? j['nombre_completo'])?.toString(),
      attendance: j['asistencia']?.toString(),
      grade: notaFinal?.toString(),
      matriculaAsignaturaId:
          (j['matricula_asignatura_id'] ?? j['matriculaAsignaturaId'])
              ?.toString(),
      observacion: j['observacion']?.toString(),
      units: unitsList,
      cells: GradeCell.fromUnidades(unids),
      rawUnits: unids is List ? unids : const [],
    );
  }
  String get displayName {
    final parts = [
      lastName,
      firstName,
    ].where((s) => s.trim().isNotEmpty).join(' ').trim();
    if (parts.isNotEmpty) return parts;
    return (fullName ?? '').trim();
  }
}

/// Una marca de asistencia del propio docente (huella/virtual), de
/// `Docente/getHistorialMarcacion`.
class TeacherPunch {
  final DateTime date;
  final String time;
  final int weekday;
  final String dayName;
  final String mode;
  final String location;
  const TeacherPunch({
    required this.date,
    required this.time,
    required this.weekday,
    required this.dayName,
    required this.mode,
    required this.location,
  });
  bool get isVirtual => location.trim().toUpperCase().startsWith('VIRTUAL');
}

/// Estado de marcación de un extremo (inicio/fin) de una clase programada,
/// según `Docente/getAsistenciaDiaria` (`statusInicio`/`statusFin`).
///
/// Valores observados con cuenta real: `1` en clases ya dictadas y marcadas,
/// `X` en clases ya pasadas sin marca y `0` en la clase en curso/por venir.
enum PunchStatus { marked, missing, pending, unknown }

/// Una clase programada del docente con el estado de su marcación de entrada
/// y salida. Fuente: `Docente/getAsistenciaDiaria`.
class TeacherClassCompliance {
  final DateTime date;
  final int weekday;
  final String dayName;
  final String startTime;
  final String endTime;
  final String subject;
  final String level;
  final String section;
  final String modality;
  final PunchStatus start;
  final PunchStatus end;
  const TeacherClassCompliance({
    required this.date,
    required this.weekday,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.level,
    required this.section,
    required this.modality,
    required this.start,
    required this.end,
  });

  bool get isComplete =>
      start == PunchStatus.marked && end == PunchStatus.marked;
  bool get hasMissing =>
      start == PunchStatus.missing || end == PunchStatus.missing;
}

/// Unidad de evaluación de una sección (`Asignatura/getTipoUnidadesV2`).
/// `enabled` indica si SIGMA permite registrar notas en ella ahora mismo.
class TeacherUnitCatalog {
  final int id;
  final String name;
  final bool enabled;
  const TeacherUnitCatalog({
    required this.id,
    required this.name,
    required this.enabled,
  });
}

class PaymentSchedule {
  final double totalAmount;
  final List<PaymentInstallment> installments;
  const PaymentSchedule({
    required this.totalAmount,
    required this.installments,
  });
}
