import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/l10n/app_localizations.dart';

/// Estado vacío con icono e ilustración minimalista. Opcionalmente muestra un
/// botón de reintento (para estados de error).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;

  /// Si se define, muestra un botón que lo ejecuta (p.ej. recargar tras error).
  final VoidCallback? onRetry;
  final String? retryLabel;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? NexoTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxxl,
        horizontal: AppSpacing.lg,
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: AppRadii.rXl,
            ),
            child: Icon(icon, color: c, size: 28),
          ),
          const Gap(AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFont.subtitle,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textPrimary,
            ),
          ),
          if (subtitle != null) ...[
            const Gap(AppSpacing.xs),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: NexoTheme.textSecondary,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const Gap(AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(retryLabel ?? AppLocalizations.of(context).actionRetry),
            ),
          ],
        ],
      ),
    );
  }
}
