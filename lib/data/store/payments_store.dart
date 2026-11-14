part of '../app_store.dart';

/// Pagos del estudiante. Pendientes, vencidos y tasas comparten una sola
/// respuesta de `/payments` (ver [NexoRepository]).
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

  Future<List<Payment>?> loadCuotasPendientes() => _wrap(
    () => _fetchOrEmpty((r) => r.pendingPayments()),
    () => pendingInstallments,
    (v) => pendingInstallments = v,
    cached: () => _cache.getPagos(),
    persist: (v) => _cache.savePagos(v),
    operationName: 'loadCuotasPendientes',
  );

  /// Cargos vencidos, matrícula incluida.
  Future<List<Payment>?> loadCuotasIntranet() => _wrap(
    () => _fetchOrEmpty((r) => r.overduePayments()),
    () => intranetInstallments,
    (v) => intranetInstallments = v,
    operationName: 'loadCuotasIntranet',
  );

  Future<List<Fee>?> loadTasas() => _wrap(
    () => _fetchOrEmpty((r) => r.fees()),
    () => tasas,
    (v) => tasas = v,
    operationName: 'loadTasas',
  );

  Future<List<PaymentRecord>?> loadHistorico() => _wrap(
    () => _fetchOrEmpty((r) => r.paymentHistory()),
    () => historico,
    (v) => historico = v,
    operationName: 'loadHistorico',
  );

  Future<PaymentSchedule?> loadPaymentSchedule() => _wrap(
    () => _fetch((r) => r.paymentSchedule()),
    () => paymentSchedule,
    (v) => paymentSchedule = v,
    operationName: 'loadPaymentSchedule',
  );
}
