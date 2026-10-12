import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/api_client.dart';
import 'package:nexo/data/teacher_repository.dart';
import 'package:nexo/domain/course_roster_stats.dart';
import 'package:nexo/domain/models.dart';

/// Fila real (recortada) de `Docente/NotasEstudianteResumenV1`.
Map<String, dynamic> _alumnoJson({
  String codigo = 'A001',
  String nombre = 'QUISPE MAMANI JUAN CARLOS',
  Object? notaFinal = 12,
  Object? asistencia = 90,
  List<Map<String, dynamic>> notas = const [
    {'idNota': 777},
  ],
}) => {
  'codigo': codigo,
  'nombreCompleto': nombre,
  'notaFinal': notaFinal,
  'asistencia': asistencia,
  'matriculaAsignaturaId': 5010,
  'unidades': [
    {
      'unidadId': 121,
      'nombre': 'UNIDAD I',
      'porcentaje': 50,
      'promedioUnidad': 12.5,
      'grupos': [
        {
          'tipoNotaAbr': 'PR',
          'peso': 30,
          'promedio': 13,
          'idTipoNota': 13,
          'notas': notas,
        },
        {
          'tipoNotaAbr': 'EV',
          'peso': 40,
          'promedio': null,
          'idTipoNota': 11,
          'notas': const [],
        },
      ],
    },
  ],
};

void main() {
  group('TeacherStudent', () {
    test('parsea unidades con ids de escritura y orden EV/DE/PR', () {
      final a = TeacherStudent.fromJson(_alumnoJson());
      final grades = a.units.single.grades;
      expect(grades.map((g) => g.code), ['EV', 'PR']);
      final pr = grades.last;
      expect(pr.tipoUnidadId, 121);
      expect(pr.tipoNotaId, 13);
      expect(pr.notaId, 777);
      expect(pr.noteCount, 1);
      expect(pr.isEditable, isTrue);
      expect(grades.first.grade, isNull, reason: 'sin notas = pendiente');
    });

    test('un componente con varias notas no es editable', () {
      final a = TeacherStudent.fromJson(
        _alumnoJson(
          notas: const [
            {'idNota': 1},
            {'idNota': 2},
          ],
        ),
      );
      final pr = a.units.single.grades.last;
      expect(pr.noteCount, 2);
      expect(pr.isEditable, isFalse);
    });

    test('la caché conserva unidades y notas (antes se perdían)', () {
      final a = TeacherStudent.fromJson(_alumnoJson());
      final back = TeacherStudent.fromJson(
        jsonDecode(jsonEncode(a.toCacheJson())) as Map<String, dynamic>,
      );
      expect(back.matriculaAsignaturaId, '5010');
      expect(back.grade, a.grade);
      final g1 = a.units.single.grades;
      final g2 = back.units.single.grades;
      expect(g2.map((g) => g.code), g1.map((g) => g.code));
      expect(g2.last.grade, g1.last.grade);
      expect(g2.last.notaId, 777);
      expect(g2.last.tipoUnidadId, 121);
      expect(g2.first.grade, isNull);
    });

    test('iniciales desde nombreCompleto (apellido + nombre)', () {
      final a = TeacherStudent.fromJson(_alumnoJson());
      expect(a.initials, 'QJ');
      expect(
        const TeacherStudent(code: 'x', firstName: '', lastName: '').initials,
        '?',
      );
    });

    test('asistencia y nota tolerantes a formato', () {
      final a = TeacherStudent.fromJson(
        _alumnoJson(notaFinal: '10,5', asistencia: '85.5%'),
      );
      expect(a.gradeNum, 10.5);
      expect(a.attendancePct, 85.5);
    });
  });

  group('CourseRosterStats', () {
    final alumnos = [
      TeacherStudent.fromJson(_alumnoJson(codigo: '1', notaFinal: 15)),
      TeacherStudent.fromJson(
        _alumnoJson(codigo: '2', notaFinal: 8, asistencia: 60),
      ),
      TeacherStudent.fromJson(
        _alumnoJson(codigo: '3', notaFinal: 18, asistencia: 65),
      ),
      TeacherStudent.fromJson(_alumnoJson(codigo: '4', notaFinal: null)),
    ];

    test('cuenta aprobados, desaprobados, sin nota y promedio', () {
      final s = CourseRosterStats.from(alumnos);
      expect(s.total, 4);
      expect(s.approved, 2);
      expect(s.failed, 1);
      expect(s.noGrade, 1);
      expect(s.average, closeTo((15 + 8 + 18) / 3, 1e-9));
      expect(s.buckets, [1, 0, 1, 1]);
    });

    test('riesgo: el más crítico primero', () {
      final s = CourseRosterStats.from(alumnos);
      expect(s.atRisk.map((r) => r.student.code), ['2', '3']);
      expect(s.atRisk.first.reasons, {
        RiskReason.lowGrade,
        RiskReason.lowAttendance,
      });
    });

    test('ordenar por nota deja sin nota al final', () {
      final asc = CourseRosterStats.sorted(alumnos, RosterSort.gradeAsc);
      expect(asc.map((a) => a.code), ['2', '1', '3', '4']);
      final desc = CourseRosterStats.sorted(alumnos, RosterSort.gradeDesc);
      expect(desc.map((a) => a.code), ['3', '1', '2', '4']);
    });

    test('resumen de asistencia del día', () {
      final r = attendanceDaySummary(['1', '2', '3', 'P', null, '9']);
      expect(r.presentes, 2);
      expect(r.faltas, 1);
      expect(r.justificadas, 1);
    });

    test('las horas se comparan como horas, no como texto', () {
      expect(compareHm('8:00', '10:00'), lessThan(0));
      expect(compareHm('08:00:00', '8:00'), 0);
    });
  });

  group('TeacherRepository.guardarNota', () {
    const pendiente = EvaluationGrade(
      code: 'EV',
      description: 'Evidencia de Conocimiento',
      weight: 40,
      tipoUnidadId: 121,
      tipoNotaId: 11,
    );
    const existente = EvaluationGrade(
      code: 'PR',
      description: 'Evidencia de Producto',
      weight: 30,
      grade: '13',
      tipoUnidadId: 121,
      tipoNotaId: 13,
      notaId: 777,
      noteCount: 1,
    );

    Future<http.Request> capture(
      Future<void> Function(TeacherRepository) op,
    ) async {
      late http.Request seen;
      final api = ApiClient(
        transport: MockClient((req) async {
          seen = req;
          return http.Response('{"success":true}', 200);
        }),
      );
      addTearDown(api.close);
      await op(TeacherRepository(api));
      return seen;
    }

    test('nota nueva → InsertarNotas con la forma real', () async {
      final req = await capture(
        (r) => r.guardarNota(
          matriculaAsignaturaId: '5010',
          evaluacion: pendiente,
          nota: 14.5,
        ),
      );
      expect(req.url.path, endsWith('Docente/InsertarNotas'));
      final body = jsonDecode(req.body) as Map<String, dynamic>;
      expect(body, {
        'Notas': [
          {
            'matricula_asignatura_id': 5010,
            'tipo_unidad_id': 121,
            'tipo_nota_id': 11,
            'nota': 14.5,
          },
        ],
      });
    });

    test('nota existente → UpdateNota con nota_id', () async {
      final req = await capture(
        (r) => r.guardarNota(
          matriculaAsignaturaId: '5010',
          evaluacion: existente,
          nota: 16,
        ),
      );
      expect(req.url.path, endsWith('Docente/UpdateNota'));
      final item =
          ((jsonDecode(req.body) as Map)['Notas'] as List).single as Map;
      expect(item['nota_id'], 777);
    });

    test('se niega sin enviar nada si faltan ids o hay varias notas', () async {
      var requests = 0;
      final api = ApiClient(
        transport: MockClient((_) async {
          requests++;
          return http.Response('{"success":true}', 200);
        }),
      );
      addTearDown(api.close);
      final repo = TeacherRepository(api);
      await expectLater(
        repo.guardarNota(
          matriculaAsignaturaId: null,
          evaluacion: pendiente,
          nota: 12,
        ),
        throwsA(isA<BadRequestException>()),
      );
      await expectLater(
        repo.guardarNota(
          matriculaAsignaturaId: '5010',
          evaluacion: const EvaluationGrade(
            code: 'PR',
            description: 'x',
            weight: 30,
            grade: '13',
            tipoUnidadId: 121,
            tipoNotaId: 13,
            notaId: 1,
            noteCount: 2,
          ),
          nota: 12,
        ),
        throwsA(isA<BadRequestException>()),
      );
      await expectLater(
        repo.guardarNota(
          matriculaAsignaturaId: '5010',
          evaluacion: pendiente,
          nota: 21,
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(requests, 0);
    });
  });
}
