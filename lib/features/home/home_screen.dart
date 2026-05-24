import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/pending_payments_widget.dart';
import 'package:nexo/shared/widgets/next_class_widget.dart';
import 'package:nexo/shared/widgets/section_card.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/student_avatar.dart';
import 'package:nexo/shared/widgets/today_classes_widget.dart';

/// Dashboard de bienvenida con resumen y accesos rápidos.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, required this.onJump});

  final AppStore store;
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
                parent: BouncingScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _Header(store: store)),
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
                            NextClassWidget(
                              all: store.horario.value ?? const [],
                            ),
                            const SizedBox(height: 16),
                          ],
                          _StatsGrid(store: store),
                          const SizedBox(height: 16),
                          _MainGrid(store: store, onJump: onJump),
                          const SizedBox(height: 32),
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
  const _Header({required this.store});

  @override
  Widget build(BuildContext context) {
    final profile = store.profile.value;
    final now = DateTime.now();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          Responsive.hPad(context), 24, Responsive.hPad(context), 16),
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
                  codigo: profile?.estId,
                  nombre: profile?.estudiante ?? '',
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
                      profile == null
                          ? '...'
                          : Fmt.firstName(profile.estudiante),
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
                        '${profile.carrera} · Nivel ${profile.nivel}',
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
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final AppStore store;
  const _StatsGrid({required this.store});

  @override
  Widget build(BuildContext context) {
    final p = store.profile.value;
    final cuotas = store.cuotasPendientes.value ?? const <Cuota>[];
    final horario = store.horario.value ?? const <ClaseHorario>[];

    final today = DateTime.now().weekday;
    final clasesHoy = horario.where((c) => c.idDia == today).length;
    final montoPendiente =
        cuotas.fold<double>(0, (acc, c) => acc + c.subtotal);

    // Promedio acumulado (de periodos completados, no el actual)
    final promedio = store.promedioAcumulado;
    final creditosAprob = store.creditosAprobados ?? p?.creditoAprobado;
    final creditosTotal = store.creditosTotales;

    final creditosLabel = creditosAprob == null
        ? '—'
        : creditosTotal != null && creditosTotal > 0
            ? '$creditosAprob/$creditosTotal'
            : '$creditosAprob';

    final stats = <_StatData>[
      _StatData(
        label: 'Promedio',
        value: promedio == null ? '—' : promedio.toStringAsFixed(2),
        icon: Icons.trending_up_rounded,
        color: NexoTheme.primary,
        loading: store.promedios.loading && !store.promedios.hasValue,
      ),
      _StatData(
        label: 'Créditos',
        value: creditosLabel,
        icon: Icons.school_rounded,
        color: NexoTheme.accent,
        loading: store.profile.loading && !store.profile.hasValue,
      ),
      _StatData(
        label: 'Clases hoy',
        value: '$clasesHoy',
        icon: Icons.today_rounded,
        color: NexoTheme.success,
        loading: store.horario.loading && !store.horario.hasValue,
      ),
      _StatData(
        label: 'Por pagar',
        value: cuotas.isEmpty ? 'S/ 0' : Fmt.currency(montoPendiente),
        icon: Icons.account_balance_wallet_rounded,
        color: NexoTheme.warning,
        loading: store.cuotasPendientes.loading &&
            !store.cuotasPendientes.hasValue,
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
    final isWide = Responsive.isDesktop(context) || Responsive.isTablet(context);

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
    return Column(
      children: [claseW, const SizedBox(height: 16), pagoW],
    );
  }
}

class _ClasesHoyBlock extends StatelessWidget {
  final AsyncValue<List<ClaseHorario>> state;
  final VoidCallback onSeeAll;
  const _ClasesHoyBlock({required this.state, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    if (state.loading && !state.hasValue) {
      return const SectionCard(
        title: 'Hoy',
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
        title: 'Hoy',
        icon: Icons.today_outlined,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'No se pudo cargar el horario',
          subtitle: state.error.toString(),
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
            label: const Text('Ver semana completa'),
          ),
        ),
      ],
    );
  }
}

class _PagosBlock extends StatelessWidget {
  final AsyncValue<List<Cuota>> state;
  final VoidCallback onSeeAll;
  const _PagosBlock({required this.state, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    if (state.loading && !state.hasValue) {
      return const SectionCard(
        title: 'Pagos pendientes',
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
        title: 'Pagos pendientes',
        icon: Icons.account_balance_wallet_outlined,
        child: EmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'No se pudo cargar los pagos',
          subtitle: state.error.toString(),
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
            label: const Text('Ver todos los pagos'),
          ),
        ),
      ],
    );
  }
}
