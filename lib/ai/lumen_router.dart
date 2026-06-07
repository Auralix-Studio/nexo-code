/// Bloques de contexto que el [LumenContextBuilder] puede inyectar.
enum LumenBlock {
  /// Próxima clase + clases de hoy + clases de la semana.
  schedule,

  /// Cuotas pendientes, vencidas, próxima a vencer.
  payments,

  /// Promedio acumulado, créditos, último periodo.
  grades,

  /// Knowledge base: carreras y planes de estudio.
  careersKb,

  /// KB: trámites (FUT, constancias, retiros, etc).
  proceduresKb,

  /// KB: UPLA general (sedes, biblioteca, autoridades).
  uplaKb,

  /// KB: sobre Nexo / Lumen.
  aboutKb,
}

/// Clasifica la consulta del usuario en uno o varios [LumenBlock] para
/// decidir qué data inyectar en el prompt.
///
/// Implementación deliberadamente boba — un regex por categoría. Es rápido
/// (microsegundos), determinístico, y no requiere modelo. Si más adelante
/// queremos algo más sofisticado (embeddings + similarity), podemos
/// reemplazar esta clase manteniendo la API.
class LumenRouter {
  const LumenRouter();

  // Detecta palabras clave incluso si vienen sin acento. Las clases de
  // caracteres `[áa]` etc cubren ambas variantes.
  static final _schedule = RegExp(
    r'\b(horari|clase|curso|materia|asignatur|hora|cu[áa]ndo|d[íi]a|'
    r'lunes|martes|mi[ée]rcoles|jueves|viernes|s[áa]bado|domingo|'
    r'pr[óo]xim|aula|sal[óo]n|docent|profesor|maestro)\b',
    caseSensitive: false,
  );

  static final _payments = RegExp(
    r'\b(cuota|pago|deud|debo|venc|mora|importe|monto|sol(es)?|'
    r's/\.?|tarifa|tasa|pension|cancel|abon)\b',
    caseSensitive: false,
  );

  static final _grades = RegExp(
    r'\b(nota|promedio|gpa|cr[ée]dito|aprob|desaprob|matricul|'
    r'ciclo|nivel|ranking|boleta|record)\b',
    caseSensitive: false,
  );

  static final _careers = RegExp(
    r'\b(carrera|carreras|facultad|facultades|plan( de)? estudio|'
    r'malla|ingenier[íi]a|derecho|medicina|enfermer[íi]a|psicolog[íi]a|'
    r'contabilidad|administraci[óo]n|odontolog[íi]a|farmacia|'
    r'arquitectura|educaci[óo]n|profesional|egresad)\b',
    caseSensitive: false,
  );

  static final _procedures = RegExp(
    r'\b(tr[áa]mite|constancia|certificado|fut|retiro|traslado|'
    r'bachiller|t[íi]tulo|grado|convalidaci[óo]n|sustentaci[óo]n|'
    r'pap[ée]l|solicitud|formulario)\b',
    caseSensitive: false,
  );

  static final _upla = RegExp(
    r'\b(upla|universidad|peruana(.+)?andes|sede|filial|huancayo|'
    r'lima|chanchamayo|satipo|biblioteca|autoridad|rector|decano|'
    r'sigma|intranet)\b',
    caseSensitive: false,
  );

  static final _about = RegExp(
    r'\b(nexo|lumen|app|aplicaci[óo]n|alessandro|villog|creador|'
    r'desarrollador|versi[óo]n|c[óo]digo abierto|github|bug|'
    r'sobre ti|qui[ée]n eres|qu[ée] eres)\b',
    caseSensitive: false,
  );

  Set<LumenBlock> route(String query) {
    final blocks = <LumenBlock>{};
    if (_schedule.hasMatch(query)) blocks.add(LumenBlock.schedule);
    if (_payments.hasMatch(query)) blocks.add(LumenBlock.payments);
    if (_grades.hasMatch(query)) blocks.add(LumenBlock.grades);
    if (_careers.hasMatch(query)) blocks.add(LumenBlock.careersKb);
    if (_procedures.hasMatch(query)) blocks.add(LumenBlock.proceduresKb);
    if (_upla.hasMatch(query)) blocks.add(LumenBlock.uplaKb);
    if (_about.hasMatch(query)) blocks.add(LumenBlock.aboutKb);
    return blocks;
  }
}
