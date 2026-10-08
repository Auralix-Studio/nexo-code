import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/features/teacher/teacher_course_detail.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

class TeacherScreen extends StatefulWidget {
  const TeacherScreen({super.key, required this.store});
  final AppStore store;
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
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              widget.store.loadTeacherInfo(),
              widget.store.loadTeacherSubjects(),
              widget.store.loadTeacherMarcacion(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: AppLocalizations.of(context).titleTeacher,
                  subtitle: AppLocalizations.of(context).subtitleTeacher,
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        index: 0,
                        child: _HeroInfoCard(state: widget.store.teacherInfo),
                      ),
                      const Gap(AppSpacing.lg),
                      Reveal(
                        index: 1,
                        child: _MetricsGrid(store: widget.store),
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

class _HeroInfoCard extends StatelessWidget {
  final AsyncValue<TeacherInfo> state;
  const _HeroInfoCard({required this.state});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return const Skeleton(height: 130, radius: 22);
    }
    final info = state.value;
    if (info == null || info.code.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rXxl,
        boxShadow: [
          BoxShadow(
            color: NexoTheme.primary.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const Gap.h(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.docenteLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  info.displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: AppFont.h2,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => ClipboardHelper.copyAndShow(
                    context,
                    info.code,
                    label: l.docenteCodeLabel,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info.code,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.88),
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.copy_rounded,
                        color: Colors.white.withValues(alpha: 0.7),
                        size: 13,
                      ),
                      if ((info.faculty ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${info.faculty}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.88),
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricsGrid extends StatelessWidget {
  final AppStore store;
  const _MetricsGrid({required this.store});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final courses = store.teacherSubjects.value ?? const <TeacherSubject>[];
    // El conteo de alumnos por sección sólo se conoce al abrir cada curso; si
    // ninguna sección lo trae aún, mostramos "—" en vez de un 0 engañoso.
    final counted = courses.where((c) => (c.enrolledCount ?? 0) > 0);
    final totalAlumnos = counted.fold<int>(0, (a, c) => a + c.enrolledCount!);
    final stats = <_StatData>[
      _StatData(
        label: l.docenteMetricCursos,
        value: '${courses.length}',
        icon: Icons.menu_book_rounded,
        color: NexoTheme.primary,
      ),
      _StatData(
        label: l.docenteMetricAlumnos,
        value: counted.isEmpty ? '—' : '$totalAlumnos',
        icon: Icons.groups_rounded,
        color: NexoTheme.accent,
      ),
      _StatData(
        label: l.docenteMetricPeriodo,
        value: courses.isEmpty ? '—' : courses.first.periodo,
        icon: Icons.calendar_month_rounded,
        color: NexoTheme.success,
      ),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        mainAxisExtent: 90,
      ),
      itemBuilder: (_, i) => _StatTile(data: stats[i]),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _StatTile extends StatelessWidget {
  final _StatData data;
  const _StatTile({required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(data.icon, color: data.color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                data.value,
                style: TextStyle(
                  fontSize: AppFont.h3,
                  fontWeight: FontWeight.w800,
                  color: NexoTheme.textPrimary,
                ),
              ),
              Text(
                data.label,
                style: TextStyle(
                  fontSize: 11,
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

/// Acceso rápido a las asignaturas del docente desde el dashboard. Reemplaza al
/// antiguo "hoy" por horario, que SIGMA no expone para el docente.
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
    return SectionCard(
      title: l.titleCourses,
      subtitle: l.docenteCoursesCountPlural(cursos.length),
      icon: Icons.menu_book_rounded,
      iconColor: NexoTheme.primary,
      trailing: cursos.isEmpty
          ? null
          : StatusChip(text: '${cursos.length}', color: NexoTheme.primary),
      child: cursos.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 32,
                    color: NexoTheme.textSecondary,
                  ),
                  const Gap(AppSpacing.sm),
                  Text(
                    l.docenteNoCoursesPeriod,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      color: NexoTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < cursos.length; i++) ...[
                  _CursoRow(store: store, course: cursos[i]),
                  if (i < cursos.length - 1) const Gap(AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _CursoRow extends StatelessWidget {
  final AppStore store;
  final TeacherSubject course;
  const _CursoRow({required this.store, required this.course});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                TeacherCourseDetailScreen(store: store, course: course),
          ),
        ),
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: NexoTheme.primary.withValues(alpha: 0.12),
                  borderRadius: AppRadii.rMd,
                ),
                child: Icon(
                  Icons.class_rounded,
                  color: NexoTheme.primary,
                  size: 20,
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.subject,
                      maxLines: 1,
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
                      '${l.detailSection} ${course.section}'
                      '${course.nrc.isNotEmpty ? ' · NRC ${course.nrc}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: NexoTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
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
