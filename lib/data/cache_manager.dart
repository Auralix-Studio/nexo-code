import 'dart:convert';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';

class CacheManager {
  CacheManager({Database? database}) : _db = database;

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final path = join(await getDatabasesPath(), 'nexo_cache.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Student Profile
    await db.execute('''
      CREATE TABLE student_profile (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Boleta cursos (new)
    await db.execute('''
      CREATE TABLE boleta_cursos (
        anio TEXT NOT NULL,
        periodo TEXT NOT NULL,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (anio, periodo)
      )
    ''');

    // Boleta legacy
    await db.execute('''
      CREATE TABLE boleta_legacy (
        anio TEXT NOT NULL,
        periodo TEXT NOT NULL,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL,
        PRIMARY KEY (anio, periodo)
      )
    ''');

    // Horario
    await db.execute('''
      CREATE TABLE horario (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Periodos
    await db.execute('''
      CREATE TABLE periodos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Promedios
    await db.execute('''
      CREATE TABLE promedios (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Pagos
    await db.execute('''
      CREATE TABLE pagos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Docente Info
    await db.execute('''
      CREATE TABLE docente_info (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Docente Cursos
    await db.execute('''
      CREATE TABLE docente_cursos (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Docente Alumnos
    await db.execute('''
      CREATE TABLE docente_alumnos (
        curso_id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Unified student
    await db.execute('''
      CREATE TABLE unified_student (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Unified teacher
    await db.execute('''
      CREATE TABLE unified_teacher (
        id TEXT PRIMARY KEY,
        json_data TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Database get db {
    final d = _db;
    if (d == null) {
      throw StateError('CacheManager not initialized. Call init() first.');
    }
    return d;
  }

  // === BoletaCurso (New Boleta) ===
  Future<void> saveBoleta(String anio, String periodo, List<BoletaCurso> cursos) async {
    await db.insert(
      'boleta_cursos',
      {
        'anio': anio,
        'periodo': periodo,
        'json_data': jsonEncode(cursos.map((c) => c.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BoletaCurso>?> getBoleta(String anio, String periodo) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'boleta_cursos',
      where: 'anio = ? AND periodo = ?',
      whereArgs: [anio, periodo],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list
          .map((e) => BoletaCurso.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // === NotaAsignatura (Legacy Boleta) ===
  // NotaAsignatura no tiene toJson propio: se serializa al esquema posicional
  // legacy (mismas claves que su `fromJson` espera) para round-trip exacto.
  Future<void> saveBoletaLegacy(String anio, String periodo, List<NotaAsignatura> notas) async {
    final list = notas.map((n) => {
      'codigo': n.codigo,
      'asignatura': n.asignatura,
      'seccion': n.seccion,
      'ciclo': n.ciclo,
      'credito': n.credito,
      'asistencia': n.asistencia,
      'tipoAsignatura': n.tipoAsignatura,
      'mtr_Anio': n.anio,
      'mtr_Periodo': n.periodoNum,
      'pf': n.pf,
      'pfp': n.pfp,
      'complementario': n.complementario,
      'cc': n.cc,
      'puesto': n.puesto,
      'pF1': n.pF1,
      'pF2': n.pF2,
      // NotasParcial serialization
      'p1': n.primer.practicas.isNotEmpty ? n.primer.practicas[0] : '',
      'p2': n.primer.practicas.length > 1 ? n.primer.practicas[1] : '',
      'p3': n.primer.practicas.length > 2 ? n.primer.practicas[2] : '',
      'p4': n.primer.practicas.length > 3 ? n.primer.practicas[3] : '',
      'ntaP1': n.primer.promPracticas,
      'ntaTI1': n.primer.trabajoInv,
      'ntaPY1': n.primer.proyecto,
      'ntaPromTiPy': n.primer.promTiPy,
      'ntaParcial1': n.primer.examen,
      '_2P1': n.segundo.practicas.isNotEmpty ? n.segundo.practicas[0] : '',
      '_2P2': n.segundo.practicas.length > 1 ? n.segundo.practicas[1] : '',
      '_2P3': n.segundo.practicas.length > 2 ? n.segundo.practicas[2] : '',
      '_2P4': n.segundo.practicas.length > 3 ? n.segundo.practicas[3] : '',
      '_2NtaP1': n.segundo.promPracticas,
      '_2NtaTI1': n.segundo.trabajoInv,
      '_2NtaPY1': n.segundo.proyecto,
      '_2NtaPromTiPy': n.segundo.promTiPy,
      '_2NtaParcial1': n.segundo.examen,
    }).toList();

    await db.insert(
      'boleta_legacy',
      {
        'anio': anio,
        'periodo': periodo,
        'json_data': jsonEncode(list),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<NotaAsignatura>?> getBoletaLegacy(String anio, String periodo) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'boleta_legacy',
      where: 'anio = ? AND periodo = ?',
      whereArgs: [anio, periodo],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => NotaAsignatura.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === Horario ===
  Future<void> saveHorario(List<ScheduleClass> clases) async {
    await db.insert(
      'horario',
      {
        'id': 'current',
        'json_data': jsonEncode(clases.map((c) => c.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScheduleClass>?> getHorario() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'horario',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => ScheduleClass.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === Docente Horario ===
  Future<void> saveDocenteHorario(List<ScheduleClass> clases) async {
    await db.insert(
      'horario',
      {
        'id': 'docente_current',
        'json_data': jsonEncode(clases.map((c) => c.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ScheduleClass>?> getDocenteHorario() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'horario',
      where: 'id = ?',
      whereArgs: ['docente_current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => ScheduleClass.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === Periodos ===
  Future<void> savePeriodos(List<Term> periodos) async {
    await db.insert(
      'periodos',
      {
        'id': 'current',
        'json_data': jsonEncode(periodos.map((p) => p.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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

  // === Promedios ===
  Future<void> savePromedios(List<TermAverage> promedios) async {
    await db.insert(
      'promedios',
      {
        'id': 'current',
        'json_data': jsonEncode(promedios.map((p) => p.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      return list.map((e) => TermAverage.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === Pagos ===
  Future<void> savePagos(List<Payment> pagos) async {
    await db.insert(
      'pagos',
      {
        'id': 'current',
        'json_data': jsonEncode(pagos.map((p) => p.toJson()).toList()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
      return list.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === DocenteInfo ===
  Future<void> saveDocenteInfo(DocenteInfo info) async {
    final data = {
      'codigo': info.codigo,
      'nombres': info.nombres,
      'apellidos': info.apellidos,
      'facultad': info.facultad,
      'especialidad': info.especialidad,
    };
    await db.insert(
      'docente_info',
      {
        'id': info.codigo,
        'json_data': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<DocenteInfo?> getDocenteInfo() async {
    final List<Map<String, dynamic>> maps = await db.query('docente_info', limit: 1);
    if (maps.isEmpty) return null;
    try {
      return DocenteInfo.fromJson(jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // === DocenteCursos ===
  Future<void> saveDocenteCursos(List<DocenteAsignatura> cursos) async {
    final list = cursos.map((c) => {
      'cleAuto': c.id,
      'codigo': c.codigo,
      'asignatura': c.asignatura,
      'seccion': c.seccion,
      'periodo': c.periodo,
      'matriculados': c.matriculados,
    }).toList();

    await db.insert(
      'docente_cursos',
      {
        'id': 'current',
        'json_data': jsonEncode(list),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocenteAsignatura>?> getDocenteCursos() async {
    final List<Map<String, dynamic>> maps = await db.query(
      'docente_cursos',
      where: 'id = ?',
      whereArgs: ['current'],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => DocenteAsignatura.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === DocenteAlumnos ===
  Future<void> saveDocenteAlumnos(String cursoId, List<DocenteAlumno> alumnos) async {
    final list = alumnos.map((a) => {
      'codigo': a.codigo,
      'nombres': a.nombres,
      'apellidos': a.apellidos,
      'asistencia': a.asistencia,
      'nota': a.nota,
    }).toList();

    await db.insert(
      'docente_alumnos',
      {
        'curso_id': cursoId,
        'json_data': jsonEncode(list),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocenteAlumno>?> getDocenteAlumnos(String cursoId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'docente_alumnos',
      where: 'curso_id = ?',
      whereArgs: [cursoId],
    );
    if (maps.isEmpty) return null;
    try {
      final list = jsonDecode(maps.first['json_data'] as String) as List;
      return list.map((e) => DocenteAlumno.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return null;
    }
  }

  // === Unified Student ===
  Future<void> saveStudent(Student student) async {
    await db.insert(
      'unified_student',
      {
        'id': student.id.isNotEmpty ? student.id : 'current',
        'json_data': jsonEncode(student.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Student?> getStudent() async {
    final List<Map<String, dynamic>> maps = await db.query('unified_student', limit: 1);
    if (maps.isEmpty) return null;
    try {
      return Student.fromJson(jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // === Unified Teacher ===
  Future<void> saveTeacher(Teacher teacher) async {
    await db.insert(
      'unified_teacher',
      {
        'id': teacher.id.isNotEmpty ? teacher.id : 'current',
        'json_data': jsonEncode(teacher.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Teacher?> getTeacher() async {
    final List<Map<String, dynamic>> maps = await db.query('unified_teacher', limit: 1);
    if (maps.isEmpty) return null;
    try {
      return Teacher.fromJson(jsonDecode(maps.first['json_data'] as String) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  // === Utilities ===
  Future<void> clearAll() async {
    final tables = [
      'student_profile',
      'boleta_cursos',
      'boleta_legacy',
      'horario',
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
      await db.delete(table);
    }
  }

  Future<void> clearExpired(Duration maxAge) async {
    final cutoff = DateTime.now().millisecondsSinceEpoch - maxAge.inMilliseconds;
    final tables = [
      'student_profile',
      'boleta_cursos',
      'boleta_legacy',
      'horario',
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

  Future<bool> isFresh(String table, String keyColumn, String keyValue, Duration maxAge) async {
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
