import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/skeleton.dart';

/// Piezas visuales compartidas por las pantallas del módulo docente.

String two(int v) => v.toString().padLeft(2, '0');

extension TeacherStringX on String {
  String ifBlank(String fallback) => trim().isEmpty ? fallback : this;
}

/// Confirmación antes de escribir en SIGMA. Muestra un resumen de lo que se
/// va a guardar para que el docente lo revise.
Future<bool?> showTeacherConfirm(
  BuildContext context, {
  required String title,
  required IconData icon,
  required List<String> lines,
  required String confirm,
  Color? color,
}) {
  final c = color ?? NexoTheme.primary;
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: NexoTheme.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            0,
            AppSpacing.xl,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.12),
                      borderRadius: AppRadii.rMd,
                    ),
                    child: Icon(icon, color: c),
                  ),
                  const Gap.h(AppSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFont.h3,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      color: NexoTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rLg,
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text(l.actionCancel),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: c,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rLg,
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: Text(confirm),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class TeacherBanner extends StatelessWidget {
  const TeacherBanner({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.action,
    this.onAction,
  });
  final Color color;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: AppRadii.rLg,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const Gap.h(AppSpacing.sm + 2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.w600,
                color: NexoTheme.textPrimary,
                height: 1.3,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class TeacherPill extends StatelessWidget {
  const TeacherPill({super.key, required this.text, required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

/// Botón cuadrado de estado (asistió / faltó / justificado) con área táctil
/// amplia para usar con el pulgar.
class AttendanceToggle extends StatelessWidget {
  const AttendanceToggle({
    super.key,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
    this.tooltip,
  });
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback? onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final btn = Material(
      color: selected ? color : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rMd,
        side: BorderSide(
          color: selected ? color : NexoTheme.border,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            color: selected
                ? Colors.white
                : (onTap == null ? NexoTheme.border : color),
          ),
        ),
      ),
    );
    return tooltip == null ? btn : Tooltip(message: tooltip!, child: btn);
  }
}

class TeacherListSkeleton extends StatelessWidget {
  const TeacherListSkeleton({super.key, this.count = 6, this.height = 64});
  final int count;
  final double height;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => Skeleton(height: height, radius: 14),
    );
  }
}

/// Etiqueta y color de un estado de asistencia de SIGMA.
({String label, Color color, IconData icon}) attendanceLook(
  BuildContext context,
  int state,
) {
  final l = AppLocalizations.of(context);
  return switch (state) {
    1 => (
      label: l.tchStatePresent,
      color: NexoTheme.success,
      icon: Icons.check_rounded,
    ),
    2 => (
      label: l.tchStateAbsent,
      color: NexoTheme.danger,
      icon: Icons.close_rounded,
    ),
    3 => (
      label: l.tchStateJustified,
      color: NexoTheme.warning,
      icon: Icons.assignment_turned_in_rounded,
    ),
    4 => (
      label: l.tchStateSuspended,
      color: NexoTheme.info,
      icon: Icons.block_rounded,
    ),
    _ => (
      label: l.tchStateNone,
      color: NexoTheme.textMuted,
      icon: Icons.remove_rounded,
    ),
  };
}

/// Color de una nota vigesimal: verde ≥ 14, azul aprobada, rojo desaprobada.
Color gradeColor(String? raw) {
  final n = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= PassingRule.standard.threshold) return NexoTheme.info;
  return NexoTheme.danger;
}
