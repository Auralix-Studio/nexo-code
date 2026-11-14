import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/tokens.dart';

class Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final Offset offsetFrom;
  final Curve curve;

  /// Tiempo que suma cada posición de la entrada escalonada.
  final Duration step;

  /// Cuántas posiciones se escalonan como máximo; el resto entra a la vez.
  static const int maxSteps = 8;

  /// Desplazamiento de entrada por defecto.
  static const Offset defaultOffset = Offset(0, 28);

  /// Desplazamiento corto para elementos de lista.
  static const Offset listOffset = Offset(0, 14);

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration = AppDurations.slow,
    this.offsetFrom = defaultOffset,
    this.curve = Motion.enter,
    this.step = AppDurations.stagger,
  });

  /// Entrada de un elemento de lista: rápida y con poco recorrido, para no
  /// frenar el desplazamiento.
  const Reveal.list({super.key, required this.child, this.index = 0})
    : baseDuration = AppDurations.normal,
      offsetFrom = listOffset,
      curve = Motion.enter,
      step = AppDurations.listStagger;

  @override
  Widget build(BuildContext context) {
    // Con "reducir movimiento" el contenido aparece directo.
    if (Motion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: baseDuration + step * index.clamp(0, maxSteps),
      curve: curve,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(
            offsetFrom.dx * (1 - value),
            offsetFrom.dy * (1 - value),
          ),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
