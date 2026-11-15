part of '../app_store.dart';

/// Pagos del estudiante. Pendientes, vencidos y tasas comparten una sola
/// respuesta de `/payments` (ver [NexoRepository]). Respetan
/// [FreshnessTtl.payments] salvo con `force`.
mixin _PaymentsStore on _StoreBase {
  AsyncValue<List<Payment>> pendingInstallments = const AsyncValue.idle();
  AsyncValue<List<Payment>> intranetInstallments = const AsyncValue.idle();
  AsyncValue<List<Fee>> tasas = const AsyncValue.idle();
  AsyncValue<List<PaymentRecord>> historico = const AsyncValue.idle();
  AsyncValue<PaymentSchedule> paymentSchedule = const AsyncValue.idle();

  void _clearPayments() {
    pendingInstallments = const AsyncValue.idle();
    intranetInstallments = const AsyncValue.idle();
    tasas = const AsyncValue.idle();
    historico = const AsyncValue.idle();
    paymentSchedule = const AsyncValue.idle();
  }

  Future<List<Payment>?> loadCuotasPendientes({bool force = false}) => _wrap(
    () => _fetchOrEmpty((r) => r.pendingPayments()),
    () => pendingInstallments,
    (v) => pendingInstallments = v,
    cached: () => _cache.getPagos(),
    persist: (v) => _cache.savePagos(v),
    operationName: 'loadCuotasPendientes',
    ttl: FreshnessTtl.payments,
    force: force,
  );

  /// Cargos vencidos, matrícula incluida.
  Future<List<Payment>?> loadCuotasIntranet({bool force = false}) => _wrap(
    () => _fetchOrEmpty((r) => r.overduePayments()),
    () => intranetInstallments,
    (v) => intranetInstallments = v,
    operationName: 'loadCuotasIntranet',
    ttl: FreshnessTtl.payments,
    force: force,
  );

  Future<List<Fee>?> loadTasas({bool force = false}) => _wrap(
    () => _fetchOrEmpty((r) => r.fees()),
    () => tasas,
    (v) => tasas = v,
    operationName: 'loadTasas',
    ttl: FreshnessTtl.payments,
    force: force,
  );

  Future<List<PaymentRecord>?> loadHistorico({bool force = false}) => _wrap(
    () => _fetchOrEmpty((r) => r.paymentHistory()),
    () => historico,
    (v) => historico = v,
    operationName: 'loadHistorico',
    ttl: FreshnessTtl.payments,
    force: force,
  );

  Future<PaymentSchedule?> loadPaymentSchedule() => _wrap(
    () => _fetch((r) => r.paymentSchedule()),
    () => paymentSchedule,
    (v) => paymentSchedule = v,
    operationName: 'loadPaymentSchedule',
  );
}
