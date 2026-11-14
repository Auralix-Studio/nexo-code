import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/data/repositories/nexo_campus_mappers.dart';

void main() {
  test('the enrollment certificate keeps what the PDF draws', () {
    final c = enrollmentFromNexo({
      'term': {'id': '2026-2', 'label': '2026-II'},
      'student': {
        'code': 'E001',
        'name': 'Rojas Quispe Jose',
        'photo_url': 'https://x/y.jpg',
      },
      'faculty': 'Ingeniería',
      'career': {
        'label': 'Carrera',
        'name': 'Ingeniería de Sistemas y Computación',
      },
      'specialty': null,
      'study_plan': '2015',
      'cycle': 7,
      'modality': 'in_person',
      'courses': [
        {
          'code': 'IS-301',
          'name': 'Base de Datos',
          'cycle': 7,
          'section': 'A1',
          'credits': 3,
        },
      ],
      'total_credits': 22,
      'issued_at': '2026-11-13',
    });

    expect(c.code, 'E001');
    expect(c.student, 'Rojas Quispe Jose');
    expect(c.specialty, '');
    expect(c.level, '7');
    expect((c.year, c.periodo), (2026, 2));
    expect(c.modality, 'PRESENCIAL');
    expect(c.careerLabel, 'Carrera');
    expect(c.courses.single.creditosNum, 3);
    expect(c.totalCredits, 22);
  });

  test('the wifi credential', () {
    final w = wifiFromNexo({'user': 'u-e001', 'password': 's'});
    expect((w.username, w.password), ('u-e001', 's'));
    expect(wifiFromNexo({'user': null, 'password': null}).username, '');
  });
}
