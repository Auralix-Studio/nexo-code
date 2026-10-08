import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_grade_entry.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';

/// Pestaña Notas del curso: unidades de SIGMA y, por cada una, las
/// evaluaciones (EV/DE/PR…) con su avance. Tocar una abre el registro de esa
/// evaluación para toda la sección.
class TeacherGradesTab extends StatefulWidget {
  const TeacherGradesTab({
    super.key,
    required this.store,
    required this.course,
  });
  final AppStore store;
  final TeacherSubject course;
  @override
  State<TeacherGradesTab> createState() => _TeacherGradesTabState();
}

class _TeacherGradesTabState extends State<TeacherGradesTab>
    with AutomaticKeepAliveClientMixin {
  late Future<List<TeacherUnitCatalog>> _units;
  TeacherUnitCatalog? _unit;

  /// Unidades que SIGMA registra con un flujo aparte (solo alumnos aptos).
  static const _special = {'COMPLEMENTARIO', 'SUSTITUTORIO'};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _units = _loadUnits();
  }

  Future<List<TeacherUnitCatalog>> _loadUnits() async {
    final u = await widget.store.docenteUnidades(widget.course);
    if (mounted && _unit == null && u.isNotEmpty) {
      setState(() {
        // Como SIGMA: se abre en la primera unidad habilitada.
        _unit = u.where((x) => x.enabled).firstOrNull ?? u.first;
      });
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<TeacherUnitCatalog>>(
      future: _units,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const TeacherListSkeleton(height: 90);
        }
        if (snap.hasError || (snap.data ?? const []).isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.cloud_off_outlined,
              title: l.tchUnitsLoadError,
              onRetry: () => setState(() => _units = _loadUnits()),
            ),
          );
        }
        final units = snap.data!;
        final unit = _unit ?? units.first;
        return ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final roster =
                widget.store.alumnosDe(widget.course.id).value ??
                const <TeacherStudent>[];
            return RefreshIndicator(
              onRefresh: () => widget.store.loadDocenteAlumnos(
                widget.course.id,
                tipoCalif: widget.course.tipoCalif,
              ),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final u in units) ...[
                          ChoiceChip(
                            avatar: u.enabled
                                ? null
                                : const Icon(
                                    Icons.lock_outline_rounded,
                                    size: 14,
                                  ),
                            label: Text(u.name),
                            selected: u.id == unit.id,
                            onSelected: (_) => setState(() => _unit = u),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _UnitSummary(unit: unit, roster: roster),
                  if (!unit.enabled)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        l.docenteUnitLocked,
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  if (_special.contains(unit.name.toUpperCase()))
                    EmptyState(
                      icon: Icons.web_rounded,
                      title: l.tchSpecialUnit(unit.name),
                    )
                  else
                    _TypesList(
                      key: ValueKey(unit.id),
                      store: widget.store,
                      course: widget.course,
                      unit: unit,
                      roster: roster,
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _UnitSummary extends StatelessWidget {
  final TeacherUnitCatalog unit;
  final List<TeacherStudent> roster;
  const _UnitSummary({required this.unit, required this.roster});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final avgs = [
      for (final s in roster)
        s.units.where((u) => u.tipoUnidadId == unit.id).firstOrNull?.average,
    ].whereType<double>().where((v) => v > 0).toList();
    if (avgs.isEmpty) return const SizedBox.shrink();
    final mean = avgs.reduce((a, b) => a + b) / avgs.length;
    final passed = avgs.where((v) => v >= 10.5).length;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        TeacherPill(
          text: l.tchGradeAverage(mean.toStringAsFixed(1)),
          color: gradeColor(mean.toStringAsFixed(1)),
        ),
        TeacherPill(
          text: l.tchGradePassed(passed, avgs.length),
          color: NexoTheme.success,
        ),
      ],
    );
  }
}

class _TypesList extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  final TeacherUnitCatalog unit;
  final List<TeacherStudent> roster;
  const _TypesList({
    super.key,
    required this.store,
    required this.course,
    required this.unit,
    required this.roster,
  });
  @override
  State<_TypesList> createState() => _TypesListState();
}

class _TypesListState extends State<_TypesList> {
  late Future<List<GradeType>> _types;

  @override
  void initState() {
    super.initState();
    _types = widget.store.docenteTiposNota(widget.unit.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<GradeType>>(
      future: _types,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Column(
            children: [
              SizedBox(height: 90, child: TeacherListSkeleton(count: 1)),
            ],
          );
        }
        final types = snap.data ?? const <GradeType>[];
        if (snap.hasError || types.isEmpty) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: l.tchTypesLoadError,
            onRetry: () => setState(
              () => _types = widget.store.docenteTiposNota(widget.unit.id),
            ),
          );
        }
        final children = <Widget>[];
        for (final t in types) {
          // Columnas existentes de este tipo (normalmente 1 por unidad).
          var columns = 0;
          for (final s in widget.roster) {
            final n = s.cells
                .where(
                  (c) => c.unidadId == widget.unit.id && c.tipoNotaId == t.id,
                )
                .length;
            if (n > columns) columns = n;
          }
          final shown = columns < t.maxCount ? columns + 1 : columns;
          for (var i = 0; i < shown; i++) {
            children.add(
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TypeCard(
                  type: t,
                  ordinal: i,
                  multi: t.maxCount > 1,
                  unit: widget.unit,
                  roster: widget.roster,
                  onTap: () => TeacherGradeEntryScreen.open(
                    context,
                    store: widget.store,
                    course: widget.course,
                    unit: widget.unit,
                    type: t,
                    ordinal: i,
                  ),
                ),
              ),
            );
          }
        }
        return Column(children: children);
      },
    );
  }
}

class _TypeCard extends StatelessWidget {
  final GradeType type;
  final int ordinal;
  final bool multi;
  final TeacherUnitCatalog unit;
  final List<TeacherStudent> roster;
  final VoidCallback onTap;
  const _TypeCard({
    required this.type,
    required this.ordinal,
    required this.multi,
    required this.unit,
    required this.roster,
    required this.onTap,
  });

  Color get _color {
    final hex = type.colorHex.replaceAll('#', '').trim();
    final v = int.tryParse(hex, radix: 16);
    if (hex.length != 6 || v == null) return NexoTheme.primary;
    // Los colores de SIGMA son pastel: se oscurecen para que el texto se lea.
    final c = Color(0xFF000000 | v);
    return HSLColor.fromColor(c).withLightness(0.42).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final values = [
      for (final s in roster) s.cellFor(unit.id, type.id, ordinal)?.value,
    ].whereType<double>().toList();
    final total = roster.length;
    final avg = values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;
    final complete = total > 0 && values.length >= total;
    final color = _color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rXl,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rXl,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: AppRadii.rLg,
                ),
                child: Text(
                  multi ? '${type.abbr}${ordinal + 1}' : type.abbr,
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      type.description,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: AppRadii.rPill,
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : values.length / total,
                        minHeight: 5,
                        backgroundColor: NexoTheme.border,
                        valueColor: AlwaysStoppedAnimation(
                          complete ? NexoTheme.success : color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        l.tchGradeFilled(values.length, total),
                        if (avg != null)
                          l.tchGradeAverage(avg.toStringAsFixed(1)),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.h(AppSpacing.sm),
              Icon(
                unit.enabled
                    ? (values.isEmpty
                          ? Icons.add_circle_rounded
                          : Icons.edit_rounded)
                    : Icons.visibility_rounded,
                color: unit.enabled ? NexoTheme.primary : NexoTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
