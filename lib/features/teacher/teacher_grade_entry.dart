import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

/// Registro de una evaluación (unidad + tipo de nota) para toda la sección.
/// Equivale a una columna del "Listado de notas" de SIGMA: las notas nuevas
/// van a `Docente/InsertarNotas` y las existentes a `Docente/UpdateNota`, cada
/// grupo en una sola petición.
class TeacherGradeEntryScreen extends StatefulWidget {
  const TeacherGradeEntryScreen({
    super.key,
    required this.store,
    required this.course,
    required this.unit,
    required this.type,
    this.ordinal = 0,
  });
  final AppStore store;
  final TeacherSubject course;
  final TeacherUnitCatalog unit;
  final GradeType type;
  final int ordinal;

  static Future<bool?> open(
    BuildContext context, {
    required AppStore store,
    required TeacherSubject course,
    required TeacherUnitCatalog unit,
    required GradeType type,
    int ordinal = 0,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TeacherGradeEntryScreen(
        store: store,
        course: course,
        unit: unit,
        type: type,
        ordinal: ordinal,
      ),
    ),
  );

  /// Valida una nota escrita: número entre 0 y [max] con hasta 2 decimales
  /// (SIGMA recorta a 2 decimales). Devuelve el valor o `null` si es inválida.
  static double? parseGrade(String raw, double max) {
    final t = raw.trim().replaceAll(',', '.');
    if (t.isEmpty) return null;
    if (!RegExp(r'^\d{1,2}(\.\d{1,2})?$').hasMatch(t)) return null;
    final v = double.parse(t);
    if (v < 0 || v > max) return null;
    return v;
  }

  @override
  State<TeacherGradeEntryScreen> createState() =>
      _TeacherGradeEntryScreenState();
}

class _TeacherGradeEntryScreenState extends State<TeacherGradeEntryScreen> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, FocusNode> _focus = {};
  bool _saving = false;
  String _q = '';

  List<TeacherStudent> get _students {
    final list = [
      ...(widget.store.alumnosDe(widget.course.id).value ??
          const <TeacherStudent>[]),
    ]..sort((a, b) => a.displayName.compareTo(b.displayName));
    return list;
  }

  GradeCell? _cell(TeacherStudent s) =>
      s.cellFor(widget.unit.id, widget.type.id, widget.ordinal);

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  TextEditingController _ctrl(TeacherStudent s) =>
      _ctrls.putIfAbsent(s.code, () {
        final v = _cell(s)?.value;
        return TextEditingController(text: v == null ? '' : _fmt(v));
      });

  FocusNode _node(String code) => _focus.putIfAbsent(code, FocusNode.new);

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    super.dispose();
  }

  /// Filas modificadas listas para enviar, y cuántas son inválidas.
  ({List<GradeWrite> writes, int invalid, int missingIds}) _collect(
    List<TeacherStudent> students,
  ) {
    final writes = <GradeWrite>[];
    var invalid = 0;
    var missing = 0;
    for (final s in students) {
      final c = _ctrls[s.code];
      if (c == null) continue;
      final text = c.text.trim();
      final cell = _cell(s);
      if (text.isEmpty) continue;
      final v = TeacherGradeEntryScreen.parseGrade(text, widget.type.maxValue);
      if (v == null) {
        invalid++;
        continue;
      }
      if (cell?.value == v) continue;
      final mat = s.matriculaAsignaturaId ?? '';
      if (mat.isEmpty) {
        missing++;
        continue;
      }
      writes.add(
        GradeWrite(
          matricula: mat,
          unidadId: widget.unit.id,
          tipoNotaId: widget.type.id,
          notaId: cell?.notaId,
          nota: v,
        ),
      );
    }
    return (writes: writes, invalid: invalid, missingIds: missing);
  }

  Future<void> _save(List<TeacherStudent> students) async {
    final l = AppLocalizations.of(context);
    final r = _collect(students);
    if (r.invalid > 0) {
      ClipboardHelper.showError(
        context,
        l.tchGradeInvalidCount(r.invalid, _fmt(widget.type.maxValue)),
      );
      return;
    }
    if (r.writes.isEmpty) return;
    final inserts = r.writes.where((w) => !w.isUpdate).length;
    final updates = r.writes.length - inserts;
    final ok = await showTeacherConfirm(
      context,
      title: l.tchGradeConfirmTitle,
      icon: Icons.grading_rounded,
      lines: [
        '${widget.unit.name} · ${widget.type.abbr} — ${widget.type.description}',
        if (inserts > 0) l.tchGradeNewCount(inserts),
        if (updates > 0) l.tchGradeUpdatedCount(updates),
        if (r.missingIds > 0) l.tchGradeMissingIds(r.missingIds),
      ],
      confirm: l.actionSave,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final res = await widget.store.guardarNotas(widget.course, r.writes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.error != null) {
      ClipboardHelper.showError(context, res.error!);
      return;
    }
    HapticFeedback.heavyImpact();
    ClipboardHelper.showSuccess(
      context,
      parseSigmaMessage(res.message).text.ifBlank(l.tchSaved),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locked = !widget.unit.enabled;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final students = _students;
        final shown = _q.isEmpty
            ? students
            : students
                  .where(
                    (s) =>
                        s.displayName.toLowerCase().contains(_q) ||
                        s.code.toLowerCase().contains(_q),
                  )
                  .toList();
        final values = [
          for (final s in students)
            TeacherGradeEntryScreen.parseGrade(
              _ctrl(s).text,
              widget.type.maxValue,
            ),
        ].whereType<double>().toList();
        final avg = values.isEmpty
            ? null
            : values.reduce((a, b) => a + b) / values.length;
        final passed = values.where((v) => v >= widget.type.minPass).length;
        final pending = _collect(students);
        return Scaffold(
          backgroundColor: NexoTheme.bg,
          appBar: AppBar(
            title: Text('${widget.type.abbr} · ${widget.unit.name}'),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  color: NexoTheme.surface,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.type.description,
                        style: TextStyle(
                          fontSize: AppFont.body,
                          fontWeight: FontWeight.w700,
                          color: NexoTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          TeacherPill(
                            text: l.tchGradeFilled(
                              values.length,
                              students.length,
                            ),
                            color: NexoTheme.primary,
                          ),
                          if (avg != null)
                            TeacherPill(
                              text: l.tchGradeAverage(avg.toStringAsFixed(1)),
                              color: NexoTheme.info,
                            ),
                          if (values.isNotEmpty)
                            TeacherPill(
                              text: l.tchGradePassed(passed, values.length),
                              color: NexoTheme.success,
                            ),
                          TeacherPill(
                            text: '0 – ${_fmt(widget.type.maxValue)}',
                            color: NexoTheme.textMuted,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (locked)
                  TeacherBanner(
                    color: NexoTheme.textMuted,
                    icon: Icons.lock_outline_rounded,
                    text: l.docenteUnitLocked,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    0,
                  ),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => _q = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l.docenteSearchStudent,
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      filled: true,
                      fillColor: NexoTheme.card,
                      border: OutlineInputBorder(
                        borderRadius: AppRadii.rLg,
                        borderSide: BorderSide(color: NexoTheme.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadii.rLg,
                        borderSide: BorderSide(color: NexoTheme.border),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = shown[i];
                      final next = i + 1 < shown.length ? shown[i + 1] : null;
                      return _GradeRow(
                        student: s,
                        controller: _ctrl(s),
                        focus: _node(s.code),
                        original: _cell(s)?.value,
                        max: widget.type.maxValue,
                        minPass: widget.type.minPass,
                        readOnly: locked,
                        isLast: next == null,
                        onChanged: () => setState(() {}),
                        onSubmitted: () {
                          if (next != null) {
                            _node(next.code).requestFocus();
                          } else {
                            FocusScope.of(context).unfocus();
                          }
                        },
                      );
                    },
                  ),
                ),
                if (!locked && pending.writes.isNotEmpty)
                  SafeArea(
                    minimum: const EdgeInsets.all(AppSpacing.lg),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: NexoTheme.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rLg,
                        ),
                      ),
                      onPressed: _saving ? null : () => _save(students),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.cloud_upload_rounded),
                      label: Text(l.tchSaveChanges(pending.writes.length)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GradeRow extends StatelessWidget {
  final TeacherStudent student;
  final TextEditingController controller;
  final FocusNode focus;
  final double? original;
  final double max;
  final double minPass;
  final bool readOnly;
  final bool isLast;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  const _GradeRow({
    required this.student,
    required this.controller,
    required this.focus,
    required this.original,
    required this.max,
    required this.minPass,
    required this.readOnly,
    required this.isLast,
    required this.onChanged,
    required this.onSubmitted,
  });
  @override
  Widget build(BuildContext context) {
    final text = controller.text.trim();
    final v = TeacherGradeEntryScreen.parseGrade(text, max);
    final invalid = text.isNotEmpty && v == null;
    final changed = v != null && v != original;
    final color = invalid
        ? NexoTheme.danger
        : v == null
        ? NexoTheme.textMuted
        : v >= minPass
        ? NexoTheme.success
        : NexoTheme.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm + 2,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: invalid
              ? NexoTheme.danger
              : changed
              ? NexoTheme.primary
              : NexoTheme.border,
          width: invalid || changed ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          StudentAvatar(
            code: student.code,
            name: student.displayName,
            size: 38,
          ),
          const Gap.h(AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                Text(
                  student.code,
                  style: TextStyle(fontSize: 11, color: NexoTheme.textMuted),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: TextField(
              controller: controller,
              focusNode: focus,
              readOnly: readOnly,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: isLast
                  ? TextInputAction.done
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                LengthLimitingTextInputFormatter(5),
              ],
              onChanged: (_) => onChanged(),
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                fontSize: AppFont.h3,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '—',
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: NexoTheme.surface,
                border: OutlineInputBorder(
                  borderRadius: AppRadii.rMd,
                  borderSide: BorderSide(color: NexoTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadii.rMd,
                  borderSide: BorderSide(color: NexoTheme.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadii.rMd,
                  borderSide: BorderSide(color: NexoTheme.primary, width: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
