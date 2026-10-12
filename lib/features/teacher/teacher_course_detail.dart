import 'package:flutter/material.dart';
import 'package:nexo/core/design/motion.dart';
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
        title: Text(
          c.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
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

/// Cabecera del curso en palabras, no en códigos: carrera, "Sección A1 ·
/// Ciclo 4 · Presencial", dónde y cuándo se dicta. El NRC queda al final,
/// discreto y copiable, para trámites con la universidad.
class _Header extends StatelessWidget {
  final TeacherSubject course;
  const _Header({required this.course});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = course;
    final ongoing = c.ongoingBlock(DateTime.now());
    final facts = courseFactsLine(l, c);
    final room = courseRoomLine(c);
    final schedule = courseScheduleLine(c);
    final muted = TextStyle(
      fontSize: AppFont.small,
      color: NexoTheme.textSecondary,
      height: 1.3,
    );
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: NexoTheme.textMuted),
          ),
          const Gap.h(AppSpacing.sm),
          Expanded(child: Text(text, style: muted)),
        ],
      ),
    );
    return Container(
      width: double.infinity,
      color: NexoTheme.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ongoing != null || c.isElective)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (ongoing != null)
                    TeacherPill(
                      text: l.tchOngoingNow(ongoing.start, ongoing.end),
                      color: NexoTheme.success,
                    ),
                  if (c.isElective)
                    TeacherPill(text: l.tchElective, color: NexoTheme.info),
                ],
              ),
            ),
          if (c.careerName.isNotEmpty)
            Text(
              c.careerName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: NexoTheme.textMuted,
              ),
            ),
          // "Sección A1 · Ciclo 4 · Presencial" y, a la derecha, el NRC
          // discreto y copiable para trámites con la universidad.
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    facts,
                    style: TextStyle(
                      fontSize: AppFont.body,
                      fontWeight: FontWeight.w700,
                      color: NexoTheme.textPrimary,
                    ),
                  ),
                ),
                if (c.nrc.isNotEmpty)
                  Tooltip(
                    message: l.tchCopyNrc,
                    child: InkWell(
                      borderRadius: AppRadii.rSm,
                      onTap: () => ClipboardHelper.copyAndShow(
                        context,
                        c.nrc,
                        label: 'NRC',
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        child: Text(
                          'NRC ${c.nrc}',
                          style: TextStyle(
                            fontSize: 11,
                            color: NexoTheme.textMuted,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (schedule.isNotEmpty) line(Icons.schedule_rounded, schedule),
          if (room.isNotEmpty) line(Icons.place_outlined, room),
        ],
      ),
    );
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
      builder: (context, _) => FadeSwitch(child: _content(context, l)),
    );
  }

  Widget _content(BuildContext context, AppLocalizations l) {
    final state = widget.store.alumnosDe(widget.course.id);
    if (state.loading && !state.hasValue) {
      return const TeacherListSkeleton(key: ValueKey('loading'));
    }
    final alumnos = [...(state.value ?? const <TeacherStudent>[])]
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    if (alumnos.isEmpty) {
      return Center(
        key: const ValueKey('empty'),
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
      key: const ValueKey('data'),
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
