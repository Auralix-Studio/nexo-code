import 'dart:convert';
import 'package:nexo/core/session_scope.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class CacheManager {
  CacheManager({Database? database, SessionScope? scope})
    : _db = database,
      _scope = scope ?? SessionScope();
  final SessionScope _scope;
  String? _account;
  static const _tables = [
    'student_profile',
    'boleta_cursos',
    'boleta_legacy',
    'schedule',
    'periodos',
    'promedios',
    'pagos',
    'docente_info',
    'docente_cursos',
    'docente_alumnos',
    'unified_student',
    'unified_teacher',
  ];
  Database? _db;
  Future<void> init() async {
    if (kIsWeb) return;
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'nexo_cache.db');
    _db = await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: (db, oldVersion, newVersion) async {
        final tables = [
          'student_profile',
          'boleta_cursos',
          'boleta_legacy',
          'schedule',
          'periodos',
          'promedios',
          'pagos',
          'docente_info',
          'docente_cursos',
          'docente_alumnos',
          'unified_student',
          'unified_teacher',
        ];
        for (final t in tables) {
          await db.execute('DROP TABLE IF EXISTS $t');
        }
        await db.execute('DROP TABLE IF EXISTS cache_owner');
        await _createTables(db, newVersion);
      },
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute(
      'CREATE TABLE cache_owner (id INTEGER PRIMARY KEY CHECK(id = 1), account TEXT NOT NULL)',
    );
    await db.execute('''
      CREATE TABLE student_profile (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE boleta_cursos (
        year TEXT NOT NULL,
        periodo TEXT NOT NULL,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (year, periodo)
      )
    ''');
    await db.execute('''
      CREATE TABLE boleta_legacy (
        year TEXT NOT NULL,
        periodo TEXT NOT NULL,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (year, periodo)
      )
    ''');
    await db.execute('''
      CREATE TABLE schedule (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE periodos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE promedios (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE pagos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE docente_info (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE docente_cursos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE docente_alumnos (
        curso_id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE unified_student (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE unified_teacher (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Only one account is retained on this device. Binding and eviction are
  /// atomic; legacy unowned data is never attributed to the next login.
  Future<void> activateAccount(String account) async {
    _scope.check();
    if (kIsWeb) return;
    await init();
    _scope.check();
    final database = _db!;
    await database.transaction((txn) async {
      _scope.check();
      final rows = await txn.query(
        'cache_owner',
        where: 'id = ?',
        whereArgs: [1],
      );
      _scope.check();
      if (rows.isEmpty || rows.first['account'] != account) {
        for (final table in _tables) {
          await txn.delete(table);
        }
        await txn.insert('cache_owner', {
          'id': 1,
          'account': account,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      _scope.check();
    });
    _scope.check();
    _account = account;
  }

  Database get db {
    _scope.check();
    if (_account == null) throw StateError('Cache has no authenticated owner.');
    final d = _db;
    if (d == null) {
      throw StateError('CacheManager not initialized. Call init() first.');
    }
    return d;
  }

  /// ¿Hay base con la que trabajar? Durante el arranque puede que todavía no,
  /// y borrar un caché que no existe no es un error: ya está vacío.
  bool get isReady => _db != null;

  /// Read the timestamp stored with the data, without refreshing its age.
  Future<DateTime?> updatedAtFor(String operation) async {
    if (!isReady) return null;
    final table = switch (operation) {
      'loadProfile' => 'unified_student',
      'loadPeriodos' => 'periodos',
      'loadHorarioActual' || 'loadDocenteHorario' => 'schedule',
      'loadPromedios' => 'promedios',
      'loadCuotasPendientes' => 'pagos',
      'loadTeacherInfo' => 'docente_info',
      'loadTeacherSubjects' => 'docente_cursos',
      _ when operation.startsWith('loadBoleta:') => 'boleta_cursos',
      _ when operation.startsWith('loadBoletaLegacy:') => 'boleta_legacy',
      _ => null,
    };
    if (table == null) return null;
    String? where;
    List<Object?>? args;
    if (operation.startsWith('loadBoleta')) {
      final period = operation.split(':').last.split('-');
      if (period.length != 2) return null;
      where = 'year = ? AND periodo = ?';
      args = period;
    } else if (table == 'schedule') {
      where = 'id = ?';
      args = [
        operation == 'loadDocenteHorario' ? 'docente_current' : 'current',
      ];
    }
    final rows = await db.query(
      table,
      columns: ['updated_at'],
      where: where,
      whereArgs: args,
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(rows.first['updated_at'] as int);
  }

  Future<void> saveBoleta(
    String year,
    String periodo,
    List<ReportCardCourse> courses,
  ) async {
    await db.insert('boleta_cursos', {
      'year': year,
      'periodo': periodo,
      'json_data': jsonEncode(courses.map((c) => c.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ReportCardCourse>?> getBoleta(String year, String periodo) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'boleta_cursos',
      where: 'year = ? AND periodo = ?',
      whereArgs: [year, periodo],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => ReportCardCourse.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveBoletaLegacy(
    String year,
    String periodo,
    List<CourseGrade> grades,
  ) async {
    final list = grades
        .map(
          (n) => {
            'codigo': n.code,
            'asignatura': n.subject,
            'seccion': n.section,
            'ciclo': n.cycle,
            'credito': n.credit,
            'asistencia': n.attendance,
            'tipoAsignatura': n.subjectType,
            'mtr_Anio': n.year,
            'mtr_Periodo': n.periodNum,
            'pf': n.pf,
            'pfp': n.pfp,
            'complementario': n.complementary,
            'cc': n.cc,
            'puesto': n.rank,
            'pF1': n.pF1,
            'pF2': n.pF2,
            'p1': n.firstTerm.practices.isNotEmpty
                ? n.firstTerm.practices[0]
                : '',
            'p2': n.firstTerm.practices.length > 1
                ? n.firstTerm.practices[1]
                : '',
            'p3': n.firstTerm.practices.length > 2
                ? n.firstTerm.practices[2]
                : '',
            'p4': n.firstTerm.practices.length > 3
                ? n.firstTerm.practices[3]
                : '',
            'ntaP1': n.firstTerm.practicesAverage,
            'ntaTI1': n.firstTerm.researchWork,
            'ntaPY1': n.firstTerm.project,
            'ntaPromTiPy': n.firstTerm.researchProjectAverage,
            'ntaParcial1': n.firstTerm.exam,
            '_2P1': n.secondTerm.practices.isNotEmpty
                ? n.secondTerm.practices[0]
                : '',
            '_2P2': n.secondTerm.practices.length > 1
                ? n.secondTerm.practices[1]
                : '',
            '_2P3': n.secondTerm.practices.length > 2
                ? n.secondTerm.practices[2]
                : '',
            '_2P4': n.secondTerm.practices.length > 3
                ? n.secondTerm.practices[3]
                : '',
            '_2NtaP1': n.secondTerm.practicesAverage,
            '_2NtaTI1': n.secondTerm.researchWork,
            '_2NtaPY1': n.secondTerm.project,
            '_2NtaPromTiPy': n.secondTerm.researchProjectAverage,
            '_2NtaParcial1': n.secondTerm.exam,
          },
        )
        .toList();
    await db.insert('boleta_legacy', {
      'year': year,
      'periodo': periodo,
      'json_data': jsonEncode(list),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<CourseGrade>?> getBoletaLegacy(
    String year,
    String periodo,
  ) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'boleta_legacy',
      where: 'year = ? AND periodo = ?',
      whereArgs: [year, periodo],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => CourseGrade.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveHorario(List<ScheduleClass> clases) async {
    if (!isReady) return;
    await db.insert('schedule', {
      'id': 'current',
      'json_data': jsonEncode(clases.map((c) => c.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScheduleClass>?> getHorario() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'schedule',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => ScheduleClass.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDocenteHorario(List<ScheduleClass> clases) async {
    if (!isReady) return;
    await db.insert('schedule', {
      'id': 'docente_current',
      'json_data': jsonEncode(clases.map((c) => c.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<ScheduleClass>?> getDocenteHorario() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'schedule',
      where: 'id = ?',
      whereArgs: ['docente_current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => ScheduleClass.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> savePeriodos(List<Term> periodos) async {
    if (!isReady) return;
    await db.insert('periodos', {
      'id': 'current',
      'json_data': jsonEncode(periodos.map((p) => p.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Term>?> getPeriodos() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'periodos',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => Term.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> savePromedios(List<TermAverage> promedios) async {
    if (!isReady) return;
    await db.insert('promedios', {
      'id': 'current',
      'json_data': jsonEncode(promedios.map((p) => p.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TermAverage>?> getPromedios() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'promedios',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => TermAverage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> savePagos(List<Payment> pagos) async {
    if (!isReady) return;
    await db.insert('pagos', {
      'id': 'current',
      'json_data': jsonEncode(pagos.map((p) => p.toJson()).toList()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Payment>?> getPagos() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'pagos',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => Payment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDocenteInfo(TeacherInfo info) async {
    if (!isReady) return;
    final data = {
      'codigo': info.code,
      'nombres': info.firstName,
      'apellidos': info.lastName,
      'facultad': info.faculty,
      'especialidad': info.specialty,
    };
    await db.insert('docente_info', {
      'id': info.code,
      'json_data': jsonEncode(data),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<TeacherInfo?> getDocenteInfo() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'docente_info',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    try {
      return TeacherInfo.fromJson(
        jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDocenteCursos(List<TeacherSubject> courses) async {
    if (!isReady) return;
    final list = courses
        .map(
          (c) => {
            'cleAuto': c.id,
            'codigo': c.code,
            'asignatura': c.subject,
            'seccion': c.section,
            'periodo': c.periodo,
            'matriculados': c.enrolledCount,
            'plan': c.plan,
            'nrc': c.nrc,
            'tipoCalif': c.tipoCalif,
          },
        )
        .toList();
    await db.insert('docente_cursos', {
      'id': 'current',
      'json_data': jsonEncode(list),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TeacherSubject>?> getDocenteCursos() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'docente_cursos',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => TeacherSubject.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDocenteAlumnos(
    String cursoId,
    List<TeacherStudent> alumnos,
  ) async {
    final list = alumnos
        .map(
          (a) => {
            'codigo': a.code,
            'nombres': a.firstName,
            'apellidos': a.lastName,
            'nombreCompleto': a.fullName,
            'asistencia': a.attendance,
            'nota': a.grade,
            'matricula_asignatura_id': a.matriculaAsignaturaId,
            'observacion': a.observacion,
          },
        )
        .toList();
    await db.insert('docente_alumnos', {
      'curso_id': cursoId,
      'json_data': jsonEncode(list),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<TeacherStudent>?> getDocenteAlumnos(String cursoId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'docente_alumnos',
      where: 'curso_id = ?',
      whereArgs: [cursoId],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => TeacherStudent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> saveStudent(Student student) async {
    if (!isReady) return;
    await db.insert('unified_student', {
      'id': student.id.isNotEmpty ? student.id : 'current',
      'json_data': jsonEncode(student.toJson()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Student?> getStudent() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_student',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    try {
      return Student.fromJson(
        jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTeacher(Teacher teacher) async {
    if (!isReady) return;
    await db.insert('unified_teacher', {
      'id': teacher.id.isNotEmpty ? teacher.id : 'current',
      'json_data': jsonEncode(teacher.toJson()),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Teacher?> getTeacher() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'unified_teacher',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    try {
      return Teacher.fromJson(
        jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clearAll() async {
    _account = null;
    final database = _db;
    if (database == null) return;
    await database.transaction((txn) async {
      for (final table in _tables) {
        await txn.delete(table);
      }
      await txn.delete('cache_owner');
    });
  }

  Future<void> clearExpired(Duration maxAge) async {
    if (!isReady) return;
    final cutoff =
        DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    final tables = [
      'student_profile',
      'boleta_cursos',
      'boleta_legacy',
      'schedule',
      'periodos',
      'promedios',
      'pagos',
      'docente_info',
      'docente_cursos',
      'docente_alumnos',
      'unified_student',
      'unified_teacher',
    ];
    for (final table in tables) {
      await db.delete(table, where: 'updated_at < ?', whereArgs: [cutoff]);
    }
  }

  Future<bool> isFresh(
    String table,
    String keyColumn,
    String keyValue,
    Duration maxAge,
  ) async {
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        table,
        columns: ['updated_at'],
        where: '$keyColumn = ?',
        whereArgs: [keyValue],
        limit: 1,
      );
      if (maps.isEmpty) return false;
      final updatedAt = maps.first['updated_at'] as int;
      final age = DateTime.now().millisecondsSinceEpoch - updatedAt;
      return age < maxAge.inMilliseconds;
    } catch (_) {
      return false;
    }
  }
}
