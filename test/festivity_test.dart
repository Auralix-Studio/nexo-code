import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/festivity/festivity.dart';

void main() {
  group('nthWeekdayOfMonth', () {
    test('Día del Padre 2026 = 3er domingo de junio = 21 jun', () {
      expect(nthWeekdayOfMonth(2026, 6, DateTime.sunday, 3), DateTime(2026, 6, 21));
    });
    test('Día de la Madre 2026 = 2º domingo de mayo = 10 may', () {
      expect(nthWeekdayOfMonth(2026, 5, DateTime.sunday, 2), DateTime(2026, 5, 10));
    });
  });

  group('FestivityService.active', () {
    ActiveFestivity? on(int y, int m, int d) =>
        FestivityService.active(DateTime(y, m, d));

    test('aniversario UPLA aparece en su ventana previa (11 jun → 18 jun)', () {
      final a = on(2026, 6, 11); // 7 días antes
      expect(a, isNotNull);
      expect(a!.festivity.id, 'upla');
      expect(a.daysUntil, 7);
      expect(a.greeting, contains('43°')); // 2026 - 1983 = 43
    });

    test('8 días antes del aniversario aún NO aparece (lead = 7)', () {
      expect(on(2026, 6, 10)?.festivity.id, isNot('upla'));
    });

    test('el mismo 18 de junio sigue activa', () {
      final a = on(2026, 6, 18);
      expect(a?.festivity.id, 'upla');
      expect(a?.daysUntil, 0);
    });

    test('UPLA gana al Día del Padre cuando se solapan (18 vs 21 jun)', () {
      // El 18 jun, la ventana del Día del Padre (21 jun, lead 3 → desde 18)
      // también está activa, pero UPLA está vigente (hoy) y tiene más prioridad.
      final a = on(2026, 6, 18);
      expect(a?.festivity.id, 'upla');
    });

    test('UPLA cede al Día del Padre cuando este se acerca (20 jun)', () {
      // 20 jun: UPLA (18) ya pasó y solo sigue en su cola; el Día del Padre
      // (21) está próximo → gana el evento por venir, aunque UPLA tenga más
      // prioridad. Así UPLA "tarda 1 día" en irse.
      expect(on(2026, 6, 20)?.festivity.id, 'dia_del_padre');
    });

    test('Fiestas Patrias cubre 28 y 29 de julio (tail)', () {
      expect(on(2026, 7, 29)?.festivity.id, 'fiestas_patrias');
    });

    test('Navidad activa en su víspera (20 dic, lead 12)', () {
      expect(on(2026, 12, 20)?.festivity.id, 'navidad');
    });

    test('Año Nuevo: ventana cruza el cambio de año (29 dic 2026)', () {
      // 1 ene 2027, lead 5 → ventana desde 27 dic 2026.
      final a = on(2026, 12, 29);
      expect(a?.festivity.id, 'anio_nuevo');
      expect(a?.greeting, contains('2027'));
    });

    test('un día cualquiera sin festividad → null', () {
      expect(on(2026, 3, 15), isNull);
    });
  });
}
