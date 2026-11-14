import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

/// Anillo de progreso que se llena al aparecer y al cambiar de valor, con el
/// porcentaje contando en el centro. [percent] nulo dibuja el anillo vacío.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.percent,
    required this.color,
    this.size = AppSizes.ring,
    this.stroke = AppSizes.ringStroke,
    this.emptyLabel = '—',
  });
  final int? percent;
  final Color color;
  final double size;
  final double stroke;
  final String emptyLabel;

  /// Proporción del diámetro que ocupa el texto central.
  static const double _labelScale = 0.26;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: size * _labelScale,
      fontWeight: FontWeight.w900,
      color: color,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final target = ((percent ?? 0) / 100).clamp(0.0, 1.0);
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: Motion.of(context, AppDurations.slow * 2),
        curve: Motion.enter,
        builder: (_, v, _) => CustomPaint(
          painter: _RingPainter(
            value: v,
            color: color,
            track: NexoTheme.border,
            stroke: stroke,
          ),
          child: Center(
            child: Text(
              percent == null ? emptyLabel : '${(v * 100).round()}%',
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.stroke,
  });
  final double value;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      paint..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}

/// Barra partida en tramos proporcionales (p. ej. asistieron / faltaron /
/// justificados) que crece desde el inicio al aparecer.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.parts, this.height = AppSizes.bar});

  /// Cantidad y color de cada tramo, en orden.
  final List<({int count, Color color})> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<int>(0, (a, p) => a + p.count);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context, AppDurations.slow * 2),
      curve: Motion.enter,
      builder: (_, v, _) => ClipRRect(
        borderRadius: AppRadii.rPill,
        child: SizedBox(
          height: height,
          child: ColoredBox(
            color: NexoTheme.border,
            child: total == 0
                ? const SizedBox.expand()
                : FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: v,
                    child: Row(
                      children: [
                        for (final p in parts)
                          if (p.count > 0)
                            Expanded(
                              flex: p.count,
                              child: ColoredBox(
                                color: p.color,
                                child: const SizedBox.expand(),
                              ),
                            ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
