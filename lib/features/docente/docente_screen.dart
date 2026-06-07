import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/features/schedule/schedule_detail_screen.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

/// Dashboard del módulo Docente: perfil + métricas + acceso a cada curso.
class DocenteScreen extends StatefulWidget {
  const DocenteScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<DocenteScreen> createState() => _DocenteScreenState();
}

class _DocenteScreenState extends State<DocenteScreen> {
  @override
  void initState() {
    super.initState();
    final s = widget.store;
    if (!s.docenteInfo.hasValue) s.loadDocenteInfo();
    if (!s.docenteAsignaturas.hasValue) s.loadDocenteAsignaturas();
    if (!s.docenteHorario.hasValue) s.loadDocenteHorario();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              widget.store.loadDocenteInfo(),
              widget.store.loadDocenteAsignaturas(),
              widget.store.loadDocenteHorario(),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
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
                        child: _HeroInfoCard(state: widget.store.docenteInfo),
                      ),
                      const Gap(AppSpacing.lg),
                      Reveal(index: 1, child: _TodayCard(store: widget.store)),
                      const Gap(AppSpacing.lg),
                      Reveal(index: 2, child: _MetricsGrid(store: widget.store)),
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

// ===== Hero card: perfil del docente =====

class _HeroInfoCard extends StatelessWidget {
  final AsyncValue<DocenteInfo> state;
  const _HeroInfoCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return const Skeleton(height: 130, radius: 22);
    }
    final info = state.value;
    if (info == null || info.codigo.isEmpty) return const SizedBox.shrink();

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
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 36),
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
                    info.codigo,
                    label: l.docenteCodeLabel,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        info.codigo,
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
                      if ((info.facultad ?? '').isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          '· ${info.facultad}',
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

// ===== Métricas (cursos, alumnos, notas pendientes) =====

class _MetricsGrid extends StatelessWidget {
  final AppStore store;
  const _MetricsGrid({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cursos = store.docenteAsignaturas.value ?? const <DocenteAsignatura>[];
    final totalAlumnos =
        cursos.fold<int>(0, (a, c) => a + (c.matriculados ?? 0));

    final stats = <_StatData>[
      _StatData(
        label: l.docenteMetricCursos,
        value: '${cursos.length}',
        icon: Icons.menu_book_rounded,
        color: NexoTheme.primary,
      ),
      _StatData(
        label: l.docenteMetricAlumnos,
        value: '$totalAlumnos',
        icon: Icons.groups_rounded,
        color: NexoTheme.accent,
      ),
      _StatData(
        label: l.docenteMetricPeriodo,
        value: cursos.isEmpty ? '—' : cursos.first.periodo,
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

/// Card "Hoy" — preview de las clases que el docente dicta hoy.
class _TodayCard extends StatelessWidget {
  final AppStore store;
  const _TodayCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final today = DateTime.now().weekday;
    final state = store.docenteHorario;

    if (state.loading && !state.hasValue) {
      return const Skeleton(height: 140, radius: 22);
    }

    final clases = (state.value ?? const <ScheduleClass>[])
        .where((c) => c.weekday == today)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final h24 = AppStorage.instance.use24h;
    final isToday = today >= 1 && today <= 7;

    return SectionCard(
      title: l.docenteToday,
      subtitle: isToday ? Fmt.dayLabel(today) : '',
      icon: Icons.today_rounded,
      iconColor: NexoTheme.primary,
      trailing: clases.isEmpty
          ? null
          : StatusChip(
              text: l.docenteClassCount(clases.length),
              color: NexoTheme.primary,
            ),
      child: clases.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.coffee_outlined,
                      size: 32, color: NexoTheme.textSecondary),
                  const Gap(AppSpacing.sm),
                  Text(
                    l.docenteNoClassesToday,
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
                for (var i = 0; i < clases.length; i++) ...[
                  _TodaySessionRow(c: clases[i], h24: h24),
                  if (i < clases.length - 1) const Gap(AppSpacing.sm),
                ],
              ],
            ),
    );
  }
}

class _TodaySessionRow extends StatelessWidget {
  final ScheduleClass c;
  final bool h24;
  const _TodaySessionRow({required this.c, required this.h24});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isTeoria = c.typeCode.toUpperCase() == 'T';
    final color = isTeoria ? NexoTheme.info : NexoTheme.success;
    final hi = Fmt.time(c.startTime, h24: h24);
    final hf = Fmt.time(c.endTime, h24: h24);

    final grupo = ScheduleClassGroup(
      subject: c.subject,
      weekday: c.weekday,
      sessions: [c],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => ScheduleDetailScreen.open(context, grupo),
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
                width: 4,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.subject,
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
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          '$hi – $hf',
                          style: TextStyle(
                            fontSize: AppFont.small,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.location_on_outlined,
                            size: 13, color: NexoTheme.textSecondary),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            Fmt.formatAula(c.room),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFont.small,
                              color: NexoTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  isTeoria ? l.docenteTypeTeoria : l.docenteTypePractica,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: 0.5,
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
