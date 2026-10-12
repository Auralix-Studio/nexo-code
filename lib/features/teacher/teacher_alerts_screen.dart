import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/teacher_insights.dart';
import 'package:nexo/features/teacher/teacher_dashboard_cards.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';

/// Todos los alumnos que necesitan atención, agrupados por sección y
/// filtrables por motivo (asistencia o notas).
class TeacherAlertsScreen extends StatefulWidget {
  const TeacherAlertsScreen({super.key, required this.store});
  final AppStore store;

  static Future<void> open(BuildContext context, AppStore store) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeacherAlertsScreen(store: store),
        ),
      );

  @override
  State<TeacherAlertsScreen> createState() => _TeacherAlertsScreenState();
}

enum _Filter { all, attendance, grades }

class _TeacherAlertsScreenState extends State<TeacherAlertsScreen> {
  _Filter _filter = _Filter.all;

  static bool _matches(StudentAlert a, _Filter f) => switch (f) {
    _Filter.all => true,
    _Filter.attendance => a.attendanceIssue,
    _Filter.grades => a.reasons.contains(AlertReason.failing),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(title: Text(l.tchAlertsTitle)),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final courses =
                widget.store.teacherSubjects.value ?? const <TeacherSubject>[];
            final all = studentAlerts(courses, widget.store.docenteRosters);
            final shown = all.where((a) => _matches(a, _filter)).toList();
            final byCourse = <String, List<StudentAlert>>{};
            for (final a in shown) {
              byCourse.putIfAbsent(a.course.id, () => []).add(a);
            }
            int count(_Filter f) => all.where((a) => _matches(a, f)).length;

            return RefreshIndicator(
              onRefresh: () => widget.store.loadDocenteResumen(force: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final (f, label) in [
                        (_Filter.all, l.docenteReportAll),
                        (_Filter.attendance, l.docenteTabAsistencia),
                        (_Filter.grades, l.docenteTabNotas),
                      ])
                        ChoiceChip(
                          label: Text('$label (${count(f)})'),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l.tchAlertsHint,
                    style: TextStyle(
                      fontSize: 11,
                      color: NexoTheme.textMuted,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (shown.isEmpty)
                    EmptyState(
                      icon: Icons.health_and_safety_outlined,
                      title: widget.store.docenteResumenLoading
                          ? l.tchAlertsChecking
                          : l.tchAlertsNone,
                    )
                  else
                    for (final c in courses)
                      if (byCourse[c.id] case final list?) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            '${c.displayName} · ${l.tchSectionLabel(c.section)}',
                            style: TextStyle(
                              fontSize: AppFont.subtitle,
                              fontWeight: FontWeight.w800,
                              color: NexoTheme.textPrimary,
                            ),
                          ),
                        ),
                        for (final a in list) ...[
                          TeacherAlertTile(store: widget.store, alert: a),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        const SizedBox(height: AppSpacing.md),
                      ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
