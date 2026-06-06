// Modelos de dominio basados en respuestas reales del API de SIGMA.
// Tolerantes a campos que vienen como string o number (algunos endpoints mezclan).

int? _toInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _toDouble(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String _toStr(Object? v) => v?.toString() ?? '';

/// Parsea booleanos tolerando todas las formas que devuelve SIGMA: `bool`
/// nativo, `0/1` (int), `"true"/"false"`, `"0"/"1"`, `"S"/"N"`. Sin esto,
/// `j['activo'] as bool?` lanzaba `TypeError` y rompía TODA la lista de
/// periodos cuando SIGMA cambiaba de bool nativo a 0/1 — el síntoma era
/// "no aparecen notas" porque sin periodos no se carga la boleta.
bool _toBool(Object? v, {bool fallback = false}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) {
    final t = v.trim().toLowerCase();
    if (t.isEmpty) return fallback;
    if (t == 'true' || t == '1' || t == 's' || t == 'si' || t == 'sí' ||
        t == 'y' || t == 'yes') {
      return true;
    }
    if (t == 'false' || t == '0' || t == 'n' || t == 'no') {
      return false;
    }
  }
  return fallback;
}

/// Parsea una nota que puede venir como "14", "14.00", "14,5" o vacía.
double? notaToDouble(String? raw) {
  if (raw == null) return null;
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty || t == '-' || t == '--') return null;
  return double.tryParse(t);
}

/// Desde 2026-1 la metodología es por unidades/evidencias (modelo nuevo).
/// Igual que `esModeloNuevo` del portal Intranet.
bool esModeloNuevo(int anio, int periodo) =>
    anio > 2026 || (anio == 2026 && periodo >= 1);

/// Formatea una nota: entero sin decimales ("15"), con decimales si los
/// tiene ("14.50"); devuelve "—" si no es numérica.
String notaFmt(String? raw) {
  final n = notaToDouble(raw);
  if (n == null) return '—';
  if (n == n.roundToDouble()) return n.toStringAsFixed(0);
  return n.toStringAsFixed(2);
}

class LoginResult {
  final String token;
  final UserInfo? info;
  const LoginResult({required this.token, this.info});

  factory LoginResult.fromJson(Map<String, dynamic> json) => LoginResult(
        token: json['token'] as String,
        info: json['info'] is Map<String, dynamic>
            ? UserInfo.fromJson(json['info'] as Map<String, dynamic>)
            : null,
      );
}

class UserInfo {
  final String? codigo;
  final String? nombres;
  final String? apellidos;
  final String? imagen;
  final bool isDocente;

  const UserInfo({
    this.codigo,
    this.nombres,
    this.apellidos,
    this.imagen,
    this.isDocente = false,
  });

  String get displayName {
    final n = (nombres ?? '').trim();
    final a = (apellidos ?? '').trim();
    return [n, a].where((s) => s.isNotEmpty).join(' ');
  }

  factory UserInfo.fromJson(Map<String, dynamic> j) => UserInfo(
        codigo: j['codigo'] as String?,
        nombres: j['nombres'] as String?,
        apellidos: j['apellidos'] as String?,
        imagen: j['imagen'] as String?,
        isDocente: _toBool(j['isDocente']),
      );

  Map<String, dynamic> toJson() => {
        'codigo': codigo,
        'nombres': nombres,
        'apellidos': apellidos,
        'imagen': imagen,
        'isDocente': isDocente,
      };
}

class StudentProfile {
  final String estId;
  final String estudiante;
  final String sede;
  final String facultad;
  final String carrera;
  final String carId;
  final String modalidad;
  final String pesId;
  final String nivel;
  final String ultimaMatricula;
  final bool matriculado;
  final int creditoAprobado;

  const StudentProfile({
    required this.estId,
    required this.estudiante,
    required this.sede,
    required this.facultad,
    required this.carrera,
    required this.carId,
    required this.modalidad,
    required this.pesId,
    required this.nivel,
    required this.ultimaMatricula,
    required this.matriculado,
    required this.creditoAprobado,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> j) => StudentProfile(
        estId: _toStr(j['est_Id']),
        estudiante: _toStr(j['estudiante']),
        sede: _toStr(j['sede']),
        facultad: _toStr(j['facultad']),
        carrera: _toStr(j['carrera']),
        carId: _toStr(j['car_Id']),
        modalidad: _toStr(j['modalidad']),
        pesId: _toStr(j['pes_Id']),
        nivel: _toStr(j['nivel']),
        ultimaMatricula: _toStr(j['ultimaMatricula']),
        matriculado: _toBool(j['matriculado']),
        creditoAprobado: _toInt(j['creditoAprobado']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'est_Id': estId,
        'estudiante': estudiante,
        'sede': sede,
        'facultad': facultad,
        'carrera': carrera,
        'car_Id': carId,
        'modalidad': modalidad,
        'pes_Id': pesId,
        'nivel': nivel,
        'ultimaMatricula': ultimaMatricula,
        'matriculado': matriculado,
        'creditoAprobado': creditoAprobado,
      };
}

class Periodo {
  final String periodoId;
  final String descripcion;
  final int anio;
  final int periodo;
  final bool activo;

  const Periodo({
    required this.periodoId,
    required this.descripcion,
    required this.anio,
    required this.periodo,
    required this.activo,
  });

  factory Periodo.fromJson(Map<String, dynamic> j) => Periodo(
        periodoId: _toStr(j['periodoId']),
        descripcion: _toStr(j['descripcion']),
        anio: _toInt(j['anio']) ?? 0,
        periodo: _toInt(j['periodo']) ?? 0,
        activo: _toBool(j['activo']),
      );

  Map<String, dynamic> toJson() => {
        'periodoId': periodoId,
        'descripcion': descripcion,
        'anio': anio,
        'periodo': periodo,
        'activo': activo,
      };
}

class ClaseHorario {
  final String id;
  final String nrc;
  final String asignatura;
  final String modalidad;
  final String seccion;
  final String nivel;
  final String sede;
  final String local;
  final String aula;
  final String observacion;
  final String docente;
  final int idDia; // 1=Lun ... 7=Dom (DateTime.weekday)
  final String dia;
  final String horaInicio; // HH:mm
  final String horaFin;
  final String idTipo; // T=Teoría, P=Práctica, L=Lab

  const ClaseHorario({
    required this.id,
    required this.nrc,
    required this.asignatura,
    required this.modalidad,
    required this.seccion,
    required this.nivel,
    required this.sede,
    required this.local,
    required this.aula,
    required this.observacion,
    required this.docente,
    required this.idDia,
    required this.dia,
    required this.horaInicio,
    required this.horaFin,
    required this.idTipo,
  });

  factory ClaseHorario.fromJson(Map<String, dynamic> j) => ClaseHorario(
        id: _toStr(j['id']),
        nrc: _toStr(j['nrc']),
        asignatura: _toStr(j['asignatura']),
        modalidad: _toStr(j['modalidad']),
        seccion: _toStr(j['seccion']),
        nivel: _toStr(j['nivel']),
        sede: _toStr(j['sede']),
        local: _toStr(j['local']),
        aula: _toStr(j['aula']),
        observacion: _toStr(j['observacion']),
        docente: _toStr(j['docente']),
        idDia: _toInt(j['idDia']) ?? 0,
        dia: _toStr(j['dia']),
        horaInicio: _toStr(j['horaInicio']),
        horaFin: _toStr(j['horaFin']),
        idTipo: _toStr(j['idTipo']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nrc': nrc,
        'asignatura': asignatura,
        'modalidad': modalidad,
        'seccion': seccion,
        'nivel': nivel,
        'sede': sede,
        'local': local,
        'aula': aula,
        'observacion': observacion,
        'docente': docente,
        'idDia': idDia,
        'dia': dia,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
        'idTipo': idTipo,
      };

  String get tipoLargo => switch (idTipo.toUpperCase()) {
        'T' => 'Teoría',
        'P' => 'Práctica',
        'L' => 'Laboratorio',
        _ => idTipo,
      };

  /// Duración en minutos.
  int get duracionMin {
    final ini = _parseHM(horaInicio);
    final fin = _parseHM(horaFin);
    if (ini == null || fin == null) return 0;
    return fin - ini;
  }
}

int? _parseHM(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  return h * 60 + m;
}

/// Agrupa todas las sesiones (teoría/práctica/lab) de **una misma asignatura**
/// en un día, para mostrarlas como una sola tarjeta.
class ClaseAgrupada {
  final String asignatura;
  final int idDia;
  /// Sesiones ordenadas por hora de inicio.
  final List<ClaseHorario> sesiones;

  const ClaseAgrupada({
    required this.asignatura,
    required this.idDia,
    required this.sesiones,
  });

  String get horaInicio => sesiones.first.horaInicio;
  String get horaFin => sesiones.last.horaFin;
  String get aula => sesiones.first.aula;
  String get docente => sesiones
      .map((s) => s.docente)
      .firstWhere((d) => d.isNotEmpty, orElse: () => '');

  bool get tienePractica =>
      sesiones.any((s) => s.idTipo.toUpperCase() != 'T');
  bool get tieneTeoria =>
      sesiones.any((s) => s.idTipo.toUpperCase() == 'T');

  /// Agrupa una lista de clases por asignatura dentro del mismo día.
  static List<ClaseAgrupada> agrupar(List<ClaseHorario> clases) {
    final map = <String, List<ClaseHorario>>{};
    for (final c in clases) {
      map.putIfAbsent('${c.idDia}|${c.asignatura}', () => []).add(c);
    }
    final result = map.entries.map((e) {
      final list = [...e.value]
        ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      return ClaseAgrupada(
        asignatura: list.first.asignatura,
        idDia: list.first.idDia,
        sesiones: list,
      );
    }).toList()
      ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    return result;
  }
}

class Cuota {
  final String descripcion;
  final String fechaVencimiento; // dd-MM-yyyy
  final String tipoMoneda;
  final double importe;
  final double mora;
  final double subtotal;
  final String observacion;

  const Cuota({
    required this.descripcion,
    required this.fechaVencimiento,
    required this.tipoMoneda,
    required this.importe,
    required this.mora,
    required this.subtotal,
    required this.observacion,
  });

  factory Cuota.fromJson(Map<String, dynamic> j) => Cuota(
        descripcion: _toStr(j['descripcion']),
        fechaVencimiento: _toStr(j['fechaVencimiento']),
        tipoMoneda: _toStr(j['tipoMoneda']),
        importe: _toDouble(j['importe']) ?? 0,
        mora: _toDouble(j['mora']) ?? 0,
        subtotal: _toDouble(j['subtotal']) ?? 0,
        observacion: _toStr(j['observacion']),
      );

  Map<String, dynamic> toJson() => {
        'descripcion': descripcion,
        'fechaVencimiento': fechaVencimiento,
        'tipoMoneda': tipoMoneda,
        'importe': importe,
        'mora': mora,
        'subtotal': subtotal,
        'observacion': observacion,
      };

  /// Parsea `dd-MM-yyyy` → DateTime; null si no es válido.
  DateTime? get vencimientoDate {
    final parts = fechaVencimiento.split('-');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  int? daysUntilDue([DateTime? now]) {
    final due = vencimientoDate;
    if (due == null) return null;
    final t = now ?? DateTime.now();
    final hoy = DateTime(t.year, t.month, t.day);
    return due.difference(hoy).inDays;
  }

  bool isVencidaAt(DateTime now) =>
      (daysUntilDue(now) ?? 0) < 0;
}

class Tasa {
  final String descripcion;
  final String tipoMoneda;
  final double importe;
  final String observacion;

  const Tasa({
    required this.descripcion,
    required this.tipoMoneda,
    required this.importe,
    required this.observacion,
  });

  factory Tasa.fromJson(Map<String, dynamic> j) => Tasa(
        descripcion: _toStr(j['descripcion']),
        tipoMoneda: _toStr(j['tipoMoneda']),
        importe: _toDouble(j['importe']) ?? 0,
        observacion: _toStr(j['observacion']),
      );
}

class PagoHistorico {
  final String serieOper;
  final String numOper;
  final String desOper;
  final String item;
  final String fecha; // yyyy-MM-dd
  final String hora;
  final String periodo;
  final String concepto;
  final String tipoMoneda;
  final double importe;
  final String observacion;
  final String comprobante;
  final String lugar;

  const PagoHistorico({
    required this.serieOper,
    required this.numOper,
    required this.desOper,
    required this.item,
    required this.fecha,
    required this.hora,
    required this.periodo,
    required this.concepto,
    required this.tipoMoneda,
    required this.importe,
    required this.observacion,
    required this.comprobante,
    required this.lugar,
  });

  factory PagoHistorico.fromJson(Map<String, dynamic> j) => PagoHistorico(
        serieOper: _toStr(j['serieOper']),
        numOper: _toStr(j['numOper']),
        desOper: _toStr(j['desOper']),
        item: _toStr(j['item']),
        fecha: _toStr(j['fecha']),
        hora: _toStr(j['hora']),
        periodo: _toStr(j['periodo']),
        concepto: _toStr(j['concepto']),
        tipoMoneda: _toStr(j['tipoMoneda']),
        importe: _toDouble(j['importe']) ?? 0,
        observacion: _toStr(j['observacion']),
        comprobante: _toStr(j['comprobante']),
        lugar: _toStr(j['lugar']),
      );

  DateTime? get fechaDate {
    final p = fecha.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  bool get esDescuento => importe < 0;
  bool get esPago => importe > 0 && desOper.toUpperCase().contains('PAGO');
}

class NotasResumen {
  final double promedio;
  final int creditosAprobados;
  final int creditosTotales;
  final int cantMatricula;

  const NotasResumen({
    required this.promedio,
    required this.creditosAprobados,
    required this.creditosTotales,
    required this.cantMatricula,
  });

  factory NotasResumen.fromJson(Map<String, dynamic> j) => NotasResumen(
        promedio: _toDouble(j['promedio']) ?? 0,
        creditosAprobados: _toInt(j['creditosAprobados']) ?? 0,
        creditosTotales: _toInt(j['creditosTotales']) ?? 0,
        cantMatricula: _toInt(j['cantMatricula']) ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'promedio': promedio,
        'creditosAprobados': creditosAprobados,
        'creditosTotales': creditosTotales,
        'cantMatricula': cantMatricula,
      };
}

class PromedioPeriodo {
  final int anio;
  final int periodo;
  final double promedio;

  const PromedioPeriodo({
    required this.anio,
    required this.periodo,
    required this.promedio,
  });

  factory PromedioPeriodo.fromJson(Map<String, dynamic> j) => PromedioPeriodo(
        anio: _toInt(j['anio']) ?? 0,
        periodo: _toInt(j['periodo']) ?? 0,
        promedio: _toDouble(j['promedio']) ?? 0,
      );

  Map<String, dynamic> toJson() =>
      {'anio': anio, 'periodo': periodo, 'promedio': promedio};

  String get label => '$anio-${periodo == 1 ? 'I' : 'II'}';
}

/// Una nota por asignatura en un periodo.
///
/// SIGMA divide el semestre en dos evaluaciones parciales. Cada una tiene:
///   - Prácticas: p1..p4
///   - Trabajos de investigación (TI), Proyectos (PY)
///   - Examen parcial
class NotaAsignatura {
  final String codigo;
  final String asignatura;
  final String seccion;
  final String ciclo;
  final double credito;
  final String? asistencia;
  final String tipoAsignatura;
  final int anio;
  final int periodoNum;

  /// Promedio final consolidado (puede venir vacío si el periodo está en curso).
  final String pf;
  /// Promedio final preliminar (sin examen complementario).
  final String pfp;
  /// Examen complementario / sustitutorio.
  final String complementario;
  /// "True"/"False" indica si la calificación fue cerrada.
  final String cc;
  /// Posición del estudiante en la sección, ej. "9/53".
  final String puesto;

  /// Promedio parcial 1 (primera mitad del semestre).
  final String pF1;
  /// Promedio parcial 2 (segunda mitad).
  final String pF2;

  /// Notas del primer parcial.
  final NotasParcial primer;
  /// Notas del segundo parcial.
  final NotasParcial segundo;

  const NotaAsignatura({
    required this.codigo,
    required this.asignatura,
    required this.seccion,
    required this.ciclo,
    required this.credito,
    required this.asistencia,
    required this.tipoAsignatura,
    required this.anio,
    required this.periodoNum,
    required this.pf,
    required this.pfp,
    required this.complementario,
    required this.cc,
    required this.puesto,
    required this.pF1,
    required this.pF2,
    required this.primer,
    required this.segundo,
  });

  factory NotaAsignatura.fromJson(Map<String, dynamic> j) => NotaAsignatura(
        codigo: _toStr(j['codigo']),
        asignatura: _toStr(j['asignatura']),
        seccion: _toStr(j['seccion']),
        ciclo: _toStr(j['ciclo']),
        credito: _toDouble(j['credito']) ?? 0,
        asistencia: j['asistencia'] == null ? null : _toStr(j['asistencia']),
        tipoAsignatura: _toStr(j['tipoAsignatura']),
        anio: _toInt(j['mtr_Anio']) ?? 0,
        periodoNum: _toInt(j['mtr_Periodo']) ?? 0,
        pf: _toStr(j['pf']).trim(),
        pfp: _toStr(j['pfp']).trim(),
        complementario: _toStr(j['complementario']).trim(),
        cc: _toStr(j['cc']),
        puesto: _toStr(j['puesto']).trim(),
        pF1: _toStr(j['pF1']).trim(),
        pF2: _toStr(j['pF2']).trim(),
        primer: NotasParcial.fromJson(j, prefix: ''),
        segundo: NotasParcial.fromJson(j, prefix: '_2'),
      );

  /// Orden posicional de la fila legacy de Intranet
  /// (`consultarconstanciaNotasDetallado`, periodos ≤2025). 1:1 con SIGMA.
  static const _legacyKeys = [
    'nombreFacultad', 'nombreCarrera', 'planEstudios', 'codigo',
    'asignatura', 'plan', 'ciclo', 'seccion', 'credito', 'asistencia',
    'pF1', 'pF2', 'pf', 'complementario', 'pfp', 'cc', 'cicloTotal',
    'seccionTotal', 'creditosTotal', 'mtr_Anio', 'mtr_Periodo',
    'tipoAsignatura', 'tar_Id', 'puesto',
    'p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8',
    'ntaP1', 'ntaTI1', 'ntaPY1', 'ntaPromTiPy', 'ntaParcial1',
    '_2P1', '_2P2', '_2P3', '_2P4', '_2P5', '_2P6', '_2P7', '_2P8',
    '_2NtaP1', '_2NtaTI1', '_2NtaPY1', '_2NtaPromTiPy', '_2NtaParcial1',
  ];

  factory NotaAsignatura.fromLegacyRow(List<dynamic> row) {
    final m = <String, dynamic>{};
    for (var i = 0; i < _legacyKeys.length && i < row.length; i++) {
      m[_legacyKeys[i]] = row[i];
    }
    return NotaAsignatura.fromJson(m);
  }

  /// Nota numérica más informativa disponible (con decimales).
  double? get notaActualNum {
    for (final c in [pf, pfp]) {
      final n = notaToDouble(c);
      if (n != null) return n;
    }
    return null;
  }

  /// Texto de la nota lista para mostrar ("15", "14.50" o "—").
  String get notaActualText {
    for (final c in [pf, pfp]) {
      if (notaToDouble(c) != null) return notaFmt(c);
    }
    return '—';
  }

  bool get aprobado {
    final n = notaActualNum;
    return n != null && n >= 10.5;
  }

  int? get asistenciaPct {
    final a = asistencia;
    if (a == null) return null;
    return int.tryParse(a.trim());
  }

  bool get cerrada => cc.toLowerCase() == 'true';
}

/// Sub-notas de un parcial. SIGMA devuelve los campos como strings, con espacios
/// en blanco cuando no hay nota.
class NotasParcial {
  /// Prácticas del parcial (p1..p4).
  final List<String> practicas;
  /// Promedio de prácticas (NtaP1).
  final String promPracticas;
  /// Nota de trabajo de investigación (NtaTI1).
  final String trabajoInv;
  /// Nota de proyecto (NtaPY1).
  final String proyecto;
  /// Promedio TI + PY (NtaPromTiPy).
  final String promTiPy;
  /// Examen parcial (NtaParcial1).
  final String examen;

  const NotasParcial({
    required this.practicas,
    required this.promPracticas,
    required this.trabajoInv,
    required this.proyecto,
    required this.promTiPy,
    required this.examen,
  });

  factory NotasParcial.fromJson(Map<String, dynamic> j,
      {required String prefix}) {
    String f(String key) => _toStr(j[key]).trim();
    // Los nombres de campo cambian según el parcial:
    //   Primer parcial:  p1..p4 + ntaP1 / ntaTI1 / ntaPY1 / ntaPromTiPy / ntaParcial1
    //   Segundo parcial: _2P1..P4 + _2NtaP1 / _2NtaTI1 / _2NtaPY1 / _2NtaPromTiPy / _2NtaParcial1
    final pPrefix = prefix.isEmpty ? 'p' : '${prefix}P';
    final ntaPrefix = prefix.isEmpty ? 'nta' : '${prefix}Nta';
    return NotasParcial(
      practicas: [for (var i = 1; i <= 4; i++) f('$pPrefix$i')],
      promPracticas: f('${ntaPrefix}P1'),
      trabajoInv: f('${ntaPrefix}TI1'),
      proyecto: f('${ntaPrefix}PY1'),
      promTiPy: f('${ntaPrefix}PromTiPy'),
      examen: f('${ntaPrefix}Parcial1'),
    );
  }

  bool get vacio =>
      practicas.every((p) => p.isEmpty) &&
      promPracticas.isEmpty &&
      trabajoInv.isEmpty &&
      proyecto.isEmpty &&
      examen.isEmpty;
}

/// Curso del record académico completo (fuente: Intranet, no SIGMA).
/// Intranet devuelve arrays posicionales; mapeamos por índice.
class RecordCurso {
  final String facultad;
  final String carrera;
  final String plan;
  final String estado; // p.ej. "concluido"
  final String tipo; // TN, TA, ...
  final String codigo;
  final String nombre;
  final String ciclo;
  final String notaRaw;

  const RecordCurso({
    required this.facultad,
    required this.carrera,
    required this.plan,
    required this.estado,
    required this.tipo,
    required this.codigo,
    required this.nombre,
    required this.ciclo,
    required this.notaRaw,
  });

  factory RecordCurso.fromRow(List<dynamic> r) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    return RecordCurso(
      facultad: at(0),
      carrera: at(1),
      plan: at(2),
      estado: at(3),
      tipo: at(4),
      codigo: at(6),
      nombre: at(7),
      ciclo: at(8),
      notaRaw: at(12),
    );
  }

  double? get nota => notaToDouble(notaRaw);
  String get notaText => notaFmt(notaRaw);
  bool get aprobado => (nota ?? 0) >= 10.5;
  bool get concluido => estado.toLowerCase().contains('conclu');
}

/// Curso de la boleta de notas (modelo nuevo, Intranet
/// `consultarconstanciaNotasDetallado`, 2026-1+).
class BoletaCurso {
  final String matriculaAsignaturaId; // GUID para el detalle
  final String plan;
  final String codigo;
  final String nombre;
  final String seccion;
  final String asistenciaRaw;
  final String promedioRaw;
  final String estado; // "Dsp." en desarrollo, "-", etc.

  const BoletaCurso({
    required this.matriculaAsignaturaId,
    required this.plan,
    required this.codigo,
    required this.nombre,
    required this.seccion,
    required this.asistenciaRaw,
    required this.promedioRaw,
    required this.estado,
  });

  factory BoletaCurso.fromRow(List<dynamic> r) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    return BoletaCurso(
      matriculaAsignaturaId: at(0),
      plan: at(1),
      codigo: at(4),
      nombre: at(5),
      seccion: at(6),
      asistenciaRaw: at(7),
      promedioRaw: at(8),
      estado: at(10),
    );
  }

  double? get promedio => notaToDouble(promedioRaw);
  String get promedioText => notaFmt(promedioRaw);
  int? get asistencia => int.tryParse(asistenciaRaw.trim());
  bool get enProceso => estado.toLowerCase().startsWith('dsp');
}

/// Una evidencia evaluada dentro de una unidad.
class EvidenciaNota {
  final String tipo; // EVIDENCIA DE CONOCIMIENTO / DESEMPEÑO / PRODUCTO
  final String pesoRaw; // peso de la evidencia (%)
  final String notaRaw;

  const EvidenciaNota({
    required this.tipo,
    required this.pesoRaw,
    required this.notaRaw,
  });

  double? get nota => notaToDouble(notaRaw);
  String get notaText => notaFmt(notaRaw);
}

/// Una unidad con su peso y sus evidencias + promedio.
class UnidadNotas {
  final String nombre; // "UNIDAD 1"
  final String pesoRaw; // "20.00"
  final List<EvidenciaNota> evidencias;
  final String promedioRaw; // promedio de la unidad (tbl3)

  const UnidadNotas({
    required this.nombre,
    required this.pesoRaw,
    required this.evidencias,
    required this.promedioRaw,
  });

  double? get peso => notaToDouble(pesoRaw);
  double? get promedio => notaToDouble(promedioRaw);
  String get promedioText => notaFmt(promedioRaw);
}

/// Detalle de notas de un curso (Intranet `consultarDetalleBoletaNotas`).
class CursoDetalleNotas {
  final List<UnidadNotas> unidades;
  final String sustitutorioRaw;
  final String promedioFinalRaw;
  final String estado;

  const CursoDetalleNotas({
    required this.unidades,
    required this.sustitutorioRaw,
    required this.promedioFinalRaw,
    required this.estado,
  });

  double? get promedioFinal => notaToDouble(promedioFinalRaw);
  String get promedioFinalText => notaFmt(promedioFinalRaw);
  String get sustitutorioText => notaFmt(sustitutorioRaw);
  bool get tieneSustitutorio => notaToDouble(sustitutorioRaw) != null;

  /// Parsea las filas posicionales (col 11 = marcador de tabla).
  factory CursoDetalleNotas.fromRows(List<dynamic> rows) {
    String at(List<dynamic> r, int i) =>
        (i < r.length ? r[i]?.toString() ?? '' : '').trim();

    final unidadesMap = <String, UnidadNotas>{};
    final orden = <String>[];
    final evidPorUnidad = <String, List<EvidenciaNota>>{};
    final pesoUnidad = <String, String>{};
    final promUnidad = <String, String>{};
    var sustitutorio = '';
    var promFinal = '';
    var estado = '';

    for (final raw in rows) {
      if (raw is! List) continue;
      final tbl = at(raw, 11);
      final unidad = at(raw, 4);
      switch (tbl) {
        case 'tbl1': // evidencias de la unidad
          if (!orden.contains(unidad)) {
            orden.add(unidad);
            pesoUnidad[unidad] = at(raw, 5);
            evidPorUnidad[unidad] = [];
          }
          evidPorUnidad[unidad]!.add(EvidenciaNota(
            tipo: at(raw, 7),
            pesoRaw: at(raw, 8),
            notaRaw: at(raw, 9),
          ));
          break;
        case 'tbl3': // promedio por unidad
          promUnidad[unidad] = at(raw, 9);
          break;
        case 'tbl5': // sustitutorio
          sustitutorio = at(raw, 9);
          break;
        case 'tbl6': // promedio final + estado
          promFinal = at(raw, 9);
          estado = at(raw, 10);
          break;
        // tbl2 (duplicado) y tbl4 (acumulado) se ignoran
      }
    }

    for (final u in orden) {
      unidadesMap[u] = UnidadNotas(
        nombre: u,
        pesoRaw: pesoUnidad[u] ?? '',
        evidencias: evidPorUnidad[u] ?? const [],
        promedioRaw: promUnidad[u] ?? '',
      );
    }

    return CursoDetalleNotas(
      unidades: orden.map((u) => unidadesMap[u]!).toList(),
      sustitutorioRaw: sustitutorio,
      promedioFinalRaw: promFinal,
      estado: estado,
    );
  }
}

// ===== Microsoft Teams / Graph Education =====
// Modelos basados en las respuestas reales de Microsoft Graph v1.0:
//   GET /education/me/classes      → educationClass
//   GET /education/me/assignments  → educationAssignment
// Se muestran tal cual llegan (sin personalización) para validar el flujo.

/// Una clase de Teams = un grupo = una asignatura (educationClass).
class TeamsClass {
  final String id;
  final String displayName;
  final String description;
  final String classCode;

  const TeamsClass({
    required this.id,
    required this.displayName,
    required this.description,
    required this.classCode,
  });

  factory TeamsClass.fromJson(Map<String, dynamic> j) => TeamsClass(
        id: _toStr(j['id']),
        displayName: _toStr(j['displayName']),
        description: _toStr(j['description']),
        classCode: _toStr(j['classCode']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'description': description,
        'classCode': classCode,
      };
}

/// Una tarea (educationAssignment).
///
/// En `/me/assignments`, los campos `instructions` y `webUrl` vienen `null`;
/// para el detalle completo hay que consultar
/// `GET /education/classes/{classId}/assignments/{id}`.
class TeamsAssignment {
  final String id;
  final String displayName;
  final String classId;
  /// Estado del lado del docente: draft, scheduled, published, assigned...
  final String status;
  /// Fecha de entrega (UTC en Graph; aquí ya en hora local). Puede ser null.
  final DateTime? dueDateTime;
  /// Solo presente en el detalle por clase.
  final String? instructions;
  final String? webUrl;

  const TeamsAssignment({
    required this.id,
    required this.displayName,
    required this.classId,
    required this.status,
    required this.dueDateTime,
    this.instructions,
    this.webUrl,
  });

  factory TeamsAssignment.fromJson(Map<String, dynamic> j) {
    // dueDateTime es un DateTimeOffset ISO-8601 (string), p.ej. "2026-05-30T03:59:00Z".
    final dueRaw = j['dueDateTime'];
    DateTime? due;
    if (dueRaw is String && dueRaw.isNotEmpty) {
      due = DateTime.tryParse(dueRaw)?.toLocal();
    } else if (dueRaw is Map) {
      // Algunos endpoints lo envuelven como { dateTime, timeZone }.
      final dt = dueRaw['dateTime'];
      if (dt is String) due = DateTime.tryParse(dt)?.toLocal();
    }
    // instructions llega como itemBody { contentType, content }.
    final instr = j['instructions'];
    final instrText = instr is Map ? instr['content'] as String? : null;
    return TeamsAssignment(
      id: _toStr(j['id']),
      displayName: _toStr(j['displayName']),
      classId: _toStr(j['classId']),
      status: _toStr(j['status']),
      dueDateTime: due,
      instructions: (instrText != null && instrText.isNotEmpty) ? instrText : null,
      webUrl: j['webUrl'] as String?,
    );
  }

  /// Días hasta la entrega (negativo si ya venció). null si no hay fecha.
  int? daysUntilDue([DateTime? now]) {
    final due = dueDateTime;
    if (due == null) return null;
    final t = now ?? DateTime.now();
    final hoy = DateTime(t.year, t.month, t.day);
    final venc = DateTime(due.year, due.month, due.day);
    return venc.difference(hoy).inDays;
  }

  bool isOverdue([DateTime? now]) {
    final due = dueDateTime;
    if (due == null) return false;
    return due.isBefore(now ?? DateTime.now());
  }
}

// ===== Documentos descargables (Intranet) =====
//
// Constancia de matrícula y Cronograma de pagos. Las fuentes son endpoints
// posicionales de Intranet (sin claves), mapeados según los comentarios del
// JS oficial (intra_pg_reportesDelEstudiante.html) y verificación manual.

/// Un curso dentro de la constancia de matrícula.
class MatriculaCurso {
  final String codigo;
  final String asignatura;
  final String ciclo;
  final String seccion;
  final String creditos;

  const MatriculaCurso({
    required this.codigo,
    required this.asignatura,
    required this.ciclo,
    required this.seccion,
    required this.creditos,
  });

  double get creditosNum => double.tryParse(creditos.trim()) ?? 0;
}

/// Constancia de matrícula completa: cabecera del estudiante + cursos.
/// Fuente: POST `consultarConstanciaMatriculaEstudiante` body `periodo=YYYY-P`.
class ConstanciaMatricula {
  final String codigo;
  final String estudiante;
  final String facultad;
  final String carrera;
  final String especialidad;
  final String planEstudios;
  final String nivel;
  final int anio;
  final int periodo;
  final String modalidad;
  final String fotoUrl;
  final String etiquetaCarrera; // "Carrera" o "EAP"
  final List<MatriculaCurso> cursos;
  final double totalCreditos;

  const ConstanciaMatricula({
    required this.codigo,
    required this.estudiante,
    required this.facultad,
    required this.carrera,
    required this.especialidad,
    required this.planEstudios,
    required this.nivel,
    required this.anio,
    required this.periodo,
    required this.modalidad,
    required this.fotoUrl,
    required this.etiquetaCarrera,
    required this.cursos,
    required this.totalCreditos,
  });

  /// Construye desde la respuesta posicional de Intranet.
  factory ConstanciaMatricula.fromRows(List<dynamic> rows) {
    String at(List<dynamic> r, int i) =>
        (i < r.length ? r[i]?.toString() ?? '' : '').trim();

    final filas = rows.whereType<List<dynamic>>().toList();
    if (filas.isEmpty) {
      return const ConstanciaMatricula(
        codigo: '', estudiante: '', facultad: '', carrera: '',
        especialidad: '', planEstudios: '', nivel: '',
        anio: 0, periodo: 0, modalidad: '', fotoUrl: '',
        etiquetaCarrera: 'Carrera', cursos: [], totalCreditos: 0,
      );
    }
    final head = filas.first;
    final cursos = filas
        .map((r) => MatriculaCurso(
              codigo: at(r, 6),
              asignatura: at(r, 7),
              ciclo: at(r, 9),
              seccion: at(r, 10),
              creditos: at(r, 13),
            ))
        .where((c) => c.codigo.isNotEmpty)
        .toList();

    final total = double.tryParse(at(head, 17)) ??
        cursos.fold<double>(0, (a, c) => a + c.creditosNum);

    return ConstanciaMatricula(
      codigo: at(head, 0),
      estudiante: at(head, 1),
      facultad: at(head, 2),
      carrera: at(head, 4),
      especialidad: at(head, 5),
      planEstudios: at(head, 8),
      nivel: at(head, 18).isNotEmpty ? at(head, 18) : at(head, 9),
      anio: int.tryParse(at(head, 11)) ?? 0,
      periodo: int.tryParse(at(head, 12)) ?? 0,
      modalidad: at(head, 14),
      fotoUrl: at(head, 19),
      etiquetaCarrera: at(head, 21).isNotEmpty ? at(head, 21) : 'Carrera',
      cursos: cursos,
      totalCreditos: total,
    );
  }

  String get periodoLabel =>
      '$anio-${periodo == 1 ? 'I' : periodo == 2 ? 'II' : periodo}';
}

/// Una cuota del cronograma (Intranet `consultarCuotasEstudiante`).
class CuotaCronograma {
  final String numero;       // "01", "02"
  final double monto;        // por cuota
  final String fechaVencRaw; // dd/MM/yyyy

  const CuotaCronograma({
    required this.numero,
    required this.monto,
    required this.fechaVencRaw,
  });

  factory CuotaCronograma.fromRow(List<dynamic> r) {
    String at(int i) => (i < r.length ? r[i]?.toString() ?? '' : '').trim();
    return CuotaCronograma(
      numero: at(3),
      monto: double.tryParse(at(2)) ?? 0,
      fechaVencRaw: at(4),
    );
  }

  DateTime? get fechaVenc {
    final p = fechaVencRaw.split('/');
    if (p.length != 3) return null;
    final d = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final y = int.tryParse(p[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }
}

// ===== Recursos institucionales (SIGMA) =====

/// Publicación / banner institucional (SIGMA `Recursos/ListarPublicaciones`).
class Publicacion {
  final int idPublicacion;
  final String tipoContenido; // "image", "video", etc.
  final String urlPrincipal;
  final String? urlAdaptable;
  final String? urlReferencia;
  final String? textoBoton;
  final bool permiteDescarga;
  final String dimensionPrincipal;

  const Publicacion({
    required this.idPublicacion,
    required this.tipoContenido,
    required this.urlPrincipal,
    required this.urlAdaptable,
    required this.urlReferencia,
    required this.textoBoton,
    required this.permiteDescarga,
    required this.dimensionPrincipal,
  });

  factory Publicacion.fromJson(Map<String, dynamic> j) => Publicacion(
        idPublicacion: _toInt(j['idPublicacion']) ?? 0,
        tipoContenido: _toStr(j['tipoContenido']),
        urlPrincipal: _toStr(j['urlPrincipal']),
        urlAdaptable: j['urlAdaptable'] as String?,
        urlReferencia: j['urlReferencia'] as String?,
        textoBoton: j['textoBoton'] as String?,
        permiteDescarga: _toBool(j['permiteDescarga']),
        dimensionPrincipal: _toStr(j['dimensionPrincipal']),
      );

  bool get esImagen => tipoContenido.toLowerCase() == 'image';
}

/// Credencial de Wi-Fi institucional (`Recursos/ObtenerWifiUsuario`).
/// Shape inferida del comportamiento de Intranet: usuario + contraseña.
class WifiCredencial {
  final String usuario;
  final String contrasena;

  const WifiCredencial({required this.usuario, required this.contrasena});

  factory WifiCredencial.fromJson(Map<String, dynamic> j) => WifiCredencial(
        usuario: _toStr(j['usuario'] ?? j['user'] ?? j['username']),
        contrasena:
            _toStr(j['contrasena'] ?? j['password'] ?? j['clave']),
      );
}

/// Conteo de notas por estado (`Estudiante/MostrarConteoNotas/{año}/{periodo}`).
/// Shape best-effort — tolerante a variaciones de nombres.
class ConteoNotas {
  final int aprobados;
  final int desaprobados;
  final int pendientes;
  final int total;

  const ConteoNotas({
    required this.aprobados,
    required this.desaprobados,
    required this.pendientes,
    required this.total,
  });

  factory ConteoNotas.fromJson(Map<String, dynamic> j) {
    final a = _toInt(j['aprobados'] ?? j['cantAprobados']) ?? 0;
    final d = _toInt(j['desaprobados'] ?? j['cantDesaprobados']) ?? 0;
    final p = _toInt(j['pendientes'] ?? j['cantPendientes']) ?? 0;
    return ConteoNotas(
      aprobados: a,
      desaprobados: d,
      pendientes: p,
      total: _toInt(j['total']) ?? (a + d + p),
    );
  }

  double get pctAprobados =>
      total == 0 ? 0 : aprobados / total;
}

// ===== Docente (scaffold sin verificar con cuenta real) =====
//
// Los siguientes modelos están construidos a partir del catálogo del bundle
// JS (sin acceso a respuestas reales). Decodificadores tolerantes —
// cuando un docente real pruebe, ajustamos los nombres de campos que no
// coincidan en un solo lugar (este archivo).

/// Información del docente autenticado (`Docente/GetInfoDocenteV1`).
class DocenteInfo {
  final String codigo;
  final String nombres;
  final String apellidos;
  final String? facultad;
  final String? especialidad;

  const DocenteInfo({
    required this.codigo,
    required this.nombres,
    required this.apellidos,
    this.facultad,
    this.especialidad,
  });

  factory DocenteInfo.fromJson(Map<String, dynamic> j) => DocenteInfo(
        codigo: _toStr(j['codigo'] ?? j['doc_Id']),
        nombres: _toStr(j['nombres']),
        apellidos: _toStr(j['apellidos']),
        facultad: j['facultad'] as String?,
        especialidad: j['especialidad'] as String?,
      );

  String get displayName =>
      [nombres, apellidos].where((s) => s.trim().isNotEmpty).join(' ').trim();
}

/// Asignatura que dicta un docente (`Docente/GetAsignaturaDocente`).
class DocenteAsignatura {
  final String id;          // cleAuto / saltemId / nrc
  final String codigo;
  final String asignatura;
  final String seccion;
  final String periodo;     // p.ej. "2026-1"
  final int? matriculados;

  const DocenteAsignatura({
    required this.id,
    required this.codigo,
    required this.asignatura,
    required this.seccion,
    required this.periodo,
    this.matriculados,
  });

  factory DocenteAsignatura.fromJson(Map<String, dynamic> j) =>
      DocenteAsignatura(
        id: _toStr(j['cleAuto'] ?? j['id'] ?? j['saltemId'] ?? j['nrc']),
        codigo: _toStr(j['codigo'] ?? j['asg_Id']),
        asignatura: _toStr(j['asignatura'] ?? j['nombreAsignatura']),
        seccion: _toStr(j['seccion']),
        periodo: _toStr(j['periodo'] ?? j['descripcionPeriodo']),
        matriculados: _toInt(j['matriculados'] ?? j['cantMatriculados']),
      );
}

/// Una evaluación dentro de una unidad/parcial.
/// Fuente real: `Docente/NotasEstudianteResumenV1`.
class NotaEvaluacion {
  final String codigo;       // e.g. "U1-P1", "PARCIAL-1"
  final String descripcion;  // e.g. "Práctica 1", "Examen parcial"
  final double peso;         // % dentro de la unidad o ciclo
  final String? nota;        // null si aún no registrada (editable)

  const NotaEvaluacion({
    required this.codigo,
    required this.descripcion,
    required this.peso,
    this.nota,
  });

  NotaEvaluacion copyWith({String? nota}) => NotaEvaluacion(
        codigo: codigo,
        descripcion: descripcion,
        peso: peso,
        nota: nota ?? this.nota,
      );

  double? get notaNum =>
      double.tryParse((nota ?? '').replaceAll(',', '.').trim());
}

/// Registro de asistencia de un alumno en una fecha.
/// Fuente: `Docente/GetAsistencia` / `InsertaRegistroAsistencia`.
class AsistenciaDia {
  final DateTime fecha;
  /// "P" = presente, "F" = falta, "T" = tardanza, "J" = justificada.
  final String estado;

  const AsistenciaDia({required this.fecha, required this.estado});

  bool get presente => estado == 'P' || estado == 'T';
}

/// Un estudiante de una sección que dicta el docente
/// (`Docente/ListarEstudianteComple?codSaltem={id}`).
class DocenteAlumno {
  final String codigo;
  final String nombres;
  final String apellidos;
  final String? asistencia; // % o "" si no aplica
  final String? nota;       // promedio o nota actual mostrable

  const DocenteAlumno({
    required this.codigo,
    required this.nombres,
    required this.apellidos,
    this.asistencia,
    this.nota,
  });

  factory DocenteAlumno.fromJson(Map<String, dynamic> j) => DocenteAlumno(
        codigo: _toStr(j['codigo'] ?? j['est_Id']),
        nombres: _toStr(j['nombres']),
        apellidos: _toStr(j['apellidos']),
        asistencia: j['asistencia']?.toString(),
        nota: j['nota']?.toString() ?? j['promedio']?.toString(),
      );

  String get displayName =>
      [apellidos, nombres].where((s) => s.trim().isNotEmpty).join(' ').trim();
}

/// Cronograma de pagos: monto total + cuotas + datos del alumno.
class CronogramaPagos {
  final double montoTotal;
  final List<CuotaCronograma> cuotas;

  const CronogramaPagos({required this.montoTotal, required this.cuotas});

  factory CronogramaPagos.fromRows(List<dynamic> rows) {
    final filas = rows.whereType<List<dynamic>>().toList();
    if (filas.isEmpty) {
      return const CronogramaPagos(montoTotal: 0, cuotas: []);
    }
    final total = double.tryParse(filas.first[1]?.toString() ?? '') ?? 0;
    final cuotas = filas.map(CuotaCronograma.fromRow).toList();
    return CronogramaPagos(montoTotal: total, cuotas: cuotas);
  }
}
