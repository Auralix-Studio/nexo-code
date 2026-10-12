import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';

/// Motivo por el que un alumno aparece como "en riesgo" en el curso.
enum RiskReason { lowGrade, lowAttendance }

/// Alumno en riesgo junto con los motivos detectados.
class AtRiskStudent {
  const AtRiskStudent(this.student, this.reasons);
  final TeacherStudent student;
  final Set<RiskReason> reasons;
}

/// Criterio de orden para las listas del docente.
enum RosterSort { name, gradeDesc, gradeAsc, attendanceAsc }

/// Estadísticas de una sección calculadas en el cliente a partir del roster
/// que devuelve SIGMA (`NotasEstudianteResumenV1`). Es puro y sin efectos,
/// para poder probarlo sin red.
class CourseRosterStats {
  CourseRosterStats._({
    required this.total,
    required this.approved,
    required this.failed,
    required this.noGrade,
    required this.average,
    required this.attendanceAverage,
    required this.buckets,
    required this.atRisk,
  });

  /// Asistencia mínima por debajo de la cual se marca riesgo (en %).
  /// En la UPLA el 30 % de inasistencias inhabilita, así que < 70 % ya es
  /// zona roja para el docente.
  static const double attendanceThreshold = 70;

  final int total;
  final int approved;
  final int failed;
  final int noGrade;

  /// Promedio de las notas finales registradas (`null` si nadie tiene nota).
  final double? average;

  /// Promedio de asistencia en % (`null` si SIGMA no la manda).
  final double? attendanceAverage;

  /// Conteo por rango de nota final: [0–10.4], [10.5–13.9], [14–16.9], [17–20].
  final List<int> buckets;

  /// Alumnos desaprobados o con asistencia baja, los más críticos primero.
  final List<AtRiskStudent> atRisk;

  factory CourseRosterStats.from(
    List<TeacherStudent> alumnos, {
    PassingRule rule = PassingRule.standard,
  }) {
    var approved = 0, failed = 0, noGrade = 0;
    var sum = 0.0, graded = 0;
    var asisSum = 0.0, asisCount = 0;
    final buckets = List<int>.filled(4, 0);
    final risk = <AtRiskStudent>[];
    for (final a in alumnos) {
      final n = a.gradeNum;
      final reasons = <RiskReason>{};
      if (n == null) {
        noGrade++;
      } else {
        graded++;
        sum += n;
        if (rule.passes(n)) {
          approved++;
        } else {
          failed++;
          reasons.add(RiskReason.lowGrade);
        }
        buckets[bucketOf(n, rule)]++;
      }
      final pct = a.attendancePct;
      if (pct != null) {
        asisSum += pct;
        asisCount++;
        if (pct < attendanceThreshold) reasons.add(RiskReason.lowAttendance);
      }
      if (reasons.isNotEmpty) risk.add(AtRiskStudent(a, reasons));
    }
    risk.sort((x, y) {
      final byCount = y.reasons.length.compareTo(x.reasons.length);
      if (byCount != 0) return byCount;
      final gx = x.student.gradeNum ?? 99;
      final gy = y.student.gradeNum ?? 99;
      return gx.compareTo(gy);
    });
    return CourseRosterStats._(
      total: alumnos.length,
      approved: approved,
      failed: failed,
      noGrade: noGrade,
      average: graded == 0 ? null : sum / graded,
      attendanceAverage: asisCount == 0 ? null : asisSum / asisCount,
      buckets: buckets,
      atRisk: risk,
    );
  }

  /// Índice del rango de nota (ver [buckets]).
  static int bucketOf(double n, [PassingRule rule = PassingRule.standard]) {
    if (!rule.passes(n)) return 0;
    if (n < 14) return 1;
    if (n < 17) return 2;
    return 3;
  }

  /// Ordena una copia del roster. Los alumnos sin nota/asistencia van al final.
  static List<TeacherStudent> sorted(
    Iterable<TeacherStudent> alumnos,
    RosterSort sort,
  ) {
    final list = alumnos.toList();
    int byName(TeacherStudent a, TeacherStudent b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
    int nullsLast(double? x, double? y, {required bool desc}) {
      if (x == null && y == null) return 0;
      if (x == null) return 1;
      if (y == null) return -1;
      return desc ? y.compareTo(x) : x.compareTo(y);
    }

    list.sort((a, b) {
      final c = switch (sort) {
        RosterSort.name => 0,
        RosterSort.gradeDesc => nullsLast(a.gradeNum, b.gradeNum, desc: true),
        RosterSort.gradeAsc => nullsLast(a.gradeNum, b.gradeNum, desc: false),
        RosterSort.attendanceAsc => nullsLast(
          a.attendancePct,
          b.attendancePct,
          desc: false,
        ),
      };
      return c != 0 ? c : byName(a, b);
    });
    return list;
  }
}

/// Resumen de un día de asistencia: cuántos presentes, faltas y justificados.
({int presentes, int faltas, int justificadas}) attendanceDaySummary(
  Iterable<String?> estados,
) {
  var p = 0, f = 0, j = 0;
  for (final raw in estados) {
    switch ((raw ?? '').trim().toUpperCase()) {
      case 'P':
      case 'T':
      case '1':
        p++;
      case 'F':
      case '2':
        f++;
      case 'J':
      case '3':
        j++;
    }
  }
  return (presentes: p, faltas: f, justificadas: j);
}

/// Hora "H:MM[:SS]" → minutos desde medianoche, o `null` si no se entiende.
/// Ordenar por minutos evita el error de comparar texto ("10:00" < "8:00").
int? hmToMinutes(String hm) {
  final p = hm.trim().split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  return (h == null || m == null) ? null : h * 60 + m;
}

/// Comparador de horas tolerante a horas sin cero a la izquierda.
int compareHm(String a, String b) {
  final x = hmToMinutes(a);
  final y = hmToMinutes(b);
  if (x == null || y == null) return a.compareTo(b);
  return x.compareTo(y);
}
