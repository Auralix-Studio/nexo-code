import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:nexo/core/storage.dart';
import 'package:nexo/domain/models.dart';
import 'package:nexo/domain/notification_prefs.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  NotificationPrefs _prefs = const NotificationPrefs();

  NotificationPrefs get prefs => _prefs;

  /// Plataformas con backend nativo de notificaciones. Web no tiene; las
  /// demás (Android/iOS/macOS/Linux/Windows) están soportadas por
  /// flutter_local_notifications >=19.
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);

  /// Plataformas donde tiene sentido programar notificaciones futuras
  /// (`zonedSchedule`). En Windows, el backend WinRT no soporta
  /// `zonedSchedule`; ahí solo usamos `show()` (inmediatas, como las de
  /// "nueva nota publicada"). Programaciones futuras de clases/pagos siguen
  /// activas en mobile/macOS/Linux.
  bool get _supportsScheduling =>
      _supported && defaultTargetPlatform != TargetPlatform.windows;

  static const _idClassBase = 10000;
  static const _idPaymentBase = 20000;
  static const _idGradeBase = 30000;

  Future<void> init() async {
    final raw = AppStorage.instance.notifPrefsJson;
    if (raw != null) {
      try {
        _prefs = NotificationPrefs.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {}
    }
    if (!_supported) return;
    try {
      tzdata.initializeTimeZones();
      final name = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (_) {}

    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    const macos = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Abrir');
    // AUMID consistente con la instalación de Windows (HKCU\...\Uninstall\Nexo
    // y los .lnk creados por WinSetupService apuntan al mismo ejecutable).
    // GUID estable para que Action Center agrupe correctamente.
    const windows = WindowsInitializationSettings(
      appName: 'Nexo UPLA',
      appUserModelId: 'pe.upla.nexo',
      guid: 'd2c4f88a-2d4b-4c0e-9e2c-3e7a4b9f1c10',
    );
    await _plugin.initialize(
      const InitializationSettings(
        android: android,
        iOS: ios,
        macOS: macos,
        linux: linux,
        windows: windows,
      ),
    );
    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (!_supported || !_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      final mac = _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >();
      final granted = await mac?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    // Linux/Windows: no requieren permiso explícito en runtime.
    return true;
  }

  Future<void> updatePrefs(
    NotificationPrefs prefs, {
    List<ClaseHorario>? clases,
    List<Cuota>? cuotas,
  }) async {
    _prefs = prefs;
    await AppStorage.instance.setNotifPrefsJson(jsonEncode(prefs.toJson()));
    notifyListeners();
    if (prefs.enabled) await requestPermission();
    await reschedule(clases: clases, cuotas: cuotas);
  }

  AndroidNotificationDetails _androidDetails(String channelId, String name) =>
      AndroidNotificationDetails(
        channelId,
        name,
        importance: Importance.high,
        priority: Priority.high,
      );

  NotificationDetails _details(String channelId, String name) =>
      NotificationDetails(
        android: _androidDetails(channelId, name),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
        linux: const LinuxNotificationDetails(),
        windows: const WindowsNotificationDetails(),
      );

  Future<void> reschedule({
    List<ClaseHorario>? clases,
    List<Cuota>? cuotas,
  }) async {
    if (!_supported || !_ready) return;
    if (_supportsScheduling) {
      await _plugin.cancelAll();
    }
    if (!_prefs.enabled) return;

    // Programaciones futuras solo donde el backend soporta zonedSchedule.
    if (!_supportsScheduling) return;

    if (_prefs.classesEnabled && clases != null) {
      await _scheduleClasses(clases);
    }
    if (_prefs.paymentsEnabled && cuotas != null) {
      await _schedulePayments(cuotas);
    }
  }

  Future<void> _scheduleClasses(List<ClaseHorario> clases) async {
    final now = tz.TZDateTime.now(tz.local);
    var id = _idClassBase;
    // Próximos 7 días de clases.
    for (var offset = 0; offset < 7; offset++) {
      final day = now.add(Duration(days: offset));
      final weekday = day.weekday; // 1=Lun..7=Dom
      for (final c in clases.where((c) => c.idDia == weekday)) {
        final hm = c.horaInicio.split(':');
        if (hm.length < 2) continue;
        final h = int.tryParse(hm[0]);
        final m = int.tryParse(hm[1]);
        if (h == null || m == null) continue;
        final start = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          h,
          m,
        );
        final when = start.subtract(Duration(minutes: _prefs.classLeadMinutes));
        if (when.isBefore(now)) continue;
        await _zoned(
          id++,
          c.asignatura,
          'Empieza en ${_prefs.classLeadMinutes} minutos',
          when,
          'clases',
          'Recordatorio de clases',
        );
      }
    }
  }

  Future<void> _schedulePayments(List<Cuota> cuotas) async {
    final now = tz.TZDateTime.now(tz.local);
    var id = _idPaymentBase;
    for (final c in cuotas) {
      final due = c.vencimientoDate;
      if (due == null) continue;
      for (final lead in _prefs.paymentLeadDays) {
        final day = due.subtract(Duration(days: lead));
        final when = tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          _prefs.paymentHour,
          0,
        );
        if (when.isBefore(now)) continue;
        final cuando = lead == 0
            ? 'vence hoy'
            : lead == 1
            ? 'vence mañana'
            : 'vence en $lead días';
        await _zoned(
          id++,
          'Pago pendiente — $cuando',
          '${c.descripcion}: ${c.tipoMoneda} '
              '${c.subtotal.toStringAsFixed(2)} (${c.fechaVencimiento})',
          when,
          'pagos',
          'Recordatorio de pagos',
        );
      }
    }
  }

  Future<void> _zoned(
    int id,
    String title,
    String body,
    tz.TZDateTime when,
    String channelId,
    String channelName,
  ) async {
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        when,
        _details(channelId, channelName),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  Future<void> showGradeChanged(String curso, String nota) async {
    if (!_supported || !_ready || !_prefs.enabled || !_prefs.gradesEnabled) {
      return;
    }
    await _plugin.show(
      _idGradeBase + (curso.hashCode % 1000),
      'Nueva nota publicada',
      '$curso: $nota',
      _details('notas', 'Notas'),
    );
  }
}
