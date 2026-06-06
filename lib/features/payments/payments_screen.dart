import 'package:flutter/material.dart';

import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/errors.dart';
import 'package:nexo/data/app_store.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/features/reports/pdf_export.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/features/payments/payment_detail_screen.dart';
import 'package:nexo/shared/widgets/empty_state.dart';
import 'package:nexo/shared/widgets/page_scaffold.dart';
import 'package:nexo/shared/widgets/reveal.dart';
import 'package:nexo/shared/widgets/skeleton.dart';
import 'package:nexo/shared/widgets/status_chip.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key, required this.store});
  final AppStore store;

  @override
  State<PaymentsScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PaymentsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      if (!widget.store.cuotasPendientes.hasValue)
        widget.store.loadCuotasPendientes(),
      if (!widget.store.cuotasIntranet.hasValue)
        widget.store.loadCuotasIntranet(),
      if (!widget.store.tasas.hasValue) widget.store.loadTasas(),
      if (!widget.store.historico.hasValue) widget.store.loadHistorico(),
    ]);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              widget.store.loadCuotasPendientes(),
              widget.store.loadCuotasIntranet(),
              widget.store.loadTasas(),
              widget.store.loadHistorico(),
            ]);
          },
          child: NestedScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            headerSliverBuilder: (_, _) => [
              SliverToBoxAdapter(
                child: PageHeader(
                  title: AppLocalizations.of(context).titlePayments,
                  subtitle: AppLocalizations.of(context).subtitlePayments,
                  actions: [
                    IconButton(
                      tooltip: AppLocalizations.of(context).paymentsDownloadSchedulePdf,
                      icon: const Icon(Icons.download_rounded),
                      onPressed: () =>
                          PdfExport.cronograma(context, widget.store),
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Reveal(index: 0, child: _SummaryCards(store: widget.store)),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 12)),
              SliverToBoxAdapter(
                child: PageBody(
                  child: _TabBar(controller: _tab),
                ),
              ),
            ],
            body: PageBody(
              child: TabBarView(
                controller: _tab,
                children: [
                  _PendientesTab(state: widget.store.cuotasPendientes),
                  _VencidasTab(state: widget.store.cuotasIntranet),
                  _TasasTab(state: widget.store.tasas),
                  _HistorialTab(state: widget.store.historico),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final AppStore store;
  const _SummaryCards({required this.store});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final pendientes = store.cuotasPendientes.value ?? const <Cuota>[];
    final vencidas =
        (store.cuotasIntranet.value ?? const <Cuota>[]).where((c) {
      final d = c.daysUntilDue();
      return d != null && d < 0;
    }).toList();
    final tasas = store.tasas.value ?? const <Tasa>[];

    final totalPend =
        pendientes.fold<double>(0, (a, c) => a + c.subtotal);
    final totalVenc = vencidas.fold<double>(0, (a, c) => a + c.subtotal);
    final totalTasas = tasas.fold<double>(0, (a, t) => a + t.importe);

    return PageBody(
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              title: l.paymentsTabPending,
              total: totalPend,
              count: pendientes.length,
              icon: Icons.schedule_rounded,
              color: NexoTheme.warning,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              title: l.paymentsTabOverdue,
              total: totalVenc,
              count: vencidas.length,
              icon: Icons.warning_amber_rounded,
              color: NexoTheme.danger,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              title: l.paymentsTabFees,
              total: totalTasas,
              count: tasas.length,
              icon: Icons.receipt_long_rounded,
              color: NexoTheme.info,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double total;
  final int count;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.total,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: NexoTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            Fmt.currency(total),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: NexoTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: NexoTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: NexoTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NexoTheme.border),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: false,
        indicator: BoxDecoration(
          color: NexoTheme.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: Colors.white,
        unselectedLabelColor: NexoTheme.textSecondary,
        labelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        splashFactory: NoSplash.splashFactory,
        dividerHeight: 0,
        tabs: [
          Tab(text: l.paymentsTabPending),
          Tab(text: l.paymentsTabOverdue),
          Tab(text: l.paymentsTabFees),
          Tab(text: l.paymentsTabHistory),
        ],
      ),
    );
  }
}

// ============== Tabs ==============

class _PendientesTab extends StatelessWidget {
  final AsyncValue<List<Cuota>> state;
  const _PendientesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _CuotaListTab(
      state: state,
      filter: (c) {
        final d = c.daysUntilDue();
        return d == null || d >= 0;
      },
      emptyTitle: l.paymentsUpToDateTitle,
      emptySubtitle: l.paymentsUpToDateSubtitle,
      emptyIcon: Icons.verified_outlined,
      emptyColor: NexoTheme.success,
    );
  }
}

class _VencidasTab extends StatelessWidget {
  final AsyncValue<List<Cuota>> state;
  const _VencidasTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _CuotaListTab(
      state: state,
      filter: (c) {
        final d = c.daysUntilDue();
        return d != null && d < 0;
      },
      emptyTitle: l.paymentsNoOverdueTitle,
      emptySubtitle: l.paymentsNoOverdueSubtitle,
      emptyIcon: Icons.celebration_outlined,
      emptyColor: NexoTheme.success,
    );
  }
}

class _CuotaListTab extends StatelessWidget {
  final AsyncValue<List<Cuota>> state;
  final bool Function(Cuota) filter;
  final String emptyTitle;
  final String emptySubtitle;
  final IconData emptyIcon;
  final Color emptyColor;

  const _CuotaListTab({
    required this.state,
    required this.filter,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.emptyIcon,
    required this.emptyColor,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) return const _LoadingList();
    if (state.error != null && !state.hasValue) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.paymentsLoadError,
        subtitle: humanizeError(state.error),
        color: NexoTheme.danger,
      );
    }
    final items = (state.value ?? const <Cuota>[]).where(filter).toList()
      ..sort((a, b) {
        final da = a.vencimientoDate;
        final db = b.vencimientoDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    if (items.isEmpty) {
      return EmptyState(
        icon: emptyIcon,
        title: emptyTitle,
        subtitle: emptySubtitle,
        color: emptyColor,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 14),
      itemBuilder: (_, i) => _CuotaCard(cuota: items[i]),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

class _CuotaCard extends StatelessWidget {
  final Cuota cuota;
  const _CuotaCard({required this.cuota});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final days = cuota.daysUntilDue();
    final isOverdue = days != null && days < 0;
    final isSoon = days != null && days >= 0 && days <= 3;
    final tagColor = isOverdue
        ? NexoTheme.danger
        : isSoon
            ? NexoTheme.warning
            : NexoTheme.textSecondary;
    final tagText = isOverdue
        ? l.paymentDaysOverdue((-days).toString())
        : days == 0
            ? l.paymentVenceHoy
            : days == 1
                ? l.paymentVenceManana
                : days == null
                    ? '—'
                    : l.paymentDaysLeft(days.toString());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PaymentDetailScreen.openCuota(context, cuota),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isOverdue
                  ? NexoTheme.danger.withValues(alpha: 0.4)
                  : NexoTheme.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cuota.descripcion,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${cuota.tipoMoneda} ${cuota.subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: NexoTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.event_outlined,
                      size: 14, color: NexoTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    cuota.fechaVencimiento,
                    style: TextStyle(
                      fontSize: 12,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              StatusChip(text: tagText, color: tagColor),
              if (cuota.mora > 0)
                StatusChip(
                  text: l.paymentMora(cuota.tipoMoneda, cuota.mora.toStringAsFixed(2)),
                  color: NexoTheme.danger,
                  icon: Icons.warning_amber_rounded,
                ),
            ],
          ),
          if (cuota.observacion.trim().isNotEmpty &&
              cuota.observacion.trim() != '--') ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: NexoTheme.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: NexoTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      cuota.observacion,
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  ),
);
  }
}

class _TasasTab extends StatelessWidget {
  final AsyncValue<List<Tasa>> state;
  const _TasasTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) return const _LoadingList();
    if (state.error != null && !state.hasValue) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.paymentsLoadError,
        subtitle: humanizeError(state.error),
        color: NexoTheme.danger,
      );
    }
    final items = state.value ?? const <Tasa>[];
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_outlined,
        title: l.paymentsNoFeesRegistered,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 14),
      itemBuilder: (_, i) => _TasaCard(tasa: items[i]),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: items.length,
    );
  }
}

class _TasaCard extends StatelessWidget {
  final Tasa tasa;
  const _TasaCard({required this.tasa});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PaymentDetailScreen.openTasa(context, tasa),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: NexoTheme.info.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.receipt_long_rounded,
                color: NexoTheme.info, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tasa.descripcion,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                if (tasa.observacion.trim().isNotEmpty &&
                    tasa.observacion.trim() != '--')
                  Text(
                    tasa.observacion,
                    style: TextStyle(
                      fontSize: 12,
                      color: NexoTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${tasa.tipoMoneda} ${tasa.importe.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: NexoTheme.textPrimary,
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistorialTab extends StatelessWidget {
  final AsyncValue<List<PagoHistorico>> state;
  const _HistorialTab({required this.state});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.loading && !state.hasValue) return const _LoadingList();
    if (state.error != null && !state.hasValue) {
      return EmptyState(
        icon: Icons.cloud_off_outlined,
        title: l.paymentsLoadError,
        subtitle: humanizeError(state.error),
        color: NexoTheme.danger,
      );
    }
    final items = state.value ?? const <PagoHistorico>[];
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.history_rounded,
        title: l.paymentsNoHistoryRegistered,
      );
    }
    // Ordenar por fecha descendente.
    final sorted = [...items]..sort((a, b) {
        final da = a.fechaDate;
        final db = b.fechaDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return db.compareTo(da);
      });

    // Agrupar por fecha.
    final byDate = <String, List<PagoHistorico>>{};
    for (final p in sorted) {
      byDate.putIfAbsent(p.fecha, () => []).add(p);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 14),
      itemCount: byDate.length,
      itemBuilder: (_, i) {
        final date = byDate.keys.elementAt(i);
        final list = byDate[date]!;
        final dt = list.first.fechaDate;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  dt == null ? date : Fmt.fullDate(dt),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textSecondary,
                  ),
                ),
              ),
              for (var j = 0; j < list.length; j++) ...[
                _HistTile(item: list[j]),
                if (j < list.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HistTile extends StatelessWidget {
  final PagoHistorico item;
  const _HistTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final esDesc = item.esDescuento;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => PaymentDetailScreen.openHistorico(context, item),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NexoTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NexoTheme.border),
          ),
          child: Row(
            children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: (esDesc ? NexoTheme.warning : NexoTheme.success)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              esDesc ? Icons.discount_outlined : Icons.check_circle_outline,
              size: 18,
              color: esDesc ? NexoTheme.warning : NexoTheme.success,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.concepto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NexoTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: [
                    Text(
                      item.periodo,
                      style: TextStyle(
                        fontSize: 11,
                        color: NexoTheme.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.lugar.trim().isNotEmpty)
                      Text(
                        '· ${item.lugar}',
                        style: TextStyle(
                          fontSize: 11,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                    if (item.comprobante.trim().isNotEmpty)
                      Text(
                        '· ${item.comprobante}',
                        style: TextStyle(
                          fontSize: 11,
                          color: NexoTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${item.tipoMoneda} ${item.importe.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: esDesc ? NexoTheme.warning : NexoTheme.textPrimary,
            ),
          ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 14),
      itemBuilder: (_, _) => const Skeleton(height: 80, radius: 16),
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: 5,
    );
  }
}
