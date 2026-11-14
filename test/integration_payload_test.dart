import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/services/integration_service.dart';
import 'package:nexo/domain/unified_models.dart';

ScheduleClass _class({
  String subject = 'Base de Datos',
  int weekday = 1,
  String start = '08:00:00',
  String end = '09:45:00',
}) => ScheduleClass(
  id: '1',
  nrc: '341119',
  subject: subject,
  modality: 'PRESENCIAL',
  section: 'A1',
  level: 'PREGRADO',
  campus: 'Huancayo',
  building: 'PABELLON H',
  room: 'H 302',
  note: '',
  teacher: 'Docente',
  weekday: weekday,
  dayName: 'Lunes',
  startTime: start,
  endTime: end,
  typeCode: 'T',
);

void main() {
  const student = Student(
    id: 'U01025B',
    fullName: 'Ana Rojas',
    career: 'Ingeniería de Sistemas',
    faculty: 'Ingeniería',
    campus: 'Huancayo',
    level: 'PREGRADO',
    studyPlan: '2015',
    modality: 'PRESENCIAL',
    isEnrolled: true,
    gpa: 15.4,
    creditsApproved: 120,
  );

  test('only identification and the weekly schedule are shared', () {
    final payload = sharedPayload(
      profile: student,
      schedule: [_class()],
      term: '2026-2',
    );

    expect(payload['profile'], {
      'code': 'U01025B',
      'name': 'Ana Rojas',
      'career': 'Ingeniería de Sistemas',
      'faculty': 'Ingeniería',
    });
    final text = payload.toString();
    expect(text, isNot(contains('15.4')));
    expect(text, isNot(contains('120')));

    final classes = (payload['schedule'] as Map)['classes'] as List;
    expect(classes.single, containsPair('start', '08:00'));
    expect(classes.single, containsPair('end', '09:45'));
    expect(classes.single, containsPair('weekday', 1));
  });

  test('drops duplicates and classes the backend would reject', () {
    final payload = sharedPayload(
      profile: null,
      schedule: [
        _class(),
        _class(),
        _class(subject: ' '),
        _class(weekday: 9),
        _class(start: '10:00', end: '09:00'),
        _class(start: 'mañana'),
      ],
    );

    expect(((payload['schedule'] as Map)['classes'] as List), hasLength(1));
    expect(payload['profile'], isEmpty);
  });
}
