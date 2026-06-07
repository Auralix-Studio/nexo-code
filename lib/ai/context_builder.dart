import 'package:flutter/services.dart' show rootBundle;

import '../data/app_store.dart';
import '../domain/models.dart';

/// Construye el "system preamble" que se prepende al primer mensaje del
/// usuario en cada sesión de chat con Lumen.
///
/// El preámbulo tiene tres partes:
/// 1. **Personalidad e instrucciones** — quién es Lumen, cómo responde.
/// 2. **Datos en vivo del estudiante** — lo que [AppStore] tenga cargado.
/// 3. **Knowledge base** — los 5 .md bundled en `assets/ai/knowledge/`.
///
/// La KB se lee una sola vez por proceso (caché estático), porque es
/// estática y vive en el bundle.
class LumenContextBuilder {
  LumenContextBuilder(this._store);

  final AppStore _store;

  static const _kbFiles = [
    'assets/ai/knowledge/upla_general.md',
    'assets/ai/knowledge/carreras.md',
    'assets/ai/knowledge/asignaturas.md',
    'assets/ai/knowledge/tramites.md',
    'assets/ai/knowledge/nexo_acerca.md',
  ];

  static String? _kbCache;

  static Future<String> _loadKnowledgeBase() async {
    final cached = _kbCache;
    if (cached != null) return cached;
    final buffer = StringBuffer();
    for (final path in _kbFiles) {
      final content = await rootBundle.loadString(path);
      buffer.writeln(content);
      buffer.writeln();
    }
    return _kbCache = buffer.toString();
  }

  /// Devuelve el preámbulo completo listo para concatenar al primer
  /// `Message.text` del usuario.
  Future<String> buildPreamble() async {
    final kb = await _loadKnowledgeBase();
    final student = _renderStudent();
    final academic = _renderAcademic();
    final financial = _renderFinancial();
    final schedule = _renderSchedule();
    final now = DateTime.now();
    final today = '${_weekday(now.weekday)} ${now.day} de ${_month(now.month)}'
        ' de ${now.year}';

    return '''
Eres Lumen, asistente IA personal de la app Nexo para estudiantes de la
Universidad Peruana Los Andes (UPLA). Respondes en español neutral, de
forma concisa, útil y honesta.

Reglas estrictas:
- Si te preguntan sobre el ESTUDIANTE (su horario, cuotas, notas,
  perfil), usa SOLO la información del bloque "═══ ESTUDIANTE ═══".
  Si un dato no está ahí, di "no tengo esa información" — NUNCA
  inventes nombres, montos, fechas ni notas.
- Si te preguntan sobre UPLA en general (carreras, sedes, trámites,
  asignaturas), usa el bloque "═══ CONOCIMIENTO UPLA ═══".
- Si te preguntan sobre Nexo o sobre ti misma, usa el bloque
  "Sobre Nexo".
- Si la pregunta es ambigua, pide aclaración en una sola frase.
- No menciones que usas un modelo de Google ni APIs externas.
- Hoy es $today.

═══ ESTUDIANTE ═══
$student

═══ ACADÉMICO ═══
$academic

═══ ESTADO FINANCIERO ═══
$financial

═══ HORARIO ═══
$schedule

═══ CONOCIMIENTO UPLA ═══
$kb
═══ FIN CONTEXTO ═══

A continuación viene la primera pregunta del estudiante:
''';
  }

  String _renderStudent() {
    final p = _store.profile.value;
    if (p == null) return 'Sin perfil cargado todavía.';
    return [
      '- Nombre: ${p.estudiante}',
      '- Código: ${p.estId}',
      '- Carrera: ${p.carrera}',
      '- Facultad: ${p.facultad}',
      '- Sede: ${p.sede}',
      '- Modalidad: ${p.modalidad}',
      '- Nivel/Ciclo: ${p.nivel}',
      '- Última matrícula: ${p.ultimaMatricula}',
      '- Matriculado actualmente: ${p.matriculado ? 'sí' : 'no'}',
      '- Créditos aprobados (total): ${p.creditoAprobado}',
    ].join('\n');
  }

  String _renderAcademic() {
    final lines = <String>[];
    final periodo = _store.periodoActivo;
    if (periodo != null) {
      lines.add('- Periodo activo: ${periodo.descripcion} '
          '(${periodo.anio}-${periodo.periodo})');
    }
    final resumen = _store.resumen.value;
    if (resumen != null) {
      lines.add('- Promedio acumulado: ${resumen.promedio.toStringAsFixed(2)}');
      lines.add('- Créditos aprobados: ${resumen.creditosAprobados}/'
          '${resumen.creditosTotales}');
      lines.add('- Matrículas registradas: ${resumen.cantMatricula}');
    }
    final proms = _store.promedios.value;
    if (proms != null && proms.isNotEmpty) {
      final last = proms.last;
      lines.add('- Promedio último periodo (${last.label}): '
          '${last.promedio.toStringAsFixed(2)}');
    }
    return lines.isEmpty ? 'Sin datos académicos cargados.' : lines.join('\n');
  }

  String _renderFinancial() {
    final pend = _store.cuotasPendientes.value ?? const <Cuota>[];
    if (pend.isEmpty) return 'Sin cuotas pendientes cargadas.';
    final now = DateTime.now();
    final vencidas = pend.where((c) {
      final f = c.vencimientoDate;
      return f != null && f.isBefore(now);
    }).toList();
    final totalPend = pend.fold<double>(0, (a, c) => a + c.subtotal);
    final totalVenc = vencidas.fold<double>(0, (a, c) => a + c.subtotal);
    final lines = <String>[
      '- Cuotas pendientes: ${pend.length} (total S/. '
          '${totalPend.toStringAsFixed(2)})',
      '- Cuotas vencidas: ${vencidas.length} (total S/. '
          '${totalVenc.toStringAsFixed(2)})',
    ];
    // Próxima a vencer (la más antigua no vencida)
    final futuras = pend
        .where((c) => c.vencimientoDate != null && c.vencimientoDate!.isAfter(now))
        .toList()
      ..sort((a, b) => a.vencimientoDate!.compareTo(b.vencimientoDate!));
    if (futuras.isNotEmpty) {
      final next = futuras.first;
      lines.add('- Próxima cuota: ${next.descripcion}, vence '
          '${next.fechaVencimiento}, S/. ${next.subtotal.toStringAsFixed(2)}');
    }
    return lines.join('\n');
  }

  String _renderSchedule() {
    final clases = _store.horario.value ?? const <ClaseHorario>[];
    if (clases.isEmpty) return 'Sin horario cargado.';
    final byDay = <int, List<ClaseHorario>>{};
    for (final c in clases) {
      byDay.putIfAbsent(c.idDia, () => []).add(c);
    }
    final sortedDays = byDay.keys.toList()..sort();
    final lines = <String>['Total de cursos matriculados: '
        '${clases.map((c) => c.asignatura).toSet().length}'];
    for (final d in sortedDays) {
      final items = byDay[d]!
        ..sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
      final dayName = items.first.dia.isNotEmpty
          ? items.first.dia
          : _weekday(d);
      lines.add('- $dayName:');
      for (final c in items) {
        lines.add('  • ${c.horaInicio}-${c.horaFin} ${c.asignatura} '
            '(${c.idTipo}) — ${c.docente.isEmpty ? 'sin docente' : c.docente}'
            '${c.aula.isEmpty ? '' : ', aula ${c.aula}'}');
      }
    }
    return lines.join('\n');
  }

  static String _weekday(int w) => const [
        '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes',
        'Sábado', 'Domingo'
      ][w.clamp(0, 7)];

  static String _month(int m) => const [
        '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ][m.clamp(0, 12)];
}
