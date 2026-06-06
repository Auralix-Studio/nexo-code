import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/shared/widgets/section_card.dart';

/// Lista las clases de Teams del alumno tal como las devuelve Graph
/// (nombre original de la asignatura). Sin personalización: solo validación.
class TeamsClassesWidget extends StatelessWidget {
  final List<TeamsClass> clases;
  const TeamsClassesWidget({super.key, required this.clases});

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Mis asignaturas',
      subtitle: 'Grupos de Teams',
      icon: Icons.groups_outlined,
      iconColor: NexoTheme.accent,
      trailing: _Counter(count: clases.length),
      child: clases.isEmpty
          ? const _Empty()
          : Column(
              children: [
                for (var i = 0; i < clases.length; i++) ...[
                  _ClassTile(clase: clases[i]),
                  if (i < clases.length - 1) const Gap(AppSpacing.sm + 2),
                ],
              ],
            ),
    );
  }
}

class _Counter extends StatelessWidget {
  final int count;
  const _Counter({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: NexoTheme.accent.withValues(alpha: 0.1),
          borderRadius: AppRadii.rPill,
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: AppFont.small,
            fontWeight: FontWeight.w600,
            color: NexoTheme.accent,
          ),
        ),
      );
}

class _ClassTile extends StatelessWidget {
  final TeamsClass clase;
  const _ClassTile({required this.clase});

  @override
  Widget build(BuildContext context) {
    final subtitle = clase.classCode.isNotEmpty
        ? clase.classCode
        : (clase.description.isNotEmpty ? clase.description : null);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg - 2),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 38,
            decoration: BoxDecoration(
              color: NexoTheme.accent.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clase.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const Gap(AppSpacing.xs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textSecondary,
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl + 4),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.school_outlined,
                size: 36, color: NexoTheme.textSecondary),
            const Gap(AppSpacing.sm),
            Text(
              'No hay asignaturas en Teams',
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
