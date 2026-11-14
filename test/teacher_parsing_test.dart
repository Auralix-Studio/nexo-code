import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/data/repositories/nexo_teacher_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/grades/teacher_grade_entry.dart';
import 'package:nexo/features/teacher/attendance/teacher_session_edit.dart';

/// Modelos del docente (los que guarda el caché y leen las pantallas) y
/// reglas de edición tomadas del cliente oficial de la universidad.
void main() {
  group('asistencia', () {
    final sheet = AttendanceSheet.fromJson([
      {
        'codigo': 'U01',
        'nombreCompleto': 'ALVAREZ ANA',
        'observacion': '---',
        'matricula_asignatura_id': 'm1',
        'cod_cursal': '419329, 419321',
        'asistencia': 66.7,
        'detalle': [
          {
            'asistencia_id': 10,
            'fecha_asistencia': '2026-09-02T10:50:12',
            'estado_asist_id': 2,
            'tipo_unidad_id': 121,
          },
          {
            'asistencia_id': 11,
            'fecha_asistencia': '2026-09-01T10:46:00',
            'estado_asist_id': 1,
            'tipo_unidad_id': 121,
          },
        ],
      },
      {
        'codigo': 'U02',
        'nombreCompleto': 'BENITO BRUNO',
        'observacion': 'Suspensión',
        'matricula_asignatura_id': 'm2',
        'cod_cursal': '419329',
        'asistencia': 100,
        'detalle': [],
      },
    ]);

    test('parsea alumnos, marcas y riesgo', () {
      final a = sheet.students.first;
      expect(a.marks.first.date, DateTime(2026, 9, 1, 10, 46));
      expect(a.marks.last.asistenciaId, 10);
      expect(a.atRisk, isTrue);
      expect(a.firstCodCursal, '419329');
      expect(sheet.students.last.isSuspended, isTrue);
      expect(sheet.sessions(tipoUnidadId: 121), hasLength(2));
      expect(sheet.totals().absent, 1);
      expect(sheet.hasRecordsOn(DateTime(2026, 9, 2)), isTrue);
    });

    test('reglas de edición por celda', () {
      final now = DateTime(2026, 10, 7, 12);
      List<int> allowed(DateTime d, int cur, {bool susp = false}) =>
          TeacherSessionEditScreen.allowedStates(
            session: d,
            current: cur,
            suspended: susp,
            now: now,
          );
      expect(allowed(DateTime(2026, 10, 7, 10), 2), [1, 2]);
      expect(allowed(DateTime(2026, 10, 1, 10), 1), [2, 3]);
      expect(allowed(DateTime(2026, 10, 1, 10), 3), isEmpty);
      expect(allowed(DateTime(2026, 10, 7, 10), 4, susp: true), isEmpty);
    });
  });

  group('notas', () {
    test('celdas con su idNota y el caché sin conexión', () {
      final s = TeacherStudent.fromJson({
        'matriculaAsignaturaId': 'd43d',
        'codigo': 'U03763B',
        'nombreCompleto': 'BENITREZ POMA JHON',
        'notaFinal': 15,
        'unidades': [
          {
            'unidadId': 121,
            'nombre': 'UNIDAD 1',
            'porcentaje': 20,
            'promedioUnidad': 15,
            'grupos': [
              {
                'idTipoNota': 11,
                'tipoNotaAbr': 'EV',
                'peso': 100,
                'promedio': 14,
                'notas': [
                  {'idNota': 1662007, 'valor': 14},
                ],
              },
            ],
          },
        ],
      });
      final c = s.cellFor(121, 11)!;
      expect(c.notaId, 1662007);
      expect(c.value, 14);
      expect(s.cellFor(121, 12), isNull);
      // Se conserva todo en caché para el modo sin conexión.
      final back = TeacherStudent.fromJson(s.toJson());
      expect(back.cellFor(121, 11)?.notaId, 1662007);
      expect(back.matriculaAsignaturaId, 'd43d');
    });

    test('validación de notas', () {
      double? p(String s) => TeacherGradeEntryScreen.parseGrade(s, 20);
      expect(p('15'), 15);
      expect(p('15,5'), 15.5);
      expect(p('20'), 20);
      expect(p('20.01'), isNull);
      expect(p('21'), isNull);
      expect(p('-1'), isNull);
      expect(p('12.345'), isNull);
      expect(p('abc'), isNull);
      expect(p(''), isNull);
    });
  });

  group('marcación', () {
    test('mensajes S/I/E de la marcación', () {
      expect(parseSigmaMessage('S - Registrado'), (
        kind: 'S',
        text: 'Registrado',
      ));
      expect(parseSigmaMessage('Fuera de horario').kind, '');
    });

    test('hora del servidor sin cambiar de zona', () {
      expect(
        limaWallClock('2026-10-07T12:59:09.93-05:00'),
        DateTime(2026, 10, 7, 12, 59, 9),
      );
    });
  });

  group('nombres legibles para el docente', () {
    test('sin paréntesis, en mayúsculas y minúsculas y con romanos', () {
      expect(readableName('BASE DE DATOS I (2026-2)'), 'Base de Datos I');
      expect(
        readableName('INTERNET DE LAS COSAS (ELECTIVO) (2026-2)'),
        'Internet de las Cosas',
      );
      expect(readableName('PROGRAMACIÓN II'), 'Programación II');
      expect(
        readableName('TEORÍA-PRÁCTICA Y ÉTICA'),
        'Teoría-Práctica y Ética',
      );
      expect(readableName('DE LA TIERRA'), 'De la Tierra');
    });

    test('electiva, carrera sin modalidad y ciclo sin ceros', () {
      final c = TeacherSubject.fromJson({
        'id': '1',
        'nrc': '333196',
        'asignatura': 'INTERNET DE LAS COSAS (ELECTIVO) (2026-2)',
        'carrera': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN - PRESENCIAL',
        'ciclo': '09',
      });
      expect(c.displayName, 'Internet de las Cosas');
      expect(c.isElective, isTrue);
      expect(c.careerName, 'Ingeniería de Sistemas y Computación');
      expect(c.cycleLabel, '9');
    });

    test('foto: alumnos en FotosAlum y docentes (DNI) en PhotD', () {
      expect(
        AppConfig.photoUrlFor('U01025B'),
        'https://academico.upla.edu.pe/FotosAlum/037000U01025B.jpg',
      );
      expect(
        AppConfig.photoUrlFor('46996068'),
        'https://academico.upla.edu.pe/PhotD/46996068.jpg',
      );
    });
  });
}
