import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

/// Reportes de la sección, equivalentes a "Asistencia › Reporte" y
/// "Notas › Reporte" de SIGMA, calculados sobre los mismos datos.
class TeacherReportTab extends StatefulWidget {
  const TeacherReportTab({
    super.key,
    required this.store,
    required this.course,
  });
  final AppStore store;
  final TeacherSubject course;
  @override
  State<TeacherReportTab> createState() => _TeacherReportTabState();
}

class _TeacherReportTabState extends State<TeacherReportTab>
    with AutomaticKeepAliveClientMixin {
  bool _grades = false;
  bool _onlyRisk = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final roster =
            widget.store.alumnosDe(widget.course.id).value ??
            const <TeacherStudent>[];
        final sheet =
            widget.store.asistenciaDe(widget.course.id).value ??
            const AttendanceSheet([]);
        final rows = _rows(roster, sheet);
        final shown = _onlyRisk ? rows.where((r) => r.risk).toList() : rows;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: Text(l.docenteTabAsistencia),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.grading_rounded, size: 18),
                  label: Text(l.docenteTabNotas),
                ),
              ],
              selected: {_grades},
              onSelectionChanged: (v) => setState(() {
                _grades = v.first;
                _onlyRisk = false;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            FadeSwitch(
              child: _grades
                  ? _GradesSummary(
                      key: const ValueKey('grades'),
                      roster: roster,
                    )
                  : _AttendanceSummary(
                      key: const ValueKey('attendance'),
                      sheet: sheet,
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l.docenteReportAll),
                  selected: !_onlyRisk,
                  onSelected: (_) => setState(() => _onlyRisk = false),
                ),
                ChoiceChip(
                  label: Text(
                    '${_grades ? l.tchFailing : l.docenteReportAtRisk} '
                    '(${rows.where((r) => _grades ? r.failing : r.atRiskAtt).length})',
                  ),
                  selected: _onlyRisk,
                  onSelected: (_) => setState(() => _onlyRisk = true),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (roster.isEmpty && sheet.students.isEmpty)
              EmptyState(
                icon: Icons.groups_outlined,
                title: l.docenteNoAlumnosInCourse,
              )
            else
              for (final r in _sorted(shown)) ...[
                _RowTile(
                  row: r,
                  grades: _grades,
                  onTap: r.student == null
                      ? null
                      : () => showTeacherStudentSheet(
                          context: context,
                          store: widget.store,
                          course: widget.course,
                          student: r.student!,
                          initialTab: _grades ? 0 : 1,
                        ),
                ),
                const SizedBox(height: 8),
              ],
          ],
        );
      },
    );
  }

  List<_Row> _rows(List<TeacherStudent> roster, AttendanceSheet sheet) {
    final byCode = {for (final s in sheet.students) s.code: s};
    final out = <_Row>[];
    final seen = <String>{};
    for (final s in roster) {
      seen.add(s.code);
      out.add(_Row(student: s, att: byCode[s.code], grades: _grades));
    }
    for (final a in sheet.students) {
      if (seen.contains(a.code)) continue;
      out.add(_Row(student: null, att: a, grades: _grades));
    }
    return out;
  }

  List<_Row> _sorted(List<_Row> rows) => [...rows]
    ..sort((a, b) {
      if (a.risk != b.risk) return a.risk ? -1 : 1;
      return a.name.compareTo(b.name);
    });
}

class _Row {
  final TeacherStudent? student;
  final AttendanceStudent? att;
  final bool grades;
  _Row({required this.student, required this.att, required this.grades});

  String get name => student?.displayName ?? att?.name ?? '';
  String get code => student?.code ?? att?.code ?? '';
  double? get grade =>
      double.tryParse((student?.grade ?? '').replaceAll(',', '.'));
  bool get hasGrade => grade != null && grade! > 0;
  bool get failing => hasGrade && !PassingRule.standard.passes(grade);
  double? get percent =>
      att?.percent ?? double.tryParse(student?.attendance ?? '');
  bool get atRiskAtt => percent != null && percent! <= 70;
  bool get risk => grades ? failing : atRiskAtt;
}

class _AttendanceSummary extends StatelessWidget {
  final AttendanceSheet sheet;
  const _AttendanceSummary({super.key, required this.sheet});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final t = sheet.totals();
    final sessions = sheet.sessions().length;
    final pct = t.total == 0 ? null : t.present * 100 / t.total;
    return _SummaryCard(
      cells: [
        ('$sessions', l.docenteReportSessions, NexoTheme.primary),
        (
          pct == null ? '—' : '${pct.round()}%',
          l.docenteReportAverage,
          NexoTheme.success,
        ),
        (
          '${sheet.students.where((s) => s.atRisk).length}',
          l.docenteReportAtRisk,
          NexoTheme.danger,
        ),
      ],
      hint: l.tchRiskHint70,
    );
  }
}

class _GradesSummary extends StatelessWidget {
  final List<TeacherStudent> roster;
  const _GradesSummary({super.key, required this.roster});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final grades = [
      for (final s in roster)
        double.tryParse((s.grade ?? '').replaceAll(',', '.')),
    ].whereType<double>().where((g) => g > 0).toList();
    final passed = grades.where(PassingRule.standard.passes).length;
    final avg = grades.isEmpty
        ? null
        : grades.reduce((a, b) => a + b) / grades.length;
    // Distribución en tramos vigesimales.
    const buckets = [(0, 5), (6, 10), (11, 13), (14, 16), (17, 20)];
    final counts = [
      for (final b in buckets)
        grades.where((g) => g.round() >= b.$1 && g.round() <= b.$2).length,
    ];
    final maxCount = counts.fold<int>(1, (a, b) => b > a ? b : a);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SummaryCard(
          cells: [
            (
              avg == null ? '—' : avg.toStringAsFixed(1),
              l.tchAverage,
              gradeColor(avg?.toStringAsFixed(1)),
            ),
            ('$passed', l.tchPassed, NexoTheme.success),
            ('${grades.length - passed}', l.tchFailing, NexoTheme.danger),
          ],
          hint: l.tchGradesHint(roster.length - grades.length),
        ),
        if (grades.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: NexoTheme.card,
              borderRadius: AppRadii.rXl,
              border: Border.all(color: NexoTheme.border),
            ),
            child: SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < buckets.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              '${counts[i]}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: NexoTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              height: 70 * counts[i] / maxCount + 2,
                              decoration: BoxDecoration(
                                color: gradeColor('${buckets[i].$2}'),
                                borderRadius: AppRadii.rSm,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${buckets[i].$1}–${buckets[i].$2}',
                              style: TextStyle(
                                fontSize: 10,
                                color: NexoTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<(String, String, Color)> cells;
  final String hint;
  const _SummaryCard({required this.cells, required this.hint});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (final c in cells)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.$1,
                        style: TextStyle(
                          fontSize: AppFont.h3,
                          fontWeight: FontWeight.w900,
                          color: c.$3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        c.$2,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: NexoTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            hint,
            style: TextStyle(fontSize: 11, color: NexoTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final _Row row;
  final bool grades;
  final VoidCallback? onTap;
  const _RowTile({required this.row, required this.grades, this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final String value;
    final Color color;
    final double? progress;
    final String detail;
    if (grades) {
      final g = row.grade;
      value = row.hasGrade ? g!.toStringAsFixed(g % 1 == 0 ? 0 : 1) : '—';
      color = row.hasGrade ? gradeColor('$g') : NexoTheme.textMuted;
      progress = row.hasGrade ? g! / 20 : null;
      detail = row.hasGrade
          ? (row.failing ? l.tchFailing : l.tchPassed)
          : l.docenteEvalPending;
    } else {
      final p = row.percent;
      value = p == null ? '—' : '${p.round()}%';
      color = p == null
          ? NexoTheme.textMuted
          : row.atRiskAtt
          ? NexoTheme.danger
          : p < 85
          ? NexoTheme.warning
          : NexoTheme.success;
      progress = p == null ? null : p / 100;
      final a = row.att;
      var pr = 0, ab = 0, j = 0;
      for (final m in a?.marks ?? const <AttendanceMark>[]) {
        if (m.state == AttendanceCode.present) pr++;
        if (m.state == AttendanceCode.absent) ab++;
        if (m.state == AttendanceCode.justified) j++;
      }
      detail = l.docenteReportCounts('$pr', '$ab', '$j');
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
            border: Border.all(
              color: row.risk
                  ? NexoTheme.danger.withValues(alpha: 0.5)
                  : NexoTheme.border,
            ),
          ),
          child: Row(
            children: [
              StudentAvatar(code: row.code, name: row.name, size: 40),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: AppRadii.rPill,
                      child: LinearProgressIndicator(
                        value: progress ?? 0,
                        minHeight: 5,
                        backgroundColor: NexoTheme.border,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.h(AppSpacing.md),
              Text(
                value,
                style: TextStyle(
                  fontSize: AppFont.subtitle,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
