import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/domain/grade_calculator.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

// ─── Helpers ───

BoletaCurso _curso(double credito, String nota, [String codigo = 'X']) =>
    BoletaCurso(
      matriculaAsignaturaId: codigo,
      plan: '2022',
      codigo: codigo,
      nombre: 'Curso $codigo',
      seccion: 'A',
      credito: credito,
      asistenciaRaw: '100',
      promedioRaw: nota,
      estado: nota.trim().isEmpty || nota.trim() == '-' ? '-' : 'Dsp.',
    );

const _parcialVacio = NotasParcial(
  practicas: ['', '', '', ''],
  promPracticas: '',
  trabajoInv: '',
  proyecto: '',
  promTiPy: '',
  examen: '',
);

NotaAsignatura _legacy(double credito, String nota) => NotaAsignatura(
      codigo: 'X',
      asignatura: 'Curso',
      seccion: 'A',
      ciclo: 'I',
      credito: credito,
      asistencia: null,
      tipoAsignatura: 'TN',
      anio: 2025,
      periodoNum: 1,
      pf: nota,
      pfp: '',
      complementario: '',
      cc: 'true',
      puesto: '',
      pF1: '',
      pF2: '',
      primer: _parcialVacio,
      segundo: _parcialVacio,
    );

void main() {
  group('promedioPonderadoBoleta (modelo nuevo)', () {
    test('reproduce el "Promedio ponderado" oficial de Intranet = 8.23', () {
      // Datos reales del portal (2026-1). El curso con "-" no cuenta.
      final cursos = [
        _curso(2, '5.80'),
        _curso(3, '6.13'),
        _curso(2, '5.53'),
        _curso(2, '5.40'),
        _curso(2, '3.47'),
        _curso(2, '5.00'),
        _curso(2, '5.93'),
        _curso(2, '5.80'),
        _curso(1, '-'), // TALLER VI — en proceso, sin nota → excluido
        _curso(2, '4.20'),
        _curso(1, '78.13'),
        _curso(3, '3.53'),
      ];
      final r = GradeCalculator.promedioPonderadoBoleta(cursos);
      expect(r, isNotNull);
      expect(r!.toStringAsFixed(2), '8.23');
    });

    test('pondera por créditos (no es media simple)', () {
      // (18*4 + 12*2) / 6 = 16.0
      final cursos = [_curso(4, '18', 'A'), _curso(2, '12', 'B')];
      expect(GradeCalculator.promedioPonderadoBoleta(cursos), 16.0);
    });

    test('ignora cursos sin nota ("-")', () {
      final cursos = [_curso(3, '15', 'A'), _curso(3, '-', 'B')];
      expect(GradeCalculator.promedioPonderadoBoleta(cursos), 15.0);
    });

    test('sin cursos con nota → null', () {
      expect(
        GradeCalculator.promedioPonderadoBoleta([_curso(3, '-', 'A')]),
        isNull,
      );
    });
  });

  group('promedioPonderadoLegacy (≤2025)', () {
    test('pondera por créditos', () {
      final cursos = [_legacy(4, '18'), _legacy(2, '12')];
      expect(GradeCalculator.promedioPonderadoLegacy(cursos), 16.0);
    });

    test('ignora cursos sin nota', () {
      final cursos = [_legacy(3, '15'), _legacy(3, '')];
      expect(GradeCalculator.promedioPonderadoLegacy(cursos), 15.0);
    });
  });

  group('promedioAcumulado', () {
    TermAverage t(int year, int number, double avg) =>
        TermAverage(year: year, number: number, average: avg);

    test('excluye el periodo activo en curso', () {
      final periodos = [t(2024, 1, 14), t(2024, 2, 16), t(2025, 1, 0)];
      expect(
        GradeCalculator.promedioAcumulado(periodos,
            activeYear: 2025, activeNumber: 1),
        15.0,
      );
    });

    test('excluye periodos con promedio 0', () {
      expect(
        GradeCalculator.promedioAcumulado([t(2024, 1, 0), t(2024, 2, 15)]),
        15.0,
      );
    });

    test('sin periodos cerrados → null', () {
      expect(
        GradeCalculator.promedioAcumulado([t(2025, 1, 0)],
            activeYear: 2025, activeNumber: 1),
        isNull,
      );
    });
  });
}
