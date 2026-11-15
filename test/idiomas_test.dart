import 'package:flutter_test/flutter_test.dart';
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

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
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
