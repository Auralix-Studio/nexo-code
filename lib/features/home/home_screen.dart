import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/pending_payments_widget.dart';
import 'package:nexo/shared/widgets/next_class_widget.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';
import 'package:nexo/shared/widgets/today_classes_widget.dart';
import 'package:nexo/ai/lumen_services.dart';
import 'package:nexo/data/connectivity_service.dart';
import 'package:nexo/features/legal/support_screen.dart';

/// Dashboard de bienvenida con resumen y accesos rápidos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.store,
    required this.connectivity,
    required this.lumen,
    required this.onJump,
  });

  final AppStore store;
  final ConnectivityService connectivity;
  final LumenServices lumen;
  final ValueChanged<int> onJump;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () => store.loadHomeEssentials(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(store: store, connectivity: connectivity),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.hPad(context),
                  vertical: 4,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1240),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if ((store.horario.value ?? const []).isNotEmpty) ...[
                            Reveal(
                              index: 0,
                              child: NextClassWidget(
                                all: store.horario.value ?? const [],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          Reveal(index: 1, child: _StatsGrid(store: store)),
                          const SizedBox(height: 16),
                          Reveal(
                            index: 2,
                            child: _MainGrid(store: store, onJump: onJump),
                          ),
                          // El FAB de Lumen vive en el shell (overlay
                          // scroll-aware), por eso aquí solo dejamos el
                          // padding inferior extra para que el último
                          // contenido no quede tapado por el FAB.
                          const SizedBox(height: 96),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final AppStore store;
  final ConnectivityService connectivity;
  const _Header({required this.store, required this.connectivity});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final profile = store.profile.value;
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Responsive.hPad(context),
        24,
        Responsive.hPad(context),
        16,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: NexoTheme.primary.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: StudentAvatar(
                  codigo: profile?.id,
                  nombre: profile?.fullName ?? '',
                  size: 56,
                  radius: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${Fmt.greeting(now)},',
                      style: TextStyle(
                        fontSize: 14,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                    Text(
                      profile == null ? '...' : Fmt.firstName(profile.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (profile != null)
                      Text(
                        profile.career,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              ListenableBuilder(
                listenable: connectivity,
                builder: (context, _) {
                  final isOnline = connectivity.hasInternet;
                  final sigmaOnline =
                      connectivity.sigmaStatus == ServerStatus.online;
                  final intranetOnline =
                      connectivity.intranetStatus == ServerStatus.online;
                  final isFullyOnline =
                      isOnline && sigmaOnline && intranetOnline;

                  final color = isFullyOnline
                      ? NexoTheme.success
                      : NexoTheme.danger;

                  return Tooltip(
                    message: l.homeVerifyConnectivity,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showConnectivityDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.4),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showConnectivityDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        final l = AppLocalizations.of(context);
        return Dialog(
          backgroundColor: NexoTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: NexoTheme.border),
          ),
          child: ListenableBuilder(
            listenable: connectivity,
            builder: (context, _) {
              final isOnline = connectivity.hasInternet;
              final sigma = connectivity.sigmaStatus;
              final intranet = connectivity.intranetStatus;

              Widget buildStatusTile(
                String title,
                bool active,
                ServerStatus? status,
              ) {
                final Color color;
                final String label;
                final IconData icon;

                if (status != null) {
                  switch (status) {
                    case ServerStatus.online:
                      color = NexoTheme.success;
                      label = l.connectivityOnline;
                      icon = Icons.check_circle_outline_rounded;
                      break;
                    case ServerStatus.degraded:
                      color = NexoTheme.warning;
                      label = l.connectivityDegraded;
                      icon = Icons.error_outline_rounded;
                      break;
                    case ServerStatus.offline:
                      color = NexoTheme.danger;
                      label = l.connectivityOffline;
                      icon = Icons.cancel_outlined;
                      break;
                  }
                } else {
                  color = active ? NexoTheme.success : NexoTheme.danger;
                  label = active
                      ? l.connectivityConnected
                      : l.connectivityDisconnected;
                  icon = active ? Icons.wifi_rounded : Icons.wifi_off_rounded;
                }

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: NexoTheme.bg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NexoTheme.border),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NexoTheme.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [NexoTheme.primary, NexoTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: NexoTheme.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sensors_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.connectivityStatusTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: NexoTheme.textPrimary,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.connectivityDiagnosticsSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    buildStatusTile(l.connectivityInternet, isOnline, null),
                    buildStatusTile(l.connectivitySigma, isOnline, sigma),
                    buildStatusTile(l.connectivityIntranet, isOnline, intranet),
                    const SizedBox(height: 16),
                    Text(
                      l.connectivityBackupNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: NexoTheme.textMuted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        SupportScreen.open(context);
                      },
                      icon: Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: NexoTheme.success,
                      ),
                      label: Text(
                        l.supportContactButton,
                        style: const TextStyle(
                          color: NexoTheme.success,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => connectivity.checkNow(),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: Text(l.actionRetry),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              side: BorderSide(color: NexoTheme.border),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: NexoTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(l.actionClose),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AppStore store;
  const _StatsGrid({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final p = store.profile.value;
    final cuotas = store.cuotasPendientes.value ?? const <Payment>[];
    final horario = store.horario.value ?? const <ScheduleClass>[];

    final today = DateTime.now().weekday;
    final clasesHoy = horario.where((c) => c.weekday == today).length;
    final montoPendiente = cuotas.fold<double>(0, (acc, c) => acc + c.total);

    // Promedio acumulado (de periodos completados, no el actual)
    final promedio = store.promedioAcumulado;
    final creditosAprob = store.creditosAprobados ?? p?.creditsApproved;
    final creditosTotal = store.creditosTotales;

    final creditosLabel = creditosAprob == null
        ? '—'
        : creditosTotal != null && creditosTotal > 0
        ? '$creditosAprob/$creditosTotal'
        : '$creditosAprob';

    final stats = <_StatData>[
      _StatData(
        label: l.homeMetricPromedio,
        value: promedio == null ? '—' : promedio.toStringAsFixed(2),
        icon: Icons.trending_up_rounded,
        color: NexoTheme.primary,
        loading: store.promedios.loading && !store.promedios.hasValue,
      ),
      _StatData(
        label: l.homeMetricCreditos,
        value: creditosLabel,
        icon: Icons.school_rounded,
        color: NexoTheme.accent,
        loading: store.profile.loading && !store.profile.hasValue,
      ),
      _StatData(
        label: l.homeMetricClasesHoy,
        value: '$clasesHoy',
        icon: Icons.today_rounded,
        color: NexoTheme.success,
        loading: store.horario.loading && !store.horario.hasValue,
      ),
      _StatData(
        label: l.homeMetricPorPagar,
        value: cuotas.isEmpty ? 'S/ 0' : Fmt.currency(montoPendiente),
        icon: Icons.account_balance_wallet_rounded,
        color: NexoTheme.warning,
        loading:
            store.cuotasPendientes.loading && !store.cuotasPendientes.hasValue,
      ),
    ];

    final isMobile = Responsive.isMobile(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 86,
      ),
      itemBuilder: (_, i) => _StatTile(data: stats[i]),
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool loading;
  const _StatData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.loading = false,
  });
}

class _StatTile extends StatelessWidget {
  final _StatData data;
  const _StatTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: NexoTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: NexoTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                data.loading
                    ? const Skeleton(height: 18, width: 56)
                    : Text(
                        data.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: NexoTheme.textPrimary,
                          letterSpacing: -0.4,
                          height: 1.1,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MainGrid extends StatelessWidget {
  final AppStore store;
  final ValueChanged<int> onJump;
  const _MainGrid({required this.store, required this.onJump});

  @override
  Widget build(BuildContext context) {
    final horario = store.horario;
    final cuotas = store.cuotasPendientes;
    final isWide =
        Responsive.isDesktop(context) || Responsive.isTablet(context);

    final claseW = _ClasesHoyBlock(state: horario, onSeeAll: () => onJump(1));
    final pagoW = _PagosBlock(state: cuotas, onSeeAll: () => onJump(3));

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: claseW),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: pagoW),
        ],
      );
    }
    return Column(children: [claseW, const SizedBox(height: 16), pagoW]);
  }
}

class _ClasesHoyBlock extends StatelessWidget {
  final AsyncValue<List<ScheduleClass>> state;
  final VoidCallback onSeeAll;
  const _ClasesHoyBlock({required this.state, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return SectionCard(
        title: l.homeTodayTitle,
        icon: Icons.today_outlined,
        child: Column(
          children: [
            Skeleton(height: 64, radius: 14),
            SizedBox(height: 10),
            Skeleton(height: 64, radius: 14),
          ],
        ),
      );
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: l.homeTodayTitle,
        icon: Icons.today_outlined,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l.homeScheduleLoadError,
          subtitle: humanizeError(state.error),
          color: NexoTheme.danger,
        ),
      );
    }
    return Column(
      children: [
        TodayClassesWidget(all: state.value ?? const []),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(l.homeSeeFullWeek),
          ),
        ),
      ],
    );
  }
}

class _PagosBlock extends StatelessWidget {
  final AsyncValue<List<Payment>> state;
  final VoidCallback onSeeAll;
  const _PagosBlock({required this.state, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) {
      return SectionCard(
        title: l.homePendingPaymentsTitle,
        icon: Icons.account_balance_wallet_outlined,
        child: Column(
          children: [
            Skeleton(height: 60, radius: 14),
            SizedBox(height: 10),
            Skeleton(height: 60, radius: 14),
          ],
        ),
      );
    }
    if (state.error != null && !state.hasValue) {
      return SectionCard(
        title: l.homePendingPaymentsTitle,
        icon: Icons.account_balance_wallet_outlined,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: l.homePaymentsLoadError,
          subtitle: humanizeError(state.error),
          color: NexoTheme.danger,
        ),
      );
    }
    return Column(
      children: [
        PendingPaymentsWidget(cuotas: state.value ?? const []),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
            label: Text(l.homeSeeAllPayments),
          ),
        ),
      ],
    );
  }
}
