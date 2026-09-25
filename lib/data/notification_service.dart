import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:nexo/l10n/app_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:nexo/core/storage.dart';
import 'package:nexo/domain/course_status.dart';
import 'package:nexo/domain/notification_prefs.dart';
import 'package:nexo/domain/unified_models.dart';

class NotificationService extends ChangeNotifier {
  NotificationService._()
    : _plugin = FlutterLocalNotificationsPlugin(),
      _timezoneName = FlutterTimezone.getLocalTimezone;

  @visibleForTesting
  NotificationService.forTesting({
    required FlutterLocalNotificationsPlugin plugin,
    required Future<String> Function() timezoneName,
  }) : _plugin = plugin,
       _timezoneName = timezoneName;
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin;
  final Future<String> Function() _timezoneName;
  bool _ready = false;
  bool _clearOnInit = false;
  NotificationPrefs _prefs = const NotificationPrefs();
  NotificationPrefs get prefs => _prefs;
  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows);
  bool get _supportsScheduling =>
      _supported && defaultTargetPlatform != TargetPlatform.linux;
  static const _idClassBase = 10000;
  static const _idPaymentBase = 20000;
  static const _idGradeBase = 30000;
  static const _idUpdate = 40001;
  static const _payloadUpdateInstall = 'nexo:update:install';
  Future<void> Function()? onInstallUpdateTap;
  AndroidScheduleMode _androidMode = AndroidScheduleMode.exactAllowWhileIdle;
  Future<void> init() async {
    if (_ready) return;
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
      final name = await _timezoneName();
      tz.setLocalLocation(tz.getLocation(name));
    } catch (e) {
      // Los horarios académicos de UPLA usan la hora de Perú. Evitar UTC
      // cuando el sistema devuelve un nombre de zona no reconocido.
      tz.setLocalLocation(tz.getLocation('America/Lima'));
      debugPrint('Notification timezone fallback (America/Lima): $e');
    }
    const android = AndroidInitializationSettings('@mipmap/launcher_icon');
    const ios = DarwinInitializationSettings();
    const macos = DarwinInitializationSettings();
    const linux = LinuxInitializationSettings(defaultActionName: 'Abrir');
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
    if (_clearOnInit) {
      await _plugin.cancelAll();
      _clearOnInit = false;
    }
    _ready = true;
    if (_classes != null || _installments != null || !_prefs.enabled) {
      await reschedule();
    }
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
    return true;
  }

  Future<void> _ensureExactAlarms({bool request = false}) async {
    if (!_supportsScheduling ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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

  Future<bool> hasExactAlarmsPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.canScheduleExactNotifications() ?? false;
  }

  Future<void> requestExactAlarmsPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    await android.requestExactAlarmsPermission();
    await _ensureExactAlarms();
    await reschedule();
    notifyListeners();
  }

  Future<void> updatePrefs(
    NotificationPrefs prefs, {
    List<ScheduleClass>? clases,
    List<Payment>? installments,
    Set<String>? finishedSubjects,
  }) async {
    _prefs = prefs;
    await AppStorage.instance.setNotifPrefsJson(jsonEncode(prefs.toJson()));
    notifyListeners();
    if (prefs.enabled) await requestPermission();
    await reschedule(
      clases: clases,
      installments: installments,
      finishedSubjects: finishedSubjects,
    );
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
  Future<void> _scheduleWork = Future.value();
  List<ScheduleClass>? _classes;
  List<Payment>? _installments;
  Set<String> _finishedSubjects = const {};
  int _revision = 0;
  Set<int>? _desiredIds;

  Future<void> clearAccount() {
    if (!_ready) _clearOnInit = true;
    _revision++;
    _classes = null;
    _installments = null;
    _finishedSubjects = const {};
    final cleared = _scheduleWork.then((_) async {
      if (_supported && _ready) await _plugin.cancelAll();
    });
    _scheduleWork = cleared.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return cleared;
  }

  Future<void> reschedule({
    List<ScheduleClass>? clases,
    List<Payment>? installments,
    Set<String>? finishedSubjects,
  }) {
    if (clases != null) _classes = List.of(clases);
    if (installments != null) _installments = List.of(installments);
    if (finishedSubjects != null) _finishedSubjects = Set.of(finishedSubjects);
    final revision = ++_revision;
    if (!_supported || !_ready) return Future.value();
    _scheduleWork = _scheduleWork
        .then((_) async {
          if (revision != _revision || !_supportsScheduling) return;
          final classes = _classes;
          final payments = _installments;
          final finished = _finishedSubjects;
          final previous = await _plugin.pendingNotificationRequests();
          _desiredIds = <int>{};
          try {
            if (_prefs.enabled) {
              await _ensureExactAlarms();
              if (_prefs.classesEnabled && classes != null) {
                await _scheduleClasses(classes, finished);
              }
              if (_prefs.paymentsEnabled && payments != null) {
                await _schedulePayments(payments);
              }
            }
            // Conservar notas y avisos de actualización. Solo retirar los
            // recordatorios obsoletos después de programar sus reemplazos.
            for (final request in previous) {
              final isClass = request.id < _idPaymentBase;
              final categoryKnown = isClass
                  ? classes != null || !_prefs.enabled || !_prefs.classesEnabled
                  : payments != null ||
                        !_prefs.enabled ||
                        !_prefs.paymentsEnabled;
              if (request.id >= _idClassBase &&
                  request.id < _idGradeBase &&
                  categoryKnown &&
                  !_desiredIds!.contains(request.id)) {
                await _plugin.cancel(request.id);
              }
            }
          } finally {
            _desiredIds = null;
          }
        })
        .catchError((Object e) {
          debugPrint('Notification scheduling failed: $e');
        });
    return _scheduleWork;
  }

  Future<void> _scheduleClasses(
    List<ScheduleClass> clases,
    Set<String> finished,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var id = _idClassBase;
    for (var offset = 0; offset <= 7; offset++) {
      final day = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + offset,
      );
      final weekday = day.weekday;
      // Por GRUPO, no por sesión: teoría y práctica de la misma asignatura el
      // mismo día son dos `ScheduleClass`, y avisar de cada una daba dos
      // notificaciones casi seguidas del mismo curso. Se avisa una vez, a la
      // hora en que empieza el bloque, y no se avisa de talleres ya cerrados.
      final grupos = remindableGroups(
        classes: clases,
        weekday: weekday,
        finished: finished,
      );
      for (final c in grupos) {
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
        final l10n = lookupAppLocalizations(
          Locale(AppStorage.instance.localeCode ?? 'es'),
        );
        await _zoned(
          id++,
          c.subject,
          l10n.notifStartsIn(_prefs.classLeadMinutes),
          when,
          'classes',
          l10n.notifClassesReminder,
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
        final l10n = lookupAppLocalizations(
          Locale(AppStorage.instance.localeCode ?? 'es'),
        );
        final cuando = lead == 0
            ? l10n.notifDueToday
            : lead == 1
            ? l10n.notifDueTomorrow
            : l10n.notifDueInDays(lead);
        await _zoned(
          id++,
          l10n.notifPendingPayment(cuando),
          '${c.description}: ${c.currency} '
              '${c.total.toStringAsFixed(2)} (${c.dueDateRaw})',
          when,
          'payments',
          l10n.notifPaymentsReminder,
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
    _desiredIds?.add(id);
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
      if (defaultTargetPlatform == TargetPlatform.android &&
          _androidMode == AndroidScheduleMode.exactAllowWhileIdle) {
        _androidMode = AndroidScheduleMode.inexactAllowWhileIdle;
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          when,
          _details(channelId, channelName),
          androidScheduleMode: _androidMode,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> showGradeChanged(String course, String grade) {
    final shown = _scheduleWork.then((_) => _showGradeChanged(course, grade));
    _scheduleWork = shown.catchError((Object e) {
      debugPrint('Grade notification failed: $e');
    });
    return _scheduleWork;
  }

  Future<void> _showGradeChanged(String course, String grade) async {
    if (!_supported || !_ready || !_prefs.enabled || !_prefs.gradesEnabled) {
      return;
    }
    await _plugin.show(
      _idGradeBase + (course.hashCode % 1000),
      'Nueva nota publicada',
      '$course: $grade',
      _details('grades', 'Notas'),
    );
  }

  Future<void> showUpdateAvailable(String version) async {
    if (!_supported || !_ready) return;
    await _plugin.show(
      _idUpdate,
      'Actualización disponible',
      'Nexo $version está disponible. Se descargará cuando haya conexión.',
      _details('actualizaciones', 'Actualizaciones'),
    );
  }

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
