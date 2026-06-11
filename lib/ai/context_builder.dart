import 'package:flutter/services.dart' show rootBundle;

import '../data/app_store.dart';
import '../domain/unified_models.dart';
import 'lumen_router.dart';

/// Construye el prompt completo que se envía al modelo en cada turno.
///
/// **Diseño v1.2 — single-shot con context selectivo.**
///
/// En vez del enfoque viejo (un preamble gigante con TODA la data inyectada
/// en el primer turno), ahora cada query del usuario se enruta con
/// [LumenRouter] para decidir qué bloques de data son relevantes, y solo
/// esos se incluyen en el prompt.
///
/// Beneficios:
/// - Prompt típico ≈ 200-600 tokens (vs 3000+ del v1).
/// - El 270M responde sin colapsar.
/// - El 1B mantiene coherencia y no entra en loops.
/// - Cada turno es stateless: limpia el chat antes de enviar, evita
///   confusión por historial cruzado entre temas distintos.
///
/// Trade-off: se pierde la "conversación fluida" multi-turno. La sesión
/// es más como un Q&A. Para v1.3 podríamos retener last-N turns en el
/// payload si la UX se siente seca.
class LumenContextBuilder {
  LumenContextBuilder(this._store, {LumenRouter? router})
      : _router = router ?? const LumenRouter();

  final AppStore _store;
  final LumenRouter _router;

  // ───── Knowledge base (lazy + cacheada) ─────

  static const _kbAssets = <LumenBlock, String>{
    LumenBlock.careersKb: 'assets/ai/knowledge/carreras.md',
    // asignaturas.md existía en disco pero no estaba cableado — el modelo
    // contestaba "no sé" a preguntas sobre prerequisitos y carga académica.
    LumenBlock.subjectsKb: 'assets/ai/knowledge/asignaturas.md',
    LumenBlock.proceduresKb: 'assets/ai/knowledge/tramites.md',
    LumenBlock.uplaKb: 'assets/ai/knowledge/upla_general.md',
    LumenBlock.aboutKb: 'assets/ai/knowledge/nexo_acerca.md',
  };
  static final Map<LumenBlock, String> _kbCache = {};

  Future<String> _loadKb(LumenBlock block) async {
    final cached = _kbCache[block];
    if (cached != null) return cached;
    final path = _kbAssets[block];
    if (path == null) return '';
    final raw = await rootBundle.loadString(path);
    return _kbCache[block] = raw;
  }

  // ───── Public API ─────

  /// Construye el prompt completo a enviar al motor. Incluye:
  /// - Identidad del asistente + nombre + fecha
  /// - Bloques de data relevantes (según routing)
  /// - La pregunta del usuario al final
  Future<String> buildPrompt({
    required String modelId,
    required String userQuery,
  }) async {
    final blocks = _router.route(userQuery);
    final p = _store.profile.value;
    final name = p?.fullName.split(' ').first ?? 'estudiante';
    final carrera = p?.career ?? '';
    final now = DateTime.now();
    final today = '${_weekday(now.weekday)} ${now.day} de ${_month(now.month)} '
        'de ${now.year}';

    final buf = StringBuffer();
    buf.writeln(
      'Eres Lumen, asistente IA local de la app Nexo, para un estudiante '
      'de la Universidad Peruana Los Andes (UPLA). Respondes en español '
      'neutral, breve (1-4 oraciones), sin inventar datos. Si la '
      'información necesaria no está más abajo, dilo con honestidad.',
    );
    buf.writeln(
      'Si te preguntan qué modelo o tecnología usas, di "soy Lumen, '
      'corro 100% en tu teléfono" — no menciones nombres de modelos.',
    );
    buf.writeln('Hoy es $today.');
    buf.writeln('Estudiante: $name${carrera.isEmpty ? '' : ', $carrera'}.');

    // Bloques de data en vivo
    if (blocks.contains(LumenBlock.schedule)) {
      buf.writeln();
      buf.writeln('=== HORARIO ===');
      buf.writeln(_renderSchedule());
    }
    if (blocks.contains(LumenBlock.payments)) {
      buf.writeln();
      buf.writeln('=== CUOTAS Y PAGOS ===');
      buf.writeln(_renderPayments());
    }
    if (blocks.contains(LumenBlock.grades)) {
      buf.writeln();
      buf.writeln('=== ACADÉMICO ===');
      buf.writeln(_renderAcademic());
    }

    // Bloques de knowledge base (estáticos)
    for (final kbBlock in [
      LumenBlock.careersKb,
      LumenBlock.subjectsKb,
      LumenBlock.proceduresKb,
      LumenBlock.uplaKb,
      LumenBlock.aboutKb,
    ]) {
      if (blocks.contains(kbBlock)) {
        buf.writeln();
        buf.writeln('=== ${_kbLabel(kbBlock)} ===');
        buf.writeln(await _loadKb(kbBlock));
      }
    }

    buf.writeln();
    buf.writeln('=== PREGUNTA DEL ESTUDIANTE ===');
    buf.writeln(userQuery);
    buf.writeln();
    buf.write('Respuesta concisa:');

    return buf.toString();
  }

  // ───── Renderers para data en vivo ─────

  String _renderSchedule() {
    final slice = _store.horario;
    final clases = slice.value ?? const <ScheduleClass>[];
    if (clases.isEmpty) {
      // Distinguir "estamos cargando" de "no hay datos" — antes los dos
      // casos colapsaban al mismo mensaje y el modelo le decía al usuario
      // que abriera el horario cuando en realidad la app ya lo estaba
      // sincronizando.
      if (slice.loading) {
        return 'Los datos del horario aún se están cargando desde SIGMA/'
            'Intranet. Pide al estudiante esperar unos segundos.';
      }
      return 'No hay horario cargado todavía. Pide al estudiante que '
          'abra la pestaña Horario para sincronizar.';
    }

    final now = DateTime.now();
    final today = now.weekday;
    final hhmm = '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}';

    // Próxima clase: la primera futura del día actual o el día siguiente.
    ScheduleClass? next;
    final ordered = [...clases]..sort((a, b) {
        final c = a.weekday.compareTo(b.weekday);
        return c != 0 ? c : a.startTime.compareTo(b.startTime);
      });
    for (final c in ordered) {
      if (c.weekday > today ||
          (c.weekday == today && c.startTime.compareTo(hhmm) > 0)) {
        next = c;
        break;
      }
    }
    next ??= ordered.isNotEmpty ? ordered.first : null;

    final buf = StringBuffer();
    if (next != null) {
      buf.writeln('Próxima clase: ${next.subject} (${next.typeCode}) — '
          '${next.dayName} ${next.startTime}-${next.endTime}, '
          '${next.teacher.isEmpty ? 'sin docente asignado' : next.teacher}, '
          'aula ${next.roomShort}.');
    }

    // Clases de hoy
    final hoy = clases.where((c) => c.weekday == today).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    if (hoy.isNotEmpty) {
      buf.writeln('Hoy (${_weekday(today)}):');
      for (final c in hoy) {
        buf.writeln('  - ${c.startTime}-${c.endTime} ${c.subject} '
            '(${c.typeCode}), aula ${c.roomShort}.');
      }
    } else {
      buf.writeln('Hoy no tienes clases.');
    }

    // Resumen semanal compacto
    final byDay = <int, List<ScheduleClass>>{};
    for (final c in clases) {
      byDay.putIfAbsent(c.weekday, () => []).add(c);
    }
    buf.writeln('Total cursos esta semana: '
        '${clases.map((c) => c.subject).toSet().length}.');
    return buf.toString();
  }

  String _renderPayments() {
    final slice = _store.cuotasPendientes;
    final pend = slice.value ?? const <Payment>[];
    if (pend.isEmpty) {
      if (slice.loading) {
        return 'Los datos de pagos aún se están cargando. Pide al '
            'estudiante esperar unos segundos.';
      }
      return 'No hay cuotas pendientes cargadas.';
    }
    final now = DateTime.now();
    final vencidas = pend.where((c) {
      final d = c.dueDate;
      return d != null && d.isBefore(now);
    }).toList();
    final futuras = pend.where((c) {
      final d = c.dueDate;
      return d != null && d.isAfter(now);
    }).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    final totalPend = pend.fold<double>(0, (a, c) => a + c.total);
    final totalVenc = vencidas.fold<double>(0, (a, c) => a + c.total);

    final buf = StringBuffer();
    buf.writeln('Cuotas pendientes: ${pend.length} '
        '(total S/. ${totalPend.toStringAsFixed(2)}).');
    if (vencidas.isNotEmpty) {
      buf.writeln('Vencidas: ${vencidas.length} '
          '(total S/. ${totalVenc.toStringAsFixed(2)}).');
    }
    if (futuras.isNotEmpty) {
      final n = futuras.first;
      buf.writeln('Próxima a vencer: ${n.description}, '
          '${n.dueDateRaw}, S/. ${n.total.toStringAsFixed(2)}'
          '${n.lateFee > 0 ? ' (incluye mora S/. ${n.lateFee.toStringAsFixed(2)})' : ''}.');
    }
    return buf.toString();
  }

  String _renderAcademic() {
    final p = _store.profile.value;
    final buf = StringBuffer();
    if (p != null) {
      buf.writeln('Ciclo / nivel: ${p.level}.');
      if (p.creditsApproved != null) {
        buf.writeln('Créditos aprobados: ${p.creditsApproved}'
            '${p.creditsTotal != null ? ' de ${p.creditsTotal}' : ''}.');
      }
      if (p.gpa != null) {
        buf.writeln('Promedio acumulado: ${p.gpa!.toStringAsFixed(2)}.');
      }
    }
    final proms = _store.promedios.value;
    if (proms != null && proms.isNotEmpty) {
      final last = proms.last;
      final label = '${last.year}-${last.number == 1 ? 'I' : 'II'}';
      buf.writeln('Último periodo: $label, '
          'promedio ${last.average.toStringAsFixed(2)}.');
    }
    if (buf.isEmpty) {
      if (_store.profile.loading || _store.promedios.loading) {
        return 'Los datos académicos aún se están cargando. Pide al '
            'estudiante esperar unos segundos.';
      }
      return 'No hay datos académicos cargados.';
    }
    return buf.toString();
  }

  // ───── Helpers ─────

  static String _kbLabel(LumenBlock b) => switch (b) {
        LumenBlock.careersKb => 'CARRERAS UPLA',
        LumenBlock.subjectsKb => 'ASIGNATURAS Y PREREQUISITOS',
        LumenBlock.proceduresKb => 'TRÁMITES UPLA',
        LumenBlock.uplaKb => 'UPLA — INFORMACIÓN GENERAL',
        LumenBlock.aboutKb => 'SOBRE NEXO Y LUMEN',
        _ => '',
      };

  static String _weekday(int w) => const [
        '', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes',
        'sábado', 'domingo'
      ][w.clamp(0, 7)];

  static String _month(int m) => const [
        '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
        'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
      ][m.clamp(0, 12)];
}
