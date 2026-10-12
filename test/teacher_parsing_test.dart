import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/config.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_grade_entry.dart';
import 'package:nexo/features/teacher/teacher_session_edit.dart';

/// Formas reales de SIGMA (capturas con cuenta docente, octubre 2026) y
/// reglas tomadas del cliente oficial (`sigma.upla.edu.pe`).
void main() {
  final asistenciaRow = <String, dynamic>{
    'id': '419329, 419321, 419325',
    'nrc': '332142',
    'asignatura': 'BASE DE DATOS I (2026-2)',
    'idModalidad': '0',
    'modalidad': 'Presencial',
    'carrera': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN - PRESENCIAL',
    'seccion': 'A1',
    'sede': 'HUANCAYO',
    'local': 'CAMPUS UNIVERSITARIO',
    'aula': 'PABELLON H - H 302 - AFORO: 60',
    'horario':
        'Jueves 11:30:00 13:00:00 P, Miércoles 10:45:00 11:30:00 T, '
        'Miércoles 11:30:00 13:00:00 P',
    'plan': '2022',
    'ciclo': '4',
    'tipoCalif': 12,
  };
  final notasRow = <String, dynamic>{
    'id': '1365838',
    'nrc': '332142',
    'asignatura': 'BASE DE DATOS I (2026-2)',
    'carrera': 'INGENIERÍA DE SISTEMAS Y COMPUTACIÓN',
    'seccion': 'A1',
    'sede': 'HUANCAYO - PRESENCIAL',
    'horario': null,
    'plan': '2022',
    'ciclo': '04',
    'tipoCalif': 12,
  };

  group('secciones', () {
    test('cruza modo=Notas con modo=Asistencia por NRC', () {
      final out = TeacherRepository.mergeAsignaturas(
        [notasRow],
        [asistenciaRow],
      );
      final c = out.single;
      expect(c.id, '1365838');
      expect(c.asistenciaId, '419329, 419321, 419325');
      // GetAsistencia usa el id de modo=Asistencia, no el de notas.
      expect(c.attendanceCodSaltem, '419329, 419321, 419325');
      expect(c.aula, 'PABELLON H - H 302 - AFORO: 60');
      expect(c.shortName, 'BASE DE DATOS I');
      expect(c.blocks, hasLength(3));
    });

    test('sin par de asistencia conserva la sección', () {
      final c = TeacherRepository.mergeAsignaturas([notasRow], []).single;
      expect(c.asistenciaId, isEmpty);
      expect(c.attendanceCodSaltem, '1365838');
    });

    test('ids de horario por día en orden domingo→sábado (a2n de SIGMA)', () {
      final blocks = TeacherBlock.parse(
        asistenciaRow['horario'] as String,
        asistenciaRow['id'] as String,
      );
      // Miércoles (orden 4) va antes que Jueves (orden 5).
      expect(blocks.map((b) => (b.dayName, b.start, b.id)).toList(), [
        ('Miércoles', '10:45', '419329'),
        ('Miércoles', '11:30', '419329'),
        ('Jueves', '11:30', '419321'),
      ]);
      expect(blocks.first.type, 'T');
      expect(blocks.first.isOngoing(DateTime(2026, 10, 7, 11)), isTrue);
      expect(blocks.first.isOngoing(DateTime(2026, 10, 8, 11)), isFalse);
    });

    test('la sección sobrevive al caché (toJson/fromJson)', () {
      final c = TeacherRepository.mergeAsignaturas(
        [notasRow],
        [asistenciaRow],
      ).single;
      final back = TeacherSubject.fromJson(c.toJson());
      expect(back.asistenciaId, c.asistenciaId);
      expect(back.blocks.length, 3);
      expect(back.blocks.last.id, '419321');
    });
  });

  test('horario docente para la pestaña Horario sale de las asignaturas', () {
    final merged = TeacherRepository.mergeAsignaturas(
      [notasRow],
      [asistenciaRow],
    );
    final out = TeacherRepository.scheduleFromSubjects(merged);
    expect(out, hasLength(3));
    expect(out.first.weekday, 3);
    expect(out.first.startTime, '10:45');
    expect(out.first.typeCode, 'T');
    expect(out.first.room, 'H 302');
    expect(out.first.subject, 'Base de Datos I');
    // Sin cruce con `modo=Asistencia` no hay bloques.
    final soloNotas = TeacherRepository.mergeAsignaturas([notasRow], const []);
    expect(TeacherRepository.scheduleFromSubjects(soloNotas), isEmpty);
  });

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

    test('payload de registro igual al cliente oficial', () {
      final body = TeacherRepository.buildAttendanceInsert(
        fecha: DateTime(2026, 10, 7, 9, 5, 3),
        unidadId: 122,
        marks: [
          (student: sheet.students.first, state: AttendanceCode.absent),
          (student: sheet.students.last, state: AttendanceCode.present),
        ],
      );
      expect(body['fecha_asistencia'], '2026-10-07 9:5:3');
      expect(body['asistencia'], [
        {
          'matricula_asignatura_id': 'm1',
          'estado_asist_id': 2,
          'cod_cursal': '419329',
          'tipo_unidad_id': 122,
        },
        // Suspendido: siempre estado 4.
        {
          'matricula_asignatura_id': 'm2',
          'estado_asist_id': 4,
          'cod_cursal': '419329',
          'tipo_unidad_id': 122,
        },
      ]);
    });

    test('payload de corrección', () {
      final a = sheet.students.first;
      final body = TeacherRepository.buildAttendanceUpdate([
        (mark: a.marks.last, student: a, state: AttendanceCode.justified),
      ]);
      expect(body, {
        'asistencia': [
          {
            'asistencia_id': 10,
            'matricula_asignatura_id': 'm1',
            'estado_asist_id': 3,
          },
        ],
      });
    });

    test('reglas de edición por celda de SIGMA', () {
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
    test('celdas con idNota desde NotasEstudianteResumenV1', () {
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

    test('tipo de nota desde getTipoNota', () {
      final t = GradeType.fromJson({
        'tipo_nota_id': 11,
        'tipo_nota_abr': 'EV',
        'tipo_nota_desc': 'EVIDENCIA DE CONOCIMIENTO',
        'tipo_nota_escala': '0 - 20    ',
        'tipo_nota_cant_max': 1,
        'minimo_aprob': 10.5,
        'tipo_nota_color': '#8CCD8C',
      });
      expect(t.maxValue, 20);
      expect(t.minPass, 10.5);
      expect(t.maxCount, 1);
    });

    test('payloads de InsertarNotas y UpdateNota', () {
      const ins = GradeWrite(
        matricula: 'm',
        unidadId: 121,
        tipoNotaId: 11,
        nota: 18,
      );
      expect(ins.isUpdate, isFalse);
      expect(ins.toInsertJson(), {
        'matricula_asignatura_id': 'm',
        'tipo_unidad_id': 121,
        'tipo_nota_id': 11,
        'nota': 18.0,
      });
      const upd = GradeWrite(
        matricula: 'm',
        unidadId: 121,
        tipoNotaId: 11,
        notaId: 1662007,
        nota: 18,
      );
      expect(upd.isUpdate, isTrue);
      expect(upd.toUpdateJson()['nota_id'], 1662007);
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
    test('clase virtual desde getAsistenciaDocente', () {
      final c = VirtualClass.fromJson({
        'codigo': '987',
        'asignatura': 'BASE DE DATOS I',
        'car_Id': 'SISTEMAS',
        'nivel': '04',
        'seccion': 'A1',
        'dia_marcado': '2026-10-07T00:00:00',
        'hora_ini': '10:45:00',
        'hora_fin': '13:00:00',
        'tol_ini': 10,
        'tol_fin': 5,
        'marc_entrada': '10:47:12',
        'marc_salida': '00:00:00',
      });
      expect(c.hasIn, isTrue);
      expect(c.canMarkIn, isFalse);
      expect(c.canMarkOut, isTrue);
    });

    test('mensajes S/I/E de SIGMA', () {
      expect(parseSigmaMessage('S - Registrado'), (
        kind: 'S',
        text: 'Registrado',
      ));
      expect(parseSigmaMessage('Fuera de horario').kind, '');
    });

    test('cumplimiento desde getAsistenciaDiaria', () {
      final c = TeacherClassCompliance.fromJson({
        'idDia': 3,
        'horaInicio': '10:45',
        'statusInicio': 'X',
        'statusFin': '1',
        'fecha': '09/30/2026 00:00:00',
      });
      expect(c.date, DateTime(2026, 9, 30));
      expect(c.start, PunchStatus.missing);
      expect(c.end, PunchStatus.marked);
    });

    test('hora del servidor sin cambiar de zona', () {
      expect(
        TeacherRepository.parseServerTime('2026-10-07T12:59:09.93-05:00'),
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
