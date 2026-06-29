import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:nexo/core/storage.dart';
import 'package:nexo/domain/notification_prefs.dart';
import 'package:nexo/domain/unified_models.dart';

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
  static const _idUpdate = 40001;
  static const _payloadUpdateInstall = 'nexo:update:install';

  /// Callback que se dispara cuando el usuario toca la notificación de
  /// actualización lista. Lo setea el wiring en main.dart con la instancia
  /// de UpdateService que debe lanzar el instalador.
  Future<void> Function()? onInstallUpdateTap;

  /// Modo de alarma en Android. Por defecto **EXACTO**: las inexactas las
  /// agrupa/posterga el sistema (Doze) y llegaban con 30+ min de retraso o a
  /// media clase. Si el dispositivo no permite exactas (Android 13+ sin el
  /// permiso SCHEDULE_EXACT_ALARM concedido), cae a inexacto como respaldo.
  AndroidScheduleMode _androidMode = AndroidScheduleMode.exactAllowWhileIdle;

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
      onDidReceiveNotificationResponse: _onTap,
    );
    _ready = true;
  }

  void _onTap(NotificationResponse r) {
    if (r.payload == _payloadUpdateInstall) {
      final cb = onInstallUpdateTap;
      if (cb != null) unawaited(cb());
    }
  }

  Future<bool> requestPermission() async {
    if (!_supported || !_ready) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await android?.requestNotificationsPermission();
      // Además del permiso de notificaciones, asegurar el de alarmas exactas
      // para que los recordatorios lleguen a tiempo.
      await _ensureExactAlarms(request: true);
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

  /// Resuelve si podemos programar alarmas **exactas** (Android 12+ requiere el
  /// permiso `SCHEDULE_EXACT_ALARM`). Si [request] y no está concedido, lo pide
  /// (en Android 13+ abre la pantalla de Ajustes). Ajusta [_androidMode]: exacto
  /// si está permitido, inexacto como respaldo.
  Future<void> _ensureExactAlarms({bool request = false}) async {
    if (!_supportsScheduling ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    var can = await android.canScheduleExactNotifications() ?? false;
    if (!can && request) {
      await android.requestExactAlarmsPermission();
      can = await android.canScheduleExactNotifications() ?? false;
    }
    _androidMode = can
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> updatePrefs(
    NotificationPrefs prefs, {
    List<ScheduleClass>? clases,
    List<Payment>? cuotas,
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
    List<ScheduleClass>? clases,
    List<Payment>? cuotas,
  }) async {
    if (!_supported || !_ready) return;
    if (_supportsScheduling) {
      await _plugin.cancelAll();
    }
    if (!_prefs.enabled) return;

    // Programaciones futuras solo donde el backend soporta zonedSchedule.
    if (!_supportsScheduling) return;

    // Elegir exacto/inexacto según el permiso actual (sin abrir Ajustes aquí;
    // eso se pide al activar las notificaciones).
    await _ensureExactAlarms();

    if (_prefs.classesEnabled && clases != null) {
      await _scheduleClasses(clases);
    }
    if (_prefs.paymentsEnabled && cuotas != null) {
      await _schedulePayments(cuotas);
    }
  }

  Future<void> _scheduleClasses(List<ScheduleClass> clases) async {
    final now = tz.TZDateTime.now(tz.local);
    var id = _idClassBase;
    // Próximos 7 días de clases.
    for (var offset = 0; offset < 7; offset++) {
      final day = now.add(Duration(days: offset));
      final weekday = day.weekday; // 1=Lun..7=Dom
      for (final c in clases.where((c) => c.weekday == weekday)) {
        final hm = c.startTime.split(':');
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
          c.subject,
          'Empieza en ${_prefs.classLeadMinutes} minutos',
          when,
          'clases',
          'Recordatorio de clases',
        );
      }
    }
  }

  Future<void> _schedulePayments(List<Payment> pagos) async {
    final now = tz.TZDateTime.now(tz.local);
    var id = _idPaymentBase;
    for (final c in pagos) {
      final due = c.dueDate;
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
          '${c.description}: ${c.currency} '
              '${c.total.toStringAsFixed(2)} (${c.dueDateRaw})',
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
        androidScheduleMode: _androidMode,
      );
    } catch (_) {
      // Si las exactas no están permitidas en este dispositivo, no perder la
      // notificación: bajar a inexacto el resto de la sesión y reintentar.
      if (_androidMode == AndroidScheduleMode.exactAllowWhileIdle) {
        _androidMode = AndroidScheduleMode.inexactAllowWhileIdle;
        try {
          await _plugin.zonedSchedule(
            id,
            title,
            body,
            when,
            _details(channelId, channelName),
            androidScheduleMode: _androidMode,
          );
        } catch (_) {}
      }
    }
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

  /// Hay una versión nueva detectada pero aún no se pudo descargar (sin red,
  /// fallo de GitHub, etc.). Se mostrará la "ready" cuando la descarga
  /// termine — esta es un fallback informativo.
  Future<void> showUpdateAvailable(String version) async {
    if (!_supported || !_ready) return;
    await _plugin.show(
      _idUpdate,
      'Actualización disponible',
      'Nexo $version está disponible. Se descargará cuando haya conexión.',
      _details('actualizaciones', 'Actualizaciones'),
    );
  }

  /// El APK nuevo ya está descargado — tocar la notificación dispara el
  /// instalador del sistema vía [onInstallUpdateTap].
  Future<void> showUpdateReady(String version) async {
    if (!_supported || !_ready) return;
    await _plugin.show(
      _idUpdate,
      'Actualización lista para instalar',
      'Toca para instalar Nexo $version.',
      _details('actualizaciones', 'Actualizaciones'),
      payload: _payloadUpdateInstall,
    );
  }
}
