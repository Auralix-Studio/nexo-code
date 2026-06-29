import 'package:nexo/domain/models.dart';

class Student {
  final String id;
  final String fullName;
  final String career;
  final String faculty;
  final String campus;
  final String level;
  final String studyPlan;
  final String modality;
  final bool isEnrolled;
  final String? lastEnrollment;
  final double? gpa;
  final int? creditsApproved;
  final int? creditsTotal;

  const Student({
    required this.id,
    required this.fullName,
    required this.career,
    required this.faculty,
    required this.campus,
    required this.level,
    required this.studyPlan,
    required this.modality,
    required this.isEnrolled,
    this.lastEnrollment,
    this.gpa,
    this.creditsApproved,
    this.creditsTotal,
  });

  static String _s(Object? v) => v?.toString() ?? '';
  static int? _i(Object? v) =>
      v is int ? v : v is num ? v.toInt() : v is String ? int.tryParse(v) : null;
  static bool _b(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      return t == 'true' || t == '1' || t == 's' || t == 'si' || t == 'sí';
    }
    return false;
  }

  /// SIGMA `Estudiante/MostrarInfoEstudiante` — JSON con keys en español.
  factory Student.fromSigmaJson(Map<String, dynamic> j) => Student(
        id: _s(j['est_Id']),
        fullName: _s(j['estudiante']),
        career: _s(j['carrera']),
        faculty: _s(j['facultad']),
        campus: _expandSede(_s(j['sede'])),
        level: _s(j['nivel']),
        studyPlan: _s(j['pes_Id']),
        modality: _s(j['modalidad']),
        isEnrolled: _b(j['matriculado']),
        lastEnrollment: j['ultimaMatricula']?.toString(),
        creditsApproved: _i(j['creditoAprobado']),
      );

  /// Códigos de sede UPLA → nombre legible.
  static const _sedeNames = {
    'HU': 'HUANCAYO',
    'HYO': 'HUANCAYO',
    'LM': 'LIMA',
    'LI': 'LIMA',
    'CHA': 'CHANCHAMAYO',
    'CH': 'CHANCHAMAYO',
    'SAT': 'SATIPO',
    'ST': 'SATIPO',
    'TAR': 'TARMA',
    'TR': 'TARMA',
    'CER': 'CERRO DE PASCO',
  };

  static String _expandSede(String code) {
    final t = code.trim().toUpperCase();
    return _sedeNames[t] ?? code;
  }

  /// Intranet PHP — combina `datosEstudianteMatriculado` (row posicional)
  /// con la cabecera de `consultarConstanciaMatriculaEstudiante` para
  /// tener nombres legibles de facultad/carrera + nivel/modalidad.
  factory Student.fromIntranetData({
    required List<dynamic> datosBasico,
    required ConstanciaMatricula constancia,
  }) {
    String at(int i) =>
        (i < datosBasico.length ? datosBasico[i]?.toString() ?? '' : '').trim();
    return Student(
      id: constancia.codigo,
      fullName: constancia.estudiante,
      career: constancia.carrera,
      faculty: constancia.facultad,
      campus: _expandSede(at(6)),
      level: constancia.nivel,
      studyPlan: constancia.planEstudios.isNotEmpty
          ? constancia.planEstudios
          : at(4),
      modality: constancia.modalidad,
      isEnrolled: constancia.codigo.isNotEmpty,
      lastEnrollment:
          constancia.anio > 0 ? '${constancia.anio}-${constancia.periodo}' : null,
      // totalCreditos del constancia = créditos matriculados ESTE semestre.
      // Es la mejor aproximación que tenemos sin record académico completo.
      creditsApproved: constancia.totalCreditos.toInt(),
    );
  }

  // Merge: prioritizes this student (e.g. SIGMA), fills in missing/nulls from other (e.g. INTRANET)
  Student mergeWith(Student other) {
    return Student(
      id: id.isNotEmpty ? id : other.id,
      fullName: fullName.isNotEmpty ? fullName : other.fullName,
      career: career.isNotEmpty ? career : other.career,
      faculty: faculty.isNotEmpty ? faculty : other.faculty,
      campus: campus.isNotEmpty ? campus : other.campus,
      level: level.isNotEmpty ? level : other.level,
      studyPlan: studyPlan.isNotEmpty ? studyPlan : other.studyPlan,
      modality: modality.isNotEmpty ? modality : other.modality,
      isEnrolled: isEnrolled || other.isEnrolled,
      lastEnrollment: lastEnrollment ?? other.lastEnrollment,
      gpa: gpa ?? other.gpa,
      creditsApproved: creditsApproved ?? other.creditsApproved,
      creditsTotal: creditsTotal ?? other.creditsTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'career': career,
        'faculty': faculty,
        'campus': campus,
        'level': level,
        'studyPlan': studyPlan,
        'modality': modality,
        'isEnrolled': isEnrolled,
        'lastEnrollment': lastEnrollment,
        'gpa': gpa,
        'creditsApproved': creditsApproved,
        'creditsTotal': creditsTotal,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        career: json['career'] as String? ?? '',
        faculty: json['faculty'] as String? ?? '',
        campus: json['campus'] as String? ?? '',
        level: json['level'] as String? ?? '',
        studyPlan: json['studyPlan'] as String? ?? '',
        modality: json['modality'] as String? ?? '',
        isEnrolled: json['isEnrolled'] as bool? ?? false,
        lastEnrollment: json['lastEnrollment'] as String?,
        gpa: (json['gpa'] as num?)?.toDouble(),
        creditsApproved: json['creditsApproved'] as int?,
        creditsTotal: json['creditsTotal'] as int?,
      );
}

class Payment {
  final String description;
  final String currency;
  final double amount;
  final double lateFee;
  final double total;
  final String note;
  /// Fecha cruda como vino del backend ("dd-MM-yyyy" SIGMA, "dd/MM/yyyy" Intranet).
  final String dueDateRaw;

  const Payment({
    required this.description,
    required this.currency,
    required this.amount,
    required this.lateFee,
    required this.total,
    required this.note,
    required this.dueDateRaw,
  });

  /// SIGMA `ListarCoutas*` — dict shape.
  factory Payment.fromSigmaJson(Map<String, dynamic> j) => Payment(
        description: j['descripcion']?.toString() ?? '',
        currency: j['tipoMoneda']?.toString() ?? '',
        amount: (j['importe'] as num?)?.toDouble() ?? 0,
        lateFee: (j['mora'] as num?)?.toDouble() ?? 0,
        total: (j['subtotal'] as num?)?.toDouble() ?? 0,
        note: j['observacion']?.toString() ?? '',
        dueDateRaw: j['fechaVencimiento']?.toString() ?? '',
      );

  /// Intranet endpoints de estado de deuda (`consultarPensiones`,
  /// `consultartotalPensiones`) — formato:
  /// `[descripcion, "dd-MM-yyyy", currency, importe, mora, total, observacion]`.
  factory Payment.fromDebtRow(List<dynamic> r) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    final amount = double.tryParse(at(3)) ?? 0;
    final lateFee = double.tryParse(at(4)) ?? 0;
    final total = double.tryParse(at(5)) ?? (amount + lateFee);
    final note = at(6);
    return Payment(
      description: at(0),
      currency: at(2),
      amount: amount,
      lateFee: lateFee,
      total: total,
      note: note == '--' ? '' : note,
      dueDateRaw: at(1),
    );
  }

  /// Intranet `consultarCuotasEstudiante` — row posicional (cronograma teórico)
  /// `[idPer, totSem, monto, nroCuota, "dd/MM/yyyy", totCuotas, fechaGen]`.
  factory Payment.fromIntranetRow(List<dynamic> r, {String? termLabel}) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    final amount = double.tryParse(at(2)) ?? 0;
    final totSem = double.tryParse(at(1)) ?? 0;
    final nro = at(3);
    final totCuotas = at(5);
    final desc = StringBuffer('Cuota $nro');
    if (totCuotas.isNotEmpty) desc.write(' de $totCuotas');
    if (termLabel != null && termLabel.isNotEmpty) desc.write(' · $termLabel');
    final note = totSem > 0
        ? 'Total semestre S/. ${totSem.toStringAsFixed(2)}'
        : '';
    return Payment(
      description: desc.toString(),
      currency: 'S/.',
      amount: amount,
      lateFee: 0,
      total: amount,
      note: note,
      dueDateRaw: at(4),
    );
  }

  DateTime? get dueDate {
    final parts = dueDateRaw.split(RegExp(r'[-/]'));
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  int? daysUntilDue([DateTime? now]) {
    final due = dueDate;
    if (due == null) return null;
    final t = now ?? DateTime.now();
    return due.difference(DateTime(t.year, t.month, t.day)).inDays;
  }

  bool isOverdueAt(DateTime now) => (daysUntilDue(now) ?? 0) < 0;

  Map<String, dynamic> toJson() => {
        'description': description,
        'currency': currency,
        'amount': amount,
        'lateFee': lateFee,
        'total': total,
        'note': note,
        'dueDateRaw': dueDateRaw,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        description: j['description'] as String? ?? '',
        currency: j['currency'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        lateFee: (j['lateFee'] as num?)?.toDouble() ?? 0,
        total: (j['total'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String? ?? '',
        dueDateRaw: j['dueDateRaw'] as String? ?? '',
      );
}

class PaymentRecord {
  final String serial;
  final String number;
  final String operationType;
  final String item;
  /// `yyyy-MM-dd` (normalizado).
  final String date;
  final String time;
  final String term;
  final String concept;
  final String currency;
  final double amount;
  final String note;
  final String voucher;
  final String place;

  const PaymentRecord({
    required this.serial,
    required this.number,
    required this.operationType,
    required this.item,
    required this.date,
    required this.time,
    required this.term,
    required this.concept,
    required this.currency,
    required this.amount,
    required this.note,
    required this.voucher,
    required this.place,
  });

  /// SIGMA `ListarHistorico` — dict.
  factory PaymentRecord.fromSigmaJson(Map<String, dynamic> j) => PaymentRecord(
        serial: j['serieOper']?.toString() ?? '',
        number: j['numOper']?.toString() ?? '',
        operationType: j['desOper']?.toString() ?? '',
        item: j['item']?.toString() ?? '',
        date: j['fecha']?.toString() ?? '',
        time: j['hora']?.toString() ?? '',
        term: j['periodo']?.toString() ?? '',
        concept: j['concepto']?.toString() ?? '',
        currency: j['tipoMoneda']?.toString() ?? '',
        amount: (j['importe'] as num?)?.toDouble() ?? 0,
        note: j['observacion']?.toString() ?? '',
        voucher: j['comprobante']?.toString() ?? '',
        place: j['lugar']?.toString() ?? '',
      );

  /// Intranet `consultarUltimasOperaciones` — row posicional.
  factory PaymentRecord.fromIntranetRow(List<dynamic> r) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    String date = at(4);
    final parts = date.split('/');
    if (parts.length == 3) {
      date = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
    }
    return PaymentRecord(
      serial: at(0),
      number: at(1),
      operationType: at(2),
      item: at(3),
      date: date,
      time: '',
      term: at(5),
      concept: at(6),
      currency: at(7),
      amount: double.tryParse(at(8)) ?? 0,
      note: at(9),
      voucher: at(10),
      place: at(11),
    );
  }

  DateTime? get dateAsDate {
    final p = date.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  bool get isDiscount => amount < 0;
  bool get isPayment =>
      amount > 0 && operationType.toUpperCase().contains('PAGO');
}

class Fee {
  final String description;
  final String currency;
  final double amount;
  final String note;

  const Fee({
    required this.description,
    required this.currency,
    required this.amount,
    required this.note,
  });

  factory Fee.fromSigmaJson(Map<String, dynamic> j) => Fee(
        description: j['descripcion']?.toString() ?? '',
        currency: j['tipoMoneda']?.toString() ?? '',
        amount: (j['importe'] as num?)?.toDouble() ?? 0,
        note: j['observacion']?.toString() ?? '',
      );
}

class ScheduleClass {
  final String id;
  final String nrc;
  final String subject;
  final String modality;
  final String section;
  final String level;
  final String campus;
  final String building;
  final String room;
  /// Aforo del aula (capacidad). 0 si desconocido.
  final int capacity;
  final String note;
  final String teacher;
  /// 1=Mon .. 7=Sun (DateTime.weekday).
  final int weekday;
  final String dayName;
  /// HH:mm.
  final String startTime;
  final String endTime;
  /// T=Teoría, P=Práctica, L=Lab.
  final String typeCode;

  const ScheduleClass({
    required this.id,
    required this.nrc,
    required this.subject,
    required this.modality,
    required this.section,
    required this.level,
    required this.campus,
    required this.building,
    required this.room,
    this.capacity = 0,
    required this.note,
    required this.teacher,
    required this.weekday,
    required this.dayName,
    required this.startTime,
    required this.endTime,
    required this.typeCode,
  });

  /// Etiqueta corta del aula para chips/listas ("I 302", "LAB-COM 4"…).
  String get roomShort => room.isNotEmpty ? room : '—';

  /// Descripción larga "Pabellón I · I 302" para vistas de detalle.
  String get locationFull {
    final parts = <String>[
      if (building.isNotEmpty) building,
      if (room.isNotEmpty) room,
    ];
    return parts.join(' · ');
  }

  factory ScheduleClass.fromSigmaJson(Map<String, dynamic> j) {
    String s(Object? v) => v?.toString() ?? '';
    int i(Object? v) => v is int
        ? v
        : v is num
            ? v.toInt()
            : v is String
                ? (int.tryParse(v) ?? 0)
                : 0;
    return ScheduleClass(
      id: s(j['id']),
      nrc: s(j['nrc']),
      subject: s(j['asignatura']),
      modality: s(j['modalidad']),
      section: s(j['seccion']),
      level: s(j['nivel']),
      campus: s(j['sede']),
      building: s(j['local']),
      room: s(j['aula']),
      capacity: i(j['capacity']),
      note: s(j['observacion']),
      teacher: s(j['docente']),
      weekday: i(j['idDia']),
      dayName: s(j['dia']),
      startTime: s(j['horaInicio']),
      endTime: s(j['horaFin']),
      typeCode: s(j['idTipo']),
    );
  }

  /// Parsea el string crudo de Intranet "PABELLON I - I 302 - AFORO: 50"
  /// (o "PABELLON I - LABORA…") en sus componentes.
  static ({String building, String room, int capacity}) parseLocation(String raw) {
    if (raw.trim().isEmpty) return (building: '', room: '', capacity: 0);
    final parts = raw.split(RegExp(r'\s*-\s*'));
    String building = '';
    String room = '';
    int capacity = 0;
    for (final p in parts) {
      final t = p.trim();
      if (t.isEmpty) continue;
      final aforoMatch = RegExp(r'^AFORO\s*:\s*(\d+)$', caseSensitive: false).firstMatch(t);
      if (aforoMatch != null) {
        capacity = int.tryParse(aforoMatch.group(1)!) ?? 0;
        continue;
      }
      if (building.isEmpty && RegExp(r'^(PABELLON|EDIFICIO|TORRE|LABORATORIO)\b', caseSensitive: false).hasMatch(t)) {
        building = t;
      } else if (room.isEmpty) {
        room = t;
      }
    }
    return (building: building, room: room, capacity: capacity);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'nrc': nrc,
        'asignatura': subject,
        'modalidad': modality,
        'seccion': section,
        'nivel': level,
        'sede': campus,
        'local': building,
        'aula': room,
        'observacion': note,
        'docente': teacher,
        'idDia': weekday,
        'dia': dayName,
        'horaInicio': startTime,
        'horaFin': endTime,
        'idTipo': typeCode,
      };

  factory ScheduleClass.fromJson(Map<String, dynamic> j) =>
      ScheduleClass.fromSigmaJson(j);

  String get typeName => switch (typeCode.toUpperCase()) {
        'T' => 'Teoría',
        'P' => 'Práctica',
        'L' => 'Laboratorio',
        _ => typeCode,
      };

  int get durationMinutes {
    final ini = _hmToMinutes(startTime);
    final fin = _hmToMinutes(endTime);
    if (ini == null || fin == null) return 0;
    return fin - ini;
  }
}

int? _hmToMinutes(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

class ScheduleClassGroup {
  final String subject;
  final int weekday;
  /// Sesiones ordenadas por `startTime`.
  final List<ScheduleClass> sessions;

  const ScheduleClassGroup({
    required this.subject,
    required this.weekday,
    required this.sessions,
  });

  String get startTime => sessions.first.startTime;
  String get endTime => sessions.last.endTime;
  String get room => sessions.first.room;
  String get teacher => sessions
      .map((s) => s.teacher)
      .firstWhere((d) => d.isNotEmpty, orElse: () => '');

  bool get hasPractice =>
      sessions.any((s) => s.typeCode.toUpperCase() != 'T');
  bool get hasTheory =>
      sessions.any((s) => s.typeCode.toUpperCase() == 'T');

  static List<ScheduleClassGroup> groupBy(List<ScheduleClass> classes) {
    final map = <String, List<ScheduleClass>>{};
    for (final c in classes) {
      map.putIfAbsent('${c.weekday}|${c.subject}', () => []).add(c);
    }
    return map.entries.map((e) {
      final list = [...e.value]
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return ScheduleClassGroup(
        subject: list.first.subject,
        weekday: list.first.weekday,
        sessions: list,
      );
    }).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }
}

class Term {
  final String id;
  final String label;
  final int year;
  final int number;
  final bool isActive;

  const Term({
    required this.id,
    required this.label,
    required this.year,
    required this.number,
    required this.isActive,
  });

  factory Term.fromSigmaJson(Map<String, dynamic> j) {
    bool b(Object? v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final t = v.trim().toLowerCase();
        return t == 'true' || t == '1' || t == 's';
      }
      return false;
    }
    int i(Object? v) => v is int
        ? v
        : v is num
            ? v.toInt()
            : v is String
                ? (int.tryParse(v) ?? 0)
                : 0;
    return Term(
      id: j['periodoId']?.toString() ?? '',
      label: j['descripcion']?.toString() ?? '',
      year: i(j['anio']),
      number: i(j['periodo']),
      isActive: b(j['activo']),
    );
  }

  /// Intranet `consultarPeriodosMatriculados` row: `[year, number]`.
  factory Term.fromIntranetRow(List<dynamic> r) {
    int i(Object? v) => v is int
        ? v
        : v is num
            ? v.toInt()
            : v is String
                ? (int.tryParse(v) ?? 0)
                : 0;
    final y = i(r.isNotEmpty ? r[0] : 0);
    final n = i(r.length > 1 ? r[1] : 0);
    return Term(
      id: '$y${n.toString().padLeft(1, '0')}',
      label: '$y - ${n == 1 ? 'I' : 'II'}',
      year: y,
      number: n,
      isActive: false,
    );
  }

  Map<String, dynamic> toJson() => {
        'periodoId': id,
        'descripcion': label,
        'anio': year,
        'periodo': number,
        'activo': isActive,
      };

  factory Term.fromJson(Map<String, dynamic> j) => Term.fromSigmaJson(j);
}

class TermAverage {
  final int year;
  final int number;
  final double average;

  const TermAverage({
    required this.year,
    required this.number,
    required this.average,
  });

  factory TermAverage.fromSigmaJson(Map<String, dynamic> j) {
    int i(Object? v) => v is int
        ? v
        : v is num
            ? v.toInt()
            : v is String
                ? (int.tryParse(v) ?? 0)
                : 0;
    double d(Object? v) => v is num
        ? v.toDouble()
        : v is String
            ? (double.tryParse(v) ?? 0)
            : 0;
    return TermAverage(
      year: i(j['anio']),
      number: i(j['periodo']),
      average: d(j['promedio']),
    );
  }

  String get label =>
      '$year - ${number == 1 ? 'I' : number == 2 ? 'II' : number}';

  Map<String, dynamic> toJson() =>
      {'anio': year, 'periodo': number, 'promedio': average};

  factory TermAverage.fromJson(Map<String, dynamic> j) =>
      TermAverage.fromSigmaJson(j);
}

/// Modelo unificado de docente
class Teacher {
  final String id;              // SIGMA.idProfesor || INTRANET.cod_docente
  final String fullName;
  final String? email;
  final String? department;
  final List<TeacherCourse> courses;

  const Teacher({
    required this.id,
    required this.fullName,
    this.email,
    this.department,
    required this.courses,
  });

  factory Teacher.fromSigmaDocente(DocenteInfo info, List<DocenteAsignatura> cursos) {
    return Teacher(
      id: info.codigo,
      fullName: info.displayName,
      department: info.facultad,
      courses: cursos.map((c) => TeacherCourse.fromDocenteAsignatura(c)).toList(),
    );
  }

  factory Teacher.fromIntranet(Map<String, dynamic> json) {
    final list = json['courses'] as List?;
    return Teacher(
      id: (json['cod_docente'] ?? json['codigo'] ?? '').toString(),
      fullName: (json['nombres_completos'] ?? json['displayName'] ?? '').toString(),
      email: json['email']?.toString(),
      department: json['department']?.toString(),
      courses: list != null
          ? list.map((e) => TeacherCourse.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }

  Teacher mergeWith(Teacher other) {
    return Teacher(
      id: id.isNotEmpty ? id : other.id,
      fullName: fullName.isNotEmpty ? fullName : other.fullName,
      email: email ?? other.email,
      department: department ?? other.department,
      courses: courses.isNotEmpty ? courses : other.courses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'department': department,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  factory Teacher.fromJson(Map<String, dynamic> json) {
    final list = json['courses'] as List?;
    return Teacher(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      department: json['department'] as String?,
      courses: list != null
          ? list.map((e) => TeacherCourse.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class TeacherCourse {
  final String id;              // cleAuto / id del curso
  final String subjectName;     // Nombre de asignatura
  final String subjectCode;     // Código
  final String section;
  final String period;          // "2026-1"
  final int? enrolledCount;     // Matriculados
  final String? schedule;

  const TeacherCourse({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.section,
    required this.period,
    this.enrolledCount,
    this.schedule,
  });

  factory TeacherCourse.fromDocenteAsignatura(DocenteAsignatura a) {
    return TeacherCourse(
      id: a.id,
      subjectName: a.asignatura,
      subjectCode: a.codigo,
      section: a.seccion,
      period: a.periodo,
      enrolledCount: a.matriculados,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'section': section,
        'period': period,
        'enrolledCount': enrolledCount,
        'schedule': schedule,
      };

  factory TeacherCourse.fromJson(Map<String, dynamic> json) => TeacherCourse(
        id: json['id'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        subjectCode: json['subjectCode'] as String? ?? '',
        section: json['section'] as String? ?? '',
        period: json['period'] as String? ?? '',
        enrolledCount: json['enrolledCount'] as int?,
        schedule: json['schedule'] as String?,
      );
}
