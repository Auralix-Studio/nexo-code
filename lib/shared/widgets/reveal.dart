import 'package:flutter/material.dart';

import 'package:nexo/core/design/tokens.dart';

/// Entrada animada (fade + slide) reutilizable, con stagger por índice.
///
/// Todas las duraciones vienen de los tokens [AppDurations] — sin números
/// mágicos. Diseñado para usarse dentro de listas o columnas:
///
/// ```dart
/// for (var i = 0; i < items.length; i++)
///   Reveal(index: i, child: MyTile(items[i])),
/// ```
class Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  /// Base de duración; cada `index` añade un retraso suave (stagger).
  final Duration baseDuration;

  /// Desplazamiento inicial (origen del slide).
  final Offset offsetFrom;

  /// Curva de la animación.
  final Curve curve;

  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration = AppDurations.slow,
    // Distancia más perceptible (antes 12, casi no se notaba).
    this.offsetFrom = const Offset(0, 28),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Stagger más marcado (110ms entre items) y capado para listas largas.
      duration: baseDuration +
          Duration(milliseconds: 110 * (index.clamp(0, 8))),
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
