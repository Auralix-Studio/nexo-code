import 'package:flutter/material.dart';
import 'package:nexo/core/design/tokens.dart';

class Reveal extends StatelessWidget {
  final int index;
  final Widget child;
  final Duration baseDuration;
  final Offset offsetFrom;
  final Curve curve;
  const Reveal({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDuration = AppDurations.slow,
    this.offsetFrom = const Offset(0, 28),
    this.curve = Curves.easeOutCubic,
  });
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration:
          baseDuration + Duration(milliseconds: 110 * (index.clamp(0, 8))),
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
