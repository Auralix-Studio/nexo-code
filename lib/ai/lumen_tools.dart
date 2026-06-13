import 'package:flutter_gemma/flutter_gemma.dart' show Tool;

import '../data/app_store.dart';
import '../domain/models.dart' show esModeloNuevo;
import '../domain/unified_models.dart';

/// Herramientas (function-calling) que Lumen puede invocar para obtener los
/// datos del estudiante **bajo demanda**, en vez de pre-inyectarlos en el
/// prompt. Cada definición es un `Tool` (JSON-Schema) y el ejecutor corre la
/// función contra el [AppStore] y devuelve un `Map` que se reenvía al modelo.
///
/// Formato de parámetros = JSON-Schema (`type/properties/required`), compatible
/// tanto con el prompt JSON de gemmaIt como con el de FunctionGemma de
/// flutter_gemma.
class LumenTools {
  LumenTools(this._store);

  final AppStore _store;

  /// Definiciones expuestas al modelo. Nombres en español para alinear con el
  /// dominio y facilitar el fine-tuning con ejemplos en español.
  static const List<Tool> definitions = [
    Tool(
      name: 'obtener_horario',
      description:
          'Devuelve el horario de clases del estudiante: próxima clase, '
          'clases de hoy y resumen semanal. Úsala para preguntas sobre clases, '
          'cursos, aulas, docentes, días u horas.',
      parameters: {
        'type': 'object',
        'properties': {
          'dia': {
            'type': 'string',
            'description':
                'Día opcional a consultar (lunes..domingo). Si se omite, '
                'devuelve hoy + la semana.',
          },
        },
      },
    ),
    Tool(
      name: 'obtener_pagos',
      description:
          'Devuelve las cuotas y pagos del estudiante: pendientes, vencidas, '
          'próxima a vencer y totales. Úsala para preguntas sobre deudas, '
          'pensiones, montos, vencimientos o mora.',
      parameters: {'type': 'object', 'properties': {}},
    ),
    Tool(
      name: 'obtener_promedio',
      description:
          'Devuelve el promedio del ciclo actual (en curso) y el acumulado '
          '(periodos cerrados), más los créditos aprobados. Úsala para '
          'preguntas sobre promedio, notas globales, rendimiento o créditos.',
      parameters: {'type': 'object', 'properties': {}},
    ),
    Tool(
      name: 'obtener_notas',
      description:
          'Devuelve las notas por curso del periodo activo (boleta). Úsala '
          'para preguntas sobre notas de cursos específicos del ciclo actual.',
      parameters: {'type': 'object', 'properties': {}},
    ),
    Tool(
      name: 'obtener_perfil',
      description:
          'Devuelve datos del estudiante: nombre, carrera, ciclo/nivel y '
          'créditos. Úsala para preguntas sobre su perfil académico.',
      parameters: {'type': 'object', 'properties': {}},
    ),
  ];

  /// Ejecuta la herramienta [name] con [args] y devuelve el resultado para
  /// reenviarlo al modelo. Nunca lanza: ante error devuelve `{'error': ...}`.
  Future<Map<String, dynamic>> execute(
    String name,
    Map<String, dynamic> args,
  ) async {
    try {
      return switch (name) {
        'obtener_horario' => _horario(args['dia'] as String?),
        'obtener_pagos' => _pagos(),
        'obtener_promedio' => _promedio(),
        'obtener_notas' => _notas(),
        'obtener_perfil' => _perfil(),
        _ => {'error': 'Herramienta desconocida: $name'},
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  Map<String, dynamic> _horario(String? dia) {
    final clases = _store.horario.value ?? const <ScheduleClass>[];
    if (clases.isEmpty) {
      return {'disponible': false, 'motivo': 'Horario no cargado todavía.'};
    }
    List<Map<String, dynamic>> mapClases(Iterable<ScheduleClass> cs) => [
          for (final c in cs)
            {
              'curso': c.subject,
              'tipo': c.typeCode,
              'dia': c.dayName,
              'inicio': c.startTime,
              'fin': c.endTime,
              'aula': c.roomShort,
              'docente': c.teacher,
            },
        ];

    if (dia != null && dia.trim().isNotEmpty) {
      final d = dia.toLowerCase();
      final filtradas = clases.where((c) => c.dayName.toLowerCase().contains(d));
      return {'dia': dia, 'clases': mapClases(filtradas)};
    }
    final hoy = DateTime.now().weekday;
    final deHoy = clases.where((c) => c.weekday == hoy);
    return {
      'hoy': mapClases(deHoy),
      'semana': mapClases(clases),
      'total_cursos': clases.map((c) => c.subject).toSet().length,
    };
  }

  Map<String, dynamic> _pagos() {
    final pend = _store.cuotasPendientes.value ?? const <Payment>[];
    final now = DateTime.now();
    final vencidas =
        pend.where((c) => c.dueDate != null && c.dueDate!.isBefore(now));
    final totalPend = pend.fold<double>(0, (a, c) => a + c.total);
    return {
      'pendientes': pend.length,
      'total_pendiente': totalPend.toStringAsFixed(2),
      'vencidas': vencidas.length,
      'detalle': [
        for (final c in pend)
          {
            'concepto': c.description,
            'monto': c.total.toStringAsFixed(2),
            'vence': c.dueDateRaw,
            'mora': c.lateFee > 0 ? c.lateFee.toStringAsFixed(2) : null,
          },
      ],
    };
  }

  Map<String, dynamic> _promedio() {
    return {
      'promedio_ciclo_actual': _store.promedioCicloActual?.toStringAsFixed(2),
      'promedio_acumulado': _store.promedioAcumulado?.toStringAsFixed(2),
      'creditos_aprobados': _store.creditosAprobados,
      'creditos_totales': _store.creditosTotales,
    };
  }

  Map<String, dynamic> _notas() {
    final activo = _store.periodoActivo;
    if (activo == null) {
      return {'disponible': false, 'motivo': 'Sin periodo activo.'};
    }
    final nuevo = esModeloNuevo(activo.year, activo.number);
    if (nuevo) {
      final cursos = _store.boletaOf(activo.year, activo.number).value;
      if (cursos == null) {
        return {'disponible': false, 'motivo': 'Boleta no cargada.'};
      }
      return {
        'periodo': activo.label,
        'cursos': [
          for (final c in cursos)
            {'curso': c.nombre, 'promedio': c.promedioText, 'estado': c.estado},
        ],
      };
    }
    final cursos = _store.boletaLegacyOf(activo.year, activo.number).value;
    if (cursos == null) {
      return {'disponible': false, 'motivo': 'Boleta no cargada.'};
    }
    return {
      'periodo': activo.label,
      'cursos': [
        for (final c in cursos)
          {'curso': c.asignatura, 'nota': c.notaActualText},
      ],
    };
  }

  Map<String, dynamic> _perfil() {
    final p = _store.profile.value;
    if (p == null) {
      return {'disponible': false, 'motivo': 'Perfil no cargado.'};
    }
    return {
      'nombre': p.fullName,
      'carrera': p.career,
      'ciclo': p.level,
      'creditos_aprobados': p.creditsApproved,
      'creditos_totales': p.creditsTotal,
    };
  }
}
