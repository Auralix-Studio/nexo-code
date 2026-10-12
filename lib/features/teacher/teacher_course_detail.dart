import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/course_roster_stats.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/features/reports/pdf_export.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/skeleton.dart';

class TeacherCourseDetailScreen extends StatefulWidget {
  const TeacherCourseDetailScreen({
    super.key,
    required this.store,
    required this.course,
  });
  final AppStore store;
  final TeacherSubject course;
  @override
  State<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState extends State<TeacherCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    if (!widget.store.alumnosDe(widget.course.id).hasValue) _reload();
  }

  Future<void> _reload() => widget.store.loadDocenteAlumnos(
    widget.course.id,
    tipoCalif: widget.course.tipoCalif,
  );

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      await PdfExport.courseRoster(context, widget.store, widget.course);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(
        title: Text(
          widget.course.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          ListenableBuilder(
            listenable: widget.store,
            builder: (context, _) {
              final hasRoster =
                  widget.store.alumnosDe(widget.course.id).hasValue;
              return IconButton(
                tooltip: l.docenteExportPdf,
                onPressed: hasRoster && !_exporting ? _export : null,
                icon: _exporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final state = widget.store.alumnosDe(widget.course.id);
            return Column(
              children: [
                _Header(
                  course: widget.course,
                  rosterCount: state.value?.length,
                ),
                ColoredBox(
                  color: NexoTheme.surface,
                  child: TabBar(
                    controller: _tabs,
                    tabs: [
                      Tab(text: l.docenteTabResumen),
                      Tab(text: l.docenteTabAlumnos),
                      Tab(text: l.docenteTabAsistencia),
                      Tab(text: l.docenteTabNotas),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      _ResumenTab(
                        store: widget.store,
                        course: widget.course,
                        onRefresh: _reload,
                      ),
                      _RosterTab(
                        store: widget.store,
                        course: widget.course,
                        onRefresh: _reload,
                        mode: _RosterMode.alumnos,
                      ),
                      _AsistenciaTab(
                        store: widget.store,
                        course: widget.course,
                      ),
                      _RosterTab(
                        store: widget.store,
                        course: widget.course,
                        onRefresh: _reload,
                        mode: _RosterMode.notas,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TeacherSubject course;

  /// Tamaño real del roster cuando ya se cargó. SIGMA no siempre manda
  /// `matriculados` en la asignatura, y sin esto se mostraba "0 alumnos".
  final int? rosterCount;
  const _Header({required this.course, this.rosterCount});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final count = rosterCount ?? course.enrolledCount ?? 0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      color: NexoTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.code.isEmpty ? l.docenteNoCode : course.code,
                  style: TextStyle(
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  l.docenteSectionPeriod(course.section, course.periodo),
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _Pill(
            text: l.docenteMetricAlumnosCount(count),
            color: NexoTheme.primary,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const _Pill({required this.text, required this.color, this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppIcon.xs, color: color),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Resumen ────────────────────────────────────────────────────────────────

class _ResumenTab extends StatelessWidget {
  final AppStore store;
  final TeacherSubject course;
  final Future<void> Function() onRefresh;
  const _ResumenTab({
    required this.store,
    required this.course,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = store.alumnosDe(course.id);
    if (state.loading && !state.hasValue) return const _SkeletonList();
    final alumnos = state.value ?? const <TeacherStudent>[];
    if (alumnos.isEmpty) {
      return _RosterEmptyOrError(
        error: state.error,
        emptyTitle: l.docenteNoAlumnosInCourse,
        onRetry: onRefresh,
      );
    }
    final stats = CourseRosterStats.from(alumnos);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _AverageCard(stats: stats),
          const SizedBox(height: AppSpacing.md),
          _CountsRow(stats: stats),
          const SizedBox(height: AppSpacing.lg),
          _DistributionCard(stats: stats),
          const SizedBox(height: AppSpacing.lg),
          _AtRiskCard(store: store, course: course, stats: stats),
        ],
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  final CourseRosterStats stats;
  const _AverageCard({required this.stats});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final avg = stats.average;
    final color = avg == null
        ? NexoTheme.textMuted
        : gradeColor(avg.toStringAsFixed(2));
    final asis = stats.attendanceAverage;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.docenteStatAverage.toUpperCase(),
                  style: TextStyle(
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  avg == null ? '—' : avg.toStringAsFixed(2),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          if (asis != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${asis.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: AppFont.h2,
                    fontWeight: FontWeight.w800,
                    color: asis < CourseRosterStats.attendanceThreshold
                        ? NexoTheme.danger
                        : NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  l.docenteStatAttendanceAvg,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CountsRow extends StatelessWidget {
  final CourseRosterStats stats;
  const _CountsRow({required this.stats});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _CountTile(
            value: stats.approved,
            label: l.docenteStatApproved,
            color: NexoTheme.success,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CountTile(
            value: stats.failed,
            label: l.docenteStatFailed,
            color: NexoTheme.danger,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _CountTile(
            value: stats.noGrade,
            label: l.docenteStatNoGrade,
            color: NexoTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _CountTile({
    required this.value,
    required this.label,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: AppFont.h2,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1.1,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  final CourseRosterStats stats;
  const _DistributionCard({required this.stats});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final threshold = PassingRule.standard.threshold;
    final labels = [
      '0 – ${(threshold - 0.1).toStringAsFixed(1)}',
      '${threshold.toStringAsFixed(1)} – 13.9',
      '14 – 16.9',
      '17 – 20',
    ];
    final colors = [
      NexoTheme.danger,
      NexoTheme.info,
      NexoTheme.success,
      NexoTheme.success,
    ];
    final maxCount = stats.buckets.fold<int>(0, (a, b) => a > b ? a : b);
    return _Section(
      title: l.docenteGradeDistribution,
      subtitle: l.docenteGradeDistributionHint,
      child: Column(
        children: [
          for (var i = 0; i < 4; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: _BarRow(
                label: labels[i],
                count: stats.buckets[i],
                fraction: maxCount == 0 ? 0 : stats.buckets[i] / maxCount,
                color: colors[i],
              ),
            ),
        ],
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final int count;
  final double fraction;
  final Color color;
  const _BarRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $count',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.rXs,
              child: Stack(
                children: [
                  Container(height: 12, color: NexoTheme.border),
                  FractionallySizedBox(
                    widthFactor: fraction.clamp(0, 1),
                    child: Container(
                      height: 12,
                      color: color.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$count',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.w800,
                color: NexoTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AtRiskCard extends StatelessWidget {
  final AppStore store;
  final TeacherSubject course;
  final CourseRosterStats stats;
  const _AtRiskCard({
    required this.store,
    required this.course,
    required this.stats,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _Section(
      title: l.docenteAtRiskTitle,
      subtitle: l.docenteAtRiskSubtitle(
        CourseRosterStats.attendanceThreshold.toStringAsFixed(0),
      ),
      trailing: stats.atRisk.isEmpty
          ? null
          : _Pill(
              text: '${stats.atRisk.length}',
              color: NexoTheme.danger,
              icon: Icons.warning_amber_rounded,
            ),
      child: stats.atRisk.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: NexoTheme.success,
                    size: AppIcon.lg,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.docenteAtRiskNone,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        color: NexoTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final r in stats.atRisk)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: _AlumnoTile(
                      student: r.student,
                      reasons: r.reasons,
                      onTap: () => showTeacherStudentSheet(
                        context: context,
                        store: store,
                        course: course,
                        student: r.student,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  const _Section({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

// ── Alumnos / Notas ───────────────────────────────────────────────────────

enum _RosterMode { alumnos, notas }

class _RosterTab extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  final Future<void> Function() onRefresh;
  final _RosterMode mode;
  const _RosterTab({
    required this.store,
    required this.course,
    required this.onRefresh,
    required this.mode,
  });
  @override
  State<_RosterTab> createState() => _RosterTabState();
}

class _RosterTabState extends State<_RosterTab>
    with AutomaticKeepAliveClientMixin {
  String _q = '';
  late RosterSort _sort = widget.mode == _RosterMode.notas
      ? RosterSort.gradeAsc
      : RosterSort.name;
  bool _onlyRisk = false;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final state = widget.store.alumnosDe(widget.course.id);
    if (state.loading && !state.hasValue) return const _SkeletonList();
    final alumnos = state.value ?? const <TeacherStudent>[];
    if (alumnos.isEmpty) {
      return _RosterEmptyOrError(
        error: state.error,
        emptyTitle: widget.mode == _RosterMode.notas
            ? l.docenteNoAlumnosInCourse
            : l.docenteNoAlumnosRegistered,
        onRetry: widget.onRefresh,
      );
    }
    final stats = CourseRosterStats.from(alumnos);
    final riskByCode = {
      for (final r in stats.atRisk) r.student.code: r.reasons,
    };
    final filtered = CourseRosterStats.sorted(
      alumnos.where(
        (a) =>
            _matchesQuery(a, _q) &&
            (!_onlyRisk || riskByCode.containsKey(a.code)),
      ),
      _sort,
    );
    return Column(
      children: [
        if (widget.mode == _RosterMode.notas)
          _NotasHeader(approved: stats.approved, total: stats.total),
        _StudentSearchField(
          count: filtered.length,
          onChanged: (v) => setState(() => _q = v),
        ),
        _ListControls(
          sort: _sort,
          onlyRisk: _onlyRisk,
          riskCount: stats.atRisk.length,
          onSort: (s) => setState(() => _sort = s),
          onOnlyRisk: (v) => setState(() => _onlyRisk = v),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filtered.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: Icons.search_off_rounded,
                        title: l.docenteSearchNoResults,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (_, i) {
                      final a = filtered[i];
                      return _AlumnoTile(
                        student: a,
                        reasons: riskByCode[a.code] ?? const {},
                        onTap: () => showTeacherStudentSheet(
                          context: context,
                          store: widget.store,
                          course: widget.course,
                          student: a,
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _NotasHeader extends StatelessWidget {
  final int approved;
  final int total;
  const _NotasHeader({required this.approved, required this.total});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l.docenteAprobadosCount(approved.toString(), total.toString()),
              style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textSecondary,
              ),
            ),
          ),
          Text(
            l.docenteTapToEdit,
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListControls extends StatelessWidget {
  final RosterSort sort;
  final bool onlyRisk;
  final int riskCount;
  final ValueChanged<RosterSort> onSort;
  final ValueChanged<bool> onOnlyRisk;
  const _ListControls({
    required this.sort,
    required this.onlyRisk,
    required this.riskCount,
    required this.onSort,
    required this.onOnlyRisk,
  });

  String _label(AppLocalizations l, RosterSort s) => switch (s) {
    RosterSort.name => l.docenteSortName,
    RosterSort.gradeDesc => l.docenteSortGradeDesc,
    RosterSort.gradeAsc => l.docenteSortGradeAsc,
    RosterSort.attendanceAsc => l.docenteSortAttendance,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Row(
        children: [
          PopupMenuButton<RosterSort>(
            tooltip: l.docenteSortLabel,
            initialValue: sort,
            onSelected: onSort,
            itemBuilder: (_) => [
              for (final s in RosterSort.values)
                PopupMenuItem(value: s, child: Text(_label(l, s))),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.sort_rounded,
                    size: AppIcon.md,
                    color: NexoTheme.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _label(l, sort),
                    style: TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down_rounded,
                    color: NexoTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          if (riskCount > 0)
            FilterChip(
              selected: onlyRisk,
              onSelected: onOnlyRisk,
              visualDensity: VisualDensity.compact,
              avatar: onlyRisk
                  ? null
                  : const Icon(
                      Icons.warning_amber_rounded,
                      size: AppIcon.sm,
                      color: NexoTheme.danger,
                    ),
              label: Text('${l.docenteOnlyAtRisk} ($riskCount)'),
            ),
        ],
      ),
    );
  }
}

class _AlumnoTile extends StatelessWidget {
  final TeacherStudent student;
  final Set<RiskReason> reasons;
  final VoidCallback onTap;
  const _AlumnoTile({
    required this.student,
    required this.onTap,
    this.reasons = const {},
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asis = student.attendancePct;
    final lowAsis = reasons.contains(RiskReason.lowAttendance);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color: reasons.isEmpty
                  ? NexoTheme.border
                  : NexoTheme.danger.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: NexoTheme.primary.withValues(alpha: 0.14),
                child: Text(
                  student.initials,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.primary,
                  ),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      reasons.isEmpty
                          ? student.code
                          : '${student.code} · ${[if (reasons.contains(RiskReason.lowGrade)) l.docenteRiskLowGrade, if (lowAsis) l.docenteRiskLowAttendance].join(' · ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: reasons.isEmpty
                            ? NexoTheme.textMuted
                            : NexoTheme.danger,
                        letterSpacing: 0.4,
                        fontWeight: reasons.isEmpty
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if ((student.grade ?? '').trim().isNotEmpty)
                    _GradePill(grade: student.grade!.trim()),
                  if (asis != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l.docenteAsisPercent(asis.toStringAsFixed(0)),
                      style: TextStyle(
                        fontSize: 10,
                        color: lowAsis ? NexoTheme.danger : NexoTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  final String grade;
  const _GradePill({required this.grade});
  @override
  Widget build(BuildContext context) {
    final color = gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: AppFont.small,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _RosterEmptyOrError extends StatelessWidget {
  final Object? error;
  final String emptyTitle;
  final Future<void> Function() onRetry;
  const _RosterEmptyOrError({
    required this.error,
    required this.emptyTitle,
    required this.onRetry,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: onRetry,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          error != null
              ? EmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: emptyTitle,
                  subtitle: humanizeError(error),
                  color: NexoTheme.danger,
                  onRetry: onRetry,
                  retryLabel: l.actionRetry,
                )
              : EmptyState(icon: Icons.groups_outlined, title: emptyTitle),
        ],
      ),
    );
  }
}

// ── Asistencia ────────────────────────────────────────────────────────────

class _AsistenciaTab extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  const _AsistenciaTab({required this.store, required this.course});
  @override
  State<_AsistenciaTab> createState() => _AsistenciaTabState();
}

class _AsistenciaTabState extends State<_AsistenciaTab>
    with AutomaticKeepAliveClientMixin {
  DateTime _fecha = DateUtils.dateOnly(DateTime.now());
  Map<String, String> _estados = {};
  bool _loading = true;
  Object? _error;

  /// Evita que una respuesta lenta de una fecha anterior pise la actual.
  int _req = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final req = ++_req;
    setState(() {
      _loading = true;
      _error = null;
    });
    Map<String, String> estados = const {};
    Object? error;
    try {
      estados = await widget.store.docenteAsistenciaDia(
        course: widget.course,
        date: _fecha,
      );
    } catch (e) {
      error = e;
    }
    if (!mounted || req != _req) return;
    setState(() {
      _estados = Map.of(estados);
      _error = error;
      _loading = false;
    });
  }

  void _shift(int days) {
    final next = _fecha.add(Duration(days: days));
    if (next.isAfter(DateUtils.dateOnly(DateTime.now()))) return;
    _fecha = next;
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    final alumnos =
        widget.store.alumnosDe(widget.course.id).value ??
        const <TeacherStudent>[];
    final fmt = MaterialLocalizations.of(context).formatMediumDate(_fecha);
    final isToday = DateUtils.isSameDay(_fecha, DateTime.now());
    final resumen = attendanceDaySummary(alumnos.map((a) => _estados[a.code]));
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          color: NexoTheme.surface,
          child: Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                onPressed: _loading ? null : () => _shift(-1),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: AppRadii.rMd,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _fecha,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      _fecha = DateUtils.dateOnly(picked);
                      await _load();
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.event_outlined,
                              size: AppIcon.md,
                              color: NexoTheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              fmt,
                              style: TextStyle(
                                fontSize: AppFont.body,
                                fontWeight: FontWeight.w700,
                                color: NexoTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (!_loading && _error == null)
                          Text(
                            l.docenteAttendanceDaySummary(
                              '${resumen.presentes}',
                              '${resumen.faltas}',
                              '${resumen.justificadas}',
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppFont.small,
                              color: NexoTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                onPressed: _loading || isToday ? null : () => _shift(1),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const _SkeletonList()
                : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: l.docenteAttendanceLoadError,
                        subtitle: humanizeError(_error),
                        color: NexoTheme.danger,
                        onRetry: _load,
                        retryLabel: l.actionRetry,
                      ),
                    ],
                  )
                : _estados.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      EmptyState(
                        icon: Icons.event_busy_outlined,
                        title: l.docenteNoClassThatDay,
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: alumnos.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.xs + 2),
                    itemBuilder: (_, i) {
                      final a = alumnos[i];
                      return _AsistenciaRow(
                        student: a,
                        state: _estados[a.code],
                      );
                    },
                  ),
          ),
        ),
        _ComingSoonBanner(text: l.docenteAttendanceComingSoon),
      ],
    );
  }
}

/// Resuelve el estado de asistencia a (etiqueta, color). Tolera tanto las
/// letras P/T/F/J como ids numéricos de SIGMA aún sin mapear (se muestran como
/// "registrado" neutro para no inventar un significado).
({String label, Color color}) _attendanceState(
  BuildContext context,
  String? raw,
) {
  final l = AppLocalizations.of(context);
  // SIGMA usa ids numéricos: 1=Presente, 2=Falta, 3=Justificado. Se mantienen
  // las letras P/T/F/J por compatibilidad con datos antiguos.
  switch ((raw ?? '').trim().toUpperCase()) {
    case '':
      return (label: '—', color: NexoTheme.textMuted);
    case 'P':
    case '1':
      return (label: l.docenteAttendancePresentShort, color: NexoTheme.success);
    case 'T':
      return (
        label: l.docenteAttendanceTardanzaShort,
        color: NexoTheme.warning,
      );
    case 'F':
    case '2':
      return (label: l.docenteAttendanceFaltaShort, color: NexoTheme.danger);
    case 'J':
    case '3':
      return (label: l.docenteAttendanceJustificada, color: NexoTheme.info);
    default:
      return (label: raw!, color: NexoTheme.info);
  }
}

class _AsistenciaRow extends StatelessWidget {
  final TeacherStudent student;
  final String? state;
  const _AsistenciaRow({required this.student, required this.state});
  @override
  Widget build(BuildContext context) {
    final st = _attendanceState(context, state);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w600,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  student.code,
                  style: TextStyle(
                    fontSize: 10,
                    color: NexoTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: st.color.withValues(alpha: 0.14),
              borderRadius: AppRadii.rPill,
            ),
            child: Text(
              st.label,
              style: TextStyle(
                fontSize: AppFont.caption,
                fontWeight: FontWeight.w800,
                color: st.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBanner extends StatelessWidget {
  final String text;
  const _ComingSoonBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: NexoTheme.info.withValues(alpha: 0.10),
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.info.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: AppIcon.md,
                color: NexoTheme.info,
              ),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Compartidos ───────────────────────────────────────────────────────────

/// Filtro case-insensitive por nombre o código.
bool _matchesQuery(TeacherStudent s, String q) {
  final t = q.trim().toLowerCase();
  if (t.isEmpty) return true;
  return s.displayName.toLowerCase().contains(t) ||
      s.code.toLowerCase().contains(t);
}

class _StudentSearchField extends StatelessWidget {
  final int count;
  final ValueChanged<String> onChanged;
  const _StudentSearchField({required this.count, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: NexoTheme.textPrimary, fontSize: AppFont.body),
        decoration: InputDecoration(
          isDense: true,
          hintText: l.docenteSearchStudent,
          hintStyle: TextStyle(color: NexoTheme.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: NexoTheme.textMuted,
            size: AppIcon.lg,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(
                l.docenteMetricAlumnosCount(count),
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          filled: true,
          fillColor: NexoTheme.card,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.rLg,
            borderSide: BorderSide(color: NexoTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.rLg,
            borderSide: BorderSide(color: NexoTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) => const Skeleton(height: 64, radius: 14),
    );
  }
}

Color gradeColor(String? raw) {
  final n = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= PassingRule.standard.threshold) return NexoTheme.info;
  return NexoTheme.danger;
}
