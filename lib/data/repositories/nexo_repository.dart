import 'package:nexo/data/repositories/nexo_campus_mappers.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/domain/idiomas_models.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Datos del estudiante servidos por la API de Nexo, ya ordenados por el
/// backend (ver `nexo-backend/docs/api-models.md`).
///
/// Convierte ese formato limpio a los modelos que ya usan las pantallas.
class NexoRepository {
  NexoRepository(this._directory);

  final DirectoryService _directory;

  /// Módulo docente (`/teaching/*`).
  late final NexoTeacherRepository teacher = NexoTeacherRepository(_directory);

  Future<Student> profile() async {
    await _directory.ensureConnected();
    return studentFromNexo(await _directory.client.profile());
  }

  Future<List<Term>> terms() async {
    await _directory.ensureConnected();
    return (await _directory.client.terms()).map(termFromNexo).toList();
  }

  /// Horario del periodo [year]-[number] (o el activo si faltan).
  Future<List<ScheduleClass>> schedule({int? year, int? number}) async {
    await _directory.ensureConnected();
    final term = year != null && number != null ? '$year-$number' : null;
    final body = await _directory.client.schedule(term: term);
    final classes = body['classes'];
    return classes is List
        ? classes
              .whereType<Map>()
              .map((e) => scheduleClassFromNexo(e.cast<String, dynamic>()))
              .toList()
        : const [];
  }

  /// Cursos de Idiomas y, aparte, sus notas con la forma que leen las
  /// pantallas (`detMatriculaId`, `promedio`, `nota1…nota6`).
  Future<({List<IdiomasCourse> courses, List<Map<String, dynamic>> grades})>
  languages() async {
    await _directory.ensureConnected();
    final rows = await _directory.client.languages();
    return (
      courses: rows.map(idiomasCourseFromNexo).toList(),
      grades: rows.map(idiomasGradesFromNexo).toList(),
    );
  }

  /// Boleta de un periodo del modelo por competencias (2026-1 en adelante),
  /// con el detalle de los cursos en proceso que el backend ya trajo.
  Future<
    ({List<ReportCardCourse> courses, Map<String, CourseGradeDetail> details})
  >
  reportCard(int year, int number) async {
    final courses = await _termCourses(year, number);
    return (
      courses: courses.map(reportCardCourseFromNexo).toList(),
      details: {
        for (final c in courses)
          if (c['units'] is List)
            _text(c['id']): courseDetailFromNexo({
              'units': c['units'],
              'makeup_exam': c['makeup_exam'],
              'final': {..._map(c['grade']), 'status': c['status']},
            }),
      },
    );
  }

  /// Notas de un periodo del modelo anterior (antes de 2026-1).
  Future<List<CourseGrade>> legacyGrades(int year, int number) async {
    final courses = await _termCourses(year, number);
    return courses.map((c) => courseGradeFromNexo(c, year, number)).toList();
  }

  Future<List<Map<String, dynamic>>> _termCourses(int year, int number) async {
    await _directory.ensureConnected();
    final body = await _directory.client.grades(term: '$year-$number');
    final raw = body['courses'];
    return raw is List
        ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : const [];
  }

  Future<CourseGradeDetail> courseDetail(
    int year,
    int number,
    String id,
  ) async {
    await _directory.ensureConnected();
    return courseDetailFromNexo(
      await _directory.client.courseGrades('$year-$number', id),
    );
  }

  Future<void> changePassword(String current, String newPassword) async {
    await _directory.ensureConnected();
    await _directory.client.changePassword(current, newPassword);
  }

  // Una respuesta sirve a varias pantallas que la piden casi juntas
  // (`/grades/summary`: resumen y promedios; `/payments`: pendientes,
  // vencidos y tasas). Se comparte 30 s para no repetir la llamada.
  final Map<String, ({Future<Map<String, dynamic>> future, DateTime at})>
  _shared = {};

  Future<Map<String, dynamic>> _sharedCall(
    String key,
    Future<Map<String, dynamic>> Function() fetch,
  ) {
    final hit = _shared[key];
    if (hit != null &&
        DateTime.now().difference(hit.at) < const Duration(seconds: 30)) {
      return hit.future;
    }
    // Se registra antes del primer `await`: dos pantallas que piden a la vez
    // esperan la misma llamada en vez de lanzar dos.
    late final Future<Map<String, dynamic>> future;
    future = () async {
      try {
        await _directory.ensureConnected();
        return await fetch();
      } catch (_) {
        if (identical(_shared[key]?.future, future)) _shared.remove(key);
        rethrow;
      }
    }();
    _shared[key] = (future: future, at: DateTime.now());
    return future;
  }

  Future<Map<String, dynamic>> _gradesSummary() =>
      _sharedCall('summary', _directory.client.gradesSummary);

  Future<GradesSummary> gradesSummary() async =>
      gradesSummaryFromNexo(await _gradesSummary());

  Future<List<TermAverage>> termAverages() async =>
      termAveragesFromNexo(await _gradesSummary());

  Future<Map<String, dynamic>> _payments() =>
      _sharedCall('payments', _directory.client.payments);

  /// Cargos por vencer (y descuentos), como la lista de pendientes.
  Future<List<Payment>> pendingPayments() async =>
      _maps((await _payments())['pending']).map(paymentFromNexo).toList();

  /// Cargos vencidos, matrícula incluida.
  Future<List<Payment>> overduePayments() async =>
      _maps((await _payments())['overdue']).map(paymentFromNexo).toList();

  Future<List<Fee>> fees() async =>
      _maps((await _payments())['fees']).map(feeFromNexo).toList();

  Future<PaymentSchedule> paymentSchedule() async {
    await _directory.ensureConnected();
    return paymentScheduleFromNexo(await _directory.client.paymentSchedule());
  }

  /// Historial con una fila por concepto, como lo muestran las pantallas;
  /// cada fila conserva la serie y el número de su operación.
  Future<List<PaymentRecord>> paymentHistory() async {
    await _directory.ensureConnected();
    return paymentRecordsFromNexo(await _directory.client.paymentHistory());
  }

  /// Constancia de matrícula del periodo [year]-[number] (o el activo).
  Future<EnrollmentCertificate> enrollment({int? year, int? number}) async {
    await _directory.ensureConnected();
    final term = year != null && number != null && year > 0 && number > 0
        ? '$year-$number'
        : null;
    return enrollmentFromNexo(await _directory.client.enrollment(term: term));
  }

  /// Se pide cada vez; no se comparte ni se guarda.
  Future<WifiCredential> wifi() async {
    await _directory.ensureConnected();
    return wifiFromNexo(await _directory.client.wifi());
  }
}

/// Un cargo de `GET /payments` → [Payment]. La fecha vuelve al formato
/// `dd-MM-yyyy` que lee el modelo.
Payment paymentFromNexo(Map<String, dynamic> json) {
  final term = _text(json['term']);
  final label = _text(json['label']);
  return Payment(
    description: term.isEmpty ? label : '$label · $term',
    currency: 'S/.',
    amount: (json['amount'] as num?)?.toDouble() ?? 0,
    lateFee: (json['late_fee'] as num?)?.toDouble() ?? 0,
    total: (json['total'] as num?)?.toDouble() ?? 0,
    note: _text(json['note']),
    dueDateRaw: _dayFirst(json['due_date'], '-'),
  );
}

Fee feeFromNexo(Map<String, dynamic> json) => Fee(
  description: _text(json['label']),
  currency: 'S/.',
  amount: (json['amount'] as num?)?.toDouble() ?? 0,
  note: _text(json['note']),
);

PaymentSchedule paymentScheduleFromNexo(Map<String, dynamic> json) =>
    PaymentSchedule(
      totalAmount: (json['term_total'] as num?)?.toDouble() ?? 0,
      installments: [
        for (final i in _maps(json['installments']))
          PaymentInstallment(
            number: ((i['number'] as num?)?.toInt() ?? 0).toString().padLeft(
              2,
              '0',
            ),
            amount: (i['amount'] as num?)?.toDouble() ?? 0,
            rawDueDate: _dayFirst(i['due_date'], '/'),
          ),
      ],
    );

List<PaymentRecord> paymentRecordsFromNexo(Map<String, dynamic> json) => [
  for (final op in _maps(json['operations']))
    for (final (index, item) in _maps(op['items']).indexed)
      PaymentRecord(
        serial: _text(op['id']).split('-').first,
        number: _text(op['id']).split('-').skip(1).join('-'),
        operationType: 'PAGOS',
        item: '${index + 1}'.padLeft(2, '0'),
        date: _text(op['date']),
        time: '',
        term: _text(op['term']),
        concept: _text(item['concept']),
        currency: 'S/.',
        amount: (item['amount'] as num?)?.toDouble() ?? 0,
        note: _text(op['bank_reference']),
        voucher: _text(item['voucher'] ?? op['voucher']),
        place: _text(op['place']),
      ),
];

/// `"2026-06-12"` → `"12-06-2026"` (o con `/`); vacío si no hay fecha.
String _dayFirst(Object? iso, String separator) {
  final parts = _text(iso).split('-');
  if (parts.length != 3) return '';
  return [parts[2], parts[1], parts[0]].join(separator);
}

/// Un curso de `GET /grades` (modelo por competencias) → [ReportCardCourse].
/// El id es el que entiende `GET /grades/{term}/courses/{id}`.
ReportCardCourse reportCardCourseFromNexo(Map<String, dynamic> json) {
  final grade = _map(json['grade']);
  return ReportCardCourse(
    enrollmentSubjectId: _text(json['id']),
    plan: '',
    code: _text(json['code']),
    name: _text(json['name']),
    section: _text(json['section']),
    credit: (json['credits'] as num?)?.toDouble() ?? 0,
    rawAttendance: _text(json['attendance_percent']),
    rawAverage: _grade(grade['current']),
    rawVigesimal: _grade(grade['official']),
    state: _statusLabel(json['status']),
  );
}

/// `GET /grades/{term}/courses/{id}` → [CourseGradeDetail]. Los promedios
/// llegan calculados; la app ya no los recalcula.
CourseGradeDetail courseDetailFromNexo(Map<String, dynamic> json) {
  final finalGrade = _map(json['final']);
  return CourseGradeDetail(
    units: [
      for (final u in _maps(json['units']))
        UnitGrades(
          name: _text(u['name']),
          rawWeight: _grade(u['weight_percent']),
          rawAverage: _grade(u['average']),
          serverAverage: (u['average'] as num?)?.toDouble(),
          evidences: [
            for (final e in _maps(u['evidences']))
              EvidenceGrade(
                type: _text(e['label']),
                rawWeight: _grade(e['weight_percent']),
                rawGrade: _grade(e['grade']),
              ),
          ],
        ),
    ],
    rawSubstitute: _grade(json['makeup_exam']),
    rawFinalAverage: _grade(finalGrade['official']),
    state: _statusLabel(finalGrade['status']),
    serverAverage: (finalGrade['current'] as num?)?.toDouble(),
  );
}

/// Un curso de `GET /grades` (modelo anterior) → [CourseGrade], rearmando
/// las claves que el modelo ya entiende.
CourseGrade courseGradeFromNexo(
  Map<String, dynamic> json,
  int year,
  int number,
) {
  final grade = _map(json['grade']);
  final rank = _map(json['rank']);
  final keys = <String, dynamic>{
    'codigo': _text(json['code']),
    'asignatura': _text(json['name']),
    'seccion': _text(json['section']),
    'ciclo': _text(json['cycle']),
    'credito': json['credits'],
    'asistencia': json['attendance_percent']?.toString(),
    'tipoAsignatura': _typeCode(json['type']),
    'mtr_Anio': year,
    'mtr_Periodo': number,
    'pf': _grade(grade['current']),
    'pfp': _grade(grade['official']),
    'complementario': _grade(json['makeup_exam']),
    'cc': json['closed'] == true ? 'True' : 'False',
    'puesto': rank.isEmpty ? '' : '${rank['position']}/${rank['of']}',
  };
  for (final u in _maps(json['units'])) {
    final half = (u['number'] as num?)?.toInt() ?? 0;
    if (half != 1 && half != 2) continue;
    final p = half == 1 ? 'p' : '_2P';
    final nta = half == 1 ? 'nta' : '_2Nta';
    keys['pF$half'] = _grade(u['average']);
    keys['${nta}P1'] = _grade(u['practices_average']);
    keys['${nta}PromTiPy'] = _grade(u['work_average']);
    var practice = 0;
    for (final e in _maps(u['evidences'])) {
      final value = _grade(e['grade']);
      switch (e['type']) {
        case 'practice':
          keys['$p${++practice}'] = value;
        case 'individual_work':
          keys['${nta}TI1'] = value;
        case 'project':
          keys['${nta}PY1'] = value;
        case 'partial_exam':
          keys['${nta}Parcial1'] = value;
      }
    }
  }
  return CourseGrade.fromJson(keys);
}

GradesSummary gradesSummaryFromNexo(Map<String, dynamic> json) {
  final credits = _map(json['credits']);
  return GradesSummary(
    average: (json['cumulative_average'] as num?)?.toDouble() ?? 0,
    approvedCredits: (credits['approved'] as num?)?.toInt() ?? 0,
    totalCredits: (credits['required'] as num?)?.toInt() ?? 0,
  );
}

List<TermAverage> termAveragesFromNexo(Map<String, dynamic> json) => [
  for (final t in _maps(json['terms']))
    if (_text(t['term']).split('-') case [final y, final n])
      TermAverage(
        year: int.tryParse(y) ?? 0,
        number: int.tryParse(n) ?? 0,
        average: (t['average'] as num?)?.toDouble() ?? 0,
      ),
];

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>())
    : const [];

/// Nota como texto, que es como la guardan los modelos de la app.
String _grade(Object? value) => value is num ? value.toString() : '';

/// Estado con la abreviatura de la boleta que ya leen las pantallas.
String _statusLabel(Object? status) => switch (status) {
  'in_progress' => 'Dsp.',
  'passed' => 'Apr.',
  'failed' => 'Des.',
  _ => '',
};

String _typeCode(Object? type) => switch (type) {
  'mandatory' => 'TN',
  'elective' => 'TE',
  'activity' => 'TA',
  'workshop' => 'TT',
  'practicum' => 'TP',
  _ => '',
};

/// Una clase de `GET /schedule` → [ScheduleClass].
ScheduleClass scheduleClassFromNexo(Map<String, dynamic> json) {
  final course = _map(json['course']);
  final room = _map(json['room']);
  return ScheduleClass(
    id: _text(json['id']),
    nrc: _text(course['nrc'] ?? course['code']),
    subject: _text(course['name']),
    modality: _modalityLabel(json['modality']?.toString()),
    section: _text(json['section']),
    level: '',
    campus: _text(room['campus']),
    building: _text(room['building']),
    room: _text(room['name']),
    capacity: (room['capacity'] as num?)?.toInt() ?? 0,
    note: '',
    teacher: _text(json['teacher']),
    weekday: (json['weekday'] as num?)?.toInt() ?? 0,
    dayName: _text(json['day']),
    startTime: _text(json['start']),
    endTime: _text(json['end']),
    typeCode: switch (json['kind']) {
      'practice' => 'P',
      'lab' => 'L',
      'language' => 'I',
      _ => 'T',
    },
  );
}

const _dayTokens = ['', 'LU', 'MA', 'MI', 'JU', 'VI', 'SA', 'DO'];

/// Un curso de `GET /languages` → [IdiomasCourse], con las claves que el
/// modelo ya entiende.
IdiomasCourse idiomasCourseFromNexo(Map<String, dynamic> json) {
  final period = _map(json['period']);
  final schedule = json['schedule'] is List
      ? (json['schedule'] as List).whereType<Map>().toList()
      : const <Map>[];
  final first = schedule.isEmpty ? const {} : schedule.first;
  final grades = _map(json['grades']);
  return IdiomasCourse.fromJson({
    'asigId': _text(json['id']),
    'asignatura': _text(json['course']),
    'dias': schedule
        .map((s) => (s['weekday'] as num?)?.toInt() ?? 0)
        .where((d) => d >= 1 && d <= 7)
        .map((d) => _dayTokens[d])
        .join('-'),
    'horaInicio': _text(first['start']),
    'horaFin': _text(first['end']),
    'aula': _text(json['room']),
    'aulaNombre': _text(json['room']),
    'detMatriculaId': int.tryParse(_text(json['id'])) ?? 0,
    'modalidad': _modalityLabel(json['modality']?.toString()),
    'idiomaNombre': _text(json['language']),
    'seccion': _text(json['section']),
    'anio': (period['year'] as num?)?.toInt() ?? 0,
    'mes': (period['month'] as num?)?.toInt() ?? 0,
    'tipoEstudio': _text(json['study_type']),
    'turno': _text(json['shift']),
    'promedio': (grades['average'] as num?) ?? 0,
  });
}

/// Las notas de un curso de `GET /languages`, como las leía la pantalla.
Map<String, dynamic> idiomasGradesFromNexo(Map<String, dynamic> json) {
  final grades = _map(json['grades']);
  final items = grades['items'] is List ? grades['items'] as List : const [];
  return {
    'detMatriculaId': int.tryParse(_text(json['id'])) ?? 0,
    'promedio': (grades['average'] as num?) ?? 0,
    for (var i = 0; i < 6; i++)
      'nota${i + 1}': i < items.length ? (items[i] as num?) ?? 0 : 0,
  };
}

/// `GET /profile` → [Student].
Student studentFromNexo(Map<String, dynamic> json) {
  final name = _map(json['name']);
  final credits = _map(json['credits']);
  final average = _map(json['average']);
  return Student(
    id: _text(json['code']),
    fullName: _text(name['full']),
    career: _text(json['career']),
    faculty: _text(json['faculty']),
    campus: _text(json['campus']),
    level: json['current_cycle']?.toString() ?? '',
    studyPlan: _text(json['study_plan']),
    modality: _modalityLabel(json['modality']?.toString()),
    isEnrolled: json['enrolled'] == true,
    lastEnrollment: json['last_enrollment']?.toString(),
    gpa: (average['cumulative'] as num?)?.toDouble(),
    creditsApproved: (credits['approved'] as num?)?.toInt(),
    creditsTotal: (credits['required'] as num?)?.toInt(),
    givenName: _given(name['first']),
  );
}

/// Primer nombre en tipo título: "ALESSANDRO JOSE" → "Alessandro".
String? _given(Object? first) {
  final word = _text(first).trim().split(RegExp(r'\s+')).first;
  if (word.isEmpty) return null;
  return word[0].toUpperCase() + word.substring(1).toLowerCase();
}

/// `GET /terms` → [Term]. El id conserva el formato que ya usa la app
/// (`"20262"`); la etiqueta es la del backend (`"2026-II"`).
Term termFromNexo(Map<String, dynamic> json) {
  final year = (json['year'] as num?)?.toInt() ?? 0;
  final number = (json['number'] as num?)?.toInt() ?? 0;
  return Term(
    id: '$year$number',
    label: _text(json['label']),
    year: year,
    number: number,
    isActive: json['active'] == true,
  );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

String _text(Object? value) => value?.toString() ?? '';

/// La modalidad llega como palabra fija (`in_person`); las pantallas aún
/// muestran el texto de la universidad.
String _modalityLabel(String? code) => switch (code) {
  'in_person' => 'PRESENCIAL',
  'distance' => 'A DISTANCIA',
  'blended' => 'SEMIPRESENCIAL',
  'virtual' => 'VIRTUAL',
  null => '',
  final other => other.toUpperCase(),
};
