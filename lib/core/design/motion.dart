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

/// Respuesta táctil: el contenido se encoge apenas mientras se presiona.
/// No captura el toque; envuelve a quien lo maneja (InkWell, botón…).
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  /// Escala mientras el dedo está abajo.
  static const double pressed = 0.97;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || Motion.reduced(context)) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? PressScale.pressed : 1,
        duration: AppDurations.press,
        curve: Motion.enter,
        child: widget.child,
      ),
    );
  }
}

/// Punto que late para señalar algo en curso. Con "reducir movimiento" queda
/// fijo.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = AppSizes.dot});
  final Color color;
  final double size;

  /// Opacidad con la que arranca la onda y cuánto crece.
  static const double _waveOpacity = 0.7;
  static const double _waveScale = 2;

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: AppDurations.loop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _ctrl.stop();
    } else if (!_ctrl.isAnimating) {
      _ctrl.repeat();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = DecoratedBox(
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      child: SizedBox.square(dimension: widget.size),
    );
    return SizedBox.square(
      dimension: widget.size * PulseDot._waveScale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FadeTransition(
            opacity: Tween<double>(
              begin: PulseDot._waveOpacity,
              end: 0,
            ).animate(_ctrl),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 1,
                end: PulseDot._waveScale,
              ).animate(CurvedAnimation(parent: _ctrl, curve: Motion.enter)),
              child: dot,
            ),
          ),
          dot,
        ],
      ),
    );
  }
}
