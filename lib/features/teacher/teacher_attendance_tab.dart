import 'package:flutter/material.dart';
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
  @override
  State<TeacherAttendanceTab> createState() => _TeacherAttendanceTabState();
}

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
      builder: (context, _) {
        final state = widget.store.asistenciaDe(widget.course.id);
        if (state.loading && !state.hasValue) {
          return const TeacherListSkeleton(height: 90);
        }
        if (state.error != null && !state.hasValue) {
          return Center(
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
        final visible = _showAll ? sessions : sessions.take(8).toList();
        return RefreshIndicator(
          onRefresh: () => widget.store.loadDocenteAsistencia(widget.course),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              _TakeCard(
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
              const SizedBox(height: AppSpacing.lg),
              _Kpis(sheet: sheet),
              const SizedBox(height: AppSpacing.xl),
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
                  if (sessions.length > 8)
                    TextButton(
                      onPressed: () => setState(() => _showAll = !_showAll),
                      child: Text(_showAll ? l.tchShowLess : l.tchShowAll),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              if (sessions.isEmpty)
                EmptyState(
                  icon: Icons.event_note_outlined,
                  title: l.docenteReportEmpty,
                )
              else
                for (final d in visible) ...[
                  _SessionTile(
                    session: d,
                    sheet: sheet,
                    unitName: _unitName(_unitOf(sheet, d)),
                    onTap: () => _openSession(d),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          ),
        );
      },
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
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ongoing = course.ongoingBlock(DateTime.now());
    String? todayText;
    if (todaySessions.isNotEmpty) {
      final last = todaySessions.first;
      var p = 0, a = 0;
      for (final s in sheet.students) {
        for (final m in s.marks) {
          if (m.date != last) continue;
          if (m.state == AttendanceCode.present) p++;
          if (m.state == AttendanceCode.absent) a++;
        }
      }
      todayText = l.tchTodayRegistered(
        '${two(last.hour)}:${two(last.minute)}',
        p,
        a,
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_rounded, color: Colors.white),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Text(
                  ongoing != null
                      ? l.tchOngoingNow(ongoing.start, ongoing.end)
                      : l.tchAttTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: AppFont.subtitle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            todayText ?? l.tchTodayNotRegistered,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: AppFont.small,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: NexoTheme.primary,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                  onPressed: onTake,
                  icon: const Icon(Icons.how_to_reg_rounded),
                  label: Text(
                    todaySessions.isEmpty ? l.tchAttTake : l.tchAttTakeAnother,
                  ),
                ),
              ),
              if (onFix != null) ...[
                const SizedBox(width: AppSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white70),
                    minimumSize: const Size(0, 48),
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                  onPressed: onFix,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(l.tchFix),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Kpis extends StatelessWidget {
  final AttendanceSheet sheet;
  const _Kpis({required this.sheet});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = sheet.totals();
    final pct = t.total == 0 ? null : (t.present * 100 / t.total).round();
    Widget kpi(String value, String label, Color color) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: NexoTheme.card,
          borderRadius: AppRadii.rLg,
          border: Border.all(color: NexoTheme.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: AppFont.h3,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            kpi(pct == null ? '—' : '$pct%', l.tchKpiGeneral, NexoTheme.info),
            const SizedBox(width: 6),
            kpi('${t.present}', l.tchKpiPresent, NexoTheme.success),
            const SizedBox(width: 6),
            kpi('${t.absent}', l.tchKpiAbsent, NexoTheme.danger),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            kpi('${t.justified}', l.tchKpiJustified, NexoTheme.warning),
            const SizedBox(width: 6),
            kpi('${t.total}', l.tchKpiTotal, NexoTheme.textSecondary),
            const SizedBox(width: 6),
            kpi(
              '${sheet.students.where((s) => s.atRisk).length}',
              l.docenteReportAtRisk,
              NexoTheme.danger,
            ),
          ],
        ),
      ],
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DateTime session;
  final AttendanceSheet sheet;
  final String unitName;
  final VoidCallback onTap;
  const _SessionTile({
    required this.session,
    required this.sheet,
    required this.unitName,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    var p = 0, a = 0, j = 0;
    for (final s in sheet.students) {
      for (final m in s.marks) {
        if (m.date != session) continue;
        if (m.state == AttendanceCode.present) p++;
        if (m.state == AttendanceCode.absent) a++;
        if (m.state == AttendanceCode.justified) j++;
      }
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: NexoTheme.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadii.rMd,
                ),
                child: Column(
                  children: [
                    Text(
                      '${session.day}',
                      style: TextStyle(
                        fontSize: AppFont.h3,
                        fontWeight: FontWeight.w900,
                        color: NexoTheme.primary,
                        height: 1,
                      ),
                    ),
                    Text(
                      Fmt.dayLabel(session.weekday).substring(0, 3),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.shortDate(session)} · '
                      '${two(session.hour)}:${two(session.minute)}',
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (unitName.isNotEmpty)
                      Text(
                        unitName,
                        style: TextStyle(
                          fontSize: 11,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: [
                        TeacherPill(text: '✓ $p', color: NexoTheme.success),
                        TeacherPill(text: '✕ $a', color: NexoTheme.danger),
                        if (j > 0)
                          TeacherPill(text: 'J $j', color: NexoTheme.warning),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: NexoTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
