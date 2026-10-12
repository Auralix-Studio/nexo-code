import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_grade_entry.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/empty_state.dart';

/// Columna de la tabla de notas: una evaluación (unidad + tipo + posición) o
/// el promedio de una unidad.
class GradeGridColumn {
  final TeacherUnitCatalog unit;
  final int? tipoNotaId;
  final int ordinal;
  final String label;
  const GradeGridColumn({
    required this.unit,
    required this.label,
    this.tipoNotaId,
    this.ordinal = 0,
  });

  bool get isAverage => tipoNotaId == null;
}

/// "UNIDAD 1" → "U1"; "INTEGRAL" → "INT".
String unitShortLabel(String name) {
  final m = RegExp(r'UNIDAD\s*(\d+)', caseSensitive: false).firstMatch(name);
  if (m != null) return 'U${m.group(1)}';
  final t = name.trim();
  return t.length <= 3 ? t : t.substring(0, 3).toUpperCase();
}

/// Columnas a partir de las notas ya registradas: por cada unidad del
/// catálogo con datos, sus evaluaciones (en el orden de SIGMA) y su promedio.
List<GradeGridColumn> gradeGridColumns(
  List<TeacherUnitCatalog> units,
  List<TeacherStudent> roster,
) {
  final out = <GradeGridColumn>[];
  for (final u in units) {
    final keys = <(int, int)>{};
    final abbr = <int, String>{};
    for (final s in roster) {
      for (final c in s.cells.where((c) => c.unidadId == u.id)) {
        keys.add((c.tipoNotaId, c.ordinal));
      }
      for (final tu in s.units.where((x) => x.tipoUnidadId == u.id)) {
        for (final g in tu.grades) {
          if (g.tipoNotaId != null) abbr[g.tipoNotaId!] = g.code;
        }
      }
    }
    if (keys.isEmpty) continue;
    final sorted = keys.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2 - b.$2);
    final multi = <int>{
      for (final k in sorted)
        if (k.$2 > 0) k.$1,
    };
    for (final (tipo, ord) in sorted) {
      final base = abbr[tipo] ?? '#$tipo';
      out.add(
        GradeGridColumn(
          unit: u,
          tipoNotaId: tipo,
          ordinal: ord,
          label: multi.contains(tipo) ? '$base${ord + 1}' : base,
        ),
      );
    }
    out.add(GradeGridColumn(unit: u, label: ''));
  }
  return out;
}

/// Sábana de notas de la sección, como el "Listado de notas" de SIGMA pero
/// legible en el celular: la columna de alumnos queda fija y el resto se
/// desplaza. Tocar una evaluación abre su registro; tocar un alumno, su ficha.
class TeacherGradesGrid extends StatelessWidget {
  const TeacherGradesGrid({
    super.key,
    required this.store,
    required this.course,
    required this.units,
    required this.roster,
  });
  final AppStore store;
  final TeacherSubject course;
  final List<TeacherUnitCatalog> units;
  final List<TeacherStudent> roster;

  static const _rowH = 44.0;
  static const _headH = 26.0;
  static const _nameW = 168.0;
  static const _cellW = 50.0;
  static const _avgW = 54.0;
  static const _finalW = 58.0;

  Future<void> _openColumn(BuildContext context, GradeGridColumn col) async {
    final l = AppLocalizations.of(context);
    try {
      final types = await store.docenteTiposNota(col.unit.id);
      final type = types.where((t) => t.id == col.tipoNotaId).firstOrNull;
      if (!context.mounted) return;
      if (type == null) {
        ClipboardHelper.showError(context, l.tchTypesLoadError);
        return;
      }
      await TeacherGradeEntryScreen.open(
        context,
        store: store,
        course: course,
        unit: col.unit,
        type: type,
        ordinal: col.ordinal,
      );
    } catch (_) {
      if (context.mounted) {
        ClipboardHelper.showError(context, l.tchTypesLoadError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final students = [...roster]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    final cols = gradeGridColumns(units, students);
    if (cols.isEmpty) {
      return EmptyState(
        icon: Icons.table_chart_outlined,
        title: l.tchGridEmpty,
      );
    }

    String fmt(double? v) {
      if (v == null) return '';
      return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
    }

    double? valueOf(TeacherStudent s, GradeGridColumn c) {
      if (c.isAverage) {
        return s.units
            .where((u) => u.tipoUnidadId == c.unit.id)
            .firstOrNull
            ?.average;
      }
      return s.cellFor(c.unit.id, c.tipoNotaId!, c.ordinal)?.value;
    }

    double? finalOf(TeacherStudent s) {
      final v = double.tryParse((s.grade ?? '').replaceAll(',', '.'));
      return v == null || v <= 0 ? null : v;
    }

    final border = BorderSide(color: NexoTheme.border);
    Widget cell(
      String text, {
      required double width,
      Color? color,
      bool bold = false,
      Color? bg,
    }) => Container(
      width: width,
      height: _rowH,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: border, left: border),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: AppFont.body,
          fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
          color: color ?? NexoTheme.textPrimary,
        ),
      ),
    );

    Widget head(
      String text, {
      required double width,
      double height = _headH,
      VoidCallback? onTap,
      Color? color,
    }) => InkWell(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: NexoTheme.surface,
          border: Border(bottom: border, left: border),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: color ?? NexoTheme.textSecondary,
            decoration: onTap == null ? null : TextDecoration.underline,
            decorationColor: color ?? NexoTheme.textSecondary,
          ),
        ),
      ),
    );

    // Encabezado de unidades: cada unidad ocupa el ancho de sus columnas.
    final unitSpans = <(TeacherUnitCatalog, double)>[];
    for (final c in cols) {
      final w = c.isAverage ? _avgW : _cellW;
      if (unitSpans.isNotEmpty && unitSpans.last.$1.id == c.unit.id) {
        unitSpans.last = (c.unit, unitSpans.last.$2 + w);
      } else {
        unitSpans.add((c.unit, w));
      }
    }

    final names = Column(
      children: [
        Container(
          width: _nameW,
          height: _headH * 2,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            border: Border(bottom: border),
          ),
          child: Text(
            l.tchGridStudent,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: NexoTheme.textSecondary,
            ),
          ),
        ),
        for (final s in students)
          InkWell(
            onTap: () => showTeacherStudentSheet(
              context: context,
              store: store,
              course: course,
              student: s,
            ),
            child: Container(
              width: _nameW,
              height: _rowH,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              decoration: BoxDecoration(border: Border(bottom: border)),
              child: Text(
                s.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.w600,
                  color: NexoTheme.textPrimary,
                  height: 1.15,
                ),
              ),
            ),
          ),
      ],
    );

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final (u, w) in unitSpans)
              head(
                unitShortLabel(u.name),
                width: w,
                color: u.enabled ? NexoTheme.primary : null,
              ),
            head(l.tchGridFinal, width: _finalW, height: _headH),
          ],
        ),
        Row(
          children: [
            for (final c in cols)
              c.isAverage
                  ? head(l.tchGridUnitAvg, width: _avgW)
                  : head(
                      c.label,
                      width: _cellW,
                      onTap: () => _openColumn(context, c),
                    ),
            head('', width: _finalW),
          ],
        ),
        for (final s in students)
          Row(
            children: [
              for (final c in cols)
                if (valueOf(s, c) case final v)
                  cell(
                    fmt(v),
                    width: c.isAverage ? _avgW : _cellW,
                    color: gradeColor(v?.toString()),
                    bold: c.isAverage,
                    bg: c.isAverage ? NexoTheme.surface : null,
                  ),
              if (finalOf(s) case final f)
                cell(
                  fmt(f),
                  width: _finalW,
                  color: gradeColor(f?.toString()),
                  bold: true,
                  bg: NexoTheme.primary.withValues(alpha: 0.06),
                ),
            ],
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.tchGridHint,
          style: TextStyle(fontSize: 11, color: NexoTheme.textMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rXl,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              names,
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: table,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
