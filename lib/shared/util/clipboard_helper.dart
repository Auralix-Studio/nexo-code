import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/core/design/tokens.dart';

abstract final class ClipboardHelper {
  static Future<void> copyAndShow(
    BuildContext context,
    String text, {
    String? label,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    final displayLabel = label ?? text;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.copy_all_rounded,
              color: Colors.white,
              size: AppIcon.lg,
            ),
            const SizedBox(width: AppSpacing.snug),
            Expanded(
              child: Text(
                'Copiado: $displayLabel',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: AppFont.body,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: NexoTheme.primary,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }

  static void showSuccess(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: AppIcon.lg,
            ),
            const SizedBox(width: AppSpacing.snug),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFont.body,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: NexoTheme.success,
        duration: const Duration(seconds: 2),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }

  static void showError(
    BuildContext context,
    Object? error, {
    String? fallback,
  }) {
    final message = error != null
        ? humanizeError(error)
        : (fallback ?? 'Ocurrió un error');
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: AppIcon.lg,
            ),
            const SizedBox(width: AppSpacing.snug),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFont.body,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: NexoTheme.danger,
        duration: const Duration(seconds: 4),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        margin: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }
}
