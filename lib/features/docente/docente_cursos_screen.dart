import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/docente/docente_curso_detail.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/skeleton.dart';

/// Pantalla dedicada de "Mis cursos" del docente. Reemplaza el card que
/// vivía dentro del dashboard de Inicio.
class DocenteCursosScreen extends StatefulWidget {
  const DocenteCursosScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<DocenteCursosScreen> createState() => _DocenteCursosScreenState();
}

class _DocenteCursosScreenState extends State<DocenteCursosScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.store.docenteAsignaturas.hasValue) {
      widget.store.loadDocenteAsignaturas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.docenteAsignaturas;
        final cursos = state.value ?? const <DocenteAsignatura>[];
        final l = AppLocalizations.of(context);

        return RefreshIndicator(
          onRefresh: () => widget.store.loadDocenteAsignaturas().then((_) {}),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: l.titleCourses,
                  subtitle: state.hasValue
                      ? l.docenteCoursesCountPlural(cursos.length)
                      : l.subtitleCourses,
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: _body(context, state, cursos),
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
    AsyncValue<List<DocenteAsignatura>> state,
    List<DocenteAsignatura> cursos,
  ) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return Column(
        children: const [
          Skeleton(height: 90, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 90, radius: 16),
          SizedBox(height: 12),
          Skeleton(height: 90, radius: 16),
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
    if (cursos.isEmpty) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < cursos.length; i++) ...[
          Reveal(
            index: i,
            child: _CursoTile(curso: cursos[i], store: widget.store),
          ),
          const Gap(AppSpacing.md),
        ],
      ],
    );
  }
}

/// Tarjeta tocable de un curso. Diseño rico — más espacio para datos clave
/// (alumnos, código, sección, periodo).
class _CursoTile extends StatelessWidget {
  final DocenteAsignatura curso;
  final AppStore store;
  const _CursoTile({required this.curso, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.rXl,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DocenteCursoDetailScreen(
              store: store,
              curso: curso,
            ),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: NexoTheme.primary.withValues(alpha: 0.12),
                      borderRadius: AppRadii.rLg,
                    ),
                    child: Icon(Icons.class_rounded,
                        color: NexoTheme.primary, size: 24),
                  ),
                  const Gap.h(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          curso.codigo,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: NexoTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          curso.asignatura,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: AppFont.subtitle + 1,
                            fontWeight: FontWeight.w800,
                            color: NexoTheme.textPrimary,
                            height: 1.2,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: NexoTheme.textMuted),
                ],
              ),
              const Gap(AppSpacing.md),
              Divider(height: 1, color: NexoTheme.border),
              const Gap(AppSpacing.md),
              Row(
                children: [
                  _pill(
                    icon: Icons.tag_rounded,
                    label: '${l.detailSection} ${curso.seccion}',
                    color: NexoTheme.info,
                  ),
                  const Gap.h(AppSpacing.sm),
                  _pill(
                    icon: Icons.groups_rounded,
                    label: l.docenteMetricAlumnosCount(curso.matriculados ?? 0),
                    color: NexoTheme.accent,
                  ),
                  const Spacer(),
                  Text(
                    curso.periodo,
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
        ),
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadii.rPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
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
