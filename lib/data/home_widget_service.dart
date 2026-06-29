import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:nexo/domain/unified_models.dart';
import 'package:nexo/shared/util/formatters.dart';
import 'package:nexo/data/app_store.dart';

/// Empuja datos de la app a los widgets de la pantalla de inicio de Android.
/// No-op en plataformas sin soporte (Windows, etc.).
class HomeWidgetService {
  static const _appGroup = 'pe.upla.nexo.widgets';

  // Nombres de los AppWidgetProvider nativos (Kotlin).
  static const _wNext = 'NextClassWidgetProvider';
  static const _wToday = 'TodayWidgetProvider';
  static const _wPay = 'PaymentWidgetProvider';
  static const _wAcad = 'AcademicWidgetProvider';

  bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> init() async {
    if (!_supported) return;
    try {
      await HomeWidget.setAppGroupId(_appGroup);
    } catch (_) {}
  }

  /// Sincroniza todos los widgets con el estado actual del store.
  Future<void> sync(AppStore store) async {
    if (!_supported) return;
    try {
      await _syncNextAndToday(store.horario.value ?? const []);
      await _syncPayment(store.cuotasPendientes.value ?? const []);
      await _syncAcademic(
        promedio: store.promedioAcumulado,
        creditosAprob: store.creditosAprobados,
        creditosTotal: store.creditosTotales,
      );
    } catch (e) {
      debugPrint('HomeWidget sync error: $e');
    }
  }

  Future<void> _save(String k, String v) =>
      HomeWidget.saveWidgetData<String>(k, v);

  Future<void> _syncNextAndToday(List<ScheduleClass> horario) async {
    final now = DateTime.now();
    final today = now.weekday;

    String nextTitle = 'Sin clases próximas';
    String nextSub = '';
    String nextWhen = '';
    final nowMin = now.hour * 60 + now.minute;
    outer:
    for (var off = 0; off < 8; off++) {
      final dia = ((today - 1 + off) % 7) + 1;
      final list = horario.where((c) => c.weekday == dia).toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      for (final c in list) {
        final ini = _toMin(c.startTime);
        if (off == 0 && ini != null && ini <= nowMin) continue;
        nextTitle = c.subject;
        nextSub = '${c.startTime}–${c.endTime}'
            '${c.room.isNotEmpty ? ' · ${Fmt.formatAula(c.room)}' : ''}';
        if (off == 0 && ini != null) {
          final d = ini - nowMin;
          nextWhen = d < 60 ? 'En $d min' : 'En ${d ~/ 60}h ${d % 60}min';
        } else {
          nextWhen = off == 1 ? 'Mañana' : Fmt.dayLabel(dia);
        }
        break outer;
      }
    }
    await _save('next_title', nextTitle);
    await _save('next_sub', nextSub);
    await _save('next_when', nextWhen);

    final hoy = horario.where((c) => c.weekday == today).toList();
    final grupos = ScheduleClassGroup.groupBy(hoy);
    final buf = StringBuffer();
    for (final g in grupos.take(6)) {
      buf.writeln('${g.startTime}  ${g.subject}');
    }
    await _save(
      'today_list',
      buf.isEmpty ? 'Sin clases hoy 🎉' : buf.toString().trim(),
    );
    await _save('today_count', '${grupos.length}');
    await _save('today_day', Fmt.dayLabel(today));

    await HomeWidget.updateWidget(name: _wNext, androidName: _wNext);
    await HomeWidget.updateWidget(name: _wToday, androidName: _wToday);
  }

  Future<void> _syncPayment(List<Payment> pagos) async {
    final sorted = [...pagos]..sort((a, b) {
        final da = a.dueDate, db = b.dueDate;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    if (sorted.isEmpty) {
      await _save('pay_desc', 'Sin deudas pendientes');
      await _save('pay_amount', '');
      await _save('pay_due', '✓ Al día');
    } else {
      final c = sorted.first;
      final d = c.daysUntilDue();
      await _save('pay_desc', c.description);
      await _save('pay_amount',
          '${c.currency} ${c.total.toStringAsFixed(2)}');
      await _save(
        'pay_due',
        d == null
            ? c.dueDateRaw
            : d < 0
                ? 'Vencida hace ${-d} d'
                : d == 0
                    ? 'Vence hoy'
                    : 'Vence en $d d (${c.dueDateRaw})',
      );
    }
    await HomeWidget.updateWidget(name: _wPay, androidName: _wPay);
  }

  Future<void> _syncAcademic({
    double? promedio,
    int? creditosAprob,
    int? creditosTotal,
  }) async {
    await _save('acad_avg',
        promedio == null ? '—' : promedio.toStringAsFixed(2));
    await _save(
      'acad_credits',
      creditosAprob == null
          ? '—'
          : creditosTotal != null && creditosTotal > 0
              ? '$creditosAprob/$creditosTotal'
              : '$creditosAprob',
    );
    await HomeWidget.updateWidget(name: _wAcad, androidName: _wAcad);
  }

  static int? _toMin(String hm) {
    final p = hm.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }
}
