import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/ai/lumen_router.dart';

void main() {
  const router = LumenRouter();

  group('routing por intención', () {
    test('horario', () {
      expect(router.route('¿qué clases tengo mañana?'),
          contains(LumenBlock.schedule));
    });

    test('pagos', () {
      expect(router.route('¿cuánto debo pagar este mes?'),
          contains(LumenBlock.payments));
    });

    test('notas / promedio', () {
      expect(router.route('¿cuál es mi promedio?'),
          contains(LumenBlock.grades));
    });
  });

  group('robustez ante acentos (normalización)', () {
    test('sin tilde: "como voy" enruta a notas', () {
      // 'cómo voy' (con tilde) es un patrón de grades; normalizado debe
      // matchear igual escrito "como voy".
      expect(router.route('como voy academicamente'),
          contains(LumenBlock.grades));
    });

    test('"miercoles" sin tilde enruta a horario', () {
      expect(router.route('que tengo el miercoles'),
          contains(LumenBlock.schedule));
    });

    test('MAYÚSCULAS también matchean', () {
      expect(router.route('CUÁNTO CUESTA LA PENSIÓN'),
          contains(LumenBlock.payments));
    });
  });

  group('fallback', () {
    test('query sin intención clara cae a UPLA + about, no vacío', () {
      final blocks = router.route('hola, buenas tardes');
      expect(blocks, isNotEmpty);
      expect(blocks, containsAll({LumenBlock.uplaKb, LumenBlock.aboutKb}));
    });
  });

  group('multi-intención', () {
    test('una query puede pedir varios bloques', () {
      final blocks = router.route('¿qué clases tengo y cuánto debo pagar?');
      expect(blocks, containsAll({LumenBlock.schedule, LumenBlock.payments}));
    });
  });
}
