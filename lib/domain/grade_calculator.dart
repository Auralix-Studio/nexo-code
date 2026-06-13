import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

/// Cálculos académicos **puros** — sin dependencias de Flutter, red ni estado.
///
/// Se aíslan aquí (fuera de `AppStore`) precisamente para poder testearlos con
/// datos simulados. Reglas explícitas y compartidas para todo cálculo de
/// promedio de la app.
class GradeCalculator {
  GradeCalculator._();

  /// Umbral de aprobación de UPLA (≥ 10.5 redondea a 11).
  static const double notaAprobatoria = 10.5;

  /// Promedio **ponderado por créditos** del ciclo (boleta modelo nuevo,
  /// 2026-1+). Reproduce el "Promedio ponderado" que muestra el portal de
  /// Intranet: `Σ(crédito × nota) / Σ(crédito)`, sobre los cursos con nota
  /// numérica (los "en proceso" sin nota, p.ej. estado "-", no cuentan).
  static double? promedioPonderadoBoleta(List<BoletaCurso> cursos) {
    double sumaPonderada = 0;
    double sumaCreditos = 0;
    for (final c in cursos) {
      final nota = c.promedio; // null si "-"/vacío
      if (nota == null) continue;
      if (c.credito <= 0) continue;
      sumaPonderada += nota * c.credito;
      sumaCreditos += c.credito;
    }
    if (sumaCreditos == 0) return null;
    return sumaPonderada / sumaCreditos;
  }

  /// Promedio **ponderado por créditos** del ciclo, modelo legacy (≤2025).
  /// Misma fórmula; la fila legacy trae su propio crédito y nota.
  static double? promedioPonderadoLegacy(List<NotaAsignatura> cursos) {
    double sumaPonderada = 0;
    double sumaCreditos = 0;
    for (final c in cursos) {
      final nota = c.notaActualNum;
      if (nota == null) continue;
      if (c.credito <= 0) continue;
      sumaPonderada += nota * c.credito;
      sumaCreditos += c.credito;
    }
    if (sumaCreditos == 0) return null;
    return sumaPonderada / sumaCreditos;
  }

  /// Promedio **acumulado** de periodos cerrados.
  ///
  /// Excluye el periodo activo (aún en curso) y los periodos sin promedio
  /// (`average == 0`). Media simple de los promedios por periodo: `TermAverage`
  /// no transporta créditos, así que no es ponderable por carga.
  static double? promedioAcumulado(
    List<TermAverage> periodos, {
    int? activeYear,
    int? activeNumber,
  }) {
    final cerrados = periodos.where((p) {
      if (p.average == 0) return false;
      final esActivo = activeYear != null &&
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
