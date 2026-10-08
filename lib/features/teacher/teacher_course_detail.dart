import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_attendance_report.dart';
import 'package:nexo/features/teacher/teacher_attendance_tab.dart';
import 'package:nexo/features/teacher/teacher_grades_tab.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/util/file_share.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';

/// Detalle de una sección a cargo del docente: asistencia, notas, alumnos y
/// reportes en una sola pantalla.
class TeacherCourseDetailScreen extends StatefulWidget {
  const TeacherCourseDetailScreen({
    super.key,
    required this.store,
    required this.course,
    this.initialTab = 0,
  });
  final AppStore store;
  final TeacherSubject course;

  /// 0 Asistencia · 1 Notas · 2 Alumnos · 3 Reporte.
  final int initialTab;

  static Future<void> open(
    BuildContext context, {
    required AppStore store,
    required TeacherSubject course,
    int initialTab = 0,
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TeacherCourseDetailScreen(
        store: store,
        course: course,
        initialTab: initialTab,
      ),
    ),
  );

  @override
  State<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState extends State<TeacherCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    final s = widget.store;
    final c = widget.course;
    if (!s.alumnosDe(c.id).hasValue) {
      s.loadDocenteAlumnos(c.id, tipoCalif: c.tipoCalif);
    }
    if (!s.asistenciaDe(c.id).hasValue) s.loadDocenteAsistencia(c);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _download(String tipo) async {
    final l = AppLocalizations.of(context);
    setState(() => _downloading = true);
    try {
      final r = await widget.store.docenteReporteAuxiliar(
        widget.course,
        tipo: tipo,
      );
      final path = await deliverFile(
        r.bytes,
        filename: r.filename,
        mimeType: mimeForExtension(r.filename),
      );
      if (!mounted) return;
      if (path != null) {
        ClipboardHelper.showSuccess(context, l.tchFileSaved(path));
      }
    } catch (e) {
      if (mounted) ClipboardHelper.showError(context, l.tchDownloadError);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = widget.course;
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(
        title: Text(c.shortName, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (_downloading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              tooltip: l.tchAuxReport,
              icon: const Icon(Icons.download_rounded),
              onSelected: _download,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'pdf',
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf_rounded),
                    title: Text(l.tchAuxReportPdf),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'xlsx',
                  child: ListTile(
                    leading: const Icon(Icons.table_chart_rounded),
                    title: Text(l.tchAuxReportXlsx),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(course: c),
            ColoredBox(
              color: NexoTheme.surface,
              child: TabBar(
                controller: _tabs,
                labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                tabs: [
                  Tab(text: l.docenteTabAsistencia),
                  Tab(text: l.docenteTabNotas),
                  Tab(text: l.docenteTabAlumnos),
                  Tab(text: l.docenteTabReporte),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  TeacherAttendanceTab(store: widget.store, course: c),
                  TeacherGradesTab(store: widget.store, course: c),
                  _AlumnosTab(store: widget.store, course: c),
                  TeacherReportTab(store: widget.store, course: c),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TeacherSubject course;
  const _Header({required this.course});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = course;
    final ongoing = c.ongoingBlock(DateTime.now());
    final days = <String, List<TeacherBlock>>{};
    for (final b in [
      ...c.blocks,
    ]..sort((a, b) => a.weekday.compareTo(b.weekday))) {
      days.putIfAbsent(b.dayName, () => []).add(b);
    }
    Widget chip(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(right: 6, bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: NexoTheme.card,
          borderRadius: AppRadii.rPill,
          border: Border.all(color: NexoTheme.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: NexoTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: NexoTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      width: double.infinity,
      color: NexoTheme.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ongoing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TeacherPill(
                text: l.tchOngoingNow(ongoing.start, ongoing.end),
                color: NexoTheme.success,
              ),
            ),
          Wrap(
            children: [
              chip(
                Icons.tag_rounded,
                'NRC ${c.nrc} · ${l.detailSection} ${c.section}',
              ),
              if (c.ciclo.isNotEmpty)
                chip(Icons.layers_rounded, l.tchCycle(c.ciclo)),
              if (c.modalidad.isNotEmpty)
                chip(Icons.devices_rounded, c.modalidad),
              if (c.aula.isNotEmpty)
                chip(Icons.meeting_room_rounded, _shortRoom(c.aula)),
              for (final e in days.entries)
                chip(
                  Icons.schedule_rounded,
                  '${e.key.substring(0, 3)} '
                  '${e.value.map((b) => '${b.start}–${b.end}').join(', ')}',
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// "PABELLON H - H 302 - AFORO: 60" → "H 302".
  static String _shortRoom(String aula) {
    final loc = ScheduleRoom.parse(aula);
    return loc.isEmpty ? aula : loc;
  }
}

/// Utilidad mínima para mostrar el aula sin el pabellón ni el aforo.
abstract final class ScheduleRoom {
  static String parse(String raw) {
    final parts = raw
        .split(RegExp(r'\s*-\s*'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && !e.toUpperCase().startsWith('AFORO'))
        .toList();
    if (parts.isEmpty) return '';
    return parts.length > 1 ? parts.sublist(1).join(' - ') : parts.first;
  }
}

class _AlumnosTab extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  const _AlumnosTab({required this.store, required this.course});
  @override
  State<_AlumnosTab> createState() => _AlumnosTabState();
}

class _AlumnosTabState extends State<_AlumnosTab> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.alumnosDe(widget.course.id);
        if (state.loading && !state.hasValue) {
          return const TeacherListSkeleton();
        }
        final alumnos = [...(state.value ?? const <TeacherStudent>[])]
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        if (alumnos.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.groups_outlined,
              title: l.docenteNoAlumnosRegistered,
              onRetry: () => widget.store.loadDocenteAlumnos(
                widget.course.id,
                tipoCalif: widget.course.tipoCalif,
              ),
            ),
          );
        }
        final sheet = widget.store.asistenciaDe(widget.course.id).value;
        final pct = {
          for (final s in sheet?.students ?? const <AttendanceStudent>[])
            s.code: s.percent,
        };
        final t = _q.trim().toLowerCase();
        final filtered = alumnos
            .where(
              (a) =>
                  t.isEmpty ||
                  a.displayName.toLowerCase().contains(t) ||
                  a.code.toLowerCase().contains(t),
            )
            .toList();
        return RefreshIndicator(
          onRefresh: () => widget.store.loadDocenteAlumnos(
            widget.course.id,
            tipoCalif: widget.course.tipoCalif,
          ),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: filtered.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return TextField(
                  onChanged: (v) => setState(() => _q = v),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.docenteSearchStudent,
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixText: l.docenteMetricAlumnosCount(filtered.length),
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
                );
              }
              final a = filtered[i - 1];
              return _AlumnoTile(
                student: a,
                attendance: pct[a.code],
                onTap: () => showTeacherStudentSheet(
                  context: context,
                  store: widget.store,
                  course: widget.course,
                  student: a,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _AlumnoTile extends StatelessWidget {
  final TeacherStudent student;
  final double? attendance;
  final VoidCallback onTap;
  const _AlumnoTile({
    required this.student,
    required this.attendance,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asis = attendance ?? double.tryParse(student.attendance ?? '');
    final grade = (student.grade ?? '').trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              StudentAvatar(
                code: student.code,
                name: student.displayName,
                size: 44,
              ),
              const Gap.h(AppSpacing.md),
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
                    const SizedBox(height: 2),
                    Text(
                      student.code,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        color: NexoTheme.textMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (grade.isNotEmpty && grade != '0')
                    TeacherPill(text: grade, color: gradeColor(grade)),
                  if (asis != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.docenteAsisPercent(asis.round().toString()),
                      style: TextStyle(
                        fontSize: 10,
                        color: asis <= 70
                            ? NexoTheme.danger
                            : NexoTheme.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
