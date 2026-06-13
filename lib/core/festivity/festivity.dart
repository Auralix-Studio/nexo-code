import 'package:flutter/widgets.dart';

/// Estilo de decoración/partículas de una festividad.
enum FestivityDecor { confetti, snow, flagsPeru, petals, graduation }

/// Una festividad con su fecha (fija o calculada), su ventana de aparición y
/// su decoración. Lógica **pura** — sin Flutter de runtime ni estado — para
/// poder testearla.
class Festivity {
  const Festivity({
    required this.id,
    required this.decor,
    required this.priority,
    required this.leadDays,
    required this.dateFor,
    required this.greetingsFor,
    required this.wordmarkFor,
    this.numberFor,
    this.tailDays = 0,
  });

  final String id;
  final FestivityDecor decor;

  /// Mayor gana si dos festividades se solapan (UPLA es la más alta).
  final int priority;

  /// Días ANTES de la fecha en que el adorno empieza a mostrarse.
  final int leadDays;

  /// Días DESPUÉS de la fecha en que sigue mostrándose (p.ej. Fiestas Patrias
  /// abarca 28 y 29).
  final int tailDays;

  /// Fecha de la festividad para un año dado (maneja fechas variables como el
  /// 3er domingo de junio).
  final DateTime Function(int year) dateFor;

  /// Frases del saludo para un año dado. **Rotan** durante la festividad en el
  /// home (la primera es la principal, p.ej. "¡Feliz 43° aniversario UPLA!").
  final List<String> Function(int year) greetingsFor;

  /// Palabras que rotan en el wordmark del sidebar DESPUÉS de "Nexo".
  /// Ej. UPLA → ["UPLA 43", "Aniversario"], de modo que el ciclo completo es
  /// "Nexo" → "UPLA 43" → "Aniversario".
  final List<String> Function(int year) wordmarkFor;

  /// Número del aniversario para el adorno colgante (UPLA → 43). `null` si la
  /// festividad no tiene un número que colgar.
  final int? Function(int year)? numberFor;
}

/// N-ésimo [weekday] (1=lunes..7=domingo) de un mes — para fechas móviles.
DateTime nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  final first = DateTime(year, month, 1);
  final offset = (weekday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + (n - 1) * 7);
}

/// Catálogo de festividades — principales del Perú + aniversario UPLA.
abstract final class FestivityCalendar {
  /// Año de fundación de la UPLA (para el ordinal del aniversario).
  static const int uplaFoundationYear = 1983;

  static final List<Festivity> all = [
    // ⭐ Aniversario UPLA — 18 de junio. La de mayor prioridad.
    Festivity(
      id: 'upla',
      decor: FestivityDecor.graduation,
      priority: 100,
      leadDays: 7,
      tailDays: 3,
      dateFor: (y) => DateTime(y, 6, 18),
      greetingsFor: (y) => [
        '¡Feliz ${y - uplaFoundationYear}° aniversario UPLA!',
        '${y - uplaFoundationYear} años transformando',
        'Orgullo Andino',
        'Celebremos juntos a la UPLA',
      ],
      wordmarkFor: (y) => ['UPLA ${y - uplaFoundationYear}', 'Aniversario'],
      numberFor: (y) => y - uplaFoundationYear,
    ),
    // Fiestas Patrias — 28 y 29 de julio.
    Festivity(
      id: 'fiestas_patrias',
      decor: FestivityDecor.flagsPeru,
      priority: 90,
      leadDays: 6,
      tailDays: 2,
      dateFor: (y) => DateTime(y, 7, 28),
      greetingsFor: (y) => [
        '¡Felices Fiestas Patrias!',
        '¡Viva el Perú!',
        'Orgullo peruano',
      ],
      wordmarkFor: (y) => ['Fiestas', 'Patrias'],
    ),
    // Navidad — 25 de diciembre.
    Festivity(
      id: 'navidad',
      decor: FestivityDecor.snow,
      priority: 80,
      leadDays: 12,
      tailDays: 2,
      dateFor: (y) => DateTime(y, 12, 25),
      greetingsFor: (y) => [
        '¡Feliz Navidad!',
        '¡Felices fiestas!',
        'Que la pases en familia',
      ],
      wordmarkFor: (y) => ['Feliz', 'Navidad'],
    ),
    // Año Nuevo — 1 de enero (la ventana cruza fin de año).
    Festivity(
      id: 'anio_nuevo',
      decor: FestivityDecor.confetti,
      priority: 80,
      leadDays: 5,
      tailDays: 1,
      dateFor: (y) => DateTime(y, 1, 1),
      greetingsFor: (y) => [
        '¡Feliz Año Nuevo $y!',
        'Nuevo año, nuevas metas',
        '¡Felices fiestas!',
      ],
      wordmarkFor: (y) => ['Feliz', 'Año $y'],
    ),
    // Día de la Canción Criolla — 31 de octubre.
    Festivity(
      id: 'cancion_criolla',
      decor: FestivityDecor.petals,
      priority: 70,
      leadDays: 3,
      tailDays: 2,
      dateFor: (y) => DateTime(y, 10, 31),
      greetingsFor: (y) => [
        'Día de la Canción Criolla',
        '¡Que viva el criollismo!',
        'Orgullo peruano',
      ],
      wordmarkFor: (y) => ['Canción', 'Criolla'],
    ),
    // Día del Padre — 3er domingo de junio.
    Festivity(
      id: 'dia_del_padre',
      decor: FestivityDecor.confetti,
      priority: 60,
      leadDays: 3,
      tailDays: 1,
      dateFor: (y) => nthWeekdayOfMonth(y, 6, DateTime.sunday, 3),
      greetingsFor: (y) => [
        '¡Feliz Día del Padre!',
        'Para todos los papás',
      ],
      wordmarkFor: (y) => ['Día del', 'Padre'],
    ),
    // Día de la Madre — 2º domingo de mayo.
    Festivity(
      id: 'dia_de_la_madre',
      decor: FestivityDecor.petals,
      priority: 60,
      leadDays: 3,
      tailDays: 1,
      dateFor: (y) => nthWeekdayOfMonth(y, 5, DateTime.sunday, 2),
      greetingsFor: (y) => [
        '¡Feliz Día de la Madre!',
        'Para todas las mamás',
      ],
      wordmarkFor: (y) => ['Día de la', 'Madre'],
    ),
  ];
}

/// Resultado activo: la festividad + su fecha/saludo ya resueltos para "hoy".
@immutable
class ActiveFestivity {
  const ActiveFestivity({
    required this.festivity,
    required this.date,
    required this.greetings,
    required this.wordmark,
    required this.number,
    required this.daysUntil,
  });

  final Festivity festivity;
  final DateTime date;

  /// Frases del saludo de esta festividad (rotan en el home). La primera es la
  /// principal.
  final List<String> greetings;

  /// Saludo principal (primera frase).
  String get greeting => greetings.first;

  /// Ciclo completo del wordmark del sidebar: "Nexo" + las palabras de la
  /// festividad (ej. ["Nexo", "UPLA 43", "Aniversario"]).
  final List<String> wordmark;

  /// Número del aniversario para el adorno colgante (UPLA → 43), o `null`.
  final int? number;

  /// Días hasta la fecha (0 = hoy, negativo = ya pasó pero dentro de tailDays).
  final int daysUntil;

  FestivityDecor get decor => festivity.decor;
}

/// Decide qué festividad (si alguna) está activa para una fecha dada.
abstract final class FestivityService {
  /// Festividad activa hoy según las ventanas `[fecha−lead, fecha+tail]`.
  /// Revisa el año anterior/actual/siguiente para cubrir ventanas que cruzan
  /// el cambio de año (Año Nuevo, Navidad). Ante empate, mayor prioridad.
  static ActiveFestivity? active(DateTime now, {List<Festivity>? calendar}) {
    final today = DateTime(now.year, now.month, now.day);
    final cal = calendar ?? FestivityCalendar.all;
    ActiveFestivity? best;
    int bestScore = -1;

    for (final f in cal) {
      for (final y in [now.year - 1, now.year, now.year + 1]) {
        final date = f.dateFor(y);
        final start = date.subtract(Duration(days: f.leadDays));
        final end = date.add(Duration(days: f.tailDays));
        if (today.isBefore(start) || today.isAfter(end)) continue;
        final daysUntil = date.difference(today).inDays;
        // Un evento **vigente o próximo** (daysUntil >= 0) desplaza a otro que
        // ya pasó y solo sigue en su "cola" (tail). Así, si se acerca un evento
        // nuevo, el anterior se va sin esperar a agotar sus días de cola.
        // Empate de frescura → mayor prioridad.
        final fresh = daysUntil >= 0;
        final score = (fresh ? 1000 : 0) + f.priority;
        if (score > bestScore) {
          bestScore = score;
          best = ActiveFestivity(
            festivity: f,
            date: date,
            greetings: f.greetingsFor(y),
            wordmark: ['Nexo', ...f.wordmarkFor(y)],
            number: f.numberFor?.call(y),
            daysUntil: daysUntil,
          );
        }
      }
    }
    return best;
  }
}
