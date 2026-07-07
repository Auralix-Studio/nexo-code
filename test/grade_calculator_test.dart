import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/domain/grade_calculator.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

// ─── Helpers ───

ReportCardCourse _curso(double credit, String grade, [String code = 'X']) =>
    ReportCardCourse(
      enrollmentSubjectId: code,
      plan: '2022',
      code: code,
      name: 'Course $code',
      section: 'A',
      credit: credit,
      rawAttendance: '100',
      rawAverage: grade,
      state: grade.trim().isEmpty || grade.trim() == '-' ? '-' : 'Dsp.',
    );

const _parcialVacio = TermGrades(
  practices: ['', '', '', ''],
  practicesAverage: '',
  researchWork: '',
  project: '',
  researchProjectAverage: '',
  exam: '',
);

CourseGrade _legacy(double credit, String grade) => CourseGrade(
      code: 'X',
      subject: 'Course',
      section: 'A',
      cycle: 'I',
      credit: credit,
      attendance: null,
      subjectType: 'TN',
      year: 2025,
      periodNum: 1,
      pf: grade,
      pfp: '',
      complementary: '',
      cc: 'true',
      rank: '',
      pF1: '',
      pF2: '',
      firstTerm: _parcialVacio,
      secondTerm: _parcialVacio,
    );

void main() {
  group('promedioPonderadoBoleta (modelo nuevo)', () {
    test('reproduce el "Promedio ponderado" oficial de Intranet = 8.23', () {
      // Datos reales del portal (2026-1). El course con "-" no cuenta.
      final courses = [
        _curso(2, '5.80'),
        _curso(3, '6.13'),
        _curso(2, '5.53'),
        _curso(2, '5.40'),
        _curso(2, '3.47'),
        _curso(2, '5.00'),
        _curso(2, '5.93'),
        _curso(2, '5.80'),
        _curso(1, '-'), // TALLER VI — en proceso, sin grade → excluido
        _curso(2, '4.20'),
        _curso(1, '78.13'),
        _curso(3, '3.53'),
      ];
      final r = GradeCalculator.promedioPonderadoBoleta(courses);
      expect(r, isNotNull);
      expect(r!.toStringAsFixed(2), '8.23');
    });

    test('pondera por créditos (no es media simple)', () {
      // (18*4 + 12*2) / 6 = 16.0
      final courses = [_curso(4, '18', 'A'), _curso(2, '12', 'B')];
      expect(GradeCalculator.promedioPonderadoBoleta(courses), 16.0);
    });

    test('ignora courses sin grade ("-")', () {
      final courses = [_curso(3, '15', 'A'), _curso(3, '-', 'B')];
      expect(GradeCalculator.promedioPonderadoBoleta(courses), 15.0);
    });

    test('sin courses con grade → null', () {
      expect(
        GradeCalculator.promedioPonderadoBoleta([_curso(3, '-', 'A')]),
        isNull,
      );
    });
  });

  group('promedioPonderadoLegacy (≤2025)', () {
    test('pondera por créditos', () {
      final courses = [_legacy(4, '18'), _legacy(2, '12')];
      expect(GradeCalculator.promedioPonderadoLegacy(courses), 16.0);
    });

    test('ignora courses sin grade', () {
      final courses = [_legacy(3, '15'), _legacy(3, '')];
      expect(GradeCalculator.promedioPonderadoLegacy(courses), 15.0);
    });
  });

  group('promedioAcumulado', () {
    TermAverage t(int year, int number, double avg) =>
        TermAverage(year: year, number: number, average: avg);

    test('excluye el periodo activo en course', () {
      final periodos = [t(2024, 1, 14), t(2024, 2, 16), t(2025, 1, 0)];
      expect(
        GradeCalculator.promedioAcumulado(periodos,
            activeYear: 2025, activeNumber: 1),
        15.0,
      );
    });

    test('excluye periodos con average 0', () {
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
