import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

/// Registro de asistencia de una sesión (equivale a "Asistencia › Registrar ›
/// Listado" de SIGMA, `Docente/InsertaRegistroAsistencia`).
///
/// Pensado para el celular en el aula: "todos presentes" y marcar solo las
/// faltas, o pase de lista uno por uno con la foto del alumno y botones
/// grandes. Como en SIGMA, al registrar solo se elige Asistió/Faltó; las
/// justificaciones se hacen después corrigiendo la sesión.
class TeacherTakeAttendanceScreen extends StatefulWidget {
  const TeacherTakeAttendanceScreen({
    super.key,
    required this.store,
    required this.course,
    this.initialDate,
  });
  final AppStore store;
  final TeacherSubject course;

  /// Fecha de la sesión a registrar (p. ej. una clase pasada que quedó sin
  /// asistencia). Por defecto, hoy según la hora de SIGMA.
  final DateTime? initialDate;

  static Future<bool?> open(
    BuildContext context, {
    required AppStore store,
    required TeacherSubject course,
    DateTime? initialDate,
  }) => Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TeacherTakeAttendanceScreen(
        store: store,
        course: course,
        initialDate: initialDate,
      ),
    ),
  );

  @override
  State<TeacherTakeAttendanceScreen> createState() =>
      _TeacherTakeAttendanceScreenState();
}

class _TeacherTakeAttendanceScreenState
    extends State<TeacherTakeAttendanceScreen> {
  late DateTime _date;
  DateTime? _serverNow;
  List<TeacherUnitCatalog> _units = const [];
  TeacherUnitCatalog? _unit;
  bool _loadingUnits = true;
  String? _unitsError;

  /// código → estado elegido (1 asistió / 2 faltó).
  final Map<String, int> _marks = {};
  bool _oneByOne = false;
  bool _saving = false;
  final _pager = PageController();
  int _page = 0;

  /// Se recuperó un borrador guardado en el dispositivo.
  bool _draftRestored = false;

  @override
  void initState() {
    super.initState();
    final start = widget.initialDate ?? DateTime.now();
    _date = DateTime(start.year, start.month, start.day);
    final s = widget.store;
    if (!s.asistenciaDe(widget.course.id).hasValue) {
      s.loadDocenteAsistencia(widget.course);
    }
    _loadUnits();
    s.docenteHoraServidor().then((t) {
      if (!mounted) return;
      setState(() {
        _serverNow = t;
        if (widget.initialDate == null) {
          _date = DateTime(t.year, t.month, t.day);
        }
      });
      _restoreDraft();
    });
  }

  /// Recupera lo marcado en esta misma fecha y unidad si la pantalla se cerró
  /// (o falló el envío) antes de registrar.
  void _restoreDraft() {
    final unit = _unit;
    if (unit == null || _marks.isNotEmpty) return;
    final draft = widget.store.docenteBorradorAsistencia(
      widget.course.id,
      _date,
      unit.id,
    );
    if (draft.isEmpty) return;
    setState(() {
      _marks.addAll(draft);
      _draftRestored = true;
    });
  }

  void _persistDraft() {
    final unit = _unit;
    if (unit == null) return;
    widget.store.guardarBorradorAsistencia(
      widget.course.id,
      _date,
      unit.id,
      Map.of(_marks),
    );
  }

  void _discardDraft() {
    final unit = _unit;
    setState(() {
      _marks.clear();
      _draftRestored = false;
    });
    if (unit != null) {
      widget.store.borrarBorradorAsistencia(widget.course.id, _date, unit.id);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  Future<void> _loadUnits() async {
    setState(() {
      _loadingUnits = true;
      _unitsError = null;
    });
    try {
      final units = await widget.store.docenteUnidadesAsistencia(widget.course);
      if (!mounted) return;
      setState(() {
        _units = units;
        _unit = units.where((u) => u.enabled).firstOrNull;
        _loadingUnits = false;
      });
      _restoreDraft();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingUnits = false;
        _unitsError = e.toString();
      });
    }
  }

  List<AttendanceStudent> _students(AttendanceSheet sheet) {
    final list = [...sheet.students]..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  void _mark(AttendanceStudent s, int state) {
    HapticFeedback.selectionClick();
    setState(() => _marks[s.code] = state);
    _persistDraft();
  }

  void _markRestPresent(List<AttendanceStudent> students) {
    HapticFeedback.mediumImpact();
    setState(() {
      for (final s in students) {
        if (!s.isSuspended) {
          _marks.putIfAbsent(s.code, () => AttendanceCode.present);
        }
      }
    });
    _persistDraft();
  }

  Future<void> _pickDate() async {
    final today = _serverNow ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      // SIGMA permite registrar hasta 150 días atrás y nunca en el futuro.
      firstDate: today.subtract(const Duration(days: 150)),
      lastDate: today,
    );
    if (picked == null || picked == _date) return;
    _persistDraft();
    setState(() {
      _date = picked;
      _marks.clear();
      _draftRestored = false;
    });
    _restoreDraft();
  }

  void _pickUnit(TeacherUnitCatalog u) {
    if (u.id == _unit?.id) return;
    _persistDraft();
    setState(() {
      _unit = u;
      _marks.clear();
      _draftRestored = false;
    });
    _restoreDraft();
  }

  int _count(List<AttendanceStudent> active, int state) =>
      active.where((s) => _marks[s.code] == state).length;

  Future<void> _save(List<AttendanceStudent> students) async {
    final l = AppLocalizations.of(context);
    final unit = _unit;
    if (unit == null) return;
    final pending = students
        .where((s) => !s.isSuspended && !_marks.containsKey(s.code))
        .length;
    if (pending > 0) {
      ClipboardHelper.showError(context, l.tchAttPending(pending));
      return;
    }
    final active = students.where((s) => !s.isSuspended).toList();
    final present = _count(active, AttendanceCode.present);
    final absent = _count(active, AttendanceCode.absent);
    final suspended = students.length - active.length;
    final now = await widget.store.docenteHoraServidor();
    if (!mounted) return;
    // Fecha elegida + hora actual del servidor, como el cliente oficial.
    final fecha = DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
      now.second,
    );
    final ok = await showTeacherConfirm(
      context,
      title: l.tchAttConfirmTitle,
      icon: Icons.fact_check_rounded,
      lines: [
        '${Fmt.dayLabel(fecha.weekday)} ${Fmt.shortDate(fecha)} · '
            '${two(fecha.hour)}:${two(fecha.minute)}',
        unit.name,
        l.tchAttSummary(present, absent),
        if (suspended > 0) l.tchAttSuspendedCount(suspended),
      ],
      confirm: l.tchAttRegister,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final res = await widget.store.registrarAsistencia(
      widget.course,
      fecha: fecha,
      unidadId: unit.id,
      marks: [
        for (final s in students)
          (
            student: s,
            state: s.isSuspended
                ? AttendanceCode.suspended
                : _marks[s.code] ?? AttendanceCode.present,
          ),
      ],
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.error != null) {
      // El borrador sigue en el dispositivo: se puede reintentar luego.
      ClipboardHelper.showError(context, res.error!);
      return;
    }
    widget.store.borrarBorradorAsistencia(widget.course.id, _date, unit.id);
    HapticFeedback.heavyImpact();
    ClipboardHelper.showSuccess(
      context,
      parseSigmaMessage(res.message).text.ifBlank(l.docenteAttendanceSaved),
    );
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.asistenciaDe(widget.course.id);
        final sheet = state.value;
        final students = sheet == null
            ? const <AttendanceStudent>[]
            : _students(sheet);
        final active = students.where((s) => !s.isSuspended).toList();
        final done = active.where((s) => _marks.containsKey(s.code)).length;
        final alreadyToday =
            sheet != null &&
            _unit != null &&
            sheet.students.any(
              (s) => s.marksOn(_date).any((m) => m.tipoUnidadId == _unit!.id),
            );
        return Scaffold(
          backgroundColor: NexoTheme.bg,
          appBar: AppBar(
            title: Text(l.tchAttTitle),
            actions: [
              if (students.isNotEmpty)
                IconButton(
                  tooltip: _oneByOne ? l.tchAttModeList : l.tchAttModeOneByOne,
                  icon: Icon(
                    _oneByOne ? Icons.view_list_rounded : Icons.style_rounded,
                  ),
                  onPressed: () => setState(() => _oneByOne = !_oneByOne),
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                _ContextBar(
                  course: widget.course,
                  date: _date,
                  onPickDate: _pickDate,
                  units: _units,
                  unit: _unit,
                  loadingUnits: _loadingUnits,
                  onUnit: _pickUnit,
                ),
                if (_draftRestored)
                  TeacherBanner(
                    color: NexoTheme.info,
                    icon: Icons.restore_rounded,
                    text: l.tchDraftRestored,
                    action: l.tchDraftDiscard,
                    onAction: _discardDraft,
                  ),
                if (alreadyToday)
                  TeacherBanner(
                    color: NexoTheme.warning,
                    icon: Icons.info_outline_rounded,
                    text: l.tchAttAlreadyRegistered,
                  ),
                Expanded(child: _body(context, state, students, active)),
                if (students.isNotEmpty && _unit != null)
                  _BottomBar(
                    done: done,
                    total: active.length,
                    present: _count(active, AttendanceCode.present),
                    absent: _count(active, AttendanceCode.absent),
                    saving: _saving,
                    onRestPresent: done < active.length
                        ? () => _markRestPresent(students)
                        : null,
                    onSave: done == active.length
                        ? () => _save(students)
                        : null,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(
    BuildContext context,
    AsyncValue<AttendanceSheet> state,
    List<AttendanceStudent> students,
    List<AttendanceStudent> active,
  ) {
    final l = AppLocalizations.of(context);
    if ((state.loading && !state.hasValue) || _loadingUnits) {
      return const TeacherListSkeleton();
    }
    if (state.error != null && !state.hasValue) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.tchAttLoadError,
          color: NexoTheme.danger,
          onRetry: () => widget.store.loadDocenteAsistencia(widget.course),
        ),
      );
    }
    if (_unitsError != null) {
      return Center(
        child: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: l.tchUnitsLoadError,
          color: NexoTheme.danger,
          onRetry: _loadUnits,
        ),
      );
    }
    if (_unit == null) {
      return Center(
        child: EmptyState(
          icon: Icons.lock_clock_rounded,
          title: l.docenteNoUnitEnabled,
        ),
      );
    }
    if (students.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: l.tchAttNoStudents,
        ),
      );
    }
    if (_oneByOne) return _oneByOneView(context, active);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      itemCount: students.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final s = students[i];
        return _StudentRow(
          index: i + 1,
          student: s,
          state: s.isSuspended ? AttendanceCode.suspended : _marks[s.code],
          onMark: s.isSuspended ? null : (v) => _mark(s, v),
        );
      },
    );
  }

  Widget _oneByOneView(BuildContext context, List<AttendanceStudent> active) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            0,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.rPill,
            child: LinearProgressIndicator(
              value: active.isEmpty ? 0 : (_page + 1) / active.length,
              minHeight: 6,
              backgroundColor: NexoTheme.border,
            ),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pager,
            itemCount: active.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final s = active[i];
              return _OneByOneCard(
                student: s,
                position: l.tchAttPosition(i + 1, active.length),
                state: _marks[s.code],
                onMark: (v) {
                  _mark(s, v);
                  if (i < active.length - 1) {
                    Future.delayed(const Duration(milliseconds: 220), () {
                      if (mounted && _pager.hasClients) {
                        _pager.nextPage(
                          duration: AppDurations.normal,
                          curve: Curves.easeOutCubic,
                        );
                      }
                    });
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ContextBar extends StatelessWidget {
  final TeacherSubject course;
  final DateTime date;
  final VoidCallback onPickDate;
  final List<TeacherUnitCatalog> units;
  final TeacherUnitCatalog? unit;
  final bool loadingUnits;
  final ValueChanged<TeacherUnitCatalog> onUnit;
  const _ContextBar({
    required this.course,
    required this.date,
    required this.onPickDate,
    required this.units,
    required this.unit,
    required this.loadingUnits,
    required this.onUnit,
  });
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final block = course.ongoingBlock(now);
    return Container(
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
            course.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: AppFont.subtitle,
              fontWeight: FontWeight.w800,
              color: NexoTheme.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ActionChip(
                  avatar: const Icon(Icons.event_rounded, size: 16),
                  label: Text(
                    '${Fmt.dayLabel(date.weekday)} ${Fmt.shortDate(date)}',
                  ),
                  onPressed: onPickDate,
                ),
                if (block != null) ...[
                  const SizedBox(width: 6),
                  Chip(
                    avatar: const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 16,
                      color: NexoTheme.success,
                    ),
                    label: Text('${block.start}–${block.end}'),
                  ),
                ],
                for (final u in units) ...[
                  const SizedBox(width: 6),
                  ChoiceChip(
                    avatar: u.enabled
                        ? null
                        : const Icon(Icons.lock_outline_rounded, size: 14),
                    label: Text(u.name),
                    selected: unit?.id == u.id,
                    onSelected: u.enabled ? (_) => onUnit(u) : null,
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

class _StudentRow extends StatelessWidget {
  final int index;
  final AttendanceStudent student;
  final int? state;
  final ValueChanged<int>? onMark;
  const _StudentRow({
    required this.index,
    required this.student,
    required this.state,
    required this.onMark,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = student;
    return AnimatedContainer(
      duration: AppDurations.fast,
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: state == AttendanceCode.absent
            ? NexoTheme.danger.withValues(alpha: 0.06)
            : NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: state == AttendanceCode.absent
              ? NexoTheme.danger.withValues(alpha: 0.4)
              : NexoTheme.border,
        ),
      ),
      child: Row(
        children: [
          StudentAvatar(code: s.code, name: s.name, size: 42),
          const Gap.h(AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                // Wrap: con letra grande en un celular angosto el código y el
                // porcentaje pasan a otra línea en vez de desbordar.
                Wrap(
                  spacing: 6,
                  children: [
                    Text(
                      '$index · ${s.code}',
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textMuted,
                      ),
                    ),
                    if (s.percent != null) ...[
                      Text(
                        '${s.percent!.round()}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: s.atRisk
                              ? NexoTheme.danger
                              : NexoTheme.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onMark == null)
            TeacherPill(text: l.tchStateSuspended, color: NexoTheme.info)
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AttendanceToggle(
                  icon: Icons.check_rounded,
                  color: NexoTheme.success,
                  selected: state == AttendanceCode.present,
                  tooltip: l.tchStatePresent,
                  onTap: () => onMark!(AttendanceCode.present),
                ),
                const SizedBox(width: 6),
                AttendanceToggle(
                  icon: Icons.close_rounded,
                  color: NexoTheme.danger,
                  selected: state == AttendanceCode.absent,
                  tooltip: l.tchStateAbsent,
                  onTap: () => onMark!(AttendanceCode.absent),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OneByOneCard extends StatelessWidget {
  final AttendanceStudent student;
  final String position;
  final int? state;
  final ValueChanged<int> onMark;
  const _OneByOneCard({
    required this.student,
    required this.position,
    required this.state,
    required this.onMark,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = student;
    Widget big(String label, IconData icon, Color color, int value) {
      final selected = state == value;
      return Expanded(
        child: SizedBox(
          height: 72,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: selected ? color : color.withValues(alpha: 0.12),
              foregroundColor: selected ? Colors.white : color,
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.rXl),
              textStyle: const TextStyle(
                fontSize: AppFont.title,
                fontWeight: FontWeight.w800,
              ),
            ),
            onPressed: () => onMark(value),
            icon: Icon(icon, size: 28),
            label: Text(label),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Text(
            position,
            style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          StudentAvatar(code: s.code, name: s.name, size: 168, radius: 28),
          const SizedBox(height: AppSpacing.lg),
          Text(
            s.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFont.h2,
              fontWeight: FontWeight.w800,
              color: NexoTheme.textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.code,
            style: TextStyle(
              fontSize: AppFont.body,
              color: NexoTheme.textMuted,
              letterSpacing: 1,
            ),
          ),
          if (s.atRisk) ...[
            const SizedBox(height: AppSpacing.sm),
            TeacherPill(
              text: l.tchAttLowAttendance(s.percent!.round()),
              color: NexoTheme.danger,
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          Row(
            children: [
              big(
                l.tchStatePresent,
                Icons.check_rounded,
                NexoTheme.success,
                AttendanceCode.present,
              ),
              const SizedBox(width: AppSpacing.md),
              big(
                l.tchStateAbsent,
                Icons.close_rounded,
                NexoTheme.danger,
                AttendanceCode.absent,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l.tchAttSwipeHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: NexoTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int done;
  final int total;
  final int present;
  final int absent;
  final bool saving;
  final VoidCallback? onRestPresent;
  final VoidCallback? onSave;
  const _BottomBar({
    required this.done,
    required this.total,
    required this.present,
    required this.absent,
    required this.saving,
    required this.onRestPresent,
    required this.onSave,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        border: Border(top: BorderSide(color: NexoTheme.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                TeacherPill(
                  text: l.tchAttProgress(done, total),
                  color: NexoTheme.primary,
                ),
                TeacherPill(text: '✓ $present', color: NexoTheme.success),
                TeacherPill(text: '✕ $absent', color: NexoTheme.danger),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Row(
            children: [
              if (onRestPresent != null) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.rLg,
                      ),
                    ),
                    onPressed: onRestPresent,
                    icon: const Icon(Icons.done_all_rounded),
                    label: Text(
                      done == 0 ? l.tchAttAllPresent : l.tchAttRestPresent,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: NexoTheme.primary,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_rounded),
                  label: Text(l.docenteSaveAttendance),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
