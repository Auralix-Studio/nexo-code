import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/domain/idiomas_models.dart';
import 'package:nexo/domain/unified_models.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

ScheduleClass _session(
  String subject, {
  required int weekday,
  required String start,
  required String end,
  String type = 'T',
}) => ScheduleClass(
  id: '$subject-$weekday-$start',
  subject: subject,
  weekday: weekday,
  dayName: '',
  startTime: start,
  endTime: end,
  typeCode: type,
  section: 'A1',
  room: 'I 302',
  building: '',
  campus: '',
  teacher: '',
  nrc: '',
  level: '',
  modality: '',
  note: '',
);

IdiomasCourse _makeIdiomasCourse({
  String asigId = 'ING101',
  String asignatura = 'INGLÉS BÁSICO I',
  String dias = 'LU-MI-VI',
  String horaInicio = '08:00',
  String horaFin = '09:30',
  String modalidad = 'VIRTUAL',
  String seccion = 'A',
  int anio = 2026,
  int mes = 9,
  int detMatriculaId = 100,
}) => IdiomasCourse(
  estNombres: 'JUAN',
  estPaterno: 'PEREZ',
  estMaterno: 'GARCIA',
  asigId: asigId,
  asignatura: asignatura,
  dias: dias,
  horaInicio: horaInicio,
  horaFin: horaFin,
  aula: '101',
  aulaNombre: 'Aula Virtual 1',
  detMatriculaId: detMatriculaId,
  modalidad: modalidad,
  idiomaNombre: 'INGLÉS',
  seccion: seccion,
  anio: anio,
  mes: mes,
  tipoEstudio: 'REGULAR',
  turno: 'MAÑANA',
  capacidad: 30,
  cantidad: 25,
  fechRegistro: '2026-09-01',
  promedio: 0,
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // B10 — Test 1: IdiomasCourse.toScheduleClasses()
  // -------------------------------------------------------------------------
  group('IdiomasCourse.toScheduleClasses()', () {
    test('genera una ScheduleClass por cada día', () {
      final course = _makeIdiomasCourse(dias: 'LU-MI-VI');
      final classes = course.toScheduleClasses();

      expect(classes, hasLength(3));
      expect(classes.map((c) => c.weekday).toList(), [1, 3, 5]);
    });

    test('cada clase tiene typeCode "I" (Idiomas)', () {
      final course = _makeIdiomasCourse(dias: 'MA-JU');
      final classes = course.toScheduleClasses();

      for (final c in classes) {
        expect(c.typeCode, 'I');
      }
    });

    test('asigna horario correcto', () {
      final course = _makeIdiomasCourse(
        dias: 'LU',
        horaInicio: '14:00',
        horaFin: '15:30',
      );
      final classes = course.toScheduleClasses();

      expect(classes.single.startTime, '14:00');
      expect(classes.single.endTime, '15:30');
    });

    test('mapea nombre de asignatura y sección', () {
      final course = _makeIdiomasCourse(
        asignatura: 'FRANCÉS INTERMEDIO',
        seccion: 'B2',
      );
      final classes = course.toScheduleClasses();

      expect(classes.first.subject, 'FRANCÉS INTERMEDIO');
      expect(classes.first.section, 'B2');
    });

    test('campus VIRTUAL para modalidad virtual', () {
      final course = _makeIdiomasCourse(modalidad: 'VIRTUAL');
      final classes = course.toScheduleClasses();

      expect(classes.first.campus, 'VIRTUAL');
      expect(classes.first.building, '');
    });

    test('campus PRESENCIAL para modalidad presencial', () {
      final course = _makeIdiomasCourse(modalidad: 'Presencial');
      final classes = course.toScheduleClasses();

      expect(classes.first.campus, 'PRESENCIAL');
      expect(classes.first.building, 'Centro de Idiomas');
    });

    test('días no reconocidos se ignoran', () {
      final course = _makeIdiomasCourse(dias: 'LU-XX-VI');
      final classes = course.toScheduleClasses();

      // Solo LU (1) y VI (5), XX se ignora.
      expect(classes, hasLength(2));
      expect(classes.map((c) => c.weekday).toList(), [1, 5]);
    });

    test('cadena de días vacía genera lista vacía', () {
      final course = _makeIdiomasCourse(dias: '');
      final classes = course.toScheduleClasses();

      expect(classes, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // B10 — Test 2: ScheduleClassGroup.isSequentialWorkshop con dos TALLERes
  // -------------------------------------------------------------------------
  group('ScheduleClassGroup fusión de talleres secuenciales', () {
    test('fusiona dos TALLER distintos del mismo día/hora', () {
      final groups = ScheduleClassGroup.groupBy([
        _session(
          'TALLER DE COMUNICACIÓN I',
          weekday: 2,
          start: '10:00',
          end: '11:30',
        ),
        _session(
          'TALLER DE COMUNICACIÓN II',
          weekday: 2,
          start: '10:00',
          end: '11:30',
        ),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.isSequentialWorkshop, isTrue);
    });

    test('no fusiona talleres en días distintos', () {
      final groups = ScheduleClassGroup.groupBy([
        _session(
          'TALLER DE COMUNICACIÓN I',
          weekday: 1,
          start: '10:00',
          end: '11:30',
        ),
        _session(
          'TALLER DE COMUNICACIÓN II',
          weekday: 3,
          start: '10:00',
          end: '11:30',
        ),
      ]);

      expect(groups, hasLength(2));
      expect(groups.any((g) => g.isSequentialWorkshop), isFalse);
    });

    test('no fusiona talleres con horarios distintos', () {
      final groups = ScheduleClassGroup.groupBy([
        _session(
          'TALLER DE REDACCIÓN I',
          weekday: 4,
          start: '08:00',
          end: '09:30',
        ),
        _session(
          'TALLER DE REDACCIÓN II',
          weekday: 4,
          start: '10:00',
          end: '11:30',
        ),
      ]);

      expect(groups, hasLength(2));
      expect(groups.any((g) => g.isSequentialWorkshop), isFalse);
    });

    test('activeWorkshopName muestra el taller activo cuando uno terminó', () {
      final groups = ScheduleClassGroup.groupBy(
        [
          _session(
            'TALLER DE COMUNICACION I',
            weekday: 2,
            start: '10:00',
            end: '11:30',
          ),
          _session(
            'TALLER DE COMUNICACION II',
            weekday: 2,
            start: '10:00',
            end: '11:30',
          ),
        ],
        finishedSubjects: {'TALLER DE COMUNICACION I'},
      );

      expect(groups.single.isSequentialWorkshop, isTrue);
      expect(groups.single.activeWorkshopName, 'TALLER DE COMUNICACION II');
    });

    test('no confunde un taller único con secuencial', () {
      final groups = ScheduleClassGroup.groupBy([
        _session('TALLER ÚNICO', weekday: 5, start: '14:00', end: '15:30'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.isSequentialWorkshop, isFalse);
    });
  });
}
