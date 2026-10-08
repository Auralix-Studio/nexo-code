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

/// Corrección de una sesión de asistencia ya registrada
/// (`Docente/ActualizarRegistroAsistencia`).
///
/// Reglas del cliente oficial de SIGMA (componente de edición por celda):
/// - Sesión de hoy: se puede cambiar entre Asistió y Faltó.
/// - Sesión pasada: solo Faltó o Justificado, y solo si el estado actual no es
///   ya Justificado.
/// - Matrícula suspendida: no se edita.
/// - Solo si la unidad de la sesión está habilitada.
class TeacherSessionEditScreen extends StatefulWidget {
  const TeacherSessionEditScreen({
    super.key,
    required this.store,
    required this.course,
    required this.session,
    required this.editable,
  });
  final AppStore store;
  final TeacherSubject course;

  /// Fecha y hora exactas de la sesión (identifican sus marcas).
  final DateTime session;
  final bool editable;

  static Future<void> open(
    BuildContext context, {
    required AppStore store,
    required TeacherSubject course,
    required DateTime session,
    required bool editable,
  }) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => TeacherSessionEditScreen(
        store: store,
        course: course,
        session: session,
        editable: editable,
      ),
    ),
  );

  /// Estados a los que se puede pasar una marca según las reglas de SIGMA.
  static List<int> allowedStates({
    required DateTime session,
    required int current,
    required bool suspended,
    DateTime? now,
  }) {
    if (suspended && current == AttendanceCode.suspended) return const [];
    final n = now ?? DateTime.now();
    final today =
        session.year == n.year &&
        session.month == n.month &&
        session.day == n.day;
    if (today) return const [AttendanceCode.present, AttendanceCode.absent];
    if (current == AttendanceCode.justified ||
        current == AttendanceCode.suspended) {
      return const [];
    }
    return const [AttendanceCode.absent, AttendanceCode.justified];
  }

  @override
  State<TeacherSessionEditScreen> createState() =>
      _TeacherSessionEditScreenState();
}

class _TeacherSessionEditScreenState extends State<TeacherSessionEditScreen> {
  final Map<String, int> _changes = {};
  bool _saving = false;

  List<({AttendanceStudent student, AttendanceMark mark})> _rows(
    AttendanceSheet sheet,
  ) {
    final out = <({AttendanceStudent student, AttendanceMark mark})>[];
    for (final s in sheet.students) {
      for (final m in s.marks) {
        if (m.date == widget.session) {
          out.add((student: s, mark: m));
          break;
        }
      }
    }
    out.sort((a, b) => a.student.name.compareTo(b.student.name));
    return out;
  }

  Future<void> _save(
    List<({AttendanceStudent student, AttendanceMark mark})> rows,
  ) async {
    final l = AppLocalizations.of(context);
    final changes = [
      for (final r in rows)
        if (_changes.containsKey(r.student.code) &&
            _changes[r.student.code] != r.mark.state)
          (mark: r.mark, student: r.student, state: _changes[r.student.code]!),
    ];
    if (changes.isEmpty) return;
    final ok = await showTeacherConfirm(
      context,
      title: l.tchSessionConfirmTitle,
      icon: Icons.edit_calendar_rounded,
      lines: [
        '${Fmt.dayLabel(widget.session.weekday)} '
            '${Fmt.shortDate(widget.session)}',
        for (final c in changes.take(6))
          '${c.student.name}: '
              '${attendanceLook(context, c.mark.state).label} → '
              '${attendanceLook(context, c.state).label}',
        if (changes.length > 6) l.tchAndMore(changes.length - 6),
      ],
      confirm: l.actionSave,
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    final res = await widget.store.actualizarAsistencia(widget.course, changes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (res.error != null) {
      ClipboardHelper.showError(context, res.error!);
      return;
    }
    HapticFeedback.mediumImpact();
    ClipboardHelper.showSuccess(
      context,
      parseSigmaMessage(res.message).text.ifBlank(l.tchSaved),
    );
    setState(_changes.clear);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final sheet = widget.store.asistenciaDe(widget.course.id).value;
        final rows = sheet == null
            ? const <({AttendanceStudent student, AttendanceMark mark})>[]
            : _rows(sheet);
        final pending = _changes.entries.where((e) {
          final r = rows.where((r) => r.student.code == e.key).firstOrNull;
          return r != null && r.mark.state != e.value;
        }).length;
        final counts = <int, int>{};
        for (final r in rows) {
          final st = _changes[r.student.code] ?? r.mark.state;
          counts[st] = (counts[st] ?? 0) + 1;
        }
        final s = widget.session;
        return Scaffold(
          backgroundColor: NexoTheme.bg,
          appBar: AppBar(
            title: Text(
              '${Fmt.dayLabel(s.weekday)} ${Fmt.shortDate(s)} · '
              '${two(s.hour)}:${two(s.minute)}',
            ),
          ),
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  color: NexoTheme.surface,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final st in const [1, 2, 3, 4])
                        if ((counts[st] ?? 0) > 0)
                          TeacherPill(
                            text:
                                '${attendanceLook(context, st).label} '
                                '${counts[st]}',
                            color: attendanceLook(context, st).color,
                          ),
                    ],
                  ),
                ),
                if (!widget.editable)
                  TeacherBanner(
                    color: NexoTheme.textMuted,
                    icon: Icons.lock_outline_rounded,
                    text: l.tchSessionLocked,
                  ),
                Expanded(
                  child: rows.isEmpty
                      ? Center(
                          child: EmptyState(
                            icon: Icons.event_busy_rounded,
                            title: l.tchSessionEmpty,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final current =
                                _changes[r.student.code] ?? r.mark.state;
                            final allowed = widget.editable
                                ? TeacherSessionEditScreen.allowedStates(
                                    session: widget.session,
                                    current: r.mark.state,
                                    suspended: r.student.isSuspended,
                                  )
                                : const <int>[];
                            return _Row(
                              student: r.student,
                              original: r.mark.state,
                              current: current,
                              allowed: allowed,
                              onChange: (v) {
                                HapticFeedback.selectionClick();
                                setState(() => _changes[r.student.code] = v);
                              },
                            );
                          },
                        ),
                ),
                if (pending > 0)
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
                      onPressed: _saving ? null : () => _save(rows),
                      icon: const Icon(Icons.save_rounded),
                      label: Text(l.tchSaveChanges(pending)),
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

class _Row extends StatelessWidget {
  final AttendanceStudent student;
  final int original;
  final int current;
  final List<int> allowed;
  final ValueChanged<int> onChange;
  const _Row({
    required this.student,
    required this.original,
    required this.current,
    required this.allowed,
    required this.onChange,
  });
  @override
  Widget build(BuildContext context) {
    final look = attendanceLook(context, current);
    final changed = current != original;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: changed ? NexoTheme.primary : NexoTheme.border,
          width: changed ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          StudentAvatar(code: student.code, name: student.name, size: 40),
          const Gap.h(AppSpacing.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                TeacherPill(text: look.label, color: look.color),
              ],
            ),
          ),
          for (final st in allowed) ...[
            const SizedBox(width: 6),
            AttendanceToggle(
              icon: attendanceLook(context, st).icon,
              color: attendanceLook(context, st).color,
              selected: current == st,
              tooltip: attendanceLook(context, st).label,
              onTap: () => onChange(st),
            ),
          ],
        ],
      ),
    );
  }
}
