import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/core/design/tokens.dart';

Future<bool> showLogoutConfirm(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
    builder: (ctx) => Dialog(
      constraints: const BoxConstraints(maxWidth: 380),
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xxl,
      ),
      backgroundColor: NexoTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rXxxl,
        side: BorderSide(color: NexoTheme.border),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: NexoTheme.danger.withValues(alpha: AppOpacity.tint),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: NexoTheme.danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                l.logoutConfirmTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFont.h3,
                  fontWeight: FontWeight.w800,
                  color: NexoTheme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: AppSpacing.snug),
              Text(
                l.logoutConfirmBody,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFont.body,
                  color: NexoTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.cozy,
                        ),
                        side: BorderSide(color: NexoTheme.border),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rMd,
                        ),
                      ),
                      child: Text(
                        l.actionCancel,
                        style: TextStyle(
                          color: NexoTheme.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: NexoTheme.danger,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.cozy,
                        ),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rMd,
                        ),
                      ),
                      child: Text(
                        l.actionLogout,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok == true;
}
