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
          // Migrate: safe upsert real id (UPDATE → INSERT IGNORE)
          final updated = await txn.update(
            _tableName,
            cal.toDbMap(isSynced: true),
            where: 'id = ?',
            whereArgs: [cal.id],
          );
          if (updated == 0) {
            await txn.insert(
              _tableName,
              cal.toDbMap(isSynced: true),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }

          // Move tasks from temp calendar id to real id
          final moved = await txn.update(
            'tasks',
            {'calendar_id': cal.id},
            where: 'calendar_id = ?',
            whereArgs: [offlineTempId],
          );

          // Remove temp calendar (id < 0)
          await txn.delete(
            _tableName,
            where: 'id = ?',
            whereArgs: [offlineTempId],
          );

          print(
            '[CalendarLocal] Migrated tempId=$offlineTempId -> realId=${cal.id}, movedTasks=$moved',
          );
        } else {
          // Safe upsert for existing/remote calendars (avoid REPLACE to prevent cascade on tasks)
          final updated = await txn.update(
            _tableName,
            cal.toDbMap(isSynced: true),
            where: 'id = ?',
            whereArgs: [cal.id],
          );
          if (updated == 0) {
            await txn.insert(
              _tableName,
              cal.toDbMap(isSynced: true),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
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
    // Accept negative id (offline). Safe upsert: UPDATE → INSERT IGNORE (no REPLACE)
    final db = await dbService.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        _tableName,
        calendar.toDbMap(isSynced: isSynced),
        where: 'id = ?',
        whereArgs: [calendar.id],
      );
      if (updated == 0) {
        await txn.insert(
          _tableName,
          calendar.toDbMap(isSynced: isSynced),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    print(
      '[CalendarLocal] Saved calendar id=${calendar.id} isSynced=$isSynced',
    );
  }

  @override
  Future<void> deleteCalendar(int calendarId) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      // NEW: guard – không cho xóa lịch mặc định hoặc lịch cuối cùng
      final totalRow = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM $_tableName',
      );
      final total = (totalRow.first['c'] as int?) ?? 0;
      if (total <= 1) {
        throw StateError('Không thể xóa bộ lịch cuối cùng của bạn.');
      }
      final defRow = await txn.query(
        _tableName,
        columns: ['is_default'],
        where: 'id = ?',
        whereArgs: [calendarId],
        limit: 1,
      );
      if (defRow.isNotEmpty && (defRow.first['is_default'] as int) == 1) {
        throw StateError(
          'Không thể xóa lịch mặc định. Vui lòng đặt một lịch khác làm mặc định trước.',
        );
      }

      await txn.delete(_tableName, where: 'id = ?', whereArgs: [calendarId]);

      // Giữ bảo đảm luôn có default nếu còn lịch
      final countRows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM $_tableName LIMIT 1',
      );
      final left = (countRows.first['c'] as int?) ?? 0;
      if (left == 0) return;

      final hasDefaultRows = await txn.rawQuery(
        'SELECT COUNT(*) AS c FROM $_tableName WHERE is_default = 1 LIMIT 1',
      );
      final hasDefault = ((hasDefaultRows.first['c'] as int?) ?? 0) > 0;
      if (!hasDefault) {
        final firstRow = await txn.query(
          _tableName,
          orderBy: 'id ASC',
          limit: 1,
          columns: ['id'],
        );
        if (firstRow.isNotEmpty) {
          final newDefaultId = firstRow.first['id'] as int;
          await txn.update(_tableName, {'is_default': 0});
          await txn.update(
            _tableName,
            {'is_default': 1},
            where: 'id = ?',
            whereArgs: [newDefaultId],
          );
        }
      }
    });
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
