import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/grades/grade_widgets.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

Color _grade(num? n) {
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= 10.5) return NexoTheme.info;
  return NexoTheme.danger;
}

/// Notas de periodos ≤2025 (modelo de 2 parciales, diseño anterior).
class LegacyNotasList extends StatelessWidget {
  final AsyncValue<List<NotaAsignatura>> state;
  final Periodo periodo;
  final AppStore store;
  const LegacyNotasList({
    super.key,
    required this.state,
    required this.periodo,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    if (state.loading && !state.hasValue) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: const [
              Skeleton(height: 18, width: 160),
              SizedBox(height: 16),
              Skeleton(height: 64, radius: 14),
              SizedBox(height: 10),
              Skeleton(height: 64, radius: 14),
            ],
          ),
        ),
      );
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: 'Asignaturas',
        icon: Icons.menu_book_rounded,
        iconColor: NexoTheme.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No se pudo cargar desde Intranet',
              subtitle: state.error.toString(),
              color: NexoTheme.danger,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  store.loadBoletaLegacy(periodo.anio, periodo.periodo),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final notas = state.value ?? const <NotaAsignatura>[];
    if (notas.isEmpty) {
      return const SectionCard(
        title: 'Asignaturas',
        icon: Icons.menu_book_rounded,
        child: EmptyState(
          icon: Icons.inbox_rounded,
          title: 'Sin notas en este periodo',
        ),
      );
    }
    return SectionCard(
      title: 'Asignaturas · ${periodo.descripcion}',
      icon: Icons.menu_book_rounded,
      iconColor: NexoTheme.primary,
      trailing: StatusChip(
        text: '${notas.length} cursos',
        color: NexoTheme.primary,
      ),
      child: Column(
        children: [
          for (var i = 0; i < notas.length; i++) ...[
            _Tile(nota: notas[i]),
            if (i < notas.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final NotaAsignatura nota;
  const _Tile({required this.nota});

  @override
  Widget build(BuildContext context) {
    final color = _grade(nota.notaActualNum);
    final enProceso = nota.notaActualNum == null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _Sheet(nota: nota),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NexoTheme.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NexoTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Center(
                      child: Text(
                        nota.notaActualText,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nota.asignatura,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: NexoTheme.textPrimary,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _meta(Icons.tag_rounded, 'Sec. ${nota.seccion}'),
                            if (nota.asistenciaPct != null)
                              _meta(Icons.fact_check_outlined,
                                  '${nota.asistenciaPct}% asist.'),
                            if (nota.puesto.isNotEmpty &&
                                nota.puesto != '0/0')
                              _meta(Icons.emoji_events_outlined,
                                  nota.puesto),
                            if (enProceso)
                              const StatusChip(
                                  text: 'EN PROCESO',
                                  color: NexoTheme.warning),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: NexoTheme.textMuted),
                ],
              ),
              if (nota.pF1.isNotEmpty || nota.pF2.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Badge(
                        label: 'Parcial 1',
                        value: notaFmt(nota.pF1),
                        color: _grade(notaToDouble(nota.pF1)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Badge(
                        label: 'Parcial 2',
                        value: notaFmt(nota.pF2),
                        color: _grade(notaToDouble(nota.pF2)),
                      ),
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

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NexoTheme.textMuted),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

class _Badge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Badge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final empty = value.isEmpty || value == '—';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            empty ? '—' : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: empty ? NexoTheme.textMuted : color,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  final NotaAsignatura nota;
  const _Sheet({required this.nota});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: NexoTheme.bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NexoTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                children: [
                  GradeHeader(
                    titulo: nota.asignatura,
                    subtitulo:
                        '${nota.codigo} · Sec. ${nota.seccion}'
                        '${nota.puesto.isNotEmpty && nota.puesto != '0/0'
                            ? ' · Puesto ${nota.puesto}'
                            : ''}',
                    notaFinalText: nota.notaActualText,
                    enProceso: nota.notaActualNum == null,
                  ),
                  const SizedBox(height: 16),
                  // Resumen de parciales como tarjeta de sección.
                  GradeSectionCard(
                    titulo: 'Resumen',
                    rows: [
                      GradeRow(
                        label: 'Promedio parcial 1',
                        valueRaw: nota.pF1,
                      ),
                      GradeRow(
                        label: 'Promedio parcial 2',
                        valueRaw: nota.pF2,
                      ),
                      GradeRow(
                        label: 'Promedio final',
                        valueRaw: nota.pf,
                        strong: true,
                        last: true,
                      ),
                    ],
                  ),
                  if (!nota.primer.vacio) ...[
                    const SizedBox(height: 12),
                    _parcialCard('Primer parcial', nota.primer),
                  ],
                  if (!nota.segundo.vacio) ...[
                    const SizedBox(height: 12),
                    _parcialCard('Segundo parcial', nota.segundo),
                  ],
                  if (nota.complementario.isNotEmpty &&
                      nota.complementario != '--') ...[
                    const SizedBox(height: 12),
                    _ComplementarioBanner(value: nota.complementario),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parcialCard(String titulo, NotasParcial p) {
    final entries = <(String, String)>[];
    void add(String label, String raw) {
      if (raw.trim().isNotEmpty) entries.add((label, raw));
    }

    for (var i = 0; i < p.practicas.length; i++) {
      add('Práctica ${i + 1}', p.practicas[i]);
    }
    add('Promedio de prácticas', p.promPracticas);
    add('Trabajo de investigación', p.trabajoInv);
    add('Proyecto', p.proyecto);
    add('Promedio TI + PY', p.promTiPy);
    add('Examen parcial', p.examen);

    if (entries.isEmpty) return const SizedBox.shrink();
    return GradeSectionCard(
      titulo: titulo,
      rows: [
        for (var i = 0; i < entries.length; i++)
          GradeRow(
            label: entries[i].$1,
            valueRaw: entries[i].$2,
            strong: entries[i].$1.startsWith('Promedio'),
            last: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _ComplementarioBanner extends StatelessWidget {
  final String value;
  const _ComplementarioBanner({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NexoTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexoTheme.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.replay_rounded,
              color: NexoTheme.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Examen complementario',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textPrimary,
              ),
            ),
          ),
          Text(
            notaFmt(value),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: NexoTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
}
