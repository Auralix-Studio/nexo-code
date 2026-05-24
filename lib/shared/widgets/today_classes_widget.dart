import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/section_card.dart';

/// Widget de "Asignaturas de hoy" — fusiona teoría + práctica del mismo curso.
class TodayClassesWidget extends StatelessWidget {
  final List<ClaseHorario> all;
  final DateTime? nowOverride;

  const TodayClassesWidget({
    super.key,
    required this.all,
    this.nowOverride,
  });

  DateTime get now => nowOverride ?? DateTime.now();

  @override
  Widget build(BuildContext context) {
    final today = now.weekday; // 1=Lun..7=Dom (igual que SIGMA)
    final hoy = all.where((c) => c.idDia == today).toList(growable: false);
    final grupos = ClaseAgrupada.agrupar(hoy);
    final nowHM = _hm(now);

    return SectionCard(
      title: 'Hoy',
      subtitle: Fmt.dayLabel(today),
      icon: Icons.today_outlined,
      iconColor: NexoTheme.primary,
      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: NexoTheme.primary.withValues(alpha: 0.1),
          borderRadius: AppRadii.rPill,
        ),
        child: Text(
          '${grupos.length} ${grupos.length == 1 ? 'curso' : 'cursos'}',
          style: const TextStyle(
            fontSize: AppFont.small,
            fontWeight: FontWeight.w600,
            color: NexoTheme.primary,
          ),
        ),
      ),
      child: grupos.isEmpty
          ? const _Empty()
          : Column(
              children: [
                for (var i = 0; i < grupos.length; i++) ...[
                  _CourseTile(grupo: grupos[i], nowHM: nowHM),
                  if (i < grupos.length - 1) const Gap(AppSpacing.sm + 2),
                ],
              ],
            ),
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl + 4),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.celebration_outlined,
                size: 36, color: NexoTheme.textSecondary),
            const Gap(AppSpacing.sm),
            Text(
              'Sin clases hoy',
              style: TextStyle(
                fontSize: AppFont.body,
                color: NexoTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _CourseTile extends StatelessWidget {
  final ClaseAgrupada grupo;
  final String nowHM;
  const _CourseTile({required this.grupo, required this.nowHM});

  bool _isOngoing(ClaseHorario c) =>
      c.horaInicio.compareTo(nowHM) <= 0 && nowHM.compareTo(c.horaFin) < 0;
  bool _isPast(String horaFin) => horaFin.compareTo(nowHM) <= 0;

  @override
  Widget build(BuildContext context) {
    final anyOngoing = grupo.sesiones.any(_isOngoing);
    final allPast = grupo.sesiones.every((s) => _isPast(s.horaFin));
    final accent = anyOngoing
        ? NexoTheme.success
        : allPast
            ? NexoTheme.textSecondary
            : NexoTheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      decoration: BoxDecoration(
        color: anyOngoing
            ? NexoTheme.success.withValues(alpha: 0.06)
            : NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: anyOngoing
              ? NexoTheme.success.withValues(alpha: 0.3)
              : NexoTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            grupo.asignatura,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: AppFont.subtitle,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                              color: allPast
                                  ? NexoTheme.textSecondary
                                  : NexoTheme.textPrimary,
                            ),
                          ),
                        ),
                        if (anyOngoing) ...[
                          const Gap.h(AppSpacing.sm),
                          _badge('EN CURSO', NexoTheme.success),
                        ],
                      ],
                    ),
                    if (grupo.aula.isNotEmpty) ...[
                      const Gap(AppSpacing.xs),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: AppIcon.xs,
                              color: NexoTheme.textSecondary),
                          const Gap.h(AppSpacing.xs),
                          Text(
                            grupo.aula,
                            style: TextStyle(
                              fontSize: AppFont.small,
                              color: NexoTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.md),
          // Lista de sesiones (teoría/práctica) fusionadas.
          ...grupo.sesiones.map((s) => _SessionRow(
                sesion: s,
                ongoing: _isOngoing(s),
                past: _isPast(s.horaFin),
              )),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(color: color, borderRadius: AppRadii.rPill),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      );
}

class _SessionRow extends StatelessWidget {
  final ClaseHorario sesion;
  final bool ongoing;
  final bool past;
  const _SessionRow({
    required this.sesion,
    required this.ongoing,
    required this.past,
  });

  @override
  Widget build(BuildContext context) {
    final c = ongoing
        ? NexoTheme.success
        : past
            ? NexoTheme.textMuted
            : NexoTheme.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs, left: AppSpacing.lg),
      child: Row(
        children: [
          Icon(
            sesion.idTipo.toUpperCase() == 'T'
                ? Icons.menu_book_outlined
                : Icons.science_outlined,
            size: AppIcon.xs,
            color: c,
          ),
          const Gap.h(AppSpacing.sm - 2),
          Text(
            sesion.tipoLargo,
            style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          const Gap.h(AppSpacing.sm),
          Text(
            '${sesion.horaInicio} – ${sesion.horaFin}',
            style: TextStyle(
              fontSize: AppFont.small,
              color: c,
              decoration:
                  past ? TextDecoration.lineThrough : TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}
