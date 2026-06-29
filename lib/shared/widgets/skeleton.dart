import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const Skeleton({
    super.key,
    this.width,
    this.height = AppSpacing.lg,
    this.radius = AppRadii.xs,
  });
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = NexoTheme.border;
    final highlight = NexoTheme.surface;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [base, highlight, base],
            stops: [
              (_ctrl.value - 0.3).clamp(0.0, 1.0),
              _ctrl.value.clamp(0.0, 1.0),
              (_ctrl.value + 0.3).clamp(0.0, 1.0),
            ],
          ),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
