import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_student_sheet.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/domain/passing_rule.dart';

class TeacherCourseDetailScreen extends StatefulWidget {
  const TeacherCourseDetailScreen({
    super.key,
    required this.store,
    required this.course,
  });
  final AppStore store;
  final TeacherSubject course;
  @override
  State<TeacherCourseDetailScreen> createState() =>
      _TeacherCourseDetailScreenState();
}

class _TeacherCourseDetailScreenState extends State<TeacherCourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    if (!widget.store.alumnosDe(widget.course.id).hasValue) {
      widget.store.loadDocenteAlumnos(widget.course.id);
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(
        title: Text(
          widget.course.subject,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _Header(course: widget.course),
            ColoredBox(
              color: NexoTheme.surface,
              child: TabBar(
                controller: _tabs,
                tabs: [
                  Tab(text: l.docenteTabAlumnos),
                  Tab(text: l.docenteTabAsistencia),
                  Tab(text: l.docenteTabNotas),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: widget.store,
                builder: (context, _) {
                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _AlumnosTab(store: widget.store, course: widget.course),
                      _AsistenciaTab(
                        store: widget.store,
                        course: widget.course,
                      ),
                      _NotasTab(store: widget.store, course: widget.course),
                    ],
                  );
                },
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      color: NexoTheme.surface,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  course.code.isEmpty ? l.docenteNoCode : course.code,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: NexoTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.docenteSectionPeriod(course.section, course.periodo),
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: NexoTheme.primary.withValues(alpha: 0.12),
              borderRadius: AppRadii.rPill,
            ),
            child: Text(
              l.docenteMetricAlumnosCount(course.enrolledCount ?? 0),
              style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.w700,
                color: NexoTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
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
    final state = widget.store.alumnosDe(widget.course.id);
    if (state.loading && !state.hasValue) {
      return const _SkeletonList();
    }
    final alumnos = state.value ?? const <TeacherStudent>[];
    if (alumnos.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.groups_outlined,
          title: l.docenteNoAlumnosRegistered,
        ),
      );
    }
    final filtered = alumnos.where((a) => _matchesQuery(a, _q)).toList();
    return Column(
      children: [
        _StudentSearchField(
          count: filtered.length,
          onChanged: (v) => setState(() => _q = v),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l.docenteSearchNoResults,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return _AlumnoTile(
                      student: a,
                      onTap: () => showTeacherStudentSheet(
                        context: context,
                        store: widget.store,
                        course: widget.course,
                        student: a,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _AlumnoTile extends StatelessWidget {
  final TeacherStudent student;
  final VoidCallback onTap;
  const _AlumnoTile({required this.student, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final asis = int.tryParse(student.attendance ?? '');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md + 2),
          decoration: BoxDecoration(
            color: NexoTheme.card,
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: NexoTheme.primary.withValues(alpha: 0.14),
                child: Text(
                  _initials(student),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.primary,
                  ),
                ),
              ),
              const Gap.h(AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
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
                  if ((student.grade ?? '').isNotEmpty)
                    _gradePill(student.grade!),
                  if (asis != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.docenteAsisPercent(asis.toString()),
                      style: TextStyle(
                        fontSize: 10,
                        color: NexoTheme.textMuted,
                        fontWeight: FontWeight.w600,
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

  String _initials(TeacherStudent a) {
    final first = (a.firstName.split(' ').firstOrNull ?? '').trim();
    final last = (a.lastName.split(' ').firstOrNull ?? '').trim();
    String pick(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    final ini = pick(first) + pick(last);
    return ini.isEmpty ? '?' : ini;
  }

  Widget _gradePill(String grade) {
    final color = gradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.rPill,
      ),
      child: Text(
        grade,
        style: TextStyle(
          fontSize: AppFont.small,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _AsistenciaTab extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  const _AsistenciaTab({required this.store, required this.course});
  @override
  State<_AsistenciaTab> createState() => _AsistenciaTabState();
}

class _AsistenciaTabState extends State<_AsistenciaTab> {
  DateTime _fecha = DateTime.now();
  Map<String, String> _estados = {};
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    Map<String, String> estados = const {};
    try {
      estados = await widget.store.docenteAsistenciaDia(
        course: widget.course,
        date: _fecha,
      );
    } catch (_) {
      // Lectura best-effort: si falla, mostramos la fecha sin estados.
    }
    if (!mounted) return;
    setState(() {
      _estados = Map.of(estados);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final alumnos =
        widget.store.alumnosDe(widget.course.id).value ??
        const <TeacherStudent>[];
    final fmt =
        '${_fecha.day.toString().padLeft(2, '0')}/'
        '${_fecha.month.toString().padLeft(2, '0')}/${_fecha.year}';
    final registrados = alumnos.where((a) => _estados[a.code] != null).length;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          color: NexoTheme.surface,
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: NexoTheme.primary),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmt,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.w700,
                        color: NexoTheme.textPrimary,
                      ),
                    ),
                    if (!_loading)
                      Text(
                        l.docenteSessionsRegisteredCount(
                          registrados.toString(),
                          alumnos.length.toString(),
                        ),
                        style: TextStyle(
                          fontSize: AppFont.small,
                          color: NexoTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fecha,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    _fecha = picked;
                    await _load();
                  }
                },
                icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                label: Text(l.docenteChangeDate),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const _SkeletonList()
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: alumnos.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final a = alumnos[i];
                    return _AsistenciaRow(student: a, state: _estados[a.code]);
                  },
                ),
        ),
        _ComingSoonBanner(text: l.docenteAttendanceComingSoon),
      ],
    );
  }
}

/// Resuelve el estado de asistencia a (etiqueta, color). Tolera tanto las
/// letras P/T/F/J como ids numéricos de SIGMA aún sin mapear (se muestran como
/// "registrado" neutro para no inventar un significado).
({String label, Color color}) _attendanceState(
  BuildContext context,
  String? raw,
) {
  final l = AppLocalizations.of(context);
  switch ((raw ?? '').trim().toUpperCase()) {
    case '':
      return (label: '—', color: NexoTheme.textMuted);
    case 'P':
      return (label: l.docenteAttendancePresentShort, color: NexoTheme.success);
    case 'T':
      return (
        label: l.docenteAttendanceTardanzaShort,
        color: NexoTheme.warning,
      );
    case 'F':
      return (label: l.docenteAttendanceFaltaShort, color: NexoTheme.danger);
    case 'J':
      return (label: l.docenteAttendanceJustificada, color: NexoTheme.info);
    default:
      return (label: raw!, color: NexoTheme.info);
  }
}

class _AsistenciaRow extends StatelessWidget {
  final TeacherStudent student;
  final String? state;
  const _AsistenciaRow({required this.student, required this.state});
  @override
  Widget build(BuildContext context) {
    final st = _attendanceState(context, state);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
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
                  student.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.w600,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  student.code,
                  style: TextStyle(
                    fontSize: 10,
                    color: NexoTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: st.color.withValues(alpha: 0.14),
              borderRadius: AppRadii.rPill,
            ),
            child: Text(
              st.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: st.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonBanner extends StatelessWidget {
  final String text;
  const _ComingSoonBanner({required this.text});
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: NexoTheme.info.withValues(alpha: 0.10),
            borderRadius: AppRadii.rLg,
            border: Border.all(color: NexoTheme.info.withValues(alpha: 0.30)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: NexoTheme.info,
              ),
              const Gap.h(AppSpacing.sm),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotasTab extends StatefulWidget {
  final AppStore store;
  final TeacherSubject course;
  const _NotasTab({required this.store, required this.course});
  @override
  State<_NotasTab> createState() => _NotasTabState();
}

class _NotasTabState extends State<_NotasTab> {
  String _q = '';
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = widget.store.alumnosDe(widget.course.id);
    if (state.loading && !state.hasValue) return const _SkeletonList();
    final alumnos = state.value ?? const <TeacherStudent>[];
    if (alumnos.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.assignment_outlined,
          title: l.docenteNoAlumnosInCourse,
        ),
      );
    }
    final approved = alumnos.where((a) {
      final n = double.tryParse((a.grade ?? '').replaceAll(',', '.'));
      return PassingRule.standard.passes(n);
    }).length;
    final filtered = alumnos.where((a) => _matchesQuery(a, _q)).toList();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          color: NexoTheme.surface,
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.docenteAprobadosCount(
                    approved.toString(),
                    alumnos.length.toString(),
                  ),
                  style: TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textSecondary,
                  ),
                ),
              ),
              Text(
                l.docenteTapToEdit,
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
        _StudentSearchField(
          count: filtered.length,
          onChanged: (v) => setState(() => _q = v),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: EmptyState(
                    icon: Icons.search_off_rounded,
                    title: l.docenteSearchNoResults,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 6),
                  itemBuilder: (_, i) {
                    final a = filtered[i];
                    return _AlumnoTile(
                      student: a,
                      onTap: () => showTeacherStudentSheet(
                        context: context,
                        store: widget.store,
                        course: widget.course,
                        student: a,
                        initialTab: 1,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Filtro case-insensitive por nombre o código.
bool _matchesQuery(TeacherStudent s, String q) {
  final t = q.trim().toLowerCase();
  if (t.isEmpty) return true;
  return s.displayName.toLowerCase().contains(t) ||
      s.code.toLowerCase().contains(t);
}

class _StudentSearchField extends StatelessWidget {
  final int count;
  final ValueChanged<String> onChanged;
  const _StudentSearchField({required this.count, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: NexoTheme.textPrimary, fontSize: AppFont.body),
        decoration: InputDecoration(
          isDense: true,
          hintText: l.docenteSearchStudent,
          hintStyle: TextStyle(color: NexoTheme.textMuted),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: NexoTheme.textMuted,
            size: 20,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: Text(
                l.docenteMetricAlumnosCount(count),
                style: TextStyle(
                  fontSize: AppFont.small,
                  color: NexoTheme.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          suffixIconConstraints: const BoxConstraints(minWidth: 0),
          filled: true,
          fillColor: NexoTheme.card,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadii.rLg,
            borderSide: BorderSide(color: NexoTheme.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadii.rLg,
            borderSide: BorderSide(color: NexoTheme.primary, width: 1.5),
          ),
        ),
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
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, _) => const Skeleton(height: 64, radius: 14),
    );
  }
}

Color gradeColor(String? raw) {
  final n = double.tryParse((raw ?? '').trim().replaceAll(',', '.'));
  if (n == null) return NexoTheme.textMuted;
  if (n >= 14) return NexoTheme.success;
  if (n >= PassingRule.standard.threshold) return NexoTheme.info;
  return NexoTheme.danger;
}
