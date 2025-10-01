import '../../../core/services/database_service.dart';

/// Gộp dữ liệu khách (offline) vào sau khi đăng nhập.
/// Quy tắc:
/// - Calendar / Tag id âm: nếu trùng tên với bản đã có id dương -> map & xóa bản âm + queue.
/// - Tasks id âm giữ nguyên để queue đẩy lên; nếu tìm thấy task dương trùng (title+calendar+start_time) thì bỏ bản âm + queue UPSERT.
class MergeGuestData {
  final DatabaseService dbService;
  MergeGuestData(this.dbService);

  Future<void> call() async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      // Map calendar âm
      final negCalendars = await txn.query('calendars', where: 'id < 0');
      for (final row in negCalendars) {
        final name = row['name'] as String;
        final tempId = row['id'] as int;
        final dup = await txn.query(
          'calendars',
          where: 'name = ? AND id > 0',
          whereArgs: [name],
          limit: 1,
        );
        if (dup.isNotEmpty) {
          final realId = dup.first['id'] as int;
          final moved = await txn.update(
            'tasks',
            {'calendar_id': realId},
            where: 'calendar_id = ?',
            whereArgs: [tempId],
          );
          await txn.delete('calendars', where: 'id = ?', whereArgs: [tempId]);
          await txn.delete(
            'sync_queue',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['CALENDAR', tempId],
          );
          // Nếu offline calendar được set default trước đó mà remote chưa default -> giữ nguyên remote default logic khác không xử tại đây.
          // Log
          print(
            '[MergeGuestData] Calendar merged tempId=$tempId -> $realId movedTasks=$moved',
          );
        }
      }

      // Map tag âm
      final negTags = await txn.query('tags', where: 'id < 0');
      for (final row in negTags) {
        final name = row['name'] as String;
        final tempId = row['id'] as int;
        final dup = await txn.query(
          'tags',
          where: 'name = ? AND id > 0',
          whereArgs: [name],
          limit: 1,
        );
        if (dup.isNotEmpty) {
          final realId = dup.first['id'] as int;
          final moved = await txn.update(
            'task_tags_local',
            {'tag_id': realId},
            where: 'tag_id = ?',
            whereArgs: [tempId],
          );
          await txn.delete('tags', where: 'id = ?', whereArgs: [tempId]);
          await txn.delete(
            'sync_queue',
            where: 'entity_type = ? AND entity_id = ?',
            whereArgs: ['TAG', tempId],
          );
          print(
            '[MergeGuestData] Tag merged tempId=$tempId -> $realId movedRefs=$moved',
          );
        }
      }

      // Deduplicate tasks âm nếu trùng (title + calendar_id + start_time) với task dương
      final negTasks = await txn.rawQuery('''
        SELECT id,title,calendar_id,start_time,repeat_type 
        FROM tasks 
        WHERE id < 0
        ''');
      for (final t in negTasks) {
        final tempId = t['id'] as int;
        final title = t['title'] as String;
        final calId = t['calendar_id'] as int;
        final startTime = t['start_time'] as String?;
        if (startTime == null) continue; // chỉ dedup task thường
        final dup = await txn.rawQuery(
          '''
          SELECT id FROM tasks 
          WHERE id > 0 AND calendar_id = ? AND title = ? AND start_time = ? 
          LIMIT 1
          ''',
          [calId, title, startTime],
        );
        if (dup.isNotEmpty) {
          final realId = dup.first['id'];
          await txn.delete('tasks', where: 'id = ?', whereArgs: [tempId]);
          await txn.delete(
            'sync_queue',
            where: 'entity_type = ? AND entity_id = ? AND action = ?',
            whereArgs: ['TASK', tempId, 'UPSERT'],
          );
          print(
            '[MergeGuestData] Removed duplicate offline task tempId=$tempId -> existingId=$realId',
          );
        }
      }
    });

    print('[MergeGuestData] DONE');
  }
}
