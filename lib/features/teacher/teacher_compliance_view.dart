import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

/// Vista "Por clase" de Marcación: clases programadas de las últimas dos
/// semanas con el estado de la marca de entrada y salida
/// (`Docente/getAsistenciaDiaria`).
class TeacherComplianceView extends StatelessWidget {
  const TeacherComplianceView({
    super.key,
    required this.store,
    required this.toggle,
  });
  final AppStore store;
  final Widget toggle;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = store.teacherCumplimiento;
    final loading = state.loading && !state.hasValue;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    // Los días futuros no aportan nada al historial.
    final items = [...(state.value ?? const <TeacherClassCompliance>[])]
      ..removeWhere((c) => c.date.isAfter(today))
      ..sort((a, b) {
        final d = b.date.compareTo(a.date);
        return d != 0 ? d : a.startTime.compareTo(b.startTime);
      });
    final byDay = <DateTime, List<TeacherClassCompliance>>{};
    for (final c in items) {
      byDay.putIfAbsent(c.date, () => []).add(c);
    }
    final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
    // El resumen solo cuenta jornadas cerradas: hoy aún puede estar en curso.
    final past = items.where((c) => c.date.isBefore(today)).toList();
    final complete = past.where((c) => c.isComplete).length;
    final missing = past.where((c) => c.hasMissing).length;

    return RefreshIndicator(
      onRefresh: () => store.loadTeacherCumplimiento().then((_) {}),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverToBoxAdapter(
            child: PageHeader(
              title: l.titleMarcacion,
              subtitle: loading
                  ? l.docenteLoadingClasses
                  : l.marcacionClassesSubtitle(
                      complete.toString(),
                      past.length.toString(),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: PageBody(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: SizedBox(width: double.infinity, child: toggle),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: PageBody(
              child: loading
                  ? const Column(
                      children: [
                        Skeleton(height: 120, radius: 22),
                        Gap(AppSpacing.md),
                        Skeleton(height: 120, radius: 22),
                      ],
                    )
                  : items.isEmpty
                  ? Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: EmptyState(
                          icon: Icons.event_available_rounded,
                          title: l.marcacionClassesEmpty,
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (missing > 0) ...[
                          _MissingBanner(count: missing),
                          const Gap(AppSpacing.md + 2),
                        ],
                        for (var i = 0; i < days.length; i++) ...[
                          Reveal(
                            index: i,
                            child: _DayCard(
                              day: days[i],
                              items: byDay[days[i]]!,
                              isToday: days[i] == today,
                            ),
                          ),
                          const Gap(AppSpacing.md + 2),
                        ],
                      ],
                    ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<TeacherClassCompliance> items;
  final bool isToday;
  const _DayCard({
    required this.day,
    required this.items,
    required this.isToday,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: Fmt.dayLabel(day.weekday),
      subtitle: Fmt.shortDate(day),
      icon: isToday ? Icons.today_rounded : Icons.event_note_rounded,
      iconColor: isToday ? NexoTheme.primary : NexoTheme.accent,
      trailing: isToday
          ? StatusChip(text: l.detailToday, color: NexoTheme.primary)
          : null,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ClassRow(item: items[i]),
            if (i < items.length - 1) const Gap(AppSpacing.sm + 2),
          ],
        ],
      ),
    );
  }
}

class _MissingBanner extends StatelessWidget {
  final int count;
  const _MissingBanner({required this.count});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: NexoTheme.danger.withValues(alpha: 0.1),
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: NexoTheme.danger),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Text(
              l.marcacionMissingCount(count),
              style: TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.w600,
                color: NexoTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassRow extends StatelessWidget {
  final TeacherClassCompliance item;
  const _ClassRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final meta = [
      if (item.section.isNotEmpty) item.section,
      if (item.modality.isNotEmpty) item.modality,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.startTime,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  item.endTime,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const Gap.h(AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subject,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap.h(AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusPill(label: l.marcacionIn, status: item.start),
              const SizedBox(height: 4),
              _StatusPill(label: l.marcacionOut, status: item.end),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final PunchStatus status;
  const _StatusPill({required this.label, required this.status});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (String text, Color color, IconData icon) = switch (status) {
      PunchStatus.marked => (
        l.marcacionMarked,
        NexoTheme.success,
        Icons.check_rounded,
      ),
      PunchStatus.missing => (
        l.marcacionMissing,
        NexoTheme.danger,
        Icons.close_rounded,
      ),
      PunchStatus.pending => (
        l.marcacionPending,
        NexoTheme.textMuted,
        Icons.schedule_rounded,
      ),
      PunchStatus.unknown => (
        '—',
        NexoTheme.textMuted,
        Icons.help_outline_rounded,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            '$label · $text',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
