import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/domain/teacher_insights.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
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
    // Con letra grande el resumen no cabe en el alto por defecto (9/16 de la
    // pantalla): la hoja crece lo necesario y, si aun así no cabe, se desplaza.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xxxl)),
    ),
    builder: (ctx) {
      final l = AppLocalizations.of(ctx);
      return SafeArea(
        child: SingleChildScrollView(
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
                      color: c.withValues(alpha: AppOpacity.tint),
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
                  padding: const EdgeInsets.only(bottom: AppSpacing.tight),
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
    this.margin = const EdgeInsets.fromLTRB(
      AppSpacing.lg,
      AppSpacing.sm,
      AppSpacing.lg,
      0,
    ),
  });
  final Color color;
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.snug,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.soft),
        borderRadius: AppRadii.rLg,
        border: Border.all(color: color.withValues(alpha: AppOpacity.outline)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: AppIcon.lg),
          const Gap.h(AppSpacing.snug),
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
  const TeacherPill({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });
  final String text;
  final Color color;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Motion.of(context, AppDurations.fast),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.tint),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIcon.xs, color: color),
            const Gap.h(AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta del módulo docente. Con [onTap] responde al toque (onda + una
/// leve escala); el borde cambia de color con una transición.
class TeacherCard extends StatelessWidget {
  const TeacherCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.radius = AppRadii.rXl,
    this.borderColor,
    this.emphasized = false,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final BorderRadius radius;
  final Color? borderColor;

  /// Borde más grueso para destacar un estado (modificado, con error…).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: Motion.of(context, AppDurations.fast),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: radius,
        border: Border.all(
          color: borderColor ?? NexoTheme.border,
          width: emphasized ? AppSizes.stroke : 1,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
    return onTap == null ? card : PressScale(child: card);
  }
}

/// Buscador de alumnos con el estilo del módulo.
class TeacherSearchField extends StatelessWidget {
  const TeacherSearchField({
    super.key,
    required this.onChanged,
    this.suffixText,
  });
  final ValueChanged<String> onChanged;
  final String? suffixText;
  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: AppRadii.rLg,
      borderSide: BorderSide(color: c, width: w),
    );
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        isDense: true,
        hintText: AppLocalizations.of(context).docenteSearchStudent,
        prefixIcon: const Icon(Icons.search_rounded, size: AppIcon.lg),
        suffixText: suffixText,
        filled: true,
        fillColor: NexoTheme.card,
        border: border(NexoTheme.border),
        enabledBorder: border(NexoTheme.border),
        focusedBorder: border(NexoTheme.primary, AppSizes.stroke),
      ),
    );
  }
}

/// Agarradera de las hojas inferiores.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: NexoTheme.border,
        borderRadius: AppRadii.rPill,
      ),
      child: const SizedBox(
        width: AppSizes.handleWidth,
        height: AppSizes.handleHeight,
      ),
    ),
  );
}

/// Indicador pequeño: un número grande con su etiqueta debajo.
class TeacherStat extends StatelessWidget {
  const TeacherStat({
    super.key,
    required this.value,
    required this.label,
    required this.color,
  });
  final int value;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedCount(
        value: value,
        style: TextStyle(
          fontSize: AppFont.h3,
          fontWeight: FontWeight.w800,
          color: color,
          height: 1.1,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      const Gap(AppSpacing.xxs),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: AppFont.caption,
          fontWeight: FontWeight.w600,
          color: NexoTheme.textSecondary,
        ),
      ),
    ],
  );
}

/// Color con el que se muestra un porcentaje de asistencia: rojo en riesgo,
/// ámbar por debajo de lo saludable, verde en adelante.
Color attendanceColor(num? percent) {
  if (percent == null) return NexoTheme.textMuted;
  if (percent <= AttendanceRule.riskPercent) return NexoTheme.danger;
  if (percent < AttendanceRule.healthyPercent) return NexoTheme.warning;
  return NexoTheme.success;
}

/// Tramos de una [SplitBar] de asistencia, en el orden de siempre.
List<({int count, Color color})> attendanceParts({
  required int present,
  required int absent,
  required int justified,
}) => [
  (count: present, color: NexoTheme.success),
  (count: justified, color: NexoTheme.warning),
  (count: absent, color: NexoTheme.danger),
];

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

  static const double _size = 46;

  @override
  Widget build(BuildContext context) {
    final btn = PressScale(
      enabled: onTap != null,
      child: AnimatedContainer(
        duration: Motion.of(context, AppDurations.fast),
        curve: Motion.enter,
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0),
          borderRadius: AppRadii.rMd,
          border: Border.all(
            color: selected ? color : NexoTheme.border,
            width: AppSizes.stroke,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.rMd,
            child: Icon(
              icon,
              color: selected
                  ? Colors.white
                  : (onTap == null ? NexoTheme.border : color),
            ),
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
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
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

/// Color de una nota vigesimal: verde si es buena, azul aprobada, rojo desaprobada.
Color gradeColor(String? raw) {
  final n = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  if (n == null) return NexoTheme.textMuted;
  if (n >= PassingRule.goodGrade) return NexoTheme.success;
  if (n >= PassingRule.standard.threshold) return NexoTheme.info;
  return NexoTheme.danger;
}

// ── Cómo se describe una sección, en palabras y no en códigos ─────────────

/// "Sección A1 · Ciclo 4 · Presencial".
String courseFactsLine(AppLocalizations l, TeacherSubject c) => [
  if (c.section.isNotEmpty) l.tchSectionLabel(c.section),
  if (c.ciclo.trim().isNotEmpty) l.tchCycle(c.cycleLabel),
  if (c.modalidad.isNotEmpty) readableName(c.modalidad),
].join(' · ');

/// "Miércoles 10:45–13:00 · Jueves 11:30–13:00" ([short]: "Mié …").
String courseScheduleLine(TeacherSubject c, {bool short = false}) =>
    weeklySlots(c)
        .map((s) {
          final day = Fmt.dayLabel(s.weekday);
          final d = short && day.length > 3 ? day.substring(0, 3) : day;
          return '$d ${s.start}–${s.end}';
        })
        .join(' · ');

/// "Pabellón H · H 302", o solo "Virtual".
String courseRoomLine(TeacherSubject c) {
  final loc = ScheduleClass.parseLocation(c.aula);
  final parts = <String>{
    for (final p in [loc.building, loc.room])
      if (p.trim().isNotEmpty)
        readableName(p.replaceAll('PABELLON', 'PABELLÓN')),
  };
  return parts.join(' · ');
}
