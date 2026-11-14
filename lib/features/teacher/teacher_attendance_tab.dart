import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_session_edit.dart';
import 'package:nexo/features/teacher/teacher_take_attendance.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/progress_ring.dart';
import 'package:nexo/shared/widgets/reveal.dart';

/// Pestaña Asistencia del curso: tomar asistencia, estado de hoy, indicadores
/// (los mismos 5 de SIGMA) e historial de sesiones con corrección.
class TeacherAttendanceTab extends StatefulWidget {
  const TeacherAttendanceTab({
    super.key,
    required this.store,
    required this.course,
  });
  final AppStore store;
  final TeacherSubject course;

  /// Sesiones que se listan antes de pedir "ver todas".
  static const int recentSessions = 8;

  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

/// Conteo de marcas de una sesión.
typedef _SessionCounts = ({int present, int absent, int justified});

_SessionCounts _countsOf(AttendanceSheet sheet, DateTime session) {
  var p = 0, a = 0, j = 0;
  for (final s in sheet.students) {
    for (final m in s.marks) {
      if (m.date != session) continue;
      if (m.state == AttendanceCode.present) p++;
      if (m.state == AttendanceCode.absent) a++;
      if (m.state == AttendanceCode.justified) j++;
    }
  }
  return (present: p, absent: a, justified: j);
}

String _hm(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

class _TeacherAttendanceTabState extends State<TeacherAttendanceTab>
    with AutomaticKeepAliveClientMixin {
  List<TeacherUnitCatalog> _units = const [];
  bool _showAll = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.store
        .docenteUnidadesAsistencia(widget.course)
        .then((u) {
          if (mounted) setState(() => _units = u);
        })
        .catchError((_) {});
  }

  bool _unitEnabled(int id) => _units.any((u) => u.id == id && u.enabled);

  String _unitName(int id) =>
      _units.where((u) => u.id == id).firstOrNull?.name ?? '';

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => FadeSwitch(child: _content(context, l)),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l) {
    final state = widget.store.asistenciaDe(widget.course.id);
    if (state.loading && !state.hasValue) {
      return const TeacherListSkeleton(key: ValueKey('loading'), height: 90);
    }
    if (state.error != null && !state.hasValue) {
      return Center(
        key: const ValueKey('error'),
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.tchAttLoadError,
          subtitle: humanizeError(state.error),
          color: NexoTheme.danger,
          onRetry: () => widget.store.loadDocenteAsistencia(widget.course),
        ),
      );
    }
    final sheet = state.value ?? const AttendanceSheet([]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessions = sheet.sessions().reversed.toList();
    final todaySessions = sessions
        .where((d) => DateTime(d.year, d.month, d.day) == today)
        .toList();
    const recent = TeacherAttendanceTab.recentSessions;
    final visible = _showAll ? sessions : sessions.take(recent).toList();
    return RefreshIndicator(
      key: const ValueKey('data'),
      onRefresh: () => widget.store.loadDocenteAsistencia(widget.course),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Reveal.list(
            child: _TakeCard(
              course: widget.course,
              todaySessions: todaySessions,
              sheet: sheet,
              onTake: () => TeacherTakeAttendanceScreen.open(
                context,
                store: widget.store,
                course: widget.course,
              ),
              onFix: todaySessions.isEmpty
                  ? null
                  : () => _openSession(todaySessions.first),
            ),
          ),
          const Gap(AppSpacing.md),
          Reveal.list(index: 1, child: _Summary(sheet: sheet)),
          const Gap(AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.tchSessionsTitle(sessions.length),
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
              ),
              if (sessions.length > recent)
                TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(_showAll ? l.tchShowLess : l.tchShowAll),
                ),
            ],
          ),
          const Gap(AppSpacing.sm),
          if (sessions.isEmpty)
            EmptyState(
              icon: Icons.event_note_outlined,
              title: l.docenteReportEmpty,
            )
          else
            for (final (i, d) in visible.indexed)
              Padding(
                key: ValueKey(d),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Reveal.list(
                  index: i + 2,
                  child: _SessionTile(
                    session: d,
                    counts: _countsOf(sheet, d),
                    unitName: _unitName(_unitOf(sheet, d)),
                    onTap: () => _openSession(d),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  int _unitOf(AttendanceSheet sheet, DateTime session) {
    for (final s in sheet.students) {
      for (final m in s.marks) {
        if (m.date == session) return m.tipoUnidadId;
      }
    }
    return 0;
  }

  void _openSession(DateTime session) {
    final sheet = widget.store.asistenciaDe(widget.course.id).value;
    final unit = sheet == null ? 0 : _unitOf(sheet, session);
    TeacherSessionEditScreen.open(
      context,
      store: widget.store,
      course: widget.course,
      session: session,
      editable: _unitEnabled(unit),
    );
  }
}

/// Llamado a la acción principal: tomar la asistencia de hoy.
class _TakeCard extends StatelessWidget {
  final TeacherSubject course;
  final List<DateTime> todaySessions;
  final AttendanceSheet sheet;
  final VoidCallback onTake;
  final VoidCallback? onFix;
  const _TakeCard({
    required this.course,
    required this.todaySessions,
    required this.sheet,
    required this.onTake,
    required this.onFix,
  });

  static const Color _onColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ongoing = course.ongoingBlock(DateTime.now());
    String? todayText;
    if (todaySessions.isNotEmpty) {
      final last = todaySessions.first;
      final c = _countsOf(sheet, last);
      todayText = l.tchTodayRegistered(_hm(last), c.present, c.absent);
    }
    const labelStyle = TextStyle(fontWeight: FontWeight.w700);
    const shape = RoundedRectangleBorder(borderRadius: AppRadii.rMd);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rXxl,
        boxShadow: [
          BoxShadow(
            color: NexoTheme.primary.withValues(alpha: AppOpacity.glow),
            blurRadius: AppSpacing.xl,
            offset: const Offset(0, AppSpacing.sm),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (ongoing != null)
                  const PulseDot(color: _onColor)
                else
                  const Icon(Icons.fact_check_rounded, color: _onColor),
                const Gap.h(AppSpacing.sm),
                Expanded(
                  child: Text(
                    ongoing != null
                        ? l.tchOngoingNow(ongoing.start, ongoing.end)
                        : l.tchAttTodayTitle,
                    style: const TextStyle(
                      color: _onColor,
                      fontWeight: FontWeight.w800,
                      fontSize: AppFont.subtitle,
                    ),
                  ),
                ),
              ],
            ),
            const Gap(AppSpacing.xs),
            Text(
              todayText ?? l.tchTodayNotRegistered,
              style: TextStyle(
                color: _onColor.withValues(alpha: AppOpacity.onColor),
                fontSize: AppFont.small,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: PressScale(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSizes.touch),
                        backgroundColor: _onColor,
                        foregroundColor: NexoTheme.primary,
                        shape: shape,
                      ),
                      onPressed: onTake,
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: Text(
                        todaySessions.isEmpty
                            ? l.tchAttTake
                            : l.tchAttTakeAnother,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ),
                if (onFix != null) ...[
                  const Gap.h(AppSpacing.sm),
                  PressScale(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.touch),
                        foregroundColor: _onColor,
                        side: BorderSide(
                          color: _onColor.withValues(alpha: AppOpacity.onColor),
                        ),
                        shape: shape,
                      ),
                      onPressed: onFix,
                      icon: const Icon(Icons.edit_rounded, size: AppIcon.md),
                      label: Text(
                        l.tchFix,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: labelStyle,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Resumen de asistencia de la sección: porcentaje general en un anillo, el
/// reparto en una barra y los indicadores de SIGMA debajo.
class _Summary extends StatelessWidget {
  final AttendanceSheet sheet;
  const _Summary({required this.sheet});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = sheet.totals();
    final pct = t.total == 0 ? null : (t.present * 100 / t.total).round();
    final risk = sheet.students.where((s) => s.atRisk).length;
    return TeacherCard(
      radius: AppRadii.rXxl,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(percent: pct, color: attendanceColor(pct)),
              const Gap.h(AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.tchKpiGeneral,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    const Gap(AppSpacing.xs),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        TeacherPill(
                          icon: Icons.checklist_rounded,
                          text: '${t.total} ${l.tchKpiTotal}',
                          color: NexoTheme.textSecondary,
                        ),
                        if (risk > 0)
                          TeacherPill(
                            icon: Icons.warning_amber_rounded,
                            text: '$risk ${l.docenteReportAtRisk}',
                            color: NexoTheme.danger,
                          ),
                      ],
                    ),
                    const Gap(AppSpacing.md),
                    SplitBar(
                      parts: attendanceParts(
                        present: t.present,
                        absent: t.absent,
                        justified: t.justified,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TeacherStat(
                  value: t.present,
                  label: l.tchKpiPresent,
                  color: NexoTheme.success,
                ),
              ),
              Expanded(
                child: TeacherStat(
                  value: t.justified,
                  label: l.tchKpiJustified,
                  color: NexoTheme.warning,
                ),
              ),
              Expanded(
                child: TeacherStat(
                  value: t.absent,
                  label: l.tchKpiAbsent,
                  color: NexoTheme.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DateTime session;
  final _SessionCounts counts;
  final String unitName;
  final VoidCallback onTap;
  const _SessionTile({
    required this.session,
    required this.counts,
    required this.unitName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dayName = Fmt.dayLabel(session.weekday);
    final states = [
      (AttendanceCode.present, counts.present),
      (AttendanceCode.justified, counts.justified),
      (AttendanceCode.absent, counts.absent),
    ];
    return TeacherCard(
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: NexoTheme.softOf(NexoTheme.primary),
                  borderRadius: AppRadii.rMd,
                ),
                child: SizedBox.square(
                  dimension: AppSizes.badge,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxs),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${session.day}',
                            style: TextStyle(
                              fontSize: AppFont.title,
                              fontWeight: FontWeight.w800,
                              color: NexoTheme.textPrimary,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            Fmt.monthLabel(session.month).toUpperCase(),
                            style: TextStyle(
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.w700,
                              color: NexoTheme.primary,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayName · ${_hm(session)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (unitName.isNotEmpty) ...[
                      const Gap(AppSpacing.xxs),
                      Text(
                        unitName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.w600,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    ],
                    const Gap(AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final (state, count) in states)
                          if (count > 0 || state != AttendanceCode.justified)
                            Builder(
                              builder: (context) {
                                final look = attendanceLook(context, state);
                                return Tooltip(
                                  message: look.label,
                                  child: TeacherPill(
                                    icon: look.icon,
                                    text: '$count',
                                    color: look.color,
                                  ),
                                );
                              },
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              const Gap.h(AppSpacing.sm),
              Icon(
                Icons.chevron_right_rounded,
                color: NexoTheme.textMuted,
                size: AppIcon.lg,
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          SplitBar(
            height: AppSizes.handleHeight,
            parts: attendanceParts(
              present: counts.present,
              absent: counts.absent,
              justified: counts.justified,
            ),
          ),
        ],
      ),
    );
  }
}
