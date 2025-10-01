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
    if (calendars.isEmpty) {
      print(
        '[CalendarLocal] Remote empty -> skip (preserve existing calendars & tasks)',
      );
      return;
    }

    final db = await dbService.database;
    await db.transaction((txn) async {
      // Lấy trạng thái hiện tại
      final existingRows = await txn.query(
        _tableName,
        columns: ['id', 'name', 'is_default'],
      );

      final Map<String, int> offlineNameToId = {
        for (final r in existingRows.where((r) => (r['id'] as int) < 0))
          (r['name'] as String): r['id'] as int,
      };

      final prevDefaultId =
          existingRows.firstWhere(
                (r) => (r['is_default'] as int) == 1,
                orElse: () => {'id': null},
              )['id']
              as int?;

      bool remoteHasDefault = calendars.any((c) => c.isDefault);

      for (final cal in calendars) {
        final offlineTempId = offlineNameToId[cal.name];
        if (offlineTempId != null) {
          // Migrate: Insert lịch mới với id thật
          await txn.insert(
            _tableName,
            cal.toDbMap(isSynced: true),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final moved = await txn.update(
            'tasks',
            {'calendar_id': cal.id},
            where: 'calendar_id = ?',
            whereArgs: [offlineTempId],
          );
          await txn.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [offlineTempId],
          );
          print(
            '[CalendarLocal] Migrated tempId=$offlineTempId -> realId=${cal.id}, movedTasks=$moved',
          );
        } else {
          await txn.insert(
            _tableName,
            cal.toDbMap(isSynced: true),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      // Không xóa các calendar không xuất hiện trong remote nữa (SAFE MODE)
      // -> Tránh mất tasks vì backend trả thiếu tạm thời

      // Đồng bộ cờ default:
      if (remoteHasDefault) {
        final defaultCal = calendars.firstWhere((c) => c.isDefault);
        await txn.update(_tableName, {'is_default': 0});
        await txn.update(
          _tableName,
          {'is_default': 1},
          where: 'id = ?',
          whereArgs: [defaultCal.id],
        );
        print('[CalendarLocal] Applied remote default id=${defaultCal.id}');
      } else if (prevDefaultId != null) {
        // Giữ nguyên default cũ
        print(
          '[CalendarLocal] Preserve previous default id=$prevDefaultId (remote did not send one)',
        );
      } else if (calendars.isNotEmpty) {
        // Chưa có default nào -> chọn cái đầu tiên trong remote
        await txn.update(_tableName, {'is_default': 0});
        await txn.update(
          _tableName,
          {'is_default': 1},
          where: 'id = ?',
          whereArgs: [calendars.first.id],
        );
        print('[CalendarLocal] Fallback set default id=${calendars.first.id}');
      }

      // NEW: Dọn các calendar âm còn sót lại (sau khi đã có ít nhất 1 remote id dương)
      final hasPositiveRemote = calendars.any((c) => c.id > 0);
      if (hasPositiveRemote) {
        final remainingNeg = await txn.query(_tableName, where: 'id < 0');
        if (remainingNeg.isNotEmpty) {
          final count = remainingNeg.length;
          await txn.delete(_tableName, where: 'id < 0');
          print(
            '[CalendarLocal] Cleaned $count stale negative calendar(s) post-auth',
          );
        }
      }
    });

    print(
      '[CalendarLocal] Safe upsert ${calendars.length} calendars (no deletions)',
    );
  }

  @override
  Future<void> saveCalendar(
    CalendarModel calendar, {
    required bool isSynced,
  }) async {
    // Chấp nhận id âm (offline) => sẽ được thay thế sau khi queue sync
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
