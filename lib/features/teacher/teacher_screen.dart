import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/teacher_insights.dart';
import 'package:nexo/features/teacher/teacher_course_detail.dart';
import 'package:nexo/features/teacher/teacher_dashboard_cards.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

/// Inicio del docente, de lo inmediato a lo general: quién soy y mis números,
/// qué dicto hoy, qué tengo pendiente y mis cursos.
class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key, required this.store, this.clock});
  final AppStore store;

  /// Hora de referencia; para pruebas. Por defecto, la del dispositivo.
  final DateTime Function()? clock;

  @override
  State<TeacherScreen> createState() => _TeacherScreenState();
}

class _TeacherScreenState extends State<TeacherScreen> {
  @override
  void initState() {
    super.initState();
    final s = widget.store;
    if (!s.teacherInfo.hasValue) s.loadTeacherInfo();
    if (!s.teacherSubjects.hasValue) s.loadTeacherSubjects();
    if (!s.teacherMarcacion.hasValue) s.loadTeacherMarcacion();
    if (!s.teacherSchedule.hasValue) s.loadDocenteHorario();
    // Rosters y hojas de asistencia de todas las secciones: alimentan la
    // agenda, los pendientes y los números de cada curso.
    s.loadDocenteResumen();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final now = (widget.clock ?? DateTime.now)();
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              widget.store.loadTeacherInfo(),
              widget.store.loadTeacherSubjects(),
              widget.store.loadTeacherMarcacion(),
              widget.store.loadDocenteHorario(),
            ]);
            await widget.store.loadDocenteResumen(force: true);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Gap(AppSpacing.xxl),
                      FadeSwitch(
                        child: KeyedSubtree(
                          key: ValueKey(widget.store.teacherInfo.hasValue),
                          child: _Header(store: widget.store, now: now),
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      _StatsStrip(store: widget.store),
                      const Gap(AppSpacing.xl),
                      Reveal(
                        index: 0,
                        child: TeacherAgendaCard(store: widget.store, now: now),
                      ),
                      const Gap(AppSpacing.lg),
                      Reveal(
                        index: 1,
                        child: TeacherPendingCard(
                          store: widget.store,
                          now: now,
                        ),
                      ),
                      const Gap(AppSpacing.lg),
                      Reveal(
                        index: 2,
                        child: _MisCursosCard(store: widget.store),
                      ),
                    ],
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
}

String _capitalized(String word) {
  final w = word.trim().toLowerCase();
  return w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}';
}

/// Saludo con foto y nombre, igual que el inicio del estudiante, y el día con
/// cuántas clases hay.
class _Header extends StatelessWidget {
  final AppStore store;
  final DateTime now;
  const _Header({required this.store, required this.now});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = store.teacherInfo;
    final info = state.value;
    if (info == null || info.code.isEmpty) {
      return state.loading || state.isIdle
          ? const Skeleton(height: 60, radius: 18)
          : Text(
              l.titleTeacher,
              style: TextStyle(
                fontSize: AppFont.h1,
                fontWeight: FontWeight.w800,
                color: NexoTheme.textPrimary,
              ),
            );
    }
    final first = _capitalized(info.firstName.split(RegExp(r'\s+')).first);
    final courses = store.teacherSubjects.value ?? const <TeacherSubject>[];
    final today = PeruHolidays.isHoliday(now)
        ? 0
        : sessionsOn(courses, now).length;
    return Row(
      children: [
        StudentAvatar(
          code: info.code,
          name: info.displayName,
          size: 56,
          radius: 18,
        ),
        const Gap.h(14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${Fmt.greeting(now)},',
                style: TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.w600,
                  color: NexoTheme.textSecondary,
                ),
              ),
              Text(
                first.isEmpty ? info.displayName : first,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: NexoTheme.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                [
                  '${Fmt.dayLabel(now.weekday)} ${now.day}',
                  if (courses.isNotEmpty) l.tchClassesToday(today),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Facultad y, en una sola franja, cursos, alumnos y periodo.
class _StatsStrip extends StatelessWidget {
  final AppStore store;
  const _StatsStrip({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final courses = store.teacherSubjects.value ?? const <TeacherSubject>[];
    // SIGMA no manda cuántos alumnos tiene cada sección: se cuentan los
    // alumnos distintos de los rosters cargados. Sin datos aún, "—" en vez de
    // un 0 engañoso.
    final rosters = store.docenteRosters;
    final codes = <String>{
      for (final c in courses)
        for (final s in rosters[c.id] ?? const <TeacherStudent>[]) s.code,
    };
    final faculty = (store.teacherInfo.value?.faculty ?? '').trim();
    final stats = <(Object, String)>[
      (courses.isEmpty ? '—' : courses.length, l.docenteMetricCursos),
      (codes.isEmpty ? '—' : codes.length, l.docenteMetricAlumnos),
      (courses.isEmpty ? '—' : courses.first.periodo, l.docenteMetricPeriodo),
    ];
    final numberStyle = TextStyle(
      fontSize: AppFont.h3,
      fontWeight: FontWeight.w900,
      color: NexoTheme.textPrimary,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (faculty.isNotEmpty) ...[
            Text(
              faculty,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: NexoTheme.textMuted,
              ),
            ),
            const Gap(AppSpacing.sm),
          ],
          IntrinsicHeight(
            child: Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0)
                    VerticalDivider(
                      width: AppSpacing.xl,
                      color: NexoTheme.border,
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (stats[i].$1 case final int n)
                          AnimatedCount(value: n, style: numberStyle)
                        else
                          Text(
                            '${stats[i].$1}',
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                            style: numberStyle,
                          ),
                        Text(
                          stats[i].$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cursos del docente con sus números de un vistazo: alumnos, asistencia
/// promedio y cuántos necesitan atención.
class _MisCursosCard extends StatelessWidget {
  final AppStore store;
  const _MisCursosCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = store.teacherSubjects;
    if (state.loading && !state.hasValue) {
      return const Skeleton(height: 180, radius: 22);
    }
    final cursos = state.value ?? const <TeacherSubject>[];
    final rosters = store.docenteRosters;
    final alerts = studentAlerts(cursos, rosters);
    return SectionCard(
      title: l.titleCourses,
      subtitle: l.docenteCoursesCountPlural(cursos.length),
      icon: Icons.menu_book_rounded,
      iconColor: NexoTheme.primary,
      child: cursos.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text(
                l.docenteNoCoursesPeriod,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppFont.body,
                  color: NexoTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < cursos.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: NexoTheme.border),
                  _CursoRow(
                    store: store,
                    course: cursos[i],
                    roster: rosters[cursos[i].id],
                    atRisk: alerts
                        .where((a) => a.course.id == cursos[i].id)
                        .length,
                  ),
                ],
              ],
            ),
    );
  }
}

class _CursoRow extends StatelessWidget {
  final AppStore store;
  final TeacherSubject course;
  final List<TeacherStudent>? roster;
  final int atRisk;
  const _CursoRow({
    required this.store,
    required this.course,
    required this.roster,
    required this.atRisk,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = roster;
    final pcts = [
      for (final s in r ?? const <TeacherStudent>[])
        double.tryParse((s.attendance ?? '').replaceAll(',', '.')),
    ].whereType<double>().toList();
    final avg = pcts.isEmpty
        ? null
        : pcts.reduce((a, b) => a + b) / pcts.length;
    final facts = [
      l.tchSectionLabel(course.section),
      if (r != null && r.isNotEmpty) l.docenteMetricAlumnosCount(r.length),
      if (avg != null) l.docenteAsisPercent('${avg.round()}'),
    ];
    return InkWell(
      onTap: () =>
          TeacherCourseDetailScreen.open(context, store: store, course: course),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const Gap(AppSpacing.xs),
                  Text(
                    facts.join(' · '),
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (atRisk > 0) ...[
              const Gap.h(AppSpacing.sm),
              TeacherPill(
                text: l.tchCourseAtRisk(atRisk),
                color: NexoTheme.danger,
              ),
            ],
            const Gap.h(AppSpacing.xs),
            Icon(Icons.chevron_right_rounded, color: NexoTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
