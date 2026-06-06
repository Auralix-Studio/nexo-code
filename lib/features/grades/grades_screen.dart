import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/grades/grade_widgets.dart';
import 'package:nexo/features/grades/legacy_notas.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

Color _gradeColor(num? n) {
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= 10.5) return NexoTheme.info;
  return NexoTheme.danger;
}

class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    if (!widget.store.periodos.hasValue) widget.store.loadPeriodos();
    if (!widget.store.promedios.hasValue) widget.store.loadPromedios();
  }

  Periodo? _currentPeriodo(List<Periodo> periodos) {
    if (periodos.isEmpty) return null;
    if (_selectedId != null) {
      try {
        return periodos.firstWhere((p) => p.periodoId == _selectedId);
      } catch (_) {}
    }
    try {
      return periodos.firstWhere((p) => p.activo);
    } catch (_) {}
    return periodos.first;
  }

  void _load(Periodo p) {
    if (esModeloNuevo(p.anio, p.periodo)) {
      if (!widget.store.boletaOf(p.anio, p.periodo).hasValue) {
        widget.store.loadBoleta(p.anio, p.periodo);
      }
    } else {
      if (!widget.store.boletaLegacyOf(p.anio, p.periodo).hasValue) {
        widget.store.loadBoletaLegacy(p.anio, p.periodo);
      }
    }
  }

  void _select(Periodo p) {
    setState(() => _selectedId = p.periodoId);
    _load(p);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final periodos = widget.store.periodos.value ?? const <Periodo>[];
        final current = _currentPeriodo(periodos);

        final nuevo =
            current != null && esModeloNuevo(current.anio, current.periodo);

        if (current != null) {
          final st = nuevo
              ? widget.store.boletaOf(current.anio, current.periodo)
              : widget.store.boletaLegacyOf(current.anio, current.periodo);
          // Auto-carga solo en estado idle inicial. Si ya falló (error != null)
          // NO se reintenta automáticamente: el usuario usa pull-to-refresh o
          // el botón "Reintentar" — si no, entramos en bucle infinito al
          // re-disparar `_load` en cada `_notify()` del store.
          if (!st.hasValue && !st.loading && st.error == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _load(current);
            });
          }
        }

        final boleta = current == null
            ? const AsyncValue<List<BoletaCurso>>.idle()
            : widget.store.boletaOf(current.anio, current.periodo);
        final legacy = current == null
            ? const AsyncValue<List<NotaAsignatura>>.idle()
            : widget.store.boletaLegacyOf(current.anio, current.periodo);

        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              widget.store.loadPromedios(),
              widget.store.loadPeriodos(),
              if (current != null) Future(() => _load(current)),
            ]);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: l.titleGrades,
                  subtitle: current == null
                      ? l.gradesSubtitleNoPeriod
                      : nuevo
                      ? l.gradesSubtitleUnits(current.descripcion)
                      : l.gradesSubtitlePartials(current.descripcion),
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Reveal(
                        index: 0,
                        child: _ResumenCard(store: widget.store),
                      ),
                      const SizedBox(height: 14),
                      if (periodos.isNotEmpty) ...[
                        Reveal(
                          index: 1,
                          child: _PeriodChips(
                            periodos: periodos,
                            selected: current,
                            onSelect: _select,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (widget.store.periodos.loading) ...[
                        const Skeleton(height: 40, radius: 999, width: 200),
                        const SizedBox(height: 14),
                      ],
                      if (current == null)
                        SectionCard(
                          title: l.gradesSubjects,
                          icon: Icons.menu_book_rounded,
                          child: EmptyState(
                            icon: Icons.menu_book_rounded,
                            title: l.gradesSelectPeriod,
                          ),
                        )
                      else if (nuevo)
                        Reveal(
                          index: 2,
                          child: _BoletaList(
                            state: boleta,
                            periodo: current,
                            store: widget.store,
                          ),
                        )
                      else
                        Reveal(
                          index: 2,
                          child: LegacyNotasList(
                            state: legacy,
                            periodo: current,
                            store: widget.store,
                          ),
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

// ===================== Lista de cursos (boleta) =====================

class _BoletaList extends StatelessWidget {
  final AsyncValue<List<BoletaCurso>> state;
  final Periodo? periodo;
  final AppStore store;
  const _BoletaList({
    required this.state,
    required this.periodo,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (periodo == null) {
      return SectionCard(
        title: l.gradesSelectPeriod,
        icon: Icons.menu_book_rounded,
        child: EmptyState(
          icon: Icons.menu_book_rounded,
          title: l.gradesSelectPeriod,
        ),
      );
    }
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
              SizedBox(height: 10),
              Skeleton(height: 64, radius: 14),
            ],
          ),
        ),
      );
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: l.gradesSubjects,
        icon: Icons.menu_book_rounded,
        iconColor: NexoTheme.danger,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmptyState(
              icon: Icons.cloud_off_outlined,
              title: l.gradesLoadError,
              subtitle: humanizeError(state.error),
              color: NexoTheme.danger,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  store.loadBoleta(periodo!.anio, periodo!.periodo),
              child: Text(l.actionRetry),
            ),
          ],
        ),
      );
    }
    final cursos = state.value ?? const <BoletaCurso>[];
    if (cursos.isEmpty) {
      return SectionCard(
        title: l.gradesSubjects,
        icon: Icons.menu_book_rounded,
        child: EmptyState(
          icon: Icons.inbox_rounded,
          title: l.gradesNoNotesTitle,
          subtitle: l.gradesNoNotesSubtitleNewModel,
        ),
      );
    }

    return SectionCard(
      title: l.gradesSubjectsWithPeriod(periodo!.descripcion),
      icon: Icons.menu_book_rounded,
      iconColor: NexoTheme.primary,
      trailing: StatusChip(
        text: l.gradesCoursesCount(cursos.length),
        color: NexoTheme.primary,
      ),
      child: Column(
        children: [
          for (var i = 0; i < cursos.length; i++) ...[
            _CursoTile(curso: cursos[i], periodo: periodo!, store: store),
            if (i < cursos.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _CursoTile extends StatelessWidget {
  final BoletaCurso curso;
  final Periodo periodo;
  final AppStore store;
  const _CursoTile({
    required this.curso,
    required this.periodo,
    required this.store,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = _gradeColor(curso.promedio);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          store.loadDetalle(
            periodo.anio,
            periodo.periodo,
            curso.matriculaAsignaturaId,
          );
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _DetalleSheet(curso: curso, store: store),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NexoTheme.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    curso.promedioText,
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
                      curso.nombre,
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
                        _meta(Icons.tag_rounded, '${l.detailSection} ${curso.seccion}'),
                        if (curso.asistencia != null)
                          _meta(
                            Icons.fact_check_outlined,
                            l.docenteAsisPercent(curso.asistencia.toString()),
                          ),
                        if (curso.enProceso)
                          StatusChip(
                            text: l.statusInProcess,
                            color: NexoTheme.warning,
                          ),
                      ],
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

// ===================== Detalle por unidad/evidencia =====================

class _DetalleSheet extends StatelessWidget {
  final BoletaCurso curso;
  final AppStore store;
  const _DetalleSheet({required this.curso, required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
              child: ListenableBuilder(
                listenable: store,
                builder: (context, _) {
                  final st = store.detalleOf(curso.matriculaAsignaturaId);
                  final det = st.value;
                  return ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    children: [
                      GradeHeader(
                        titulo: curso.nombre,
                        subtitulo: '${curso.codigo} · ${l.detailSection} ${curso.seccion}',
                        notaFinalText:
                            det?.promedioFinalText ?? curso.promedioText,
                        enProceso: curso.enProceso,
                      ),
                      const SizedBox(height: 16),
                      if (st.loading && det == null)
                        const Column(
                          children: [
                            Skeleton(height: 90, radius: 16),
                            SizedBox(height: 12),
                            Skeleton(height: 90, radius: 16),
                          ],
                        )
                      else if (st.error != null && det == null)
                        EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: l.gradesDetailLoadError,
                          subtitle: humanizeError(st.error),
                          color: NexoTheme.danger,
                        )
                      else if (det != null) ...[
                        for (final u in det.unidades) ...[
                          GradeSectionCard(
                            titulo: u.nombre,
                            pesoText: u.peso != null
                                ? '${u.peso!.toStringAsFixed(0)}%'
                                : null,
                            promedioRaw: u.promedioRaw,
                            rows: [
                              for (var i = 0; i < u.evidencias.length; i++)
                                GradeRow(
                                  label: _tipoCorto(u.evidencias[i].tipo, l),
                                  valueRaw: u.evidencias[i].notaRaw,
                                  last: i == u.evidencias.length - 1,
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (det.tieneSustitutorio)
                          _Banner(
                            icon: Icons.replay_rounded,
                            label: l.gradesSustitutorio,
                            valueRaw: det.sustitutorioRaw,
                            color: NexoTheme.warning,
                          ),
                        if (det.unidades.isEmpty)
                          EmptyState(
                            icon: Icons.hourglass_empty_rounded,
                            title: l.gradesNoUnitsYetTitle,
                            subtitle: l.gradesNoUnitsYetSubtitle,
                          ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tipoCorto(String t, AppLocalizations l) {
    final u = t.toUpperCase();
    if (u.contains('CONOCIMIENTO')) return l.gradesEvidenciaConocimiento;
    if (u.contains('DESEMPE')) return l.gradesEvidenciaDesempeno;
    if (u.contains('PRODUCTO')) return l.gradesEvidenciaProducto;
    return t;
  }
}

/// Banner resaltado (sustitutorio, complementario…).
class _Banner extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valueRaw;
  final Color color;
  const _Banner({
    required this.icon,
    required this.label,
    required this.valueRaw,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: NexoTheme.textPrimary,
              ),
            ),
          ),
          Text(
            notaFmt(valueRaw),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ===================== Resumen reutilizable =====================

class _ResumenCard extends StatelessWidget {
  final AppStore store;
  const _ResumenCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final promedios = store.promedios.value ?? const <PromedioPeriodo>[];
    final acumulado = store.promedioAcumulado;
    final creditosAprob = store.creditosAprobados;
    final creditosTotal = store.creditosTotales;

    final isWide = MediaQuery.sizeOf(context).width >= 720;

    final metric = _BigMetric(
      label: l.gradesPromedioAcumulado,
      value: acumulado == null ? '—' : acumulado.toStringAsFixed(2),
      hint: creditosAprob == null
          ? l.gradesNoCreditsData
          : creditosTotal != null && creditosTotal > 0
          ? l.gradesCreditsSummary(creditosAprob.toString(), creditosTotal.toString())
          : l.gradesCreditsApprovedCount(creditosAprob),
    );

    final chart = _PromediosChart(items: promedios);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: isWide
            ? IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: metric),
                    const SizedBox(width: 16),
                    Expanded(flex: 3, child: chart),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [metric, const SizedBox(height: 16), chart],
              ),
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  final String label;
  final String value;
  final String hint;
  const _BigMetric({
    required this.label,
    required this.value,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (value != '—') {
          ClipboardHelper.copyAndShow(context, value, label: label);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [NexoTheme.primary, NexoTheme.primaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hint,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromediosChart extends StatelessWidget {
  final List<PromedioPeriodo> items;
  const _PromediosChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: NexoTheme.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NexoTheme.border),
        ),
        height: 160,
        child: EmptyState(
          icon: Icons.show_chart_rounded,
          title: l.gradesNoHistoryYet,
        ),
      );
    }
    final sorted = [...items]
      ..sort((a, b) {
        final byYear = a.anio.compareTo(b.anio);
        return byYear != 0 ? byYear : a.periodo.compareTo(b.periodo);
      });

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: NexoTheme.bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l.gradesEvolutionByPeriod,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final p in sorted) Expanded(child: _BarColumn(p: p)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final PromedioPeriodo p;
  const _BarColumn({required this.p});

  @override
  Widget build(BuildContext context) {
    final ok = p.promedio >= 11;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            p.promedio == 0 ? '—' : p.promedio.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (ctx, c) {
                final h = c.maxHeight;
                final value = p.promedio == 0 ? 4.0 : (p.promedio / 20.0) * h;
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    width: double.infinity,
                    height: value.clamp(4.0, h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: p.promedio == 0
                            ? [NexoTheme.border, NexoTheme.border]
                            : ok
                            ? [NexoTheme.success, NexoTheme.accent]
                            : const [NexoTheme.warning, NexoTheme.danger],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(6),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Text(
            p.label,
            style: TextStyle(
              fontSize: 10,
              color: NexoTheme.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  final List<Periodo> periodos;
  final Periodo? selected;
  final ValueChanged<Periodo> onSelect;

  const _PeriodChips({
    required this.periodos,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final p in periodos) ...[
            _Chip(
              text: p.descripcion,
              active: p.periodoId == selected?.periodoId,
              onTap: () => onSelect(p),
              activo: p.activo,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final bool active;
  final bool activo;
  final VoidCallback onTap;
  const _Chip({
    required this.text,
    required this.active,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? NexoTheme.primary : NexoTheme.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? NexoTheme.primary : NexoTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : NexoTheme.textPrimary,
              ),
            ),
            if (activo) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active ? Colors.white : NexoTheme.success,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
