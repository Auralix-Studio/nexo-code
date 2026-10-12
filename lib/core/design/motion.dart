import 'package:flutter/material.dart';
import 'package:nexo/core/design/tokens.dart';

/// Movimiento de la app. Todas las animaciones toman sus tiempos de
/// [AppDurations] y respetan "reducir movimiento" del sistema: con esa
/// preferencia el contenido aparece directo, sin transición.
abstract final class Motion {
  static const Curve enter = Curves.easeOutCubic;
  static const Curve exit = Curves.easeInCubic;

  /// El usuario pidió menos movimiento (accesibilidad del sistema).
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d], o cero si hay que reducir el movimiento.
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;
}

/// Cambio suave entre estados de una vista (cargando, contenido, error): el
/// nuevo aparece con un fundido y un desplazamiento corto hacia arriba.
///
/// Distingue los estados por la `key` de [child]; dale una distinta a cada
/// estado (p. ej. `KeyedSubtree(key: const ValueKey('cargando'), …)`).
class FadeSwitch extends StatelessWidget {
  const FadeSwitch({
    super.key,
    required this.child,
    this.duration = AppDurations.normal,
    this.alignment = Alignment.topCenter,
  });
  final Widget child;
  final Duration duration;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.of(context, duration),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) =>
          Stack(alignment: alignment, children: [...previous, ?current]),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Número que cuenta hasta su valor al aparecer y al cambiar.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    this.style,
    this.suffix = '',
    this.duration = AppDurations.slow,
  });
  final int value;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final d = Motion.of(context, duration);
    if (d == Duration.zero) return Text('$value$suffix', style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()),
      duration: d,
      curve: Motion.enter,
      builder: (_, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
