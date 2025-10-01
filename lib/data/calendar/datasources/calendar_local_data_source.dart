import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/calendar_model.dart';

abstract class CalendarLocalDataSource {
  Future<List<CalendarModel>> getAllCalendars();
  Future<void> cacheCalendars(List<CalendarModel> calendars);
  Future<void> saveCalendar(CalendarModel calendar, {required bool isSynced});
  Future<void> deleteCalendar(int calendarId);
  Future<void> setDefaultCalendar(int calendarId);
}

class CalendarLocalDataSourceImpl implements CalendarLocalDataSource {
  final DatabaseService dbService;
  final String _tableName = 'calendars';

  CalendarLocalDataSourceImpl({required this.dbService});

  @override
  Future<List<CalendarModel>> getAllCalendars() async {
    final db = await dbService.database;
    final maps = await db.query(_tableName, orderBy: 'is_default DESC, id ASC');
    return maps.map(CalendarModel.fromDb).toList();
  }

  @override
  Future<void> cacheCalendars(List<CalendarModel> calendars) async {
    final db = await dbService.database;
    final batch = db.batch();
    batch.delete(_tableName);
    for (final c in calendars) {
      batch.insert(
        _tableName,
        c.toDbMap(isSynced: true),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    print('[CalendarLocal] Cached ${calendars.length} calendars');
  }

  @override
  Future<void> saveCalendar(
    CalendarModel calendar, {
    required bool isSynced,
  }) async {
    final db = await dbService.database;
    await db.insert(
      _tableName,
      calendar.toDbMap(isSynced: isSynced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    print(
      '[CalendarLocal] Saved calendar id=${calendar.id} isSynced=$isSynced',
    );
  }

  @override
  Future<void> deleteCalendar(int calendarId) async {
    final db = await dbService.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [calendarId]);
    print('[CalendarLocal] Deleted calendar id=$calendarId');
  }

  @override
  Future<void> setDefaultCalendar(int calendarId) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      await txn.update(_tableName, {'is_default': 0});
      await txn.update(
        _tableName,
        {'is_default': 1},
        where: 'id = ?',
        whereArgs: [calendarId],
      );
    });
    print('[CalendarLocal] Set default calendar id=$calendarId');
  }
}
