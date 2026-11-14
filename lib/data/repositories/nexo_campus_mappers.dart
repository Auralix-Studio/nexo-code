import 'package:nexo/domain/models.dart';

/// Convierte las respuestas de la API de Nexo para la constancia de
/// matrícula, los anuncios y el wifi (módulo 6) a los modelos que ya usan
/// las pantallas.

/// `GET /enrollment` → [EnrollmentCertificate]. El PDF lo sigue dibujando la
/// app con estos datos.
EnrollmentCertificate enrollmentFromNexo(Map<String, dynamic> json) {
  final term = _map(json['term']);
  final student = _map(json['student']);
  final career = _map(json['career']);
  final parts = _text(term['id']).split('-');
  final courses = [
    for (final c in _maps(json['courses']))
      EnrollmentCourse(
        code: _text(c['code']),
        subject: _text(c['name']),
        cycle: _text(c['cycle']),
        section: _text(c['section']),
        creditos: _text(c['credits']),
      ),
  ];
  return EnrollmentCertificate(
    code: _text(student['code']),
    student: _text(student['name']),
    faculty: _text(json['faculty']),
    career: _text(career['name']),
    specialty: _text(json['specialty']),
    studyPlan: _text(json['study_plan']),
    level: _text(json['cycle']),
    year: parts.length == 2 ? int.tryParse(parts[0]) ?? 0 : 0,
    periodo: parts.length == 2 ? int.tryParse(parts[1]) ?? 0 : 0,
    modality: switch (json['modality']) {
      'in_person' => 'PRESENCIAL',
      'distance' => 'A DISTANCIA',
      'blended' => 'SEMIPRESENCIAL',
      'virtual' => 'VIRTUAL',
      null => '',
      final other => other.toString().toUpperCase(),
    },
    photoUrl: _text(student['photo_url']),
    careerLabel: career['label'] == null ? 'Carrera' : _text(career['label']),
    courses: courses,
    totalCredits:
        (json['total_credits'] as num?)?.toDouble() ??
        courses.fold<double>(0, (a, c) => a + c.creditosNum),
  );
}

/// `GET /wifi` → [WifiCredential]; vacía si la universidad no tiene una.
WifiCredential wifiFromNexo(Map<String, dynamic> json) => WifiCredential(
  username: _text(json['user']),
  password: _text(json['password']),
);

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const {};

Iterable<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>())
    : const [];

String _text(Object? value) => value?.toString() ?? '';
