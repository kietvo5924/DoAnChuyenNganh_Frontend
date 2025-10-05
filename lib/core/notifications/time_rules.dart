import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime nextInstanceOfTime(int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (scheduled.isBefore(now))
    scheduled = scheduled.add(const Duration(days: 1));
  return scheduled;
}

tz.TZDateTime nextInstanceOfDayAndTime(int weekday, int hour, int minute) {
  final now = tz.TZDateTime.now(tz.local);
  var scheduled = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  while (scheduled.weekday != weekday || scheduled.isBefore(now)) {
    scheduled = scheduled.add(const Duration(days: 1));
  }
  return scheduled;
}

DateTime? tryParseDateLocal(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  try {
    return DateTime.parse(iso).toLocal();
  } catch (_) {
    return null;
  }
}

int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

tz.TZDateTime nextInstanceOfMonthly({
  required int day,
  required int hour,
  required int minute,
  DateTime? anchor,
}) {
  final now = tz.TZDateTime.now(tz.local);
  final base = anchor != null ? anchor.toLocal() : now;
  var y = base.year;
  var mo = base.month;
  var dom = day.clamp(1, _daysInMonth(y, mo));
  var scheduled = tz.TZDateTime(tz.local, y, mo, dom, hour, minute);
  if (!scheduled.isAfter(now)) {
    mo += 1;
    if (mo > 12) {
      mo = 1;
      y += 1;
    }
    dom = day.clamp(1, _daysInMonth(y, mo));
    scheduled = tz.TZDateTime(tz.local, y, mo, dom, hour, minute);
  }
  return scheduled;
}

tz.TZDateTime nextInstanceOfYearly({
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  final now = tz.TZDateTime.now(tz.local);
  var y = now.year;
  var dom = day.clamp(1, _daysInMonth(y, month));
  var scheduled = tz.TZDateTime(tz.local, y, month, dom, hour, minute);
  if (!scheduled.isAfter(now)) {
    y += 1;
    dom = day.clamp(1, _daysInMonth(y, month));
    scheduled = tz.TZDateTime(tz.local, y, month, dom, hour, minute);
  }
  return scheduled;
}

int prevWeekday(int weekday) {
  // 1..7 (Mon..Sun) -> previous day
  return (weekday == DateTime.monday) ? DateTime.sunday : weekday - 1;
}

tz.TZDateTime nextInstanceOfMonthlyPreDay({
  required int day,
  required int hour,
  required int minute,
  DateTime? anchor,
}) {
  // Find the next event occurrence, then subtract 1 day at given hour:minute.
  final nextEvent = nextInstanceOfMonthly(
    day: day,
    hour: 0,
    minute: 0,
    anchor: anchor,
  );
  var pre = tz.TZDateTime(
    tz.local,
    nextEvent.year,
    nextEvent.month,
    nextEvent.day,
    0,
    0,
  ).subtract(const Duration(days: 1));
  pre = tz.TZDateTime(tz.local, pre.year, pre.month, pre.day, hour, minute);

  final now = tz.TZDateTime.now(tz.local);
  if (!pre.isAfter(now)) {
    // Move to event in the following month
    final nextMonthEvent = nextInstanceOfMonthly(
      day: day,
      hour: 0,
      minute: 0,
      anchor: DateTime(nextEvent.year, nextEvent.month + 1, 1),
    );
    var pre2 = tz.TZDateTime(
      tz.local,
      nextMonthEvent.year,
      nextMonthEvent.month,
      nextMonthEvent.day,
      0,
      0,
    ).subtract(const Duration(days: 1));
    pre2 = tz.TZDateTime(
      tz.local,
      pre2.year,
      pre2.month,
      pre2.day,
      hour,
      minute,
    );
    return pre2;
  }
  return pre;
}

tz.TZDateTime nextInstanceOfYearlyPreDay({
  required int month,
  required int day,
  required int hour,
  required int minute,
}) {
  // Find the next event occurrence, then subtract 1 day at given hour:minute.
  final nextEvent = nextInstanceOfYearly(
    month: month,
    day: day,
    hour: 0,
    minute: 0,
  );
  var pre = tz.TZDateTime(
    tz.local,
    nextEvent.year,
    nextEvent.month,
    nextEvent.day,
    0,
    0,
  ).subtract(const Duration(days: 1));
  pre = tz.TZDateTime(tz.local, pre.year, pre.month, pre.day, hour, minute);

  final now = tz.TZDateTime.now(tz.local);
  if (!pre.isAfter(now)) {
    // Move to event in the following year
    final nextYearEvent = nextInstanceOfYearly(
      month: month,
      day: day,
      hour: 0,
      minute: 0,
    );
    var pre2 = tz.TZDateTime(
      tz.local,
      nextYearEvent.year,
      nextYearEvent.month,
      nextYearEvent.day,
      0,
      0,
    ).subtract(const Duration(days: 1));
    pre2 = tz.TZDateTime(
      tz.local,
      pre2.year,
      pre2.month,
      pre2.day,
      hour,
      minute,
    );
    return pre2;
  }
  return pre;
}
