import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/domain/grade_paste.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/teacher_insights.dart';

TeacherSubject _course(String id, String nrc, String horario) =>
    TeacherRepository.mergeAsignaturas(
      [
        {
          'id': id,
          'nrc': nrc,
          'asignatura': 'CURSO $nrc (2026-2)',
          'seccion': 'A1',
          'tipoCalif': 12,
        },
      ],
      [
        {'id': '9$id', 'nrc': nrc, 'seccion': 'A1', 'horario': horario},
      ],
    ).single;

AttendanceSheet _sheet(List<String> dates) => AttendanceSheet.fromJson([
  {
    'codigo': 'U001',
    'nombreCompleto': 'ALVAREZ ANA',
    'matricula_asignatura_id': 'm1',
    'detalle': [
      for (final d in dates)
        {'fecha_asistencia': d, 'estado_asist_id': 1, 'tipo_unidad_id': 121},
    ],
  },
]);

TeacherStudent _student(String code, {String? att, Object? grade}) =>
    TeacherStudent.fromJson({
      'codigo': code,
      'nombreCompleto': 'ALUMNO $code',
      'asistencia': att,
      'notaFinal': grade,
    });

void main() {
  // BD I: miércoles 10:45–11:30 T + 11:30–13:00 P, jueves 11:30–13:00 P.
  final bd = _course(
    '1365838',
    '332142',
    'Jueves 11:30:00 13:00:00 P, Miércoles 10:45:00 11:30:00 T, '
        'Miércoles 11:30:00 13:00:00 P',
  );
  // IoT: lunes y jueves 17:30–19:00.
  final iot = _course(
    '1370908',
    '333196',
    'Jueves 17:30:00 19:00:00 P, Lunes 17:30:00 19:00:00 T',
  );

  group('agenda', () {
    test('junta teoría y práctica seguidas en una sola clase', () {
      // Miércoles 7 de octubre de 2026.
      final s = sessionsOn([bd, iot], DateTime(2026, 10, 7));
      expect(s, hasLength(1));
      expect((s.single.start, s.single.end), ('10:45', '13:00'));
    });

    test('teoría de mañana y práctica de noche son dos clases', () {
      final fp = _course(
        '1371480',
        '332116',
        'Viernes 11:30:00 13:00:00 T, Viernes 19:45:00 21:15:00 P',
      );
      final friday = DateTime(2026, 10, 16);
      expect(sessionsOn([fp], friday).map((s) => (s.start, s.end)), [
        ('11:30', '13:00'),
        ('19:45', '21:15'),
      ]);
      // La asistencia es por fecha: se reclama una sola vez.
      final missing = missingAttendance(
        [fp],
        {fp.id: _sheet(const [])},
        DateTime(2026, 10, 16, 22),
        days: 1,
      );
      expect(missing, hasLength(1));
    });

    test('ordena las clases del día por hora', () {
      final s = sessionsOn([iot, bd], DateTime(2026, 10, 15)); // jueves
      expect(s.map((e) => e.course.nrc), ['332142', '333196']);
    });

    test('fase de la clase según la hora', () {
      final s = sessionsOn([bd], DateTime(2026, 10, 7)).single;
      expect(s.phaseAt(DateTime(2026, 10, 7, 9)), ClassPhase.upcoming);
      expect(s.phaseAt(DateTime(2026, 10, 7, 12)), ClassPhase.ongoing);
      expect(s.phaseAt(DateTime(2026, 10, 7, 13, 1)), ClassPhase.finished);
    });

    test('próxima clase salta al siguiente día con clases', () {
      final next = nextSession([bd, iot], DateTime(2026, 10, 6, 14));
      expect(next!.course.nrc, '332142');
      expect(next.day, DateTime(2026, 10, 7)); // miércoles
    });

    test('próxima clase salta feriados', () {
      // Jueves 8 (Angamos) no hay clase: la siguiente es IoT el lunes 12.
      final next = nextSession([bd, iot], DateTime(2026, 10, 7, 14));
      expect(next!.course.nrc, '333196');
      expect(next.day, DateTime(2026, 10, 12));
    });
  });

  group('clases sin asistencia', () {
    // Viernes 16 de octubre, 20:00. Hubo clase de BD el miércoles 7, el
    // miércoles 14 y el jueves 15; el jueves 8 (Angamos) fue feriado.
    final now = DateTime(2026, 10, 16, 20);

    test('reclama solo las fechas sin marcas, de las dos últimas semanas', () {
      final missing = missingAttendance(
        [bd],
        {
          bd.id: _sheet(['2026-10-14T10:50:00']),
        },
        now,
      );
      expect(missing.map((s) => s.day), [
        DateTime(2026, 10, 15),
        DateTime(2026, 10, 7),
      ]);
      // Con una ventana de una semana, el miércoles 7 ya queda fuera.
      final week = missingAttendance(
        [bd],
        {
          bd.id: _sheet(['2026-10-14T10:50:00']),
        },
        now,
        days: 7,
      );
      expect(week.map((s) => s.day), [DateTime(2026, 10, 15)]);
    });

    test(
      'omite feriados, descartadas, hojas no cargadas y clases sin terminar',
      () {
        final empty = _sheet(const []);
        // El 8 de octubre es feriado aunque hubo bloque de BD ese jueves.
        final week = missingAttendance(
          [bd],
          {bd.id: empty},
          DateTime(2026, 10, 9, 8),
          days: 7,
        );
        expect(week.map((s) => s.day), [DateTime(2026, 10, 7)]);

        final dismissed = missingAttendance(
          [bd],
          {bd.id: empty},
          now,
          days: 7,
          dismissed: {'${bd.id}|2026-10-15'},
        );
        expect(dismissed.map((s) => s.day), [DateTime(2026, 10, 14)]);

        expect(missingAttendance([bd], const {}, now), isEmpty);

        // Jueves 15 a las 12:00: la clase aún no termina.
        final during = missingAttendance(
          [bd],
          {bd.id: empty},
          DateTime(2026, 10, 15, 12),
          days: 7,
        );
        expect(during.map((s) => s.day), [DateTime(2026, 10, 14)]);
      },
    );

    test('feriados nacionales, incluidos Jueves y Viernes Santo', () {
      expect(PeruHolidays.easterSunday(2026), DateTime(2026, 4, 5));
      expect(PeruHolidays.easterSunday(2027), DateTime(2027, 3, 28));
      expect(PeruHolidays.isHoliday(DateTime(2026, 4, 2)), isTrue);
      expect(PeruHolidays.isHoliday(DateTime(2026, 4, 3)), isTrue);
      expect(PeruHolidays.isHoliday(DateTime(2026, 10, 8)), isTrue);
      expect(PeruHolidays.isHoliday(DateTime(2026, 10, 7)), isFalse);
    });
  });

  group('alumnos que necesitan atención', () {
    test('niveles de asistencia y nota a la fecha', () {
      final alerts = studentAlerts(
        [bd],
        {
          bd.id: [
            _student('A', att: '100', grade: 15),
            _student('B', att: '80', grade: 14),
            _student('C', att: '65', grade: 12),
            _student('D', att: '95', grade: 9),
            _student('E', att: '100', grade: 0), // sin notas aún
            _student('F', att: '81', grade: null),
          ],
        },
      );
      expect(alerts.map((a) => a.student.code), ['C', 'D', 'B']);
      expect(alerts[0].reasons, {AlertReason.attendanceCritical});
      expect(alerts[1].reasons, {AlertReason.failing});
      expect(alerts[2].reasons, {AlertReason.attendanceWarning});
      expect(alerts[2].critical, isFalse);
    });

    test('10.5 aprueba (redondeo vigesimal)', () {
      final alerts = studentAlerts(
        [bd],
        {
          bd.id: [_student('A', att: '100', grade: '10.5')],
        },
      );
      expect(alerts, isEmpty);
    });
  });

  group('pegar notas desde Excel', () {
    const codes = ['U001', 'U002', 'U003'];

    test('por código, con coma decimal y en cualquier orden', () {
      final p = parseGradePaste(
        'CODIGO\tNOTA\nu003\t8,5\nU001\t16\n',
        codes,
        max: 20,
      )!;
      expect(p.byCode, isTrue);
      expect(p.values, {'U003': 8.5, 'U001': 16.0});
      expect(p.skipped, 0);
    });

    test('por código ignora filas ambiguas o fuera de rango', () {
      final p = parseGradePaste(
        '1\tU001\tALVAREZ ANA\t14\n'
        '2\tU002\tBENITO\t25\n'
        '3\tU003\tCASTRO\t12\t13\n'
        'U999\t11\n',
        codes,
        max: 20,
      )!;
      expect(p.values, {'U001': 14.0});
      expect(p.skipped, 3);
    });

    test('por orden, con encabezado, celda vacía y N.º de orden', () {
      final p = parseGradePaste('NOTA\n1  15\n\n3  9.5\r\n', codes, max: 20)!;
      expect(p.byCode, isFalse);
      expect(p.values, {'U001': 15.0, 'U003': 9.5});
    });

    test('por orden no aplica nada si no cuadra el número de filas', () {
      final p = parseGradePaste('15\n12\n', codes, max: 20)!;
      expect(p.mismatchRows, 2);
      expect(p.values, isEmpty);
    });

    test('portapapeles sin notas', () {
      expect(parseGradePaste('', codes, max: 20), isNull);
      expect(parseGradePaste('hola\nmundo', codes, max: 20), isNull);
    });

    test('validación de una nota', () {
      expect(parseGradeValue('12,5', 20), 12.5);
      expect(parseGradeValue('20', 20), 20);
      expect(parseGradeValue('20.5', 20), isNull);
      expect(parseGradeValue('1.234', 20), isNull);
      expect(parseGradeValue('-1', 20), isNull);
    });
  });
}
