import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/teacher_insights.dart';
import 'package:nexo/features/teacher/teacher_alerts_screen.dart';
import 'package:nexo/features/teacher/teacher_course_detail.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/features/teacher/teacher_take_attendance.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

String _hm(String raw) => Fmt.time(raw, h24: AppStorage.instance.use24h);

/// Agenda del día: cada clase con su estado (más tarde, en curso, terminó) y
/// si ya tiene asistencia registrada en SIGMA. La clase en curso se destaca
/// con accesos directos a tomar asistencia y registrar notas.
class TeacherAgendaCard extends StatelessWidget {
  const TeacherAgendaCard({super.key, required this.store, this.now});
  final AppStore store;

  /// Para pruebas; por defecto la hora del dispositivo.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = store.teacherSubjects;
    if (state.loading && !state.hasValue) {
      return const Skeleton(height: 150, radius: 22);
    }
    final courses = state.value ?? const <TeacherSubject>[];
    if (courses.isEmpty) return const SizedBox.shrink();
    final now = this.now ?? DateTime.now();
    final today = sessionsOn(courses, now);
    final holiday = PeruHolidays.isHoliday(now);
    final sheets = store.docenteHojas;

    Widget body;
    if (today.isEmpty || holiday) {
      final next = nextSession(courses, now);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            holiday ? l.tchAgendaHoliday : l.tchAgendaEmpty,
            style: TextStyle(
              fontSize: AppFont.body,
              fontWeight: FontWeight.w700,
              color: NexoTheme.textPrimary,
            ),
          ),
          if (next != null) ...[
            const Gap(AppSpacing.xs),
            Text(
              l.tchAgendaNext(
                '${Fmt.dayLabel(next.day.weekday)} ${_hm(next.start)}',
                next.course.displayName,
              ),
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textSecondary,
              ),
            ),
          ],
        ],
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < today.length; i++) ...[
            _AgendaRow(
              store: store,
              session: today[i],
              phase: today[i].phaseAt(now),
              sheet: sheets[today[i].course.id],
              sheetLoading: store.asistenciaDe(today[i].course.id).loading,
            ),
            if (i < today.length - 1) const Gap(AppSpacing.sm),
          ],
        ],
      );
    }

    return SectionCard(
      title: l.tchAgendaTitle,
      icon: Icons.today_rounded,
      iconColor: NexoTheme.success,
      trailing: today.isEmpty || holiday
          ? null
          : StatusChip(text: '${today.length}', color: NexoTheme.success),
      child: body,
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final AppStore store;
  final ClassSession session;
  final ClassPhase phase;
  final AttendanceSheet? sheet;
  final bool sheetLoading;
  const _AgendaRow({
    required this.store,
    required this.session,
    required this.phase,
    required this.sheet,
    required this.sheetLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = session.course;
    final ongoing = phase == ClassPhase.ongoing;
    final registered = sheet?.hasRecordsOn(session.day);
    final (phaseText, phaseColor) = switch (phase) {
      ClassPhase.upcoming => (l.tchPhaseUpcoming, NexoTheme.info),
      ClassPhase.ongoing => (l.tchPhaseOngoing, NexoTheme.success),
      ClassPhase.finished => (l.tchPhaseFinished, NexoTheme.textMuted),
    };
    // Estado de asistencia: solo importa desde que empieza la clase.
    Widget? attStatus;
    if (phase != ClassPhase.upcoming) {
      if (registered == null) {
        attStatus = sheetLoading
            ? TeacherPill(text: l.tchAgendaChecking, color: NexoTheme.textMuted)
            : null;
      } else {
        attStatus = TeacherPill(
          text: registered ? l.tchAgendaRegistered : l.tchAgendaPending,
          color: registered ? NexoTheme.success : NexoTheme.warning,
        );
      }
    }
    final room = c.aula.isEmpty ? '' : ScheduleRoom.parse(c.aula);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ongoing
            ? NexoTheme.success.withValues(alpha: 0.06)
            : NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(
          color: ongoing ? NexoTheme.success : NexoTheme.border,
          width: ongoing ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 54,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _hm(session.start),
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w900,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    Text(
                      _hm(session.end),
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Gap(2),
                    Text(
                      [
                        l.tchSectionLabel(c.section),
                        if (room.isNotEmpty) room,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                    const Gap(AppSpacing.xs + 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        TeacherPill(text: phaseText, color: phaseColor),
                        ?attStatus,
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ongoing || (phase == ClassPhase.finished && registered == false))
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        backgroundColor: NexoTheme.primary,
                        shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.rLg,
                        ),
                      ),
                      onPressed: () => TeacherTakeAttendanceScreen.open(
                        context,
                        store: store,
                        course: c,
                        initialDate: session.day,
                      ),
                      icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                      label: Text(
                        registered == true ? l.tchAttTakeAnother : l.tchAttTake,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.outlined(
                    tooltip: l.docenteTabNotas,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(44, 44),
                      shape: const RoundedRectangleBorder(
                        borderRadius: AppRadii.rLg,
                      ),
                    ),
                    onPressed: () => TeacherCourseDetailScreen.open(
                      context,
                      store: store,
                      course: c,
                      initialTab: 1,
                    ),
                    icon: const Icon(Icons.grading_rounded, size: 20),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que el docente tiene pendiente en todas sus secciones, en un solo lugar:
/// clases ya dictadas sin asistencia en SIGMA (últimas dos semanas) y alumnos que
/// necesitan atención. SIGMA no avisa de ninguna de las dos cosas.
class TeacherPendingCard extends StatelessWidget {
  const TeacherPendingCard({super.key, required this.store, this.now});
  final AppStore store;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final courses = store.teacherSubjects.value ?? const <TeacherSubject>[];
    if (courses.isEmpty) return const SizedBox.shrink();
    final missing = missingAttendance(
      courses,
      store.docenteHojas,
      now ?? DateTime.now(),
      dismissed: store.docenteClasesDescartadas,
    );
    final rosters = store.docenteRosters;
    final alerts = studentAlerts(courses, rosters);
    final allChecked = courses.every((c) => rosters.containsKey(c.id));
    final checking = store.docenteResumenLoading || !allChecked;
    final total = missing.length + alerts.length;

    final children = <Widget>[];
    if (missing.isNotEmpty) {
      final shown = missing.take(3).toList();
      children.add(
        _PendingHeading(
          icon: Icons.event_busy_rounded,
          color: NexoTheme.warning,
          title: l.tchMissingCount(missing.length),
          subtitle: l.tchMissingSubtitle,
        ),
      );
      for (final s in shown) {
        children
          ..add(const Gap(AppSpacing.sm))
          ..add(_MissingRow(store: store, session: s));
      }
      if (missing.length > shown.length) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Text(
              l.tchAndMore(missing.length - shown.length),
              style: TextStyle(
                fontSize: AppFont.small,
                color: NexoTheme.textMuted,
              ),
            ),
          ),
        );
      }
    }
    if (alerts.isNotEmpty) {
      if (children.isNotEmpty) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, color: NexoTheme.border),
          ),
        );
      }
      children.add(_AlertsSummary(store: store, alerts: alerts));
    }
    if (checking) {
      children.add(
        Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : AppSpacing.md),
          child: Row(
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NexoTheme.textMuted,
                ),
              ),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Text(
                  l.tchAlertsChecking,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (children.isEmpty) {
      // Solo se afirma que todo está al día con todas las secciones revisadas.
      children.add(
        Row(
          children: [
            const Icon(
              Icons.task_alt_rounded,
              color: NexoTheme.success,
              size: 22,
            ),
            const Gap.h(AppSpacing.sm),
            Expanded(
              child: Text(
                l.tchPendingNone,
                style: TextStyle(
                  fontSize: AppFont.body,
                  color: NexoTheme.textSecondary,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SectionCard(
      title: l.tchPendingTitle,
      icon: Icons.checklist_rounded,
      iconColor: total > 0 ? NexoTheme.warning : NexoTheme.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _PendingHeading extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  const _PendingHeading({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const Gap.h(AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: AppFont.body,
                  fontWeight: FontWeight.w800,
                  color: NexoTheme.textPrimary,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Resumen de alumnos en riesgo: cuántos y por qué, con acceso a la lista.
class _AlertsSummary extends StatelessWidget {
  final AppStore store;
  final List<StudentAlert> alerts;
  const _AlertsSummary({required this.store, required this.alerts});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    int count(AlertReason r) =>
        alerts.where((a) => a.reasons.contains(r)).length;
    final critical = count(AlertReason.attendanceCritical);
    final near = count(AlertReason.attendanceWarning);
    final failing = count(AlertReason.failing);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.rLg,
        onTap: () => TeacherAlertsScreen.open(context, store),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PendingHeading(
                      icon: Icons.priority_high_rounded,
                      color: NexoTheme.danger,
                      title: l.tchAlertsRow(alerts.length),
                      subtitle: l.tchAlertsSubtitle,
                    ),
                    const Gap(AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(left: 28),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (critical > 0)
                            TeacherPill(
                              text: l.tchAlertsCriticalCount(critical),
                              color: NexoTheme.danger,
                            ),
                          if (near > 0)
                            TeacherPill(
                              text: l.tchAlertsNearCount(near),
                              color: NexoTheme.warning,
                            ),
                          if (failing > 0)
                            TeacherPill(
                              text: l.tchAlertsFailingCount(failing),
                              color: NexoTheme.danger,
                            ),
                        ],
                      ),
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
}

class _MissingRow extends StatelessWidget {
  final AppStore store;
  final ClassSession session;
  const _MissingRow({required this.store, required this.session});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = session.course;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
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
                  c.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  '${Fmt.fullDate(session.day)} · '
                  '${_hm(session.start)}–${_hm(session.end)}',
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => TeacherTakeAttendanceScreen.open(
              context,
              store: store,
              course: c,
              initialDate: session.day,
            ),
            child: Text(l.tchMissingRegister),
          ),
          PopupMenuButton<String>(
            tooltip: l.tchMissingDismiss,
            icon: Icon(Icons.more_vert_rounded, color: NexoTheme.textMuted),
            onSelected: (_) async {
              await store.descartarClaseSinAsistencia(session.key);
              if (context.mounted) {
                ClipboardHelper.showSuccess(context, l.tchMissingDismissed);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'dismiss',
                child: ListTile(
                  leading: const Icon(Icons.event_busy_outlined),
                  title: Text(l.tchMissingDismiss),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Motivos de una alerta como texto corto ("Asistencia 65 % · crítica").
List<(String, Color)> alertReasons(BuildContext context, StudentAlert a) {
  final l = AppLocalizations.of(context);
  final pct = a.attendance?.round() ?? 0;
  final g = a.grade;
  return [
    if (a.reasons.contains(AlertReason.attendanceCritical))
      (l.tchAlertAttCritical(pct), NexoTheme.danger),
    if (a.reasons.contains(AlertReason.attendanceWarning))
      (l.tchAlertAttWarning(pct), NexoTheme.warning),
    if (a.reasons.contains(AlertReason.failing) && g != null)
      (
        l.tchAlertFailing(g.toStringAsFixed(g % 1 == 0 ? 0 : 1)),
        NexoTheme.danger,
      ),
  ];
}

class TeacherAlertTile extends StatelessWidget {
  const TeacherAlertTile({
    super.key,
    required this.store,
    required this.alert,
    this.dense = false,
    this.onTap,
  });
  final AppStore store;
  final StudentAlert alert;

  /// En el tablero se muestra también el curso.
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final a = alert;
    final s = a.student;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadii.rLg,
        onTap:
            onTap ??
            () => showTeacherStudentSheet(
              context: context,
              store: store,
              course: a.course,
              student: s,
              initialTab: a.attendanceIssue ? 1 : 0,
            ),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: AppRadii.rLg,
            border: Border.all(
              color: a.critical
                  ? NexoTheme.danger.withValues(alpha: 0.4)
                  : NexoTheme.border,
            ),
          ),
          child: Row(
            children: [
              StudentAvatar(code: s.code, name: s.displayName, size: 38),
              const Gap.h(AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (dense)
                      Text(
                        '${a.course.displayName} · ${AppLocalizations.of(context).tchSectionLabel(a.course.section)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    const Gap(AppSpacing.xs),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        for (final r in alertReasons(context, a))
                          TeacherPill(text: r.$1, color: r.$2),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
