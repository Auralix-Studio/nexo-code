import 'package:flutter/widgets.dart';

enum FestivityDecor { confetti, snow, flagsPeru, petals, graduation }

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
    this.enabled = true,
    this.decorColors,
  });
  final String id;
  final bool enabled;
  final FestivityDecor decor;
  final List<Color>? decorColors;
  final int priority;
  final int leadDays;
  final int tailDays;
  final DateTime Function(int year) dateFor;
  final List<String> Function(int year) greetingsFor;
  final List<String> Function(int year) wordmarkFor;
  final int? Function(int year)? numberFor;
}

DateTime nthWeekdayOfMonth(int year, int month, int weekday, int n) {
  final first = DateTime(year, month, 1);
  final offset = (weekday - first.weekday + 7) % 7;
  return DateTime(year, month, 1 + offset + (n - 1) * 7);
}

abstract final class FestivityCalendar {
  static const int uplaFoundationYear = 1983;
  static final List<Festivity> all = [
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
    Festivity(
      id: 'fiestas_patrias',
      decor: FestivityDecor.confetti,
      decorColors: const [Color(0xFFD91023), Color(0xFFFFFFFF)],
      priority: 90,
      leadDays: 27,
      tailDays: 3,
      dateFor: (y) => DateTime(y, 7, 28),
      greetingsFor: (y) => [
        '¡Felices Fiestas Patrias!',
        '¡Viva el Perú!',
        'Orgullo peruano',
      ],
      wordmarkFor: (y) => ['Fiestas', 'Patrias'],
    ),
    Festivity(
      id: 'dia_del_maestro',
      enabled: false,
      decor: FestivityDecor.confetti,
      decorColors: const [Color(0xFF42A5F5), Color(0xFF66BB6A), Color(0xFFFFFFFF)],
      priority: 85,
      leadDays: 1,
      tailDays: 1,
      dateFor: (y) => DateTime(y, 7, 6),
      greetingsFor: (y) => [
        '¡Feliz Día del Maestro!',
        'Gracias por tus enseñanzas',
      ],
      wordmarkFor: (y) => ['Día del', 'Maestro'],
    ),
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
    Festivity(
      id: 'dia_del_padre',
      decor: FestivityDecor.confetti,
      priority: 60,
      leadDays: 3,
      tailDays: 1,
      dateFor: (y) => nthWeekdayOfMonth(y, 6, DateTime.sunday, 3),
      greetingsFor: (y) => ['¡Feliz Día del Padre!', 'Para todos los papás'],
      wordmarkFor: (y) => ['Día del', 'Padre'],
    ),
    Festivity(
      id: 'dia_de_la_madre',
      decor: FestivityDecor.petals,
      priority: 60,
      leadDays: 3,
      tailDays: 1,
      dateFor: (y) => nthWeekdayOfMonth(y, 5, DateTime.sunday, 2),
      greetingsFor: (y) => ['¡Feliz Día de la Madre!', 'Para todas las mamás'],
      wordmarkFor: (y) => ['Día de la', 'Madre'],
    ),
  ];
}

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
  final List<String> greetings;
  String get greeting => greetings.first;
  final List<String> wordmark;
  final int? number;
  final int daysUntil;
  FestivityDecor get decor => festivity.decor;
}

abstract final class FestivityService {
  static ActiveFestivity? active(DateTime now, {List<Festivity>? calendar}) {
    final today = DateTime(now.year, now.month, now.day);
    final cal = calendar ?? FestivityCalendar.all;
    ActiveFestivity? best;
    int bestScore = -1;
    for (final f in cal) {
      if (!f.enabled) continue;
      for (final y in [now.year - 1, now.year, now.year + 1]) {
        final date = f.dateFor(y);
        final start = date.subtract(Duration(days: f.leadDays));
        final end = date.add(Duration(days: f.tailDays));
        if (today.isBefore(start) || today.isAfter(end)) continue;
        final daysUntil = date.difference(today).inDays;
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
