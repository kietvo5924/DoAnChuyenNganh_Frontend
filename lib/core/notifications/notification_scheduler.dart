import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationScheduler {
  NotificationScheduler._();
  static final NotificationScheduler instance = NotificationScheduler._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Allow service to decide whether to use AlarmClock for one-off alarms
  bool useAlarmClockForOneOff = true;

  Future<void> init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    try {
      await androidImpl?.requestNotificationsPermission();
      final enabled = await androidImpl?.areNotificationsEnabled();
      if (kDebugMode) {
        print('[Notifications][perm] areNotificationsEnabled=$enabled');
      }
    } catch (e) {
      if (kDebugMode) print('[Notifications][perm] notify perm err: $e');
    }

    try {
      await androidImpl?.requestExactAlarmsPermission();
      if (kDebugMode) {
        print(
          '[Notifications][perm] requested exact alarm permission (API 31+)',
        );
      }
    } catch (e) {
      if (kDebugMode) print('[Notifications][perm] exact alarm err: $e');
    }

    if (kDebugMode) {
      try {
        await androidImpl?.deleteNotificationChannel('my_schedule_channel_id');
        print(
          '[Notifications][chan] deleted channel -> will recreate on first use',
        );
      } catch (e) {
        print('[Notifications][chan] delete channel err: $e');
      }
    }
  }

  AndroidNotificationDetails _androidDetails() => AndroidNotificationDetails(
    'my_schedule_channel_id',
    'My Schedule Reminders',
    channelDescription: 'Kênh nhắc nhở công việc',
    importance: Importance.max,
    priority: Priority.high,
    enableVibration: true,
    playSound: true,
    category: AndroidNotificationCategory.message,
    visibility: NotificationVisibility.public,
    ticker: 'MySchedule Reminder',
    styleInformation: const BigTextStyleInformation(''),
    groupKey: 'planmate_reminders',
  );

  Future<void> scheduleZoned({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime when,
    DateTimeComponents? match,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    if (kDebugMode) {
      print(
        '[Notifications][zoned] try id=$id when=$when now=$now match=$match',
      );
    }
    if (!when.isAfter(now)) {
      if (kDebugMode)
        print('[Notifications][zoned] skip past id=$id when=$when');
      return;
    }

    final mode = (match == null && useAlarmClockForOneOff)
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(android: _androidDetails()),
      androidScheduleMode: mode,
      matchDateTimeComponents: match,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    if (kDebugMode) {
      print('[Notifications][zoned] scheduled OK id=$id when=$when mode=$mode');
    }
  }

  Future<void> showNow({
    required int id,
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: _androidDetails()),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  Future<void> cancelAll() => _plugin.cancelAll();

  Future<List<PendingNotificationRequest>> pendingRequests() =>
      _plugin.pendingNotificationRequests();
}
