import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

Future<void> showTeacherStudentSheet({
  required BuildContext context,
  required AppStore store,
  required TeacherSubject course,
  required TeacherStudent student,
  int initialTab = 0,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AlumnoSheet(
      store: store,
      course: course,
      student: student,
      initialTab: initialTab,
    ),
  );
}

class _AlumnoSheet extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  final TeacherStudent student;
  final int initialTab;
  const _AlumnoSheet({
    required this.store,
    required this.course,
    required this.student,
    required this.initialTab,
  });
  @override
  State<_AlumnoSheet> createState() => _AlumnoSheetState();
}

class _AlumnoSheetState extends State<_AlumnoSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Unidades en las que SIGMA permite registrar notas ahora. `null` mientras
  /// carga o si el catálogo falla: en ese caso no se bloquea nada.
  Set<int>? _enabledUnits;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    if (!widget.store.asistenciaDe(widget.course.id).hasValue) {
      widget.store.loadDocenteAsistencia(widget.course);
    }
    widget.store
        .docenteUnidades(widget.course)
        .then((units) {
          if (!mounted || units.isEmpty) return;
          setState(() {
            _enabledUnits = {
              for (final u in units)
                if (u.enabled) u.id,
            };
          });
        })
        .catchError((_) {});
  }

  /// Versión vigente del alumno: tras guardar una nota el store recarga el
  /// roster y aquí se toma la fila nueva en vez del snapshot inicial.
  TeacherStudent get _student {
    final list = widget.store.alumnosDe(widget.course.id).value;
    if (list == null) return widget.student;
    for (final s in list) {
      if (s.code == widget.student.code) return s;
    }
    return widget.student;
  }

  bool _isLocked(EvaluationGrade e) {
    final enabled = _enabledUnits;
    if (enabled == null || e.tipoUnidadId == null) return false;
    return !enabled.contains(e.tipoUnidadId);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => DecoratedBox(
        decoration: BoxDecoration(
          color: NexoTheme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            const SizedBox(height: 8),
            _Header(student: widget.student),
            ColoredBox(
              color: NexoTheme.surface,
              child: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l.docenteTabNotas),
                  Tab(text: l.docenteTabAsistencia),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListenableBuilder(
                    listenable: widget.store,
                    builder: (context, _) => _NotasTab(
                      units: _student.units,
                      onEdit: _editEval,
                      isLocked: _isLocked,
                      scrollController: controller,
                    ),
                  ),
                  ListenableBuilder(
                    listenable: widget.store,
                    builder: (context, _) {
                      final st = widget.store.asistenciaDe(widget.course.id);
                      final att = st.value?.students
                          .where((a) => a.code == widget.student.code)
                          .firstOrNull;
                      return _AsistenciaTab(
                        loading: st.loading && !st.hasValue,
                        student: att,
                        scrollController: controller,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEval(EvaluationGrade eval) async {
    final l0 = AppLocalizations.of(context);
    if (_isLocked(eval)) {
      ClipboardHelper.showError(context, l0.docenteUnitLocked);
      return;
    }
    final matricula = _student.matriculaAsignaturaId ?? '';
    if (matricula.isEmpty ||
        (eval.tipoUnidadId ?? 0) == 0 ||
        (eval.tipoNotaId ?? 0) == 0) {
      // Sin estos ids SIGMA guardaría la nota en un registro equivocado.
      ClipboardHelper.showError(context, l0.docenteGradeMissingIds);
      return;
    }
    final ctrl = TextEditingController(text: eval.grade ?? '');
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (dctx) {
        final l = AppLocalizations.of(dctx);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Dialog(
            backgroundColor: NexoTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: NexoTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: NexoTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: NexoTheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          eval.description,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: NexoTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Form(
                    key: formKey,
                    child: TextFormField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autofocus: true,
                      style: TextStyle(color: NexoTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: l.docenteGradeLabel,
                        labelStyle: TextStyle(color: NexoTheme.textSecondary),
                        prefixIcon: Icon(
                          Icons.grade_rounded,
                          color: NexoTheme.textSecondary,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: NexoTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: NexoTheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: NexoTheme.danger),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: NexoTheme.danger,
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (v) {
                        final t = (v ?? '').trim().replaceAll(',', '.');
                        if (t.isEmpty) return l.docenteGradeEnter;
                        final n = double.tryParse(t);
                        if (n == null) return l.docenteGradeInvalidNumber;
                        if (n < 0 || n > 20) return l.docenteGradeRange;
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dctx).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: NexoTheme.border),
                          ),
                          child: Text(
                            l.actionCancel,
                            style: TextStyle(
                              color: NexoTheme.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.of(dctx).pop(ctrl.text.trim());
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: NexoTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            l.actionSave,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (result == null) return;
    final value = double.tryParse(result.replaceAll(',', '.'));
    if (value == null) return;
    final res = await widget.store.guardarNotas(widget.course, [
      GradeWrite(
        matricula: matricula,
        unidadId: eval.tipoUnidadId ?? 0,
        tipoNotaId: eval.tipoNotaId ?? 0,
        notaId: eval.notaId,
        nota: value,
      ),
    ]);
    if (!mounted) return;
    if (res.error == null) {
      ClipboardHelper.showSuccess(context, '${eval.description}: $result');
    } else {
      ClipboardHelper.showError(context, res.error!);
    }
  }
}

class _Header extends StatelessWidget {
  final TeacherStudent student;
  const _Header({required this.student});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          StudentAvatar(
            code: student.code,
            name: student.displayName,
            size: 52,
          ),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.displayName,
                  style: TextStyle(
                    fontSize: AppFont.h3,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      student.code,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: NexoTheme.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    IconButton(
                      iconSize: 16,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ClipboardHelper.copyAndShow(
                          context,
                          student.code,
                          label: AppLocalizations.of(context).actionCodeCopied,
                        );
                      },
                      icon: Icon(
                        Icons.copy_rounded,
                        color: NexoTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotasTab extends StatelessWidget {
  final List<TeacherUnit> units;
  final ValueChanged<EvaluationGrade> onEdit;
  final bool Function(EvaluationGrade) isLocked;
  final ScrollController scrollController;
  const _NotasTab({
    required this.units,
    required this.onEdit,
    required this.isLocked,
    required this.scrollController,
  });
  @override
  Widget build(BuildContext context) {
    if (units.isEmpty) {
      return Center(
        child: Text(
          AppLocalizations.of(context).docenteNoGrades,
          style: TextStyle(color: NexoTheme.textMuted),
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final u in units) ...[
          _PromedioCard(title: u.name, average: u.average, weight: u.weight),
          const SizedBox(height: 12),
          for (final e in u.grades)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _EvalRow(
                eval: e,
                locked: isLocked(e),
                onEdit: () => onEdit(e),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _PromedioCard extends StatelessWidget {
  final String title;
  final double? average;
  final double weight;
  const _PromedioCard({
    required this.title,
    this.average,
    required this.weight,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = average != null
        ? gradeColor(average!.toStringAsFixed(1))
        : NexoTheme.textMuted;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  average != null ? average!.toStringAsFixed(2) : '—',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l.docenteCoursePercentGraded(weight.toStringAsFixed(0)),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvalRow extends StatelessWidget {
  final EvaluationGrade eval;
  final bool locked;
  final VoidCallback onEdit;
  const _EvalRow({
    required this.eval,
    required this.onEdit,
    this.locked = false,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pending = eval.grade == null || eval.grade!.trim().isEmpty;
    return InkWell(
      borderRadius: AppRadii.rLg,
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: NexoTheme.card,
          borderRadius: AppRadii.rLg,
          border: Border.all(color: NexoTheme.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eval.description,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textPrimary,
                    ),
                  ),
                  Text(
                    eval.code,
                    style: TextStyle(
                      fontSize: AppFont.small,
                      color: NexoTheme.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            if (pending)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: NexoTheme.warning.withValues(alpha: 0.14),
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  l.docenteEvalPending,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.warning,
                    letterSpacing: 0.5,
                  ),
                ),
              )
            else
              Text(
                eval.grade!,
                style: TextStyle(
                  fontSize: AppFont.h3,
                  fontWeight: FontWeight.w900,
                  color: gradeColor(eval.grade),
                ),
              ),
            const SizedBox(width: 4),
            Icon(
              locked ? Icons.lock_outline_rounded : Icons.edit_outlined,
              size: 16,
              color: NexoTheme.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _AsistenciaTab extends StatelessWidget {
  final bool loading;
  final AttendanceStudent? student;
  final ScrollController scrollController;
  const _AsistenciaTab({
    required this.loading,
    required this.student,
    required this.scrollController,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (loading) return const _SkeletonList();
    final marks = [...?student?.marks]
      ..sort((a, b) => b.date.compareTo(a.date));
    if (marks.isEmpty) {
      return Center(
        child: Text(
          l.docenteNoAttendanceRecords,
          style: TextStyle(color: NexoTheme.textMuted),
        ),
      );
    }
    final presentes = marks
        .where((m) => m.state == AttendanceCode.present)
        .length;
    final pct =
        student?.percent?.round() ?? (presentes / marks.length * 100).round();
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _AsistenciaResumen(total: marks.length, presentes: presentes, pct: pct),
        const SizedBox(height: 12),
        for (final m in marks) _DiaRow(mark: m),
      ],
    );
  }
}

class _AsistenciaResumen extends StatelessWidget {
  final int total;
  final int presentes;
  final int pct;
  const _AsistenciaResumen({
    required this.total,
    required this.presentes,
    required this.pct,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = pct >= 80
        ? NexoTheme.success
        : pct >= 65
        ? NexoTheme.warning
        : NexoTheme.danger;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.docenteAttendanceLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$pct%',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          Text(
            l.docenteSessionsRegisteredCount(
              presentes.toString(),
              total.toString(),
            ),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _DiaRow extends StatelessWidget {
  final AttendanceMark mark;
  const _DiaRow({required this.mark});
  @override
  Widget build(BuildContext context) {
    final look = attendanceLook(context, mark.state);
    final d = mark.date;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(look.icon, color: look.color, size: 20),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Text(
              '${Fmt.dayLabel(d.weekday)} ${Fmt.shortDate(d)} · '
              '${two(d.hour)}:${two(d.minute)}',
              style: TextStyle(
                fontSize: AppFont.body,
                color: NexoTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            look.label,
            style: TextStyle(
              fontSize: AppFont.small,
              color: look.color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: 5,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const Skeleton(height: 60, radius: 14),
    );
  }
}
