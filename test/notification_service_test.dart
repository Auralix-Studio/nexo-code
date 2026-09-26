import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexo/core/secret_store.dart';
import 'package:nexo/core/storage.dart';
import 'package:nexo/data/notification_service.dart';
import 'package:nexo/domain/notification_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'class_grouping_test.dart' show session;

class RecordingNotifications implements FlutterLocalNotificationsPlugin {
  final scheduled = <Invocation>[];
  final cancelled = <int>[];
  final pending = <PendingNotificationRequest>[];
  int cleared = 0;
  bool failSchedule = false;
  Completer<void>? blockedSchedule;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #initialize:
        return Future<bool>.value(true);
      case #resolvePlatformSpecificImplementation:
        return null;
      case #pendingNotificationRequests:
        return Future<List<PendingNotificationRequest>>.value(List.of(pending));
      case #zonedSchedule:
        scheduled.add(invocation);
        if (failSchedule) {
          return Future<void>.error(StateError('scheduler failed'));
        }
        return blockedSchedule?.future ?? Future<void>.value();
      case #cancel:
        cancelled.add(invocation.positionalArguments.first as int);
        return Future<void>.value();
      case #cancelAll:
        cleared++;
        scheduled.clear();
        return Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RecordingNotifications plugin;
  late NotificationService service;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    await AppStorage.init(secrets: MemorySecretStore());
    await AppStorage.instance.setNotifPrefsJson(
      jsonEncode(const NotificationPrefs(enabled: true).toJson()),
    );
    plugin = RecordingNotifications();
    service = NotificationService.forTesting(
      plugin: plugin,
      timezoneName: () async => 'America/Lima',
    );
  });
  tearDown(() {
    service.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  // Tomorrow in Peru, safely beyond the reminder lead time at any test hour.
  int tomorrow() => DateTime.now()
      .toUtc()
      .subtract(const Duration(hours: 5))
      .add(const Duration(days: 1))
      .weekday;

  test('startup replays four sessions as two course reminders', () async {
    await service.reschedule(
      clases: [
        session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
        session(
          'FÍSICA',
          weekday: tomorrow(),
          start: '10:00',
          end: '11:00',
          type: 'P',
        ),
        session('ÁLGEBRA', weekday: tomorrow(), start: '13:00', end: '14:00'),
        session(
          'ÁLGEBRA',
          weekday: tomorrow(),
          start: '14:00',
          end: '15:00',
          type: 'P',
        ),
      ],
    );
    expect(plugin.scheduled, isEmpty);
    await service.init();
    expect(plugin.scheduled, hasLength(2));
    expect(plugin.scheduled.first.positionalArguments[1], 'FÍSICA');
    final when = plugin.scheduled.first.positionalArguments[3] as tz.TZDateTime;
    expect(when.hour, 8);
    expect(when.minute, 30);
  });

  test(
    'refresh cancels obsolete reminders but preserves notes and updates',
    () async {
      plugin.pending.addAll(const [
        PendingNotificationRequest(10008, 'old class', '', null),
        PendingNotificationRequest(20008, 'old payment', '', null),
        PendingNotificationRequest(30008, 'grade', '', null),
        PendingNotificationRequest(40001, 'update', '', null),
      ]);
      await service.init();
      await service.reschedule(clases: [], installments: []);
      expect(plugin.cancelled, [10008, 20008]);
      expect(plugin.cleared, 0);
    },
  );

  test('unknown data does not remove existing reminders', () async {
    plugin.pending.addAll(const [
      PendingNotificationRequest(10008, 'class', '', null),
      PendingNotificationRequest(20008, 'payment', '', null),
    ]);
    await service.init();
    await service.reschedule();
    expect(plugin.cancelled, isEmpty);
    await service.reschedule(clases: []);
    expect(plugin.cancelled, [10008]);
  });

  test('preference updates retain finished subjects', () async {
    await service.reschedule(
      clases: [
        session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
      ],
      finishedSubjects: {'FISICA'},
    );
    await service.init();
    await service.updatePrefs(
      const NotificationPrefs(enabled: true, classLeadMinutes: 15),
    );
    expect(plugin.scheduled, isEmpty);
  });

  test('scheduler failure preserves existing reminders', () async {
    plugin.pending.add(
      const PendingNotificationRequest(10008, 'class', '', null),
    );
    plugin.failSchedule = true;
    await service.init();
    await service.reschedule(
      clases: [
        session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
      ],
    );
    expect(plugin.cancelled, isEmpty);
    expect(plugin.cleared, 0);
  });

  test('logout discards the snapshot waiting for initialization', () async {
    await service.reschedule(
      clases: [
        session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
      ],
    );
    await service.clearAccount();
    await service.init();
    expect(plugin.scheduled, isEmpty);
    expect(plugin.cleared, 1);
  });

  test(
    'logout waits for ongoing scheduling and clears its notifications',
    () async {
      await service.init();
      plugin.blockedSchedule = Completer<void>();
      final scheduled = service.reschedule(
        clases: [
          session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
        ],
      );
      await Future<void>.delayed(Duration.zero);
      expect(plugin.scheduled, hasLength(1));
      final cleared = service.clearAccount();
      plugin.blockedSchedule!.complete();
      await Future.wait([scheduled, cleared]);
      expect(plugin.cleared, 1);
      expect(plugin.scheduled, isEmpty);
      await service.reschedule();
      expect(plugin.scheduled, isEmpty);
    },
  );

  test('Windows schedules dated reminders', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await service.init();
    await service.reschedule(
      clases: [
        session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
      ],
    );
    expect(plugin.scheduled, hasLength(1));
  });

  test('identical refresh does not reschedule alarms', () async {
    await service.init();
    final classes = [
      session('FÍSICA', weekday: tomorrow(), start: '09:00', end: '10:00'),
    ];
    await service.reschedule(clases: classes);
    final count = plugin.scheduled.length;
    await service.reschedule(clases: List.of(classes));
    expect(plugin.scheduled.length, count);
    await service.updatePrefs(
      const NotificationPrefs(enabled: true, classLeadMinutes: 15),
    );
    expect(plugin.scheduled.length, greaterThan(count));
  });
}
