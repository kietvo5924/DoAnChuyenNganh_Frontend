import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:planmate_app/domain/task/entities/task_entity.dart';
import '../notifications/notification_scheduler.dart';
import '../notifications/time_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../injection.dart';

class NotificationService {
  NotificationService._privateConstructor();
  static final NotificationService instance =
      NotificationService._privateConstructor();

  static const bool _alsoAtStartForTesting = true;
  static const bool _useAlarmClockForOneOff = true;
  static const int _allDayReminderHour = 18;
  static const int _allDayReminderMinute = 0;

  // NEW: preference keys and defaults
  static const _kLeadMinutesKey = 'notify_lead_minutes';
  static const _kPreDayEnabledKey = 'notify_preday_enabled';
  static const _kPreDayHourKey = 'notify_preday_hour';
  static const _kPreDayMinuteKey = 'notify_preday_minute';
  static const int _defaultLeadMinutes = 15;
  static const int _defaultPreDayHour = 18;
  static const int _defaultPreDayMinute = 0;

  // Helpers to read current prefs
  Future<int> _leadMinutes() async =>
      getIt<SharedPreferences>().getInt(_kLeadMinutesKey) ??
      _defaultLeadMinutes;
  Future<bool> _preDayEnabled() async =>
      getIt<SharedPreferences>().getBool(_kPreDayEnabledKey) ??
      true; // NOT USED ANYMORE
  Future<int> _preDayHour() async =>
      getIt<SharedPreferences>().getInt(_kPreDayHourKey) ?? _defaultPreDayHour;
  Future<int> _preDayMinute() async =>
      getIt<SharedPreferences>().getInt(_kPreDayMinuteKey) ??
      _defaultPreDayMinute;

  Future<void> init() async {
    // Timezone init stays here
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    } catch (_) {}

    // Delegate plugin init and permissions
    final sched = NotificationScheduler.instance;
    sched.useAlarmClockForOneOff = _useAlarmClockForOneOff; // config
    await sched.init();
  }

  Future<void> cancelAllNotifications() async {
    await NotificationScheduler.instance.cancelAll();
    if (kDebugMode) print('[Notifications] Đã hủy tất cả thông báo.');
  }

  Future<void> rescheduleAllFromDb(
    Database db, {
    int remindBeforeMinutes = 15,
  }) async {
    final usedLead = await _leadMinutes();
    // NEW: fixed pre-day time per requirement (18:00)
    final preH = _allDayReminderHour;
    final preM = _allDayReminderMinute;

    if (kDebugMode) {
      print(
        '[Notifications] Reschedule ALL from DB (remindBefore=$remindBeforeMinutes)',
      );
    }
    await cancelAllNotifications();
    final rows = await db.query('tasks');
    final now = DateTime.now();
    int scheduledCount = 0;
    final sched = NotificationScheduler.instance;

    for (final row in rows) {
      final id = row['id'] as int;
      final title = (row['title'] as String?) ?? 'Công việc';
      final repeatType = (row['repeat_type'] as String?) ?? 'NONE';
      if (kDebugMode)
        print('[Notifications][Task $id] "$title" repeatType=$repeatType');

      if (repeatType == 'NONE') {
        final startTimeStr = row['start_time'] as String?;
        if (kDebugMode) {
          print(
            '[Notifications][Task $id] start_time(UTC)="$startTimeStr" nowLocal=$now',
          );
        }
        if (startTimeStr != null) {
          final startTimeUtc = DateTime.tryParse(startTimeStr);
          if (startTimeUtc != null) {
            final startLocal = startTimeUtc.toLocal();

            final isAllDay = ((row['is_all_day'] as int?) ?? 0) == 1;
            if (isAllDay) {
              // CHANGED: use pre-day prefs time
              final baseDate = DateTime(
                startLocal.year,
                startLocal.month,
                startLocal.day,
              );
              final prevDay = baseDate.subtract(const Duration(days: 1));
              final fireAt = DateTime(
                prevDay.year,
                prevDay.month,
                prevDay.day,
                preH,
                preM,
              );
              if (kDebugMode) {
                print(
                  '[Notifications][Task $id] ALL-DAY remindAt(prev-day 18:00)=$fireAt nid=${_generateNotificationId(id, 0)}',
                );
              }
              if (fireAt.isAfter(now)) {
                await sched.scheduleZoned(
                  id: _generateNotificationId(id, 0),
                  title: title,
                  body: 'Nhắc sự kiện cả ngày vào ngày mai',
                  when: tz.TZDateTime.from(fireAt, tz.local),
                );
                scheduledCount++;
              } else if (kDebugMode) {
                print('[Notifications][Task $id] ALL-DAY skip (past)');
              }
              continue;
            }

            final beforeLocal = startLocal.subtract(
              Duration(minutes: usedLead),
            );
            if (beforeLocal.isAfter(now)) {
              if (kDebugMode) {
                print(
                  '[Notifications][Task $id] SINGLE remindAt=$beforeLocal nid=${_generateNotificationId(id, 0)}',
                );
              }
              await sched.scheduleZoned(
                id: _generateNotificationId(id, 0),
                title: title,
                body: 'Sắp tới giờ bắt đầu công việc',
                when: tz.TZDateTime.from(beforeLocal, tz.local),
              );
              scheduledCount++;
            } else if (kDebugMode) {
              print('[Notifications][Task $id] SINGLE remind skip (past)');
            }

            if (_alsoAtStartForTesting && startLocal.isAfter(now)) {
              if (kDebugMode) {
                print(
                  '[Notifications][Task $id] SINGLE atStart=$startLocal nid=${_generateNotificationId(id, 1)}',
                );
              }
              await sched.scheduleZoned(
                id: _generateNotificationId(id, 1),
                title: title,
                body: 'Đến giờ bắt đầu công việc',
                when: tz.TZDateTime.from(startLocal, tz.local),
              );
              scheduledCount++;
            }
          }
        }
      } else {
        final repeatStartTimeStr = row['repeat_start_time'] as String?;
        if (kDebugMode) {
          print(
            '[Notifications][Task $id] repeat_start_time="$repeatStartTimeStr"',
          );
        }
        if (repeatStartTimeStr == null) continue;

        final parts = repeatStartTimeStr.split(':');
        if (parts.length < 2) continue;
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;

        final remindBase = DateTime(
          2000,
          1,
          1,
          h,
          m,
        ).subtract(Duration(minutes: usedLead));
        final remindH = remindBase.hour;
        final remindM = remindBase.minute;
        final startH = h, startM = m;

        if (repeatType == 'DAILY') {
          final whenRemind = nextInstanceOfTime(remindH, remindM);
          if (kDebugMode) {
            print(
              '[Notifications][Task $id] DAILY remind next=$whenRemind nid=${_generateNotificationId(id, 0)}',
            );
          }
          await sched.scheduleZoned(
            id: _generateNotificationId(id, 0),
            title: title,
            body: 'Công việc hàng ngày sắp bắt đầu',
            when: whenRemind,
            match: DateTimeComponents.time,
          );
          scheduledCount++;

          if (_alsoAtStartForTesting) {
            final whenStart = nextInstanceOfTime(startH, startM);
            if (kDebugMode) {
              print(
                '[Notifications][Task $id] DAILY atStart next=$whenStart nid=${_generateNotificationId(id, 1)}',
              );
            }
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 1),
              title: title,
              body: 'Đến giờ bắt đầu công việc',
              when: whenStart,
              match: DateTimeComponents.time,
            );
            scheduledCount++;
          }

          // NEW: pre-day daily switched by per-task? For recurring, read flag from DB row:
          // daily applies pre-day only if row['pre_day_notify']==1
          final preDayOn = ((row['pre_day_notify'] as int?) ?? 0) == 1;
          if (preDayOn) {
            final preDaily = nextInstanceOfTime(preH, preM);
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 2),
              title: title,
              body: 'Nhắc việc ngày mai',
              when: preDaily,
              match: DateTimeComponents.time,
            );
            scheduledCount++;
          }
        } else if (repeatType == 'WEEKLY') {
          final rawDays = row['repeat_days'] as String?;
          if (rawDays != null && rawDays.trim().isNotEmpty) {
            final weekdays = _safeParseIntList(rawDays);
            final preDayOn = ((row['pre_day_notify'] as int?) ?? 0) == 1; // NEW
            for (int i = 0; i < weekdays.length; i++) {
              final wd = weekdays[i];

              // CHANGED: use 3 offsets per weekday to avoid collisions
              final nidRemind = _generateNotificationId(id, i * 3);
              final whenRemind = nextInstanceOfDayAndTime(wd, remindH, remindM);
              await sched.scheduleZoned(
                id: nidRemind,
                title: title,
                body: 'Công việc hàng tuần sắp bắt đầu',
                when: whenRemind,
                match: DateTimeComponents.dayOfWeekAndTime,
              );
              scheduledCount++;

              if (_alsoAtStartForTesting) {
                final nidStart = _generateNotificationId(id, i * 3 + 1);
                final whenStart = nextInstanceOfDayAndTime(wd, startH, startM);
                await sched.scheduleZoned(
                  id: nidStart,
                  title: title,
                  body: 'Đến giờ bắt đầu công việc',
                  when: whenStart,
                  match: DateTimeComponents.dayOfWeekAndTime,
                );
                scheduledCount++;
              }

              if (preDayOn) {
                final preWd = prevWeekday(wd);
                final nidPre = _generateNotificationId(id, i * 3 + 2);
                final whenPre = nextInstanceOfDayAndTime(preWd, preH, preM);
                await sched.scheduleZoned(
                  id: nidPre,
                  title: title,
                  body: 'Nhắc việc ngày mai',
                  when: whenPre,
                  match: DateTimeComponents.dayOfWeekAndTime,
                );
                scheduledCount++;
              }
            }
          }
        } else if (repeatType == 'MONTHLY') {
          // Define variables used below
          final int dayOfMonth =
              (row['repeat_day_of_month'] as int?) ??
              tryParseDateLocal(row['repeat_start'] as String?)?.day ??
              1;
          final DateTime? anchor = tryParseDateLocal(
            row['repeat_start'] as String?,
          );

          // Restore monthly remind (offset 0)
          final whenRemind = nextInstanceOfMonthly(
            day: dayOfMonth,
            hour: remindH,
            minute: remindM,
            anchor: anchor,
          );
          await sched.scheduleZoned(
            id: _generateNotificationId(id, 0),
            title: title,
            body: 'Công việc hàng tháng sắp bắt đầu',
            when: whenRemind,
            match: DateTimeComponents.dayOfMonthAndTime,
          );
          scheduledCount++;

          // Restore monthly at-start (offset 1) for debug/testing
          if (_alsoAtStartForTesting) {
            final whenStart = nextInstanceOfMonthly(
              day: dayOfMonth,
              hour: startH,
              minute: startM,
              anchor: anchor,
            );
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 1),
              title: title,
              body: 'Đến giờ bắt đầu công việc',
              when: whenStart,
              match: DateTimeComponents.dayOfMonthAndTime,
            );
            scheduledCount++;
          }

          // Pre-day one-off (offset 2) if enabled per-task
          final preDayOn = ((row['pre_day_notify'] as int?) ?? 0) == 1;
          if (preDayOn) {
            final whenPre = nextInstanceOfMonthlyPreDay(
              day: dayOfMonth,
              hour: preH,
              minute: preM,
              anchor: anchor,
            );
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 2),
              title: title,
              body: 'Nhắc việc ngày mai',
              when: whenPre,
            );
            scheduledCount++;
          }
        } else if (repeatType == 'YEARLY') {
          final startDate = tryParseDateLocal(row['repeat_start'] as String?);
          if (startDate != null) {
            final month = startDate.month;
            final day = startDate.day;

            // Restore yearly remind (offset 0)
            final whenRemind = nextInstanceOfYearly(
              month: month,
              day: day,
              hour: remindH,
              minute: remindM,
            );
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 0),
              title: title,
              body: 'Công việc hàng năm sắp bắt đầu',
              when: whenRemind,
              match: DateTimeComponents.dateAndTime,
            );
            scheduledCount++;

            // Restore yearly at-start (offset 1) for debug/testing
            if (_alsoAtStartForTesting) {
              final whenStart = nextInstanceOfYearly(
                month: month,
                day: day,
                hour: startH,
                minute: startM,
              );
              await sched.scheduleZoned(
                id: _generateNotificationId(id, 1),
                title: title,
                body: 'Đến giờ bắt đầu công việc',
                when: whenStart,
                match: DateTimeComponents.dateAndTime,
              );
              scheduledCount++;
            }
          }

          // Pre-day one-off (offset 2) if enabled per-task
          final preDayOn = ((row['pre_day_notify'] as int?) ?? 0) == 1;
          if (preDayOn && startDate != null) {
            final whenPre = nextInstanceOfYearlyPreDay(
              month: startDate.month,
              day: startDate.day,
              hour: preH,
              minute: preM,
            );
            await sched.scheduleZoned(
              id: _generateNotificationId(id, 2),
              title: title,
              body: 'Nhắc việc ngày mai',
              when: whenPre,
            );
            scheduledCount++;
          }
        }
      }
    }

    if (kDebugMode) {
      print(
        '[Notifications] Done rescheduling from DB. scheduled=$scheduledCount',
      );
      try {
        final pendings = await sched.pendingRequests();
        print(
          '[Notifications][pending] count=${pendings.length} ids=${pendings.map((e) => e.id).toList()}',
        );
      } catch (_) {}
    }
  }

  Future<void> rescheduleAllUpcomingTasksFromDb(
    Database db, {
    int remindBeforeMinutes = 15,
  }) async {
    await rescheduleAllFromDb(db, remindBeforeMinutes: remindBeforeMinutes);
  }

  Future<void> cancelTaskNotifications(int taskId) async {
    // CHANGED: cover more offsets for pre-day schedules
    if (kDebugMode)
      print('[Notifications] Cancel task notifications task=$taskId');
    for (var offset = 0; offset < 64; offset++) {
      final nid = _generateNotificationId(taskId, offset);
      await NotificationScheduler.instance.cancel(nid);
    }
    if (kDebugMode)
      print('[Notifications] Cancelled notifications for task=$taskId');
  }

  Future<void> scheduleForTaskEntity(
    TaskEntity task, {
    int remindBeforeMinutes = 15,
  }) async {
    final usedLead = await _leadMinutes();
    final preH = _allDayReminderHour;
    final preM = _allDayReminderMinute;

    if (kDebugMode) {
      print(
        '[Notifications] scheduleForTaskEntity id=${task.id} title="${task.title}" type=${task.repeatType} remindBefore=$remindBeforeMinutes',
      );
    }
    await cancelTaskNotifications(task.id);
    final now = DateTime.now();
    final sched = NotificationScheduler.instance;

    if (task.repeatType == RepeatType.NONE) {
      final start = task.startTime;
      if (kDebugMode) {
        print(
          '[Notifications][Task ${task.id}] SINGLE startLocal=${start?.toLocal()} nowLocal=$now',
        );
      }
      if (start != null) {
        final startLocal = start.toLocal();
        if (task.isAllDay == true) {
          final baseDate = DateTime(
            startLocal.year,
            startLocal.month,
            startLocal.day,
          );
          final prevDay = baseDate.subtract(const Duration(days: 1));
          final fireAt = DateTime(
            prevDay.year,
            prevDay.month,
            prevDay.day,
            preH,
            preM,
          );
          if (kDebugMode) {
            print(
              '[Notifications][Task ${task.id}] ALL-DAY remindAt(prev-day 18:00)=$fireAt nid=${_generateNotificationId(task.id, 0)}',
            );
          }
          if (fireAt.isAfter(now)) {
            await sched.scheduleZoned(
              id: _generateNotificationId(task.id, 0),
              title: task.title,
              body: 'Nhắc sự kiện cả ngày vào ngày mai',
              when: tz.TZDateTime.from(fireAt, tz.local),
            );
          } else if (kDebugMode) {
            print('[Notifications][Task ${task.id}] ALL-DAY skip (past)');
          }
          return;
        }

        // lead-before using usedLead
        final beforeLocal = startLocal.subtract(Duration(minutes: usedLead));
        if (beforeLocal.isAfter(now)) {
          if (kDebugMode) {
            print(
              '[Notifications][Task ${task.id}] SINGLE remindAt=$beforeLocal nid=${_generateNotificationId(task.id, 0)}',
            );
          }
          await sched.scheduleZoned(
            id: _generateNotificationId(task.id, 0),
            title: task.title,
            body: 'Sắp tới giờ bắt đầu công việc',
            when: tz.TZDateTime.from(beforeLocal, tz.local),
          );
        } else if (kDebugMode) {
          print('[Notifications][Task ${task.id}] SINGLE remind skip (past)');
        }

        if (_alsoAtStartForTesting && startLocal.isAfter(now)) {
          if (kDebugMode) {
            print(
              '[Notifications][Task ${task.id}] SINGLE atStart=$startLocal nid=${_generateNotificationId(task.id, 1)}',
            );
          }
          await sched.scheduleZoned(
            id: _generateNotificationId(task.id, 1),
            title: task.title,
            body: 'Đến giờ bắt đầu công việc',
            when: tz.TZDateTime.from(startLocal, tz.local),
          );
        }
      }
      return;
    }

    final tod = task.repeatStartTime;
    if (kDebugMode) {
      print(
        '[Notifications][Task ${task.id}] RECUR repeatStartTime=$tod repeatDays="${task.repeatDays}"',
      );
    }
    if (tod == null) return;
    final notifyBase = DateTime(
      2000,
      1,
      1,
      tod.hour,
      tod.minute,
    ).subtract(Duration(minutes: usedLead));
    final nh = notifyBase.hour;
    final nm = notifyBase.minute;
    final sh = tod.hour;
    final sm = tod.minute;

    if (task.repeatType == RepeatType.DAILY) {
      final whenRemind = nextInstanceOfTime(nh, nm);
      if (kDebugMode) {
        print(
          '[Notifications][Task ${task.id}] DAILY remind next=$whenRemind nid=${_generateNotificationId(task.id, 0)}',
        );
      }
      await sched.scheduleZoned(
        id: _generateNotificationId(task.id, 0),
        title: task.title,
        body: 'Công việc hàng ngày sắp bắt đầu',
        when: whenRemind,
        match: DateTimeComponents.time,
      );

      if (_alsoAtStartForTesting) {
        final whenStart = nextInstanceOfTime(sh, sm);
        if (kDebugMode) {
          print(
            '[Notifications][Task ${task.id}] DAILY atStart next=$whenStart nid=${_generateNotificationId(task.id, 1)}',
          );
        }
        await sched.scheduleZoned(
          id: _generateNotificationId(task.id, 1),
          title: task.title,
          body: 'Đến giờ bắt đầu công việc',
          when: whenStart,
          match: DateTimeComponents.time,
        );
      }

      // NEW: pre-day repeating daily (offset 2)
      if (task.preDayNotify == true) {
        // NEW
        final preDaily = nextInstanceOfTime(preH, preM);
        await sched.scheduleZoned(
          id: _generateNotificationId(task.id, 2),
          title: task.title,
          body: 'Nhắc việc ngày mai',
          when: preDaily,
          match: DateTimeComponents.time,
        );
      }
    } else if (task.repeatType == RepeatType.WEEKLY) {
      final daysStr = task.repeatDays ?? '[]';
      final weekdays = _safeParseIntList(daysStr);
      for (int i = 0; i < weekdays.length; i++) {
        final wd = weekdays[i];

        // CHANGED: use 3 offsets per weekday
        final nidRemind = _generateNotificationId(task.id, i * 3);
        final whenRemind = nextInstanceOfDayAndTime(wd, nh, nm);
        await sched.scheduleZoned(
          id: nidRemind,
          title: task.title,
          body: 'Công việc hàng tuần sắp bắt đầu',
          when: whenRemind,
          match: DateTimeComponents.dayOfWeekAndTime,
        );

        if (_alsoAtStartForTesting) {
          final nidStart = _generateNotificationId(task.id, i * 3 + 1);
          final whenStart = nextInstanceOfDayAndTime(wd, sh, sm);
          await sched.scheduleZoned(
            id: nidStart,
            title: task.title,
            body: 'Đến giờ bắt đầu công việc',
            when: whenStart,
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }

        if (task.preDayNotify == true) {
          // NEW
          final preWd = prevWeekday(wd);
          final nidPre = _generateNotificationId(task.id, i * 3 + 2);
          final whenPre = nextInstanceOfDayAndTime(preWd, preH, preM);
          await sched.scheduleZoned(
            id: nidPre,
            title: task.title,
            body: 'Nhắc việc ngày mai',
            when: whenPre,
            match: DateTimeComponents.dayOfWeekAndTime,
          );
        }
      }
    } else if (task.repeatType == RepeatType.MONTHLY) {
      // Define variables used below
      final int dayOfMonth =
          task.repeatDayOfMonth ?? task.repeatStart?.day ?? 1;
      final DateTime? anchor = task.repeatStart;

      // Restore monthly remind (offset 0)
      final whenRemind = nextInstanceOfMonthly(
        day: dayOfMonth,
        hour: nh,
        minute: nm,
        anchor: anchor,
      );
      await sched.scheduleZoned(
        id: _generateNotificationId(task.id, 0),
        title: task.title,
        body: 'Công việc hàng tháng sắp bắt đầu',
        when: whenRemind,
        match: DateTimeComponents.dayOfMonthAndTime,
      );

      // Restore monthly at-start (offset 1)
      if (_alsoAtStartForTesting) {
        final whenStart = nextInstanceOfMonthly(
          day: dayOfMonth,
          hour: sh,
          minute: sm,
          anchor: anchor,
        );
        await sched.scheduleZoned(
          id: _generateNotificationId(task.id, 1),
          title: task.title,
          body: 'Đến giờ bắt đầu công việc',
          when: whenStart,
          match: DateTimeComponents.dayOfMonthAndTime,
        );
      }

      // Pre-day monthly (offset 2) if toggled per task
      if (task.preDayNotify == true) {
        final whenPre = nextInstanceOfMonthlyPreDay(
          day: dayOfMonth,
          hour: preH,
          minute: preM,
          anchor: anchor,
        );
        await sched.scheduleZoned(
          id: _generateNotificationId(task.id, 2),
          title: task.title,
          body: 'Nhắc việc ngày mai',
          when: whenPre,
        );
      }
    } else if (task.repeatType == RepeatType.YEARLY) {
      final DateTime? start = task.repeatStart;
      if (start != null) {
        // Restore yearly remind (offset 0)
        final whenRemind = nextInstanceOfYearly(
          month: start.month,
          day: start.day,
          hour: nh,
          minute: nm,
        );
        await sched.scheduleZoned(
          id: _generateNotificationId(task.id, 0),
          title: task.title,
          body: 'Công việc hàng năm sắp bắt đầu',
          when: whenRemind,
          match: DateTimeComponents.dateAndTime,
        );

        // Restore yearly at-start (offset 1)
        if (_alsoAtStartForTesting) {
          final whenStart = nextInstanceOfYearly(
            month: start.month,
            day: start.day,
            hour: sh,
            minute: sm,
          );
          await sched.scheduleZoned(
            id: _generateNotificationId(task.id, 1),
            title: task.title,
            body: 'Đến giờ bắt đầu công việc',
            when: whenStart,
            match: DateTimeComponents.dateAndTime,
          );
        }

        // Pre-day yearly (offset 2) if toggled per task
        if (task.preDayNotify == true) {
          final whenPre = nextInstanceOfYearlyPreDay(
            month: start.month,
            day: start.day,
            hour: preH,
            minute: preM,
          );
          await sched.scheduleZoned(
            id: _generateNotificationId(task.id, 2),
            title: task.title,
            body: 'Nhắc việc ngày mai',
            when: whenPre,
          );
        }
      }
    }
  }

  Future<void> debugImmediatePing({
    String title = '[DEBUG] Ping',
    String body = 'Kênh thông báo hoạt động',
  }) async {
    if (kDebugMode) print('[Notifications][debug] show immediate ping');
    await NotificationScheduler.instance.showNow(
      id: 999003,
      title: title,
      body: body,
    );
  }

  Future<void> scheduleDebugInSeconds(int seconds, {String? label}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    if (kDebugMode) {
      print('[Notifications][debug] schedule in ${seconds}s at $when');
    }
    await NotificationScheduler.instance.scheduleZoned(
      id: 999004,
      title: '[DEBUG] Hẹn giờ thử',
      body: label ?? 'Sẽ hiển thị sau $seconds giây',
      when: when,
    );
  }

  // CHANGED: widen per-task ID block to 64 to avoid collisions with weekly (3 offsets/weekday)
  int _generateNotificationId(int taskId, [int offset = 0]) =>
      (taskId.abs() % 100000) * 64 + offset;

  List<int> _safeParseIntList(String input) {
    try {
      final v = jsonDecode(input);
      if (v is List) return v.whereType<int>().toList();
    } catch (_) {}
    return [];
  }
}
