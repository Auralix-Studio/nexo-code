import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:nexo/data/remote/backend_client.dart';
import 'package:nexo/data/repositories/nexo_repository.dart';
import 'package:nexo/data/services/directory_service.dart';
import 'package:nexo/domain/models.dart';

import 'support/fake_nexo_api.dart';

void main() {
  test('the backend profile maps to the Student the screens use', () {
    final student = studentFromNexo({
      'code': 'U01025B',
      'name': {'first': 'Ana', 'last': 'Rojas', 'full': 'Ana Rojas'},
      'faculty': 'Ingeniería',
      'career': 'Ingeniería de Sistemas y Computación',
      'campus': 'Huancayo',
      'modality': 'in_person',
      'study_plan': '2015',
      'current_cycle': 7,
      'enrolled': true,
      'last_enrollment': '2026-2',
      'credits': {'approved': 168, 'required': 220, 'enrolled_this_term': 22},
      'average': {'cumulative': 14.12},
    });

    expect(student.id, 'U01025B');
    expect(student.fullName, 'Ana Rojas');
    expect(student.level, '7');
    expect(student.modality, 'PRESENCIAL');
    expect(student.creditsApproved, 168);
    expect(student.creditsTotal, 220);
    expect(student.gpa, 14.12);
    expect(student.isEnrolled, isTrue);
  });

  test('missing values stay empty instead of breaking', () {
    final student = studentFromNexo({'code': 'U01025B', 'credits': {}});
    expect(student.fullName, '');
    expect(student.creditsApproved, isNull);
    expect(student.gpa, isNull);
  });

  test('terms keep the id format the app already stores', () {
    final term = termFromNexo({
      'id': '2026-2',
      'year': 2026,
      'number': 2,
      'label': '2026-II',
      'active': true,
    });

    expect(term.id, '20262');
    expect(term.label, '2026-II');
    expect(term.isActive, isTrue);
  });

  test('a schedule class keeps room, teacher and the lab type', () {
    final c = scheduleClassFromNexo({
      'id': 'abc',
      'course': {'code': 'IS-301', 'name': 'Base de Datos', 'nrc': null},
      'section': 'A1',
      'kind': 'lab',
      'weekday': 3,
      'day': 'Miércoles',
      'start': '10:00',
      'end': '11:30',
      'room': {
        'campus': 'Huancayo',
        'building': 'Pabellón H',
        'name': 'H 305',
        'capacity': 40,
      },
      'teacher': 'Garcia Lopez Ana',
      'modality': null,
      'source': 'university',
    });

    expect(c.nrc, 'IS-301');
    expect(c.subject, 'Base de Datos');
    expect(c.typeCode, 'L');
    expect(c.typeName, 'Laboratorio');
    expect(c.weekday, 3);
    expect(c.room, 'H 305');
    expect(c.capacity, 40);
    expect(c.teacher, 'Garcia Lopez Ana');
    expect(c.durationMinutes, 90);
  });

  test('a language course keeps its days and grades for the screens', () {
    final json = {
      'id': '555',
      'language': 'Inglés',
      'course': 'Inglés B1',
      'section': 'B',
      'modality': 'virtual',
      'period': {'year': 2026, 'month': 11},
      'current': true,
      'shift': 'Noche',
      'study_type': 'Regular',
      'room': 'Aula 5',
      'schedule': [
        {'weekday': 1, 'start': '19:00', 'end': '20:30'},
        {'weekday': 3, 'start': '19:00', 'end': '20:30'},
      ],
      'grades': {
        'items': [15.0, 14.0, null, null, null, null],
        'average': 14.5,
      },
    };

    final course = idiomasCourseFromNexo(json);
    expect(course.detMatriculaId, 555);
    expect(course.dias, 'LU-MI');
    expect(course.modalidad, 'VIRTUAL');
    expect(course.anio, 2026);
    expect(course.mes, 11);

    final grades = idiomasGradesFromNexo(json);
    expect(grades['detMatriculaId'], 555);
    expect(grades['promedio'], 14.5);
    expect(grades['nota1'], 15.0);
    expect(grades['nota3'], 0);
  });

  group('grades', () {
    final inProgress = {
      'id': 'IS-301',
      'code': 'IS-301',
      'name': 'Base de Datos',
      'section': 'A1',
      'cycle': 7,
      'credits': 3,
      'attendance_percent': 95,
      'status': 'in_progress',
      'grade': {'current': 14.6, 'official': 3},
      'closed': false,
      'units': [
        {
          'number': 1,
          'name': 'Unidad 1',
          'weight_percent': 20,
          'average': 14.6,
          'evidences': [
            {
              'type': 'knowledge',
              'label': 'Evidencia de Conocimiento',
              'weight_percent': 40,
              'grade': 14,
            },
          ],
        },
        {
          'number': 2,
          'name': 'Unidad 2',
          'weight_percent': 80,
          'average': null,
          'evidences': [],
        },
      ],
    };

    test('a competencies course keeps the backend averages', () {
      final c = reportCardCourseFromNexo(inProgress);
      expect(c.enrollmentSubjectId, 'IS-301');
      expect(c.credit, 3);
      expect(c.attendance, 95);
      expect(c.inProgress, isTrue);
      expect(c.vigesimalAverage, 14.6);
      expect(c.rawVigesimal, '3');

      final d = courseDetailFromNexo({
        'units': inProgress['units'],
        'final': {'current': 14.6, 'official': 3, 'status': 'in_progress'},
      });
      expect(d.units.first.average, 14.6);
      expect(d.units.last.average, isNull);
      expect(d.serverAverage, 14.6);
      expect(parseGrade(d.rawFinalAverage), 3);
    });

    test('a legacy course rebuilds both halves', () {
      final g = courseGradeFromNexo(
        {
          'code': 'IS-201',
          'name': 'Estructura de Datos',
          'cycle': 5,
          'credits': 4,
          'type': 'mandatory',
          'grade': {'current': 15, 'official': 15},
          'makeup_exam': null,
          'rank': {'position': 3, 'of': 40},
          'closed': true,
          'units': [
            {
              'number': 1,
              'average': 14,
              'practices_average': 14,
              'evidences': [
                {'type': 'practice', 'grade': 15},
                {'type': 'practice', 'grade': 13},
                {'type': 'partial_exam', 'grade': 13},
              ],
            },
            {
              'number': 2,
              'average': 16,
              'evidences': [
                {'type': 'practice', 'grade': 16},
              ],
            },
          ],
        },
        2025,
        2,
      );

      expect(g.isClosed, isTrue);
      expect(g.currentGradeNum, 15);
      expect(g.rank, '3/40');
      expect(g.subjectType, 'TN');
      expect(g.pF1, '14');
      expect(g.firstTerm.practices.take(2), ['15', '13']);
      expect(g.firstTerm.exam, '13');
      expect(g.secondTerm.practices.first, '16');
      expect(g.year, 2025);
    });

    test('summary and term averages', () {
      final summary = {
        'cumulative_average': 14.12,
        'credits': {'approved': 168, 'required': 220},
        'terms': [
          {'term': '2026-1', 'average': 13.8},
        ],
        'current_term': {'passed': 1, 'failed': 1, 'pending': 2},
      };
      expect(gradesSummaryFromNexo(summary).average, 14.12);
      expect(gradesSummaryFromNexo(summary).totalCredits, 220);
      final avg = termAveragesFromNexo(summary).single;
      expect((avg.year, avg.number, avg.average), (2026, 1, 13.8));
    });
  });

  group('payments', () {
    test('a charge keeps its due date in the format the model reads', () {
      final p = paymentFromNexo({
        'id': '2026-1-cuota-03-credits',
        'kind': 'credit_extension',
        'label': 'Ampliación de créditos',
        'term': '2026-1',
        'number': 3,
        'due_date': '2026-06-13',
        'amount': 124.0,
        'late_fee': 0.22,
        'total': 124.22,
        'status': 'pending',
        'note': '4 créditos × S/ 31.00',
      });
      expect(p.description, 'Ampliación de créditos · 2026-1');
      expect(p.dueDate, DateTime(2026, 6, 13));
      expect(p.total, 124.22);
      expect(p.note, '4 créditos × S/ 31.00');

      final enrollment = paymentFromNexo({
        'label': 'Matricula',
        'due_date': null,
        'total': 150.0,
      });
      expect(enrollment.dueDate, isNull);
    });

    test('schedule and history', () {
      final s = paymentScheduleFromNexo({
        'term_total': 2750.0,
        'installments': [
          {'number': 1, 'amount': 550.0, 'due_date': '2026-04-28'},
        ],
      });
      expect(s.totalAmount, 2750);
      expect(s.installments.single.number, '01');
      expect(s.installments.single.dueDate, DateTime(2026, 4, 28));

      final rows = paymentRecordsFromNexo({
        'operations': [
          {
            'id': '0002-002368017',
            'date': '2026-05-20',
            'term': '2026-1',
            'place': 'Caja Huancayo',
            'voucher': 'B010-1',
            'bank_reference': 'CMAC',
            'total': 522.5,
            'items': [
              {'concept': 'Cuota 02', 'kind': 'payment', 'amount': 550.0},
              {'concept': 'Dscto', 'kind': 'discount', 'amount': -27.5},
            ],
          },
        ],
      });
      expect(rows.length, 2);
      expect((rows.first.serial, rows.first.number), ('0002', '002368017'));
      expect(rows.last.amount, -27.5);
      expect(rows.last.voucher, 'B010-1');
      expect(rows.first.dateAsDate, DateTime(2026, 5, 20));
    });
  });

  test(
    'screens asking at once share one /payments and one summary call',
    () async {
      final gets = <String, int>{};
      final api = BackendClient(
        transport: MockClient((req) async {
          gets[req.url.path] = (gets[req.url.path] ?? 0) + 1;
          return nexoOk(switch (req.url.path) {
            '/payments' => {'pending': [], 'overdue': [], 'fees': []},
            _ => {'cumulative_average': 14.1, 'terms': []},
          });
        }),
      )..setToken('t');
      final repo = NexoRepository(DirectoryService(client: api));
      await Future.wait([
        repo.pendingPayments(),
        repo.overduePayments(),
        repo.fees(),
        repo.gradesSummary(),
        repo.termAverages(),
      ]);
      expect(gets.values.toList(), [1, 1]);
    },
  );
}
