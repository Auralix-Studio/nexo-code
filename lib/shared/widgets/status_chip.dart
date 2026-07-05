import 'package:flutter/material.dart';
import 'package:nexo/core/design/tokens.dart';

class StatusChip extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const StatusChip({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const Gap.h(AppSpacing.xs),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: AppFont.caption,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
