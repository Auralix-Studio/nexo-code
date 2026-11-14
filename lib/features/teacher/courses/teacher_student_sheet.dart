import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/passing_rule.dart';
import 'package:nexo/features/teacher/widgets/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/progress_ring.dart';
import 'package:nexo/shared/widgets/reveal.dart';
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
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.xxl),
          ),
        ),
        child: Column(
          children: [
            const SheetHandle(),
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
      barrierColor: Colors.black.withValues(alpha: AppOpacity.scrim),
      builder: (dctx) {
        final l = AppLocalizations.of(dctx);
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.dialogMaxWidth),
          child: Dialog(
            backgroundColor: NexoTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.all(
                Radius.circular(AppSpacing.xxl),
              ),
              side: BorderSide(color: NexoTheme.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: AppSizes.avatarMd,
                        height: AppSizes.avatarMd,
                        decoration: BoxDecoration(
                          color: NexoTheme.primary.withValues(
                            alpha: AppOpacity.tint,
                          ),
                          borderRadius: AppRadii.rSm,
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          color: NexoTheme.primary,
                          size: AppIcon.xl,
                        ),
                      ),
                      const Gap.h(AppSpacing.md),
                      Expanded(
                        child: Text(
                          eval.description,
                          style: TextStyle(
                            fontSize: AppFont.h3,
                            fontWeight: FontWeight.w800,
                            color: NexoTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Gap(AppSpacing.xl),
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
                          borderRadius: AppRadii.rMd,
                          borderSide: BorderSide(color: NexoTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: AppRadii.rMd,
                          borderSide: BorderSide(
                            color: NexoTheme.primary,
                            width: 2,
                          ),
                        ),
                        errorBorder: const OutlineInputBorder(
                          borderRadius: AppRadii.rMd,
                          borderSide: BorderSide(color: NexoTheme.danger),
                        ),
                        focusedErrorBorder: const OutlineInputBorder(
                          borderRadius: AppRadii.rMd,
                          borderSide: BorderSide(
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
                        if (n < 0 || n > PassingRule.scaleMax) {
                          return l.docenteGradeRange;
                        }
                        return null;
                      },
                    ),
                  ),
                  const Gap(AppSpacing.xxl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(dctx).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(AppSizes.button),
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.rMd,
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
                      const Gap.h(AppSpacing.md),
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
                            minimumSize: const Size.fromHeight(AppSizes.button),
                            elevation: 0,
                            shape: const RoundedRectangleBorder(
                              borderRadius: AppRadii.rMd,
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
            size: AppSizes.avatarLg,
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
                const Gap(AppSpacing.xxs),
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
                      iconSize: AppIcon.sm,
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
        child: EmptyState(
          icon: Icons.grading_outlined,
          title: AppLocalizations.of(context).docenteNoGrades,
        ),
      );
    }
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final (i, u) in units.indexed)
          Reveal.list(
            index: i,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PromedioCard(
                  title: u.name,
                  average: u.average,
                  weight: u.weight,
                ),
                const Gap(AppSpacing.md),
                for (final e in u.grades)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _EvalRow(
                      eval: e,
                      locked: isLocked(e),
                      onEdit: () => onEdit(e),
                    ),
                  ),
                const Gap(AppSpacing.lg),
              ],
            ),
          ),
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
        color: color.withValues(alpha: AppOpacity.soft),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: color.withValues(alpha: AppOpacity.outline)),
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
                    fontSize: AppFont.caption,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const Gap(AppSpacing.xs),
                Text(
                  average != null ? average!.toStringAsFixed(2) : '—',
                  style: TextStyle(
                    fontSize: AppFont.metric,
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
    return TeacherCard(
      radius: AppRadii.rLg,
      onTap: onEdit,
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
            TeacherPill(text: l.docenteEvalPending, color: NexoTheme.warning)
          else
            Text(
              eval.grade!,
              style: TextStyle(
                fontSize: AppFont.h3,
                fontWeight: FontWeight.w900,
                color: gradeColor(eval.grade),
              ),
            ),
          const Gap.h(AppSpacing.sm),
          Icon(
            locked ? Icons.lock_outline_rounded : Icons.edit_outlined,
            size: AppIcon.sm,
            color: NexoTheme.textMuted,
          ),
        ],
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
        child: EmptyState(
          icon: Icons.event_busy_outlined,
          title: l.docenteNoAttendanceRecords,
        ),
      );
    }
    int count(int state) => marks.where((m) => m.state == state).length;
    final present = count(AttendanceCode.present);
    final pct =
        student?.percent?.round() ?? (present / marks.length * 100).round();
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Reveal.list(
          child: _AsistenciaResumen(
            pct: pct,
            present: present,
            absent: count(AttendanceCode.absent),
            justified: count(AttendanceCode.justified),
          ),
        ),
        const Gap(AppSpacing.md),
        Reveal.list(
          index: 1,
          child: TeacherCard(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              children: [
                for (final (i, m) in marks.indexed) ...[
                  if (i > 0) Divider(height: 1, color: NexoTheme.divider),
                  _DiaRow(mark: m),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AsistenciaResumen extends StatelessWidget {
  final int pct;
  final int present;
  final int absent;
  final int justified;
  const _AsistenciaResumen({
    required this.pct,
    required this.present,
    required this.absent,
    required this.justified,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = attendanceColor(pct);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppOpacity.soft),
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: color.withValues(alpha: AppOpacity.outline)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            ProgressRing(percent: pct, color: color),
            const Gap.h(AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.docenteAttendanceLabel,
                    style: TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: NexoTheme.textMuted,
                    ),
                  ),
                  const Gap(AppSpacing.sm),
                  SplitBar(
                    parts: attendanceParts(
                      present: present,
                      absent: absent,
                      justified: justified,
                    ),
                  ),
                  const Gap(AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TeacherStat(
                          value: present,
                          label: l.tchKpiPresent,
                          color: NexoTheme.success,
                        ),
                      ),
                      Expanded(
                        child: TeacherStat(
                          value: justified,
                          label: l.tchKpiJustified,
                          color: NexoTheme.warning,
                        ),
                      ),
                      Expanded(
                        child: TeacherStat(
                          value: absent,
                          label: l.tchKpiAbsent,
                          color: NexoTheme.danger,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: look.color.withValues(alpha: AppOpacity.tint),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: AppSizes.iconBadge,
              child: Icon(look.icon, color: look.color, size: AppIcon.sm),
            ),
          ),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${Fmt.dayLabel(d.weekday)} ${Fmt.shortDate(d)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    color: NexoTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${two(d.hour)}:${two(d.minute)}',
                  style: TextStyle(
                    fontSize: AppFont.caption,
                    color: NexoTheme.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const Gap.h(AppSpacing.sm),
          TeacherPill(text: look.label, color: look.color),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();
  @override
  Widget build(BuildContext context) =>
      const TeacherListSkeleton(count: 5, height: 60);
}
