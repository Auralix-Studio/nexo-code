import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/teacher_insights.dart';
import 'package:nexo/features/teacher/teacher_course_detail.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/skeleton.dart';

class TeacherCoursesScreen extends StatefulWidget {
  const TeacherCoursesScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<TeacherCoursesScreen> createState() => _TeacherCoursesScreenState();
}

class _TeacherCoursesScreenState extends State<TeacherCoursesScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.store.teacherSubjects.hasValue) {
      widget.store.loadTeacherSubjects();
    }
    // Alumnos y asistencia de cada sección para los números de las tarjetas.
    widget.store.loadDocenteResumen();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.teacherSubjects;
        final courses = state.value ?? const <TeacherSubject>[];
        final l = AppLocalizations.of(context);
        return RefreshIndicator(
          onRefresh: () async {
            await widget.store.loadTeacherSubjects();
            await widget.store.loadDocenteResumen(force: true);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: l.titleCourses,
                  subtitle: state.hasValue && courses.isNotEmpty
                      ? '${l.docenteCoursesCountPlural(courses.length)}'
                            ' · ${courses.first.periodo}'
                      : l.subtitleCourses,
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: FadeSwitch(
                    child: KeyedSubtree(
                      key: ValueKey(
                        state.loading && !state.hasValue
                            ? 'loading'
                            : courses.isEmpty
                            ? 'empty'
                            : 'data',
                      ),
                      child: _body(context, state, courses),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<List<TeacherSubject>> state,
    List<TeacherSubject> courses,
  ) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return const Column(
        children: [
          Skeleton(height: 150, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 150, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 150, radius: 16),
        ],
      );
    }
    if (state.error != null && !state.hasValue) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.cloud_off_rounded,
            title: l.docenteLoadCoursesError,
            subtitle: humanizeError(state.error),
            color: NexoTheme.danger,
          ),
        ),
      );
    }
    if (courses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: EmptyState(
            icon: Icons.menu_book_outlined,
            title: l.docenteNoCoursesPeriod,
          ),
        ),
      );
    }
    final rosters = widget.store.docenteRosters;
    final alerts = studentAlerts(courses, rosters);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < courses.length; i++) ...[
          Reveal(
            index: i,
            child: _CursoCard(
              course: courses[i],
              store: widget.store,
              roster: rosters[courses[i].id],
              atRisk: alerts.where((a) => a.course.id == courses[i].id).length,
            ),
          ),
          const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

/// Una sección a cargo: qué es, cuándo y dónde se dicta, y cómo va.
class _CursoCard extends StatelessWidget {
  final TeacherSubject course;
  final AppStore store;
  final List<TeacherStudent>? roster;
  final int atRisk;
  const _CursoCard({
    required this.course,
    required this.store,
    required this.roster,
    required this.atRisk,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = course;
    final schedule = courseScheduleLine(c, short: true);
    final room = courseRoomLine(c);
    final r = roster;
    final pcts = [
      for (final s in r ?? const <TeacherStudent>[])
        double.tryParse((s.attendance ?? '').replaceAll(',', '.')),
    ].whereType<double>().toList();
    final avg = pcts.isEmpty
        ? null
        : pcts.reduce((a, b) => a + b) / pcts.length;
    final ongoing = c.ongoingBlock(DateTime.now());

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: NexoTheme.textMuted),
          ),
          const Gap.h(AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.rXl,
        onTap: () =>
            TeacherCourseDetailScreen.open(context, store: store, course: c),
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rXl,
            border: Border.all(
              color: ongoing != null ? NexoTheme.success : NexoTheme.border,
              width: ongoing != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      c.displayName,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const Gap.h(AppSpacing.sm),
                  Icon(Icons.chevron_right_rounded, color: NexoTheme.textMuted),
                ],
              ),
              const Gap(2),
              Text(
                courseFactsLine(l, c),
                style: TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.w600,
                  color: NexoTheme.textPrimary,
                ),
              ),
              if (schedule.isNotEmpty) line(Icons.schedule_rounded, schedule),
              if (room.isNotEmpty) line(Icons.place_outlined, room),
              if (ongoing != null ||
                  c.isElective ||
                  (r != null && r.isNotEmpty)) ...[
                const Gap(AppSpacing.md),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (ongoing != null)
                      TeacherPill(
                        text: l.tchOngoingNow(ongoing.start, ongoing.end),
                        color: NexoTheme.success,
                      ),
                    if (c.isElective)
                      TeacherPill(text: l.tchElective, color: NexoTheme.info),
                    if (r != null && r.isNotEmpty)
                      TeacherPill(
                        text: l.docenteMetricAlumnosCount(r.length),
                        color: NexoTheme.primary,
                      ),
                    if (avg != null)
                      TeacherPill(
                        text: l.docenteAsisPercent('${avg.round()}'),
                        color: avg <= AttendanceRisk.critical
                            ? NexoTheme.danger
                            : NexoTheme.success,
                      ),
                    if (atRisk > 0)
                      TeacherPill(
                        text: l.tchCourseAtRisk(atRisk),
                        color: NexoTheme.danger,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
