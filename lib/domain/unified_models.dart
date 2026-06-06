import 'package:nexo/domain/models.dart';

/// Modelo unificado de estudiante
class Student {
  final String id;              // SIGMA.estId || INTRANET.codigoEstudiante
  final String fullName;        // Estudiante (nombre completo)
  final String career;          // SIGMA.carrera || INTRANET.nom_carrera
  final String faculty;         // SIGMA.facultad || INTRANET.nom_facultad
  final String campus;          // SIGMA.sede || INTRANET.sede
  final String level;           // SIGMA.nivel
  final String studyPlan;       // SIGMA.pesId
  final String modality;        // SIGMA.modalidad
  final bool isEnrolled;        // SIGMA.matriculado
  final String? lastEnrollment; // SIGMA.ultimaMatricula
  final double? gpa;            // Promedio acumulado
  final int? creditsApproved;   // SIGMA.creditoAprobado
  final int? creditsTotal;

  const Student({
    required this.id,
    required this.fullName,
    required this.career,
    required this.faculty,
    required this.campus,
    required this.level,
    required this.studyPlan,
    required this.modality,
    required this.isEnrolled,
    this.lastEnrollment,
    this.gpa,
    this.creditsApproved,
    this.creditsTotal,
  });

  // Factory unificado: mapea desde SIGMA
  factory Student.fromSigmaProfile(StudentProfile p) {
    return Student(
      id: p.estId,
      fullName: p.estudiante,
      career: p.carrera,
      faculty: p.facultad,
      campus: p.sede,
      level: p.nivel,
      studyPlan: p.pesId,
      modality: p.modalidad,
      isEnrolled: p.matriculado,
      lastEnrollment: p.ultimaMatricula,
      creditsApproved: p.creditoAprobado,
    );
  }

  // Factory unificado: mapea desde JSON plano (por ejemplo, de Intranet)
  factory Student.fromIntranetProfile(Map<String, dynamic> json) {
    return Student(
      id: (json['codigoEstudiante'] ?? json['codigoEstudiantee'] ?? json['cod_estudiante'] ?? '').toString(),
      fullName: (json['estudiante'] ?? json['nombre_completo'] ?? json['nombre'] ?? '').toString(),
      career: (json['carrera'] ?? json['nom_carrera'] ?? '').toString(),
      faculty: (json['facultad'] ?? json['nom_facultad'] ?? '').toString(),
      campus: (json['sede'] ?? '').toString(),
      level: (json['nivel'] ?? '').toString(),
      studyPlan: (json['pesId'] ?? json['pes_Id'] ?? '').toString(),
      modality: (json['modalidad'] ?? '').toString(),
      isEnrolled: json['matriculado'] as bool? ?? false,
      lastEnrollment: json['ultimaMatricula']?.toString(),
      creditsApproved: json['creditoAprobado'] as int?,
    );
  }

  // Merge: prioritizes this student (e.g. SIGMA), fills in missing/nulls from other (e.g. INTRANET)
  Student mergeWith(Student other) {
    return Student(
      id: id.isNotEmpty ? id : other.id,
      fullName: fullName.isNotEmpty ? fullName : other.fullName,
      career: career.isNotEmpty ? career : other.career,
      faculty: faculty.isNotEmpty ? faculty : other.faculty,
      campus: campus.isNotEmpty ? campus : other.campus,
      level: level.isNotEmpty ? level : other.level,
      studyPlan: studyPlan.isNotEmpty ? studyPlan : other.studyPlan,
      modality: modality.isNotEmpty ? modality : other.modality,
      isEnrolled: isEnrolled || other.isEnrolled,
      lastEnrollment: lastEnrollment ?? other.lastEnrollment,
      gpa: gpa ?? other.gpa,
      creditsApproved: creditsApproved ?? other.creditsApproved,
      creditsTotal: creditsTotal ?? other.creditsTotal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'career': career,
        'faculty': faculty,
        'campus': campus,
        'level': level,
        'studyPlan': studyPlan,
        'modality': modality,
        'isEnrolled': isEnrolled,
        'lastEnrollment': lastEnrollment,
        'gpa': gpa,
        'creditsApproved': creditsApproved,
        'creditsTotal': creditsTotal,
      };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
        id: json['id'] as String? ?? '',
        fullName: json['fullName'] as String? ?? '',
        career: json['career'] as String? ?? '',
        faculty: json['faculty'] as String? ?? '',
        campus: json['campus'] as String? ?? '',
        level: json['level'] as String? ?? '',
        studyPlan: json['studyPlan'] as String? ?? '',
        modality: json['modality'] as String? ?? '',
        isEnrolled: json['isEnrolled'] as bool? ?? false,
        lastEnrollment: json['lastEnrollment'] as String?,
        gpa: (json['gpa'] as num?)?.toDouble(),
        creditsApproved: json['creditsApproved'] as int?,
        creditsTotal: json['creditsTotal'] as int?,
      );
}

/// Modelo unificado de docente
class Teacher {
  final String id;              // SIGMA.idProfesor || INTRANET.cod_docente
  final String fullName;
  final String? email;
  final String? department;
  final List<TeacherCourse> courses;

  const Teacher({
    required this.id,
    required this.fullName,
    this.email,
    this.department,
    required this.courses,
  });

  factory Teacher.fromSigmaDocente(DocenteInfo info, List<DocenteAsignatura> cursos) {
    return Teacher(
      id: info.codigo,
      fullName: info.displayName,
      department: info.facultad,
      courses: cursos.map((c) => TeacherCourse.fromDocenteAsignatura(c)).toList(),
    );
  }

  factory Teacher.fromIntranet(Map<String, dynamic> json) {
    final list = json['courses'] as List?;
    return Teacher(
      id: (json['cod_docente'] ?? json['codigo'] ?? '').toString(),
      fullName: (json['nombres_completos'] ?? json['displayName'] ?? '').toString(),
      email: json['email']?.toString(),
      department: json['department']?.toString(),
      courses: list != null
          ? list.map((e) => TeacherCourse.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }

  Teacher mergeWith(Teacher other) {
    return Teacher(
      id: id.isNotEmpty ? id : other.id,
      fullName: fullName.isNotEmpty ? fullName : other.fullName,
      email: email ?? other.email,
      department: department ?? other.department,
      courses: courses.isNotEmpty ? courses : other.courses,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'department': department,
        'courses': courses.map((c) => c.toJson()).toList(),
      };

  factory Teacher.fromJson(Map<String, dynamic> json) {
    final list = json['courses'] as List?;
    return Teacher(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String?,
      department: json['department'] as String?,
      courses: list != null
          ? list.map((e) => TeacherCourse.fromJson(e as Map<String, dynamic>)).toList()
          : const [],
    );
  }
}

class TeacherCourse {
  final String id;              // cleAuto / id del curso
  final String subjectName;     // Nombre de asignatura
  final String subjectCode;     // Código
  final String section;
  final String period;          // "2026-1"
  final int? enrolledCount;     // Matriculados
  final String? schedule;

  const TeacherCourse({
    required this.id,
    required this.subjectName,
    required this.subjectCode,
    required this.section,
    required this.period,
    this.enrolledCount,
    this.schedule,
  });

  factory TeacherCourse.fromDocenteAsignatura(DocenteAsignatura a) {
    return TeacherCourse(
      id: a.id,
      subjectName: a.asignatura,
      subjectCode: a.codigo,
      section: a.seccion,
      period: a.periodo,
      enrolledCount: a.matriculados,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'subjectCode': subjectCode,
        'section': section,
        'period': period,
        'enrolledCount': enrolledCount,
        'schedule': schedule,
      };

  factory TeacherCourse.fromJson(Map<String, dynamic> json) => TeacherCourse(
        id: json['id'] as String? ?? '',
        subjectName: json['subjectName'] as String? ?? '',
        subjectCode: json['subjectCode'] as String? ?? '',
        section: json['section'] as String? ?? '',
        period: json['period'] as String? ?? '',
        enrolledCount: json['enrolledCount'] as int?,
        schedule: json['schedule'] as String?,
      );
}
