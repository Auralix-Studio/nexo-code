class IdiomasCourse {
  final String estNombres;
  final String estPaterno;
  final String estMaterno;
  final String asigId;
  final String asignatura;
  final String dias;
  final String horaInicio;
  final String horaFin;
  final String aula;
  final String aulaNombre;
  final int detMatriculaId;
  final String modalidad;
  final String idiomaNombre;
  final String seccion;
  final int anio;
  final int mes;
  final String tipoEstudio;
  final String turno;
  final int capacidad;
  final int cantidad;
  final String fechRegistro;
  final num promedio;

  IdiomasCourse({
    required this.estNombres,
    required this.estPaterno,
    required this.estMaterno,
    required this.asigId,
    required this.asignatura,
    required this.dias,
    required this.horaInicio,
    required this.horaFin,
    required this.aula,
    required this.aulaNombre,
    required this.detMatriculaId,
    required this.modalidad,
    required this.idiomaNombre,
    required this.seccion,
    required this.anio,
    required this.mes,
    required this.tipoEstudio,
    required this.turno,
    required this.capacidad,
    required this.cantidad,
    required this.fechRegistro,
    required this.promedio,
  });

  factory IdiomasCourse.fromJson(Map<String, dynamic> json) {
    return IdiomasCourse(
      estNombres: json['estNombres'] ?? '',
      estPaterno: json['estPaterno'] ?? '',
      estMaterno: json['estMaterno'] ?? '',
      asigId: json['asigId'] ?? '',
      asignatura: json['asignatura'] ?? '',
      dias: json['dias'] ?? '',
      horaInicio: json['horaInicio'] ?? '',
      horaFin: json['horaFin'] ?? '',
      aula: json['aula'] ?? '',
      aulaNombre: json['aulaNombre'] ?? '',
      detMatriculaId: json['detMatriculaId'] ?? 0,
      modalidad: json['modalidad'] ?? '',
      idiomaNombre: json['idiomaNombre'] ?? '',
      seccion: json['seccion'] ?? '',
      anio: json['anio'] ?? 0,
      mes: json['mes'] ?? 0,
      tipoEstudio: json['tipoEstudio'] ?? '',
      turno: json['turno'] ?? '',
      capacidad: json['capacidad'] ?? 0,
      cantidad: json['cantidad'] ?? 0,
      fechRegistro: json['fechRegistro'] ?? '',
      promedio: json['promedio'] ?? 0,
    );
  }
}
