import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class GradeCalculator {
  GradeCalculator._();
  static const double notaAprobatoria = 10.5;
  static double? promedioPonderadoBoleta(List<ReportCardCourse> courses) {
    double sumaPonderada = 0;
    double sumaCreditos = 0;
    for (final c in courses) {
      final grade = c.average;
      if (grade == null) continue;
      if (c.credit <= 0) continue;
      sumaPonderada += grade * c.credit;
      sumaCreditos += c.credit;
    }
    if (sumaCreditos == 0) return null;
    return sumaPonderada / sumaCreditos;
  }

  static double? promedioPonderadoLegacy(List<CourseGrade> courses) {
    double sumaPonderada = 0;
    double sumaCreditos = 0;
    for (final c in courses) {
      final grade = c.currentGradeNum;
      if (grade == null) continue;
      if (c.credit <= 0) continue;
      sumaPonderada += grade * c.credit;
      sumaCreditos += c.credit;
    }
    if (sumaCreditos == 0) return null;
    return sumaPonderada / sumaCreditos;
  }

  static double? promedioAcumulado(
    List<TermAverage> periodos, {
    int? activeYear,
    int? activeNumber,
  }) {
    final cerrados = periodos.where((p) {
      if (p.average == 0) return false;
      final esActivo =
          activeYear != null &&
          activeNumber != null &&
          p.year == activeYear &&
          p.number == activeNumber;
      return !esActivo;
    }).toList();
    if (cerrados.isEmpty) return null;
    final suma = cerrados.fold<double>(0, (a, b) => a + b.average);
    return suma / cerrados.length;
  }
}
