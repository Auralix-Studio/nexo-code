import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<ScheduleScreen> createState() => _HorarioScreenState();
}

class _HorarioScreenState extends State<ScheduleScreen> {
  bool _weekView = true;

  @override
  void initState() {
    super.initState();
    if (!widget.store.horario.hasValue) {
      widget.store.loadHorarioActual();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.horario;
        return RefreshIndicator(
          onRefresh: () => widget.store.loadHorarioActual(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: 'Horario',
                  subtitle: 'Periodo activo · ${state.value?.length ?? 0} clases',
                  actions: [
                    _ViewToggle(
                      weekView: _weekView,
                      onChanged: (v) => setState(() => _weekView = v),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: _buildBody(context, state),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AsyncValue<List<ClaseHorario>> state) {
    if (state.loading && !state.hasValue) {
      return const _Loading();
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: 'Error',
        icon: Icons.cloud_off_outlined,
        iconColor: NexoTheme.danger,
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'No se pudo cargar el horario',
          subtitle: state.error.toString(),
          color: NexoTheme.danger,
        ),
      );
    }
    final clases = state.value ?? const <ClaseHorario>[];
    if (clases.isEmpty) {
      return const SectionCard(
        title: 'Sin clases',
        icon: Icons.calendar_today_outlined,
        child: EmptyState(
          icon: Icons.event_busy_rounded,
          title: 'No hay clases registradas',
        ),
      );
    }
    return _weekView ? _WeekView(clases: clases) : _DayListView(clases: clases);
  }
}

class _ViewToggle extends StatelessWidget {
  final bool weekView;
  final ValueChanged<bool> onChanged;
  const _ViewToggle({required this.weekView, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggle('Semana', weekView, () => onChanged(true)),
          _toggle('Lista', !weekView, () => onChanged(false)),
        ],
      ),
    );
  }

  Widget _toggle(String label, bool active, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? NexoTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : NexoTheme.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      );
}

class _WeekView extends StatelessWidget {
  final List<ClaseHorario> clases;
  const _WeekView({required this.clases});

  @override
  Widget build(BuildContext context) {
    // Agrupar por día.
    final byDay = <int, List<ClaseHorario>>{};
    for (final c in clases) {
      byDay.putIfAbsent(c.idDia, () => []).add(c);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.horaInicio.compareTo(b.horaInicio));
    }

    final today = DateTime.now().weekday;
    final daysOrder = [1, 2, 3, 4, 5, 6, 7]
        .where((d) => byDay.containsKey(d))
        .toList();
    if (daysOrder.isEmpty) {
      return const EmptyState(
        icon: Icons.event_busy_rounded,
        title: 'Sin clases programadas',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final day in daysOrder) ...[
          _DaySection(
            day: day,
            clases: byDay[day]!,
            isToday: day == today,
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _DayListView extends StatelessWidget {
  final List<ClaseHorario> clases;
  const _DayListView({required this.clases});

  @override
  Widget build(BuildContext context) {
    // Primero agrupamos por día
    final byDay = <int, List<ClaseHorario>>{};
    for (final c in clases) {
      byDay.putIfAbsent(c.idDia, () => []).add(c);
    }
    
    // Convertimos cada día en grupos unificados
    final gruposTotales = <ClaseAgrupada>[];
    final days = byDay.keys.toList()..sort();
    for (final d in days) {
      gruposTotales.addAll(ClaseAgrupada.agrupar(byDay[d]!));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            for (var i = 0; i < gruposTotales.length; i++) ...[
              _GrupoTile(grupo: gruposTotales[i], showDay: true),
              if (i < gruposTotales.length - 1)
                const Divider(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  final int day;
  final List<ClaseHorario> clases;
  final bool isToday;

  const _DaySection({
    required this.day,
    required this.clases,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final grupos = ClaseAgrupada.agrupar(clases);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isToday ? NexoTheme.primary : NexoTheme.accent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  Fmt.dayLabel(day),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(width: 10),
                if (isToday)
                  const StatusChip(text: 'HOY', color: NexoTheme.primary),
                const Spacer(),
                Text(
                  '${grupos.length} ${grupos.length == 1 ? 'curso' : 'cursos'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: NexoTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < grupos.length; i++) ...[
              _GrupoTile(grupo: grupos[i]),
              if (i < grupos.length - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _GrupoTile extends StatelessWidget {
  final ClaseAgrupada grupo;
  final bool showDay;
  const _GrupoTile({required this.grupo, this.showDay = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time block
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: NexoTheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NexoTheme.border),
            ),
            child: Column(
              children: [
                Text(
                  grupo.horaInicio,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                    width: 18,
                    height: 1,
                    color: NexoTheme.border),
                const SizedBox(height: 2),
                Text(
                  grupo.horaFin,
                  style: TextStyle(
                    fontSize: 13,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  grupo.asignatura,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    if (showDay)
                      _meta(Icons.calendar_today_outlined,
                          Fmt.dayLabel(grupo.idDia)),
                    if (grupo.aula.isNotEmpty)
                      _meta(Icons.location_on_outlined, grupo.aula),
                    _meta(Icons.tag_rounded, grupo.sesiones.first.seccion),
                  ],
                ),
                if (grupo.docente.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 14, color: NexoTheme.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          grupo.docente,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: NexoTheme.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                // Sesiones unificadas
                for (final s in grupo.sesiones)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      children: [
                        Icon(
                          s.idTipo.toUpperCase() == 'T'
                              ? Icons.menu_book_outlined
                              : Icons.science_outlined,
                          size: 13,
                          color: NexoTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${s.tipoLargo} (${s.horaInicio} - ${s.horaFin})',
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: NexoTheme.textSecondary),
          const SizedBox(width: 4),
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

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < 3; i++) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Skeleton(height: 18, width: 120),
                  SizedBox(height: 16),
                  Skeleton(height: 64, radius: 14),
                  SizedBox(height: 10),
                  Skeleton(height: 64, radius: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
