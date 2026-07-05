import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/l10n/app_localizations.dart';
class UpcomingAssignmentsWidget extends StatelessWidget {
  final List<TeamsAssignment> assignments;
  final Map<String, String> classNames;
  final DateTime? nowOverride;
  const UpcomingAssignmentsWidget({
    super.key,
    required this.assignments,
    this.classNames = const {},
    this.nowOverride,
  });
  DateTime get _now => nowOverride ?? DateTime.now();
  @override
  Widget build(BuildContext context) {
    final sorted = [...assignments]
      ..sort((a, b) {
        final da = a.dueDateTime, db = b.dueDateTime;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    final l10n = AppLocalizations.of(context);
    return SectionCard(
      title: l10n.widgetAssignmentsTitle,
      subtitle: l10n.widgetAssignmentsSubtitle,
      icon: Icons.assignment_outlined,
      iconColor: NexoTheme.primary,
      child: sorted.isEmpty
          ? const _Empty()
          : Column(
              children: [
                for (var i = 0; i < sorted.length; i++) ...[
                  _AssignmentTile(
                    a: sorted[i],
                    className: classNames[sorted[i].classId] ?? '',
                    now: _now,
                  ),
                  if (i < sorted.length - 1) const Gap(AppSpacing.sm + 2),
                ],
              ],
            ),
    );
  }
}

class _AssignmentTile extends StatelessWidget {
  final TeamsAssignment a;
  final String className;
  final DateTime now;
  const _AssignmentTile({
    required this.a,
    required this.className,
    required this.now,
  });
  @override
  Widget build(BuildContext context) {
    final overdue = a.isOverdue(now);
    final accent = overdue ? NexoTheme.danger : NexoTheme.primary;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                if (className.isNotEmpty) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
                const Gap(AppSpacing.xs),
                Row(
                  children: [
                    Icon(
                      overdue
                          ? Icons.event_busy_outlined
                          : Icons.event_outlined,
                      size: AppIcon.xs,
                      color: accent,
                    ),
                    const Gap.h(AppSpacing.xs),
                    Text(
                      _dueLabel(context),
                      style: TextStyle(
                        fontSize: AppFont.small,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dueLabel(BuildContext context) {
    final due = a.dueDateTime;
    final l10n = AppLocalizations.of(context);
    if (due == null) return l10n.assignmentNoDate;
    final days = a.daysUntilDue(now);
    final date = Fmt.shortDate(due);
    if (days == null) return date;
    if (days < 0) return '${l10n.assignmentOverdue} · $date';
    if (days == 0) return '${l10n.assignmentDueToday} · $date';
    if (days == 1) return '${l10n.assignmentDueTomorrow} · $date';
    return '${l10n.assignmentDueInDays(days)} · $date';
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl + 4),
    alignment: Alignment.center,
    child: Column(
      children: [
        Icon(Icons.task_alt_outlined, size: 36, color: NexoTheme.textSecondary),
        const Gap(AppSpacing.sm),
        Text(
          AppLocalizations.of(context).assignmentEmpty,
          style: TextStyle(
            fontSize: AppFont.body,
            color: NexoTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}
