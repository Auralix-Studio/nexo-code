import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/teacher/teacher_ui.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/clipboard_helper.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/skeleton.dart';

/// Marcación virtual del docente ("Marcación › Virtual" de SIGMA): clases de
/// hoy con su hora y tolerancia, y botones de entrada/salida
/// (`Docente/InsertaRegistroAsistenciaDocente?codigo=`).
class TeacherVirtualView extends StatefulWidget {
  const TeacherVirtualView({
    super.key,
    required this.store,
    required this.toggle,
  });
  final AppStore store;
  final Widget toggle;
  @override
  State<TeacherVirtualView> createState() => _TeacherVirtualViewState();
}

class _TeacherVirtualViewState extends State<TeacherVirtualView> {
  String? _busy;

  @override
  void initState() {
    super.initState();
    if (!widget.store.teacherVirtual.hasValue) {
      widget.store.loadTeacherVirtual();
    }
  }

  Future<void> _mark(VirtualClass c, bool entry) async {
    final l = AppLocalizations.of(context);
    final ok = await showTeacherConfirm(
      context,
      title: entry ? l.tchVirtualConfirmIn : l.tchVirtualConfirmOut,
      icon: entry ? Icons.login_rounded : Icons.logout_rounded,
      color: entry ? NexoTheme.success : NexoTheme.info,
      lines: [
        c.subject,
        '${_hm(c.start)} – ${_hm(c.end)}',
        l.tchVirtualExactTime,
      ],
      confirm: entry ? l.tchVirtualMarkIn : l.tchVirtualMarkOut,
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = c.code);
    final res = await widget.store.marcarVirtual(c.code);
    if (!mounted) return;
    setState(() => _busy = null);
    if (res.error != null) {
      ClipboardHelper.showError(context, res.error!);
      return;
    }
    final msg = parseSigmaMessage(res.message);
    if (msg.kind == 'E') {
      ClipboardHelper.showError(context, msg.text);
    } else {
      HapticFeedback.heavyImpact();
      ClipboardHelper.showSuccess(context, msg.text.ifBlank(l.tchSaved));
    }
  }

  static String _hm(String t) {
    final p = t.split(':');
    return p.length >= 2 ? '${p[0]}:${p[1]}' : t;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final state = widget.store.teacherVirtual;
        final loading = state.loading && !state.hasValue;
        final list = state.value ?? const <VirtualClass>[];
        return RefreshIndicator(
          onRefresh: () => widget.store.loadTeacherVirtual().then((_) {}),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: l.titleMarcacion,
                  subtitle: l.tchVirtualSubtitle,
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: SizedBox(
                      width: double.infinity,
                      child: widget.toggle,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: PageBody(
                  child: loading
                      ? const Column(
                          children: [
                            Skeleton(height: 160, radius: 22),
                            Gap(AppSpacing.md),
                            Skeleton(height: 160, radius: 22),
                          ],
                        )
                      : state.error != null && !state.hasValue
                      ? EmptyState(
                          icon: Icons.cloud_off_outlined,
                          title: l.tchVirtualLoadError,
                          subtitle: humanizeError(state.error),
                          color: NexoTheme.danger,
                          onRetry: widget.store.loadTeacherVirtual,
                        )
                      : list.isEmpty
                      ? Card(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: EmptyState(
                              icon: Icons.event_available_rounded,
                              title: l.tchVirtualEmpty,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l.tchVirtualHelp,
                              style: TextStyle(
                                fontSize: AppFont.small,
                                color: NexoTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final c in list) ...[
                              _VirtualCard(
                                item: c,
                                busy: _busy == c.code,
                                onIn: c.canMarkIn && _busy == null
                                    ? () => _mark(c, true)
                                    : null,
                                onOut: c.canMarkOut && _busy == null
                                    ? () => _mark(c, false)
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.md),
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
}

class _VirtualCard extends StatelessWidget {
  final VirtualClass item;
  final bool busy;
  final VoidCallback? onIn;
  final VoidCallback? onOut;
  const _VirtualCard({
    required this.item,
    required this.busy,
    required this.onIn,
    required this.onOut,
  });

  static String _hm(String t) {
    final p = t.split(':');
    return p.length >= 2 ? '${p[0]}:${p[1]}' : t;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = item;
    final (status, color) = c.hasOut
        ? (l.tchVirtualDone, NexoTheme.success)
        : c.hasIn
        ? (l.tchVirtualPartial, NexoTheme.warning)
        : (l.marcacionPending, NexoTheme.textMuted);
    Widget slot(String label, String scheduled, int tol, String marked) =>
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: NexoTheme.surface,
              borderRadius: AppRadii.rLg,
              border: Border.all(color: NexoTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textMuted,
                  ),
                ),
                Text(
                  _hm(scheduled),
                  style: TextStyle(
                    fontSize: AppFont.h3,
                    fontWeight: FontWeight.w900,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                Text(
                  l.tchVirtualTolerance(tol),
                  style: TextStyle(fontSize: 10, color: NexoTheme.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  marked.trim().isEmpty || marked == '00:00:00'
                      ? '—'
                      : l.tchVirtualMarkedAt(_hm(marked)),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: marked.trim().isEmpty || marked == '00:00:00'
                        ? NexoTheme.textMuted
                        : NexoTheme.success,
                  ),
                ),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: AppRadii.rXxl,
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  c.subject,
                  style: TextStyle(
                    fontSize: AppFont.subtitle,
                    fontWeight: FontWeight.w800,
                    color: NexoTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TeacherPill(text: status, color: color),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (c.section.isNotEmpty) '${l.detailSection} ${c.section}',
              if (c.level.isNotEmpty) l.tchCycle(c.level),
              if (c.career.isNotEmpty) c.career,
            ].join(' · '),
            style: TextStyle(
              fontSize: AppFont.small,
              color: NexoTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              slot(l.marcacionIn, c.start, c.toleranceStart, c.markIn),
              const SizedBox(width: AppSpacing.sm),
              slot(l.marcacionOut, c.end, c.toleranceEnd, c.markOut),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: NexoTheme.success,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                  onPressed: onIn,
                  icon: busy && onOut == null && c.canMarkIn
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(l.tchVirtualMarkIn),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: NexoTheme.info,
                    shape: const RoundedRectangleBorder(
                      borderRadius: AppRadii.rLg,
                    ),
                  ),
                  onPressed: onOut,
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l.tchVirtualMarkOut),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
