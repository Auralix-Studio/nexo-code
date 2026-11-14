import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      18,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  });
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (iconColor ?? NexoTheme.primary).withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      icon,
                      size: AppIcon.lg,
                      color: iconColor ?? NexoTheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w800,
                          color: NexoTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: AppFont.label,
                            color: NexoTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Al pasar de cargando a contenido la tarjeta crece suave en vez
            // de saltar.
            AnimatedSize(
              duration: Motion.of(context, AppDurations.normal),
              curve: Motion.enter,
              alignment: Alignment.topCenter,
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
