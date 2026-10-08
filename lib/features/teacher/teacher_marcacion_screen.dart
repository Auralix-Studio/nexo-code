import 'package:flutter/material.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_compliance_view.dart';
import 'package:nexo/features/teacher/teacher_virtual_view.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

/// Marcación de asistencia del propio docente. Dos vistas:
/// - Marcas: huella / virtual de los últimos 30 días
///   (`Docente/getHistorialMarcacion`).
/// - Por clase: cada clase programada con su marca de entrada y salida
///   (`Docente/getAsistenciaDiaria`), como el reporte diario de SIGMA.
class TeacherMarcacionScreen extends StatefulWidget {
  const TeacherMarcacionScreen({super.key, required this.store});
  final AppStore store;
  @override
  State<TeacherMarcacionScreen> createState() => _TeacherMarcacionScreenState();
}

class _TeacherMarcacionScreenState extends State<TeacherMarcacionScreen> {
  /// 0 Virtual · 1 Marcas · 2 Por clase.
  int _view = 0;

  void _setView(int v) {
    setState(() => _view = v);
    if (v == 2 && !widget.store.teacherCumplimiento.hasValue) {
      widget.store.loadTeacherCumplimiento();
    }
  }

  @override
  void initState() {
    super.initState();
    if (!widget.store.teacherMarcacion.hasValue) {
      widget.store.loadTeacherMarcacion();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final l = AppLocalizations.of(context);
        final state = widget.store.teacherMarcacion;
        final loading = state.loading && !state.hasValue;
        final punches = [...(state.value ?? const <TeacherPunch>[])];
        // Agrupar por fecha, días más recientes primero; dentro del día, la
        // marca más reciente arriba.
        punches.sort((a, b) {
          final d = b.date.compareTo(a.date);
          return d != 0 ? d : b.time.compareTo(a.time);
        });
        final byDay = <DateTime, List<TeacherPunch>>{};
        for (final p in punches) {
          byDay.putIfAbsent(p.date, () => []).add(p);
        }
        final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
        final today = DateTime.now();
        final toggle = SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 0, label: Text(l.tchVirtualTab)),
            ButtonSegment(value: 1, label: Text(l.marcacionViewPunches)),
            ButtonSegment(value: 2, label: Text(l.marcacionViewClasses)),
          ],
          selected: {_view},
          onSelectionChanged: (v) => _setView(v.first),
        );
        if (_view == 0) {
          return TeacherVirtualView(store: widget.store, toggle: toggle);
        }
        if (_view == 2) {
          return TeacherComplianceView(store: widget.store, toggle: toggle);
        }
        return RefreshIndicator(
          onRefresh: () => widget.store.loadTeacherMarcacion().then((_) {}),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: l.titleMarcacion,
                  subtitle: loading
                      ? l.docenteLoadingClasses
                      : l.marcacionSubtitlePlural(punches.length),
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SizedBox(width: double.infinity, child: toggle),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: loading
                      ? const Column(
                          children: [
                            Skeleton(height: 120, radius: 22),
                            Gap(AppSpacing.md),
                            Skeleton(height: 120, radius: 22),
                          ],
                        )
                      : punches.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: EmptyState(
                              icon: Icons.fingerprint_rounded,
                              title: l.marcacionEmpty,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < days.length; i++) ...[
                              Reveal(
                                index: i,
                                child: _DayCard(
                                  day: days[i],
                                  punches: byDay[days[i]]!,
                                  isToday: _sameDay(days[i], today),
                                ),
                              ),
                              const Gap(AppSpacing.md + 2),
                            ],
                          ],
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCard extends StatelessWidget {
  final DateTime day;
  final List<TeacherPunch> punches;
  final bool isToday;
  const _DayCard({
    required this.day,
    required this.punches,
    required this.isToday,
  });
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SectionCard(
      title: Fmt.dayLabel(day.weekday),
      subtitle:
          '${Fmt.shortDate(day)} · ${l.marcacionCountDay(punches.length)}',
      icon: isToday ? Icons.today_rounded : Icons.fingerprint_rounded,
      iconColor: isToday ? NexoTheme.primary : NexoTheme.accent,
      trailing: isToday
          ? StatusChip(text: l.detailToday, color: NexoTheme.primary)
          : null,
      child: Column(
        children: [
          for (var i = 0; i < punches.length; i++) ...[
            _PunchRow(punch: punches[i]),
            if (i < punches.length - 1) const Gap(AppSpacing.sm + 2),
          ],
        ],
      ),
    );
  }
}

class _PunchRow extends StatelessWidget {
  final TeacherPunch punch;
  const _PunchRow({required this.punch});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final color = punch.isVirtual ? NexoTheme.info : NexoTheme.success;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: AppRadii.rLg,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadii.rMd,
            ),
            child: Icon(
              punch.isVirtual
                  ? Icons.wifi_tethering_rounded
                  : Icons.fingerprint_rounded,
              color: color,
              size: 22,
            ),
          ),
          const Gap.h(AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _hhmm(punch.time),
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  punch.location.isEmpty
                      ? punch.mode
                      : (punch.isVirtual ? l.marcacionVirtual : punch.location),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppFont.small,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: AppRadii.rPill,
            ),
            child: Text(
              punch.isVirtual ? l.marcacionVirtual : 'Huella',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hhmm(String raw) {
    final p = raw.split(':');
    if (p.length >= 2) return '${p[0]}:${p[1]}';
    return raw;
  }
}
