import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';

class NotificationPrefs {
  final bool enabled;
  final bool paymentsEnabled;
  final List<int> paymentLeadDays;
  final int paymentHour;
  final bool classesEnabled;
  final int classLeadMinutes;
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
      paymentLeadDays:
          (j['paymentLeadDays'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [3, 1, 0],
      paymentHour: (j['paymentHour'] as num?)?.toInt() ?? 9,
      classesEnabled: j['classesEnabled'] as bool? ?? true,
      classLeadMinutes: (j['classLeadMinutes'] as num?)?.toInt() ?? 30,
      gradesEnabled: j['gradesEnabled'] as bool? ?? true,
    );
  }
  static String labelLeadDays(BuildContext context, int d) {
    final l10n = AppLocalizations.of(context);
    return switch (d) {
      0 => l10n.prefSameDay,
      1 => l10n.prefOneDayBefore,
      _ => l10n.prefDaysBefore(d),
    };
  }

  static String labelLeadMinutes(BuildContext context, int m) {
    final l10n = AppLocalizations.of(context);
    return switch (m) {
      60 => l10n.prefOneHourBefore,
      120 => l10n.prefTwoHoursBefore,
      _ => l10n.prefMinBefore(m),
    };
  }
}
