/// Bloques de contexto que el [LumenContextBuilder] puede inyectar.
enum LumenBlock {
  /// Próxima clase + clases de hoy + clases de la semana.
  schedule,

  /// Cuotas pendientes, vencidas, próxima a vencer.
  payments,

  /// Promedio acumulado, créditos, último periodo.
  grades,

  /// KB: carreras y planes de estudio.
  careersKb,

  /// KB: asignaturas comunes, prerequisitos, carga por ciclo.
  subjectsKb,

  /// KB: trámites (FUT, constancias, retiros, etc).
  proceduresKb,

  /// KB: UPLA general (sedes, biblioteca, autoridades).
  uplaKb,

  /// KB: sobre Nexo / Lumen.
  aboutKb,
}

/// Clasifica la consulta del usuario en uno o varios [LumenBlock].
///
/// Regex por categoría — rápido (microsegundos), determinístico, sin
/// dependencias. Los patrones cubren sinónimos y formas naturales en
/// español rioplatense/andino (cómo me toca / qué debo / queda por…).
///
/// Si ningún bloque matchea, devuelve un fallback mínimo en vez de set
/// vacío — antes esto dejaba al modelo SIN contexto y respondía con su
/// conocimiento de pre-entrenamiento (que no sabe nada de UPLA).
class LumenRouter {
  const LumenRouter();

  static final _schedule = RegExp(
    r'\b(horari|clase|curso|materia|asignatur|hora|cu[áa]ndo|d[íi]a|'
    r'lunes|martes|mi[ée]rcoles|jueves|viernes|s[áa]bado|domingo|'
    r'pr[óo]xim|aula|sal[óo]n|docent|profesor|maestro|'
    // Sinónimos comunes:
    r'ma[ñn]ana|hoy|ahora|toca|tengo|cu[áa]l es mi|cu[áa]l tengo|'
    r'pendient|asisten|inasisten)\b',
    caseSensitive: false,
  );

  static final _payments = RegExp(
    r'\b(cuota|pago|pagar|deud|debo|venc|mora|importe|monto|sol(es)?|'
    r's/\.?|tarifa|tasa|pension|cancel|abon|'
    // Sinónimos:
    r'cost|precio|cuesta|cu[áa]nto|queda(n)? por|me falta|adeud|'
    r'descuent|beca|factura|recibo|caja|tesorer[íi]a|bolet[óo]n)\b',
    caseSensitive: false,
  );

  static final _grades = RegExp(
    r'\b(nota|promedio|gpa|cr[ée]dito|aprob|desaprob|matricul|'
    r'ciclo|nivel|ranking|boleta|record|'
    // Sinónimos:
    r'puntaje|c[áa]lcul|jal[ée]|jalar|reproba|paso|'
    r'voy bien|c[óo]mo (estoy|voy)|rendimient|m[ée]rit)\b',
    caseSensitive: false,
  );

  static final _careers = RegExp(
    r'\b(carrera|carreras|facultad|facultades|plan( de)? estudio|'
    r'malla|ingenier[íi]a|derecho|medicina|enfermer[íi]a|psicolog[íi]a|'
    r'contabilidad|administraci[óo]n|odontolog[íi]a|farmacia|'
    r'arquitectura|educaci[óo]n|profesional|egresad|'
    // Sinónimos:
    r'epg|posgrado|maestr[íi]a|doctorad|diplomad|especialidad)\b',
    caseSensitive: false,
  );

  static final _subjects = RegExp(
    r'\b(asignatur|curso|materia|prerequisito|pre.requisito|requisit|'
    r'an[áa]lisis matem[áa]tic|c[áa]lculo|[áa]lgebra|f[íi]sica|qu[íi]mica|'
    r'biolog[íi]a|anatom[íi]a|histolog[íi]a|filosof[íi]a|comunicaci[óo]n i|'
    r'estad[íi]stic|programaci[óo]n|algoritm|metodolog[íi]a|'
    r'depende de|llev[oa]r? primero|antes de|para llevar|'
    r'carga acad[ée]mica|cantidad de cursos|cu[áa]ntos cursos|'
    r'qu[ée] llev[oa])\b',
    caseSensitive: false,
  );

  static final _procedures = RegExp(
    r'\b(tr[áa]mite|constancia|certificado|fut|retiro|traslado|'
    r'bachiller|t[íi]tulo|grado|convalidaci[óo]n|sustentaci[óo]n|'
    r'pap[ée]l|solicitud|formulario|'
    // Sinónimos:
    r'c[óo]mo (hago|saco|pido|obtengo|tramit)|d[óo]nde (saco|pido|tramit)|'
    r'qu[ée] necesito para|requisitos para|reincorpor|reserv|practic|'
    r'oficina|secretar[íi]a|registro)\b',
    caseSensitive: false,
  );

  static final _upla = RegExp(
    r'\b(upla|universidad|peruana(.+)?andes|sede|filial|huancayo|'
    r'lima|chanchamayo|satipo|biblioteca|autoridad|rector|decano|'
    r'sigma|intranet|'
    // Sinónimos:
    r'campus|pabell[óo]n|fundaci[óo]n|misi[óo]n|visi[óo]n|valores|'
    r'comedor|cafeter[íi]a|laboratorio|wifi|wi.fi|tut[oó]r|tutor[íi]a)\b',
    caseSensitive: false,
  );

  static final _about = RegExp(
    r'\b(nexo|lumen|app|aplicaci[óo]n|alessandro|villog|creador|'
    r'desarrollador|versi[óo]n|c[óo]digo abierto|github|bug|'
    r'sobre ti|qui[ée]n eres|qu[ée] eres|'
    // Sinónimos:
    r'auralix|hecho por|c[óo]mo funcionas|qu[ée] hac[ée]s|para qu[ée] sirves|'
    r'soporte|ayuda(?! con)|contacto|reportar)\b',
    caseSensitive: false,
  );

  /// Normaliza la query antes de matchear: minúsculas + sin diacríticos.
  /// Es seguro con los patrones existentes (sus clases `[áa]` ya incluyen la
  /// letra base), y añade robustez ante tildes omitidas o mal puestas
  /// ("matricula", "cuanto", "miercoles") y mayúsculas.
  static String _normalize(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
    const to = 'aaaaaeeeeiiiiooooouuuun';
    final lower = s.toLowerCase();
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      final idx = from.indexOf(ch);
      sb.write(idx >= 0 ? to[idx] : ch);
    }
    return sb.toString();
  }

  Set<LumenBlock> route(String rawQuery) {
    final query = _normalize(rawQuery);
    final blocks = <LumenBlock>{};
    if (_schedule.hasMatch(query)) blocks.add(LumenBlock.schedule);
    if (_payments.hasMatch(query)) blocks.add(LumenBlock.payments);
    if (_grades.hasMatch(query)) blocks.add(LumenBlock.grades);
    if (_careers.hasMatch(query)) blocks.add(LumenBlock.careersKb);
    if (_subjects.hasMatch(query)) blocks.add(LumenBlock.subjectsKb);
    if (_procedures.hasMatch(query)) blocks.add(LumenBlock.proceduresKb);
    if (_upla.hasMatch(query)) blocks.add(LumenBlock.uplaKb);
    if (_about.hasMatch(query)) blocks.add(LumenBlock.aboutKb);

    // Fallback: si la query no matchea nada, al menos el modelo sabe que
    // está en Nexo / UPLA. Sin esto contestaba con su conocimiento general
    // (que no es de UPLA) y se inventaba cosas.
    if (blocks.isEmpty) {
      blocks.addAll({LumenBlock.uplaKb, LumenBlock.aboutKb});
    }
    return blocks;
  }
}
