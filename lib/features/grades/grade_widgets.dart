import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/models.dart';

/// Color de una nota según rango.
Color gradeColor(num? n) {
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= 10.5) return NexoTheme.info;
  return NexoTheme.danger;
}

/// Badge cuadrado redondeado con la nota. Tamaño configurable.
class GradeBadge extends StatelessWidget {
  final String text;
  final double size;
  final double fontSize;
  const GradeBadge({
    super.key,
    required this.text,
    this.size = 52,
    this.fontSize = 18,
  });

  factory GradeBadge.fromRaw(String raw, {double size = 52, double fs = 18}) =>
      GradeBadge(text: notaFmt(raw), size: size, fontSize: fs);

  @override
  Widget build(BuildContext context) {
    final c = gradeColor(notaToDouble(text == '—' ? null : text));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: c.withValues(alpha: 0.32)),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          color: c,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

/// Encabezado de detalle: nota final + nombre + meta.
class GradeHeader extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final String notaFinalText;
  final bool enProceso;
  const GradeHeader({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.notaFinalText,
    this.enProceso = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = gradeColor(
        notaToDouble(notaFinalText == '—' ? null : notaFinalText));
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [c.withValues(alpha: 0.14), c.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          GradeBadge(text: notaFinalText, size: 70, fontSize: 26),
          const Gap.h(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titulo,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.h3,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (enProceso) ...[
                      const Gap.h(AppSpacing.sm),
                      _miniChip('EN PROCESO', NexoTheme.warning),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String t, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: AppRadii.rPill,
        ),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: 0.4,
          ),
        ),
      );
}

/// Fila de evaluación: etiqueta a la izquierda, nota a la derecha,
/// con barra de progreso sutil. Estilo "tabla", no chips.
class GradeRow extends StatelessWidget {
  final String label;
  final String valueRaw;
  final bool strong;
  final bool last;
  const GradeRow({
    super.key,
    required this.label,
    required this.valueRaw,
    this.strong = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final n = notaToDouble(valueRaw);
    final c = gradeColor(n);
    final txt = notaFmt(valueRaw);
    return Container(
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(color: NexoTheme.divider),
              ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFont.body,
                color: strong ? NexoTheme.textPrimary : NexoTheme.textSecondary,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          if (n != null) ...[
            SizedBox(
              width: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: (n / 20).clamp(0, 1).toDouble(),
                  minHeight: 5,
                  backgroundColor: NexoTheme.divider,
                  valueColor: AlwaysStoppedAnimation(c),
                ),
              ),
            ),
            const Gap.h(AppSpacing.md),
          ],
          SizedBox(
            width: 44,
            child: Text(
              txt,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: AppFont.subtitle,
                fontWeight: FontWeight.w800,
                color: c,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de sección (Unidad / Parcial): cabecera con título, peso y
/// promedio, y lista de filas.
class GradeSectionCard extends StatelessWidget {
  final String titulo;
  final String? pesoText; // "20%"
  final String? promedioRaw;
  final List<Widget> rows;
  const GradeSectionCard({
    super.key,
    required this.titulo,
    required this.rows,
    this.pesoText,
    this.promedioRaw,
  });

  @override
  Widget build(BuildContext context) {
    final promColor = gradeColor(notaToDouble(promedioRaw));
    return Container(
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rXl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cabecera
          Container(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md,
                AppSpacing.lg, AppSpacing.md),
            decoration: BoxDecoration(
              color: NexoTheme.bg,
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppRadii.xl)),
              border: Border(
                  bottom: BorderSide(color: NexoTheme.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: NexoTheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Gap.h(AppSpacing.md),
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                if (pesoText != null) ...[
                  const Gap.h(AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm, vertical: 2),
                    decoration: BoxDecoration(
                      color: NexoTheme.accent.withValues(alpha: 0.14),
                      borderRadius: AppRadii.rPill,
                    ),
                    child: Text(
                      pesoText!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.accent,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (promedioRaw != null && notaFmt(promedioRaw) != '—')
                  Row(
                    children: [
                      Text(
                        'Promedio ',
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        notaFmt(promedioRaw),
                        style: TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.w900,
                          color: promColor,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Filas
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(children: rows),
          ),
          const Gap(AppSpacing.sm),
        ],
      ),
    );
  }
}
