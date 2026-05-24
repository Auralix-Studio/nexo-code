/// Preferencias de notificaciones, persistidas como JSON.
class NotificationPrefs {
  /// Interruptor maestro. Si está apagado, no se envía nada.
  final bool enabled;

  // --- Pagos ---
  final bool paymentsEnabled;
  /// Días de antelación para avisar de una cuota (ej. [3, 1, 0]).
  /// 0 = el mismo día del vencimiento.
  final List<int> paymentLeadDays;
  /// Hora del día (0-23) para los avisos de pago.
  final int paymentHour;

  // --- Clases ---
  final bool classesEnabled;
  /// Minutos de antelación antes del inicio de cada clase.
  final int classLeadMinutes;

  // --- Notas ---
  /// Avisar cuando se detecta una nota nueva o cambiada.
  final bool gradesEnabled;

  const NotificationPrefs({
    this.enabled = false,
    this.paymentsEnabled = true,
    this.paymentLeadDays = const [3, 1, 0],
    this.paymentHour = 9,
    this.classesEnabled = true,
    this.classLeadMinutes = 30,
    this.gradesEnabled = true,
  });

  static const opcionesLeadDays = [3, 1, 0];
  static const opcionesLeadMinutes = [15, 30, 60, 120];

  NotificationPrefs copyWith({
    bool? enabled,
    bool? paymentsEnabled,
    List<int>? paymentLeadDays,
    int? paymentHour,
    bool? classesEnabled,
    int? classLeadMinutes,
    bool? gradesEnabled,
  }) {
    return NotificationPrefs(
      enabled: enabled ?? this.enabled,
      paymentsEnabled: paymentsEnabled ?? this.paymentsEnabled,
      paymentLeadDays: paymentLeadDays ?? this.paymentLeadDays,
      paymentHour: paymentHour ?? this.paymentHour,
      classesEnabled: classesEnabled ?? this.classesEnabled,
      classLeadMinutes: classLeadMinutes ?? this.classLeadMinutes,
      gradesEnabled: gradesEnabled ?? this.gradesEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'paymentsEnabled': paymentsEnabled,
        'paymentLeadDays': paymentLeadDays,
        'paymentHour': paymentHour,
        'classesEnabled': classesEnabled,
        'classLeadMinutes': classLeadMinutes,
        'gradesEnabled': gradesEnabled,
      };

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) {
    return NotificationPrefs(
      enabled: j['enabled'] as bool? ?? false,
      paymentsEnabled: j['paymentsEnabled'] as bool? ?? true,
      paymentLeadDays: (j['paymentLeadDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [3, 1, 0],
      paymentHour: (j['paymentHour'] as num?)?.toInt() ?? 9,
      classesEnabled: j['classesEnabled'] as bool? ?? true,
      classLeadMinutes: (j['classLeadMinutes'] as num?)?.toInt() ?? 30,
      gradesEnabled: j['gradesEnabled'] as bool? ?? true,
    );
  }

  static String labelLeadDays(int d) => switch (d) {
        0 => 'El mismo día',
        1 => '1 día antes',
        _ => '$d días antes',
      };

  static String labelLeadMinutes(int m) => switch (m) {
        60 => '1 hora antes',
        120 => '2 horas antes',
        _ => '$m min antes',
      };
}
