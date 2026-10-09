/// Lo que el tablero docente sabe y SIGMA no muestra: la agenda del día con el
/// estado de la asistencia de cada clase, las clases que quedaron sin
/// asistencia registrada y los alumnos que necesitan atención en todas las
/// secciones. Son funciones puras sobre datos que la app ya descargó.
library;

import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _minutes(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return 0;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

DateTime _at(DateTime day, String hm) {
  final m = _minutes(hm);
  return DateTime(day.year, day.month, day.day, m ~/ 60, m % 60);
}

enum ClassPhase { upcoming, ongoing, finished }

/// Una clase de un curso en un día concreto. Los bloques del mismo curso en
/// el mismo día (teoría + práctica seguidas) se juntan: SIGMA registra una
/// asistencia por fecha, no por bloque.
class ClassSession {
  final TeacherSubject course;
  final DateTime day;
  final String start;
  final String end;
  const ClassSession({
    required this.course,
    required this.day,
    required this.start,
    required this.end,
  });

  DateTime get startsAt => _at(day, start);
  DateTime get endsAt => _at(day, end);

  ClassPhase phaseAt(DateTime now) {
    if (now.isBefore(startsAt)) return ClassPhase.upcoming;
    if (now.isAfter(endsAt)) return ClassPhase.finished;
    return ClassPhase.ongoing;
  }

  /// Clave estable para recordar decisiones del docente sobre esta clase.
  String get key =>
      '${course.id}|${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// Clases de [courses] en [day], ordenadas por hora de inicio. Los bloques
/// seguidos (hasta 15 min de separación) forman una sola clase; una teoría de
/// mañana y una práctica de noche quedan como dos.
List<ClassSession> sessionsOn(List<TeacherSubject> courses, DateTime day) {
  final d = _dateOnly(day);
  final out = <ClassSession>[];
  for (final c in courses) {
    final blocks = c.blocks.where((b) => b.weekday == d.weekday).toList();
    if (blocks.isEmpty) continue;
    blocks.sort((a, b) => _minutes(a.start).compareTo(_minutes(b.start)));
    var start = blocks.first.start;
    var end = blocks.first.end;
    for (final b in blocks.skip(1)) {
      if (_minutes(b.start) - _minutes(end) <= 15) {
        if (_minutes(b.end) > _minutes(end)) end = b.end;
        continue;
      }
      out.add(ClassSession(course: c, day: d, start: start, end: end));
      start = b.start;
      end = b.end;
    }
    out.add(ClassSession(course: c, day: d, start: start, end: end));
  }
  out.sort((a, b) => _minutes(a.start).compareTo(_minutes(b.start)));
  return out;
}

/// Próxima clase a partir de [now], saltando feriados (busca hasta dos
/// semanas adelante).
ClassSession? nextSession(List<TeacherSubject> courses, DateTime now) {
  for (var i = 0; i <= 14; i++) {
    final day = _dateOnly(now).add(Duration(days: i));
    if (PeruHolidays.isHoliday(day)) continue;
    for (final s in sessionsOn(courses, day)) {
      if (s.startsAt.isAfter(now)) return s;
    }
  }
  return null;
}

/// Clases ya dictadas en los últimos [days] días (hoy incluido) cuya fecha no
/// tiene ninguna marca de asistencia en SIGMA. Más recientes primero.
///
/// SIGMA guarda la asistencia por fecha, así que un curso con dos clases el
/// mismo día aparece una sola vez (la primera que terminó). Solo considera
/// cursos con su hoja de asistencia cargada y con alumnos, y omite los
/// feriados nacionales y las clases que el docente descartó.
List<ClassSession> missingAttendance(
  List<TeacherSubject> courses,
  Map<String, AttendanceSheet> sheets,
  DateTime now, {
  int days = 14,
  Set<String> dismissed = const {},
}) {
  final out = <ClassSession>[];
  final seen = <String>{};
  for (var i = 0; i < days; i++) {
    final day = _dateOnly(now).subtract(Duration(days: i));
    if (PeruHolidays.isHoliday(day)) continue;
    for (final s in sessionsOn(courses, day)) {
      if (s.phaseAt(now) != ClassPhase.finished) continue;
      if (dismissed.contains(s.key) || !seen.add(s.key)) continue;
      final sheet = sheets[s.course.id];
      if (sheet == null || sheet.students.isEmpty) continue;
      if (!sheet.hasRecordsOn(day)) out.add(s);
    }
  }
  out.sort((a, b) => b.startsAt.compareTo(a.startsAt));
  return out;
}

/// Feriados nacionales del Perú (Ley 27921 y modificatorias). En esos días
/// no hay clases, así que no se reclama asistencia.
abstract final class PeruHolidays {
  static const _fixed = {
    (1, 1), // Año Nuevo
    (5, 1), // Día del Trabajo
    (6, 7), // Batalla de Arica y Día de la Bandera
    (6, 29), // San Pedro y San Pablo
    (7, 23), // Día de la Fuerza Aérea
    (7, 28), // Fiestas Patrias
    (7, 29), // Fiestas Patrias
    (8, 6), // Batalla de Junín
    (8, 30), // Santa Rosa de Lima
    (10, 8), // Combate de Angamos
    (11, 1), // Todos los Santos
    (12, 8), // Inmaculada Concepción
    (12, 9), // Batalla de Ayacucho
    (12, 25), // Navidad
  };

  static bool isHoliday(DateTime d) {
    if (_fixed.contains((d.month, d.day))) return true;
    // Jueves y Viernes Santo.
    final easter = easterSunday(d.year);
    final day = _dateOnly(d);
    return day == easter.subtract(const Duration(days: 3)) ||
        day == easter.subtract(const Duration(days: 2));
  }

  /// Domingo de Pascua (algoritmo anónimo gregoriano).
  static DateTime easterSunday(int y) {
    final a = y % 19;
    final b = y ~/ 100;
    final c = y % 100;
    final d = b ~/ 4;
    final e = b % 4;
    final f = (b + 8) ~/ 25;
    final g = (b - f + 1) ~/ 3;
    final h = (19 * a + b - d - g + 15) % 30;
    final i = c ~/ 4;
    final k = c % 4;
    final l = (32 + 2 * e + 2 * i - h - k) % 7;
    final m = (a + 11 * h + 22 * l) ~/ 451;
    final month = (h + l - 7 * m + 114) ~/ 31;
    final day = ((h + l - 7 * m + 114) % 31) + 1;
    return DateTime(y, month, day);
  }
}

/// Umbrales de asistencia. SIGMA pinta en rojo a quien tiene ≤ 70 % (30 % de
/// inasistencias inhabilita); Nexo avisa antes, desde el 80 %.
abstract final class AttendanceRisk {
  static const critical = 70.0;
  static const warning = 80.0;
}

enum AlertReason { attendanceCritical, attendanceWarning, failing }

/// Un alumno de una sección que necesita atención, con los motivos.
class StudentAlert {
  final TeacherSubject course;
  final TeacherStudent student;
  final double? attendance;
  final double? grade;
  final Set<AlertReason> reasons;
  const StudentAlert({
    required this.course,
    required this.student,
    required this.attendance,
    required this.grade,
    required this.reasons,
  });

  bool get critical =>
      reasons.contains(AlertReason.attendanceCritical) ||
      reasons.contains(AlertReason.failing);

  bool get attendanceIssue =>
      reasons.contains(AlertReason.attendanceCritical) ||
      reasons.contains(AlertReason.attendanceWarning);
}

double? _num(String? raw) =>
    double.tryParse((raw ?? '').trim().replaceAll(',', '.'));

/// Alumnos con asistencia baja o nota desaprobatoria a la fecha en todas las
/// secciones cuyo roster ya está cargado. Primero los críticos, luego por
/// asistencia ascendente.
List<StudentAlert> studentAlerts(
  List<TeacherSubject> courses,
  Map<String, List<TeacherStudent>> rosters, {
  PassingRule rule = PassingRule.standard,
}) {
  final out = <StudentAlert>[];
  for (final c in courses) {
    for (final s in rosters[c.id] ?? const <TeacherStudent>[]) {
      final att = _num(s.attendance);
      final grade = _num(s.grade);
      final reasons = <AlertReason>{};
      if (att != null) {
        if (att <= AttendanceRisk.critical) {
          reasons.add(AlertReason.attendanceCritical);
        } else if (att <= AttendanceRisk.warning) {
          reasons.add(AlertReason.attendanceWarning);
        }
      }
      // Sin notas, SIGMA manda 0 o null: no es una nota desaprobatoria.
      if (grade != null && grade > 0 && !rule.passes(grade)) {
        reasons.add(AlertReason.failing);
      }
      if (reasons.isEmpty) continue;
      out.add(
        StudentAlert(
          course: c,
          student: s,
          attendance: att,
          grade: grade,
          reasons: reasons,
        ),
      );
    }
  }
  out.sort((a, b) {
    if (a.critical != b.critical) return a.critical ? -1 : 1;
    final pa = a.attendance ?? 100, pb = b.attendance ?? 100;
    if (pa != pb) return pa.compareTo(pb);
    return a.student.displayName.compareTo(b.student.displayName);
  });
  return out;
}

/// Horario semanal de una sección, un tramo por día con los bloques seguidos
/// ya juntos, de lunes a domingo: Mié 10:45–13:00, Jue 11:30–13:00.
List<({int weekday, String start, String end})> weeklySlots(TeacherSubject c) {
  // 1 de enero de 2024 fue lunes.
  final monday = DateTime(2024);
  return [
    for (var wd = 1; wd <= 7; wd++)
      for (final s in sessionsOn([c], monday.add(Duration(days: wd - 1))))
        (weekday: wd, start: s.start, end: s.end),
  ];
}
