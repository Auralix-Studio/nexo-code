import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:nexo/core/design/theme.dart';
import 'package:nexo/core/design/tokens.dart';
import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/shared/widgets/section_card.dart';

enum PaymentType { cuota, tasa, historico }

class PaymentDetailScreen extends StatelessWidget {
  final Object payment;
  final PaymentType type;
  const PaymentDetailScreen.cuota({super.key, required Payment cuota})
    : payment = cuota,
      type = PaymentType.cuota;
  const PaymentDetailScreen.tasa({super.key, required Fee tasa})
    : payment = tasa,
      type = PaymentType.tasa;
  const PaymentDetailScreen.historico({super.key, required PaymentRecord pago})
    : payment = pago,
      type = PaymentType.historico;
  static Future<void> openCuota(BuildContext context, Payment cuota) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailScreen.cuota(cuota: cuota),
          settings: RouteSettings(name: cuota.description),
        ),
      );
  static Future<void> openTasa(BuildContext context, Fee tasa) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailScreen.tasa(tasa: tasa),
          settings: RouteSettings(name: tasa.description),
        ),
      );
  static Future<void> openHistorico(BuildContext context, PaymentRecord pago) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaymentDetailScreen.historico(pago: pago),
          settings: RouteSettings(name: pago.concept),
        ),
      );
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final String title = switch (type) {
      PaymentType.cuota => l.paymentDetailCuota,
      PaymentType.tasa => l.paymentDetailTasa,
      PaymentType.historico => l.paymentDetailPago,
    };
    return Scaffold(
      backgroundColor: NexoTheme.bg,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: PaymentDetailBody(payment: payment, type: type),
      ),
    );
  }
}

class PaymentDetailBody extends StatelessWidget {
  const PaymentDetailBody({
    super.key,
    required this.payment,
    required this.type,
  });
  final Object payment;
  final PaymentType type;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _Hero(payment: payment, type: type),
            const Gap(AppSpacing.lg),
            _DetailsCard(payment: payment, type: type),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final Object payment;
  final PaymentType type;
  const _Hero({required this.payment, required this.type});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    String title = '';
    String subtitle = '';
    String amountText = '';
    Color statusColor = NexoTheme.primary;
    String statusLabel = '';
    if (type == PaymentType.cuota) {
      final cuota = payment as Payment;
      title = cuota.description;
      amountText = '${cuota.currency} ${cuota.total.toStringAsFixed(2)}';
      final days = cuota.daysUntilDue();
      final isOverdue = days != null && days < 0;
      final isSoon = days != null && days >= 0 && days <= 3;
      statusColor = isOverdue
          ? NexoTheme.danger
          : isSoon
          ? NexoTheme.warning
          : NexoTheme.success;
      statusLabel = isOverdue
          ? l.paymentsTabOverdue.toUpperCase()
          : days == 0
          ? l.paymentVenceHoy
          : days == 1
          ? l.paymentVenceMananaCaps
          : l.paymentsTabPending.toUpperCase();
      subtitle = l.paymentVenceEl(cuota.dueDateRaw);
    } else if (type == PaymentType.tasa) {
      final tasa = payment as Fee;
      title = tasa.description;
      amountText = '${tasa.currency} ${tasa.amount.toStringAsFixed(2)}';
      statusColor = NexoTheme.info;
      statusLabel = l.paymentsTabFees.toUpperCase();
      subtitle = l.paymentDetailTasaAdministrativa;
    } else if (type == PaymentType.historico) {
      final hist = payment as PaymentRecord;
      title = hist.concept;
      amountText = '${hist.currency} ${hist.amount.toStringAsFixed(2)}';
      statusColor = NexoTheme.success;
      statusLabel = l.paymentStatusPaid;
      subtitle = l.paymentDateOfPayment(hist.date);
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NexoTheme.primary, NexoTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadii.rXxl,
        boxShadow: [
          BoxShadow(
            color: NexoTheme.primary.withValues(alpha: 0.25),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm + 2,
                  vertical: 3,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: AppRadii.rPill,
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Gap(AppSpacing.lg),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppFont.h2,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
              height: 1.15,
            ),
          ),
          const Gap(AppSpacing.xs),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: AppFont.body,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Gap(AppSpacing.lg),
          Text(
            amountText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Object payment;
  final PaymentType type;
  const _DetailsCard({required this.payment, required this.type});
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fields = <_DetailField>[];
    if (type == PaymentType.cuota) {
      final cuota = payment as Payment;
      fields.add(
        _DetailField(
          l.paymentDetailImporteBase,
          '${cuota.currency} ${cuota.amount.toStringAsFixed(2)}',
          Icons.payments_outlined,
        ),
      );
      if (cuota.lateFee > 0) {
        fields.add(
          _DetailField(
            l.paymentMoraLabel,
            '${cuota.currency} ${cuota.lateFee.toStringAsFixed(2)}',
            Icons.warning_amber_rounded,
            isWarning: true,
          ),
        );
      }
      fields.add(
        _DetailField(
          l.paymentDetailFechaVencimiento,
          cuota.dueDateRaw,
          Icons.event_outlined,
        ),
      );
      if (cuota.note.trim().isNotEmpty && cuota.note.trim() != '--') {
        fields.add(
          _DetailField(
            l.paymentDetailObservacion,
            cuota.note,
            Icons.info_outline,
          ),
        );
      }
    } else if (type == PaymentType.tasa) {
      final tasa = payment as Fee;
      fields.add(
        _DetailField(
          l.paymentDetailConcepto,
          tasa.description,
          Icons.receipt_long_rounded,
        ),
      );
      fields.add(
        _DetailField(
          l.paymentDetailImporte,
          '${tasa.currency} ${tasa.amount.toStringAsFixed(2)}',
          Icons.payments_outlined,
        ),
      );
      if (tasa.note.trim().isNotEmpty && tasa.note.trim() != '--') {
        fields.add(
          _DetailField(
            l.paymentDetailObservacion,
            tasa.note,
            Icons.info_outline,
          ),
        );
      }
    } else if (type == PaymentType.historico) {
      final hist = payment as PaymentRecord;
      fields.add(
        _DetailField(
          l.paymentDetailConcepto,
          hist.concept,
          Icons.receipt_long_rounded,
        ),
      );
      fields.add(
        _DetailField(
          l.paymentDetailImportePagado,
          '${hist.currency} ${hist.amount.toStringAsFixed(2)}',
          Icons.payments_outlined,
        ),
      );
      fields.add(
        _DetailField(l.paymentDetailFechaPago, hist.date, Icons.event_outlined),
      );
      if (hist.time.trim().isNotEmpty && hist.time.trim() != '--') {
        fields.add(
          _DetailField(
            l.paymentDetailHoraPago,
            hist.time,
            Icons.schedule_rounded,
          ),
        );
      }
      if (hist.term.trim().isNotEmpty) {
        fields.add(
          _DetailField(
            l.paymentDetailPeriodoAcademico,
            hist.term,
            Icons.school_outlined,
          ),
        );
      }
      if (hist.voucher.trim().isNotEmpty) {
        fields.add(
          _DetailField(
            l.paymentDetailComprobante,
            hist.voucher,
            Icons.assignment_outlined,
          ),
        );
      }
      if (hist.place.trim().isNotEmpty) {
        fields.add(
          _DetailField(
            l.paymentDetailLugarPago,
            hist.place,
            Icons.storefront_outlined,
          ),
        );
      }
      if (hist.serial.trim().isNotEmpty || hist.number.trim().isNotEmpty) {
        fields.add(
          _DetailField(
            l.paymentDetailOperacion,
            '${hist.serial} - ${hist.number}',
            Icons.vpn_key_outlined,
          ),
        );
      }
      if (hist.operationType.trim().isNotEmpty &&
          hist.operationType.trim() != '--') {
        fields.add(
          _DetailField(
            l.paymentDetailDescripcionOperacion,
            hist.operationType,
            Icons.description_outlined,
          ),
        );
      }
      if (hist.note.trim().isNotEmpty && hist.note.trim() != '--') {
        fields.add(
          _DetailField(
            l.paymentDetailObservacion,
            hist.note,
            Icons.info_outline,
          ),
        );
      }
    }
    return SectionCard(
      title: l.paymentDetailInformacionDetallada,
      icon: Icons.info_outline,
      iconColor: NexoTheme.primary,
      child: Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[
            _FieldRow(field: fields[i]),
            if (i < fields.length - 1)
              Divider(color: NexoTheme.border, height: 24),
          ],
        ],
      ),
    );
  }
}

class _DetailField {
  final String label;
  final String value;
  final IconData icon;
  final bool isWarning;
  _DetailField(this.label, this.value, this.icon, {this.isWarning = false});
}

class _FieldRow extends StatelessWidget {
  final _DetailField field;
  const _FieldRow({required this.field});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          field.icon,
          size: 20,
          color: field.isWarning ? NexoTheme.danger : NexoTheme.textSecondary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                field.label,
                style: TextStyle(
                  fontSize: 12,
                  color: NexoTheme.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                field.value,
                style: TextStyle(
                  fontSize: 14,
                  color: field.isWarning
                      ? NexoTheme.danger
                      : NexoTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
