import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/domain/models.dart';

void main() {
  test('a Nexo section keeps what the teacher screens read', () {
    final s = teacherSubjectFromNexo({
      'id': 'sec_0123456789abcdef',
      'term': '2026-2',
      'nrc': '341120',
      'course': {'code': '341120', 'name': 'Internet de las Cosas'},
      'section': 'B1',
      'career': 'Ingenieria de Sistemas',
      'modality': 'in_person',
      'cycle': 4,
      'elective': true,
      'enrolled': 38,
      'campus': 'Huancayo',
      'room': {'building': 'Pabellón K', 'name': 'K 101', 'capacity': 40},
      'schedule': [
        {'weekday': 2, 'start': '16:45', 'end': '19:00', 'kind': 'practice'},
      ],
    });

    expect(s.id, 'sec_0123456789abcdef');
    expect(s.displayName, 'Internet de las Cosas');
    expect(s.isElective, isTrue);
    expect(s.modalidad, 'PRESENCIAL');
    expect(s.cycleLabel, '4');
    expect(s.blocks.single.type, 'P');
    expect(s.blocks.single.dayName, 'Martes');
    final schedule = teacherScheduleFromSubjects([s]).single;
    expect(
      (schedule.building, schedule.room, schedule.capacity),
      ('Pabellón K', 'K 101', 40),
    );
  });

  test('roster: code as enrolment key, column + 1 as grade id', () {
    final st = teacherStudentFromNexo({
      'code': 'U001',
      'name': 'Rojas Quispe Ana',
      'attendance_percent': 82.5,
      'suspended': false,
      'final_grade': 13.0,
      'units': [
        {
          'unit_id': 101,
          'name': 'Unidad 1',
          'weight_percent': 25,
          'average': 14,
          'evaluations': [
            {
              'type_id': 11,
              'abbr': 'EV',
              'weight_percent': 30,
              'grades': [15, 12],
            },
          ],
        },
      ],
    });

    expect(st.matriculaAsignaturaId, 'U001');
    expect(st.grade, '13.0');
    expect(st.cellFor(101, 11, 1)!.notaId, 2);
    expect(st.cellFor(101, 11, 1)!.value, 12);
    expect(st.units.single.grades.single.grade, '13.5');
  });

  test('grade writes: existing cells carry their column, new ones none', () {
    final body = gradeWriteBody(101, 11, const [
      GradeWrite(
        matricula: 'U001',
        unidadId: 101,
        tipoNotaId: 11,
        notaId: 2,
        nota: 16,
      ),
      GradeWrite(matricula: 'U002', unidadId: 101, tipoNotaId: 11, nota: 12),
    ]);
    expect(body['grades'], [
      {'student': 'U001', 'value': 16.0, 'column': 1},
      {'student': 'U002', 'value': 12.0},
    ]);
  });

  test('attendance sheet: sessions by timestamp, suspended kept', () {
    final sheet = attendanceSheetFromNexo({
      'sessions': [
        {'id': '2026-10-29T14:41:00', 'unit_id': 201},
      ],
      'students': [
        {
          'code': 'U002',
          'name': 'Perez Luis',
          'percent': 60,
          'suspended': true,
          'marks': [
            {'session': '2026-10-29T14:41:00', 'state': 'suspended'},
          ],
        },
      ],
    });
    final s = sheet.students.single;
    expect(s.isSuspended, isTrue);
    expect(s.atRisk, isTrue);
    expect(s.marks.single.state, AttendanceCode.suspended);
    expect(s.marks.single.tipoUnidadId, 201);
    expect(sessionIdOf(s.marks.single.date), '2026-10-29T14:41:00');
    expect(attendanceWord(AttendanceCode.none), isNull);
  });

  test('own attendance', () {
    final v = virtualClassFromNexo({
      'id': 'C123',
      'course': 'Base de Datos I',
      'section': 'A2',
      'start': '08:00',
      'end': '09:45',
      'tolerance': {'before_minutes': 10, 'after_minutes': 15},
      'checked_in_at': '07:58',
      'checked_out_at': null,
    });
    expect((v.canMarkIn, v.canMarkOut, v.toleranceEnd), (false, true, 15));

    final c = complianceFromNexo({
      'date': '2026-10-07',
      'weekday': 3,
      'course': 'Base de Datos I',
      'start': '08:00',
      'end': '09:45',
      'modality': 'in_person',
      'check_in': 'marked',
      'check_out': 'missing',
    });
    expect(
      (c.dayName, c.start, c.end),
      ('Miércoles', PunchStatus.marked, PunchStatus.missing),
    );

    final p = teacherPunchFromNexo({
      'date': '2026-10-07',
      'time': '07:58',
      'weekday': 3,
      'mode': 'Entrada',
      'location': 'VIRTUAL',
    });
    expect(p.isVirtual, isTrue);
  });
}
