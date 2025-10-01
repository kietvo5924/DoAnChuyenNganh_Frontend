import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../../../data/sync/datasources/sync_queue_local_data_source.dart';
import '../../../data/sync/models/sync_queue_item_model.dart';
import 'process_sync_queue.dart';

class UploadGuestData {
  final DatabaseService dbService;
  final SyncQueueLocalDataSource queueDs;
  final ProcessSyncQueue processSyncQueue;

  UploadGuestData({
    required this.dbService,
    required this.queueDs,
    required this.processSyncQueue,
  });

  Future<void> call() async {
    final db = await dbService.database;

    // 1. Backfill hàng đợi cho mọi bản ghi chưa sync
    await db.transaction((txn) async {
      // Calendars
      final cals = await txn.query(
        'calendars',
        where: 'is_synced = 0 OR id < 0',
      );
      for (final c in cals) {
        final existing = await txn.query(
          'sync_queue',
          where: 'entity_type=? AND entity_id=? AND action=?',
          whereArgs: ['CALENDAR', c['id'], 'UPSERT'],
          limit: 1,
        );
        if (existing.isEmpty) {
          await queueDs.addAction(
            SyncQueueItemModel(
              entityType: 'CALENDAR',
              entityId: c['id'] as int,
              action: 'UPSERT',
              payload:
                  '{"name":"${c['name']}","description":"${c['description'] ?? ''}","isDefault":${(c['is_default'] ?? 0) == 1}}',
            ),
          );
        }
      }

      // Tags
      final tags = await txn.query('tags', where: 'is_synced = 0 OR id < 0');
      for (final t in tags) {
        final existing = await txn.query(
          'sync_queue',
          where: 'entity_type=? AND entity_id=? AND action=?',
          whereArgs: ['TAG', t['id'], 'UPSERT'],
          limit: 1,
        );
        if (existing.isEmpty) {
          await queueDs.addAction(
            SyncQueueItemModel(
              entityType: 'TAG',
              entityId: t['id'] as int,
              action: 'UPSERT',
              payload: '{"name":"${t['name']}","color":"${t['color'] ?? ''}"}',
            ),
          );
        }
      }

      // Tasks
      final tasks = await txn.query('tasks', where: 'is_synced = 0');
      for (final r in tasks) {
        final existing = await txn.query(
          'sync_queue',
          where: 'entity_type=? AND entity_id=? AND action=?',
          whereArgs: ['TASK', r['id'], 'UPSERT'],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;

        final tagRows = await txn.rawQuery(
          'SELECT tag_id FROM task_tags_local WHERE task_id = ?',
          [r['id']],
        );
        final tagIds = tagRows.map((e) => e['tag_id']).toList();
        final repeatType = r['repeat_type'] as String;
        final isSingle = repeatType == 'NONE';
        final payload = jsonEncode({
          'calendarId': r['calendar_id'],
          'taskData': {
            'title': r['title'],
            'description': r['description'],
            'tagIds': tagIds,
            'repeatType': repeatType,
            'startTime': isSingle ? r['start_time'] : null,
            'endTime': isSingle ? r['end_time'] : null,
            'allDay': isSingle ? (r['is_all_day'] == 1) : null,
            'repeatStartTime': !isSingle ? r['repeat_start_time'] : null,
            'repeatEndTime': !isSingle ? r['repeat_end_time'] : null,
            'repeatInterval': !isSingle ? r['repeat_interval'] : null,
            'repeatDays': !isSingle ? r['repeat_days'] : null,
            'repeatDayOfMonth': !isSingle ? r['repeat_day_of_month'] : null,
            'repeatWeekOfMonth': !isSingle ? r['repeat_week_of_month'] : null,
            'repeatDayOfWeek': !isSingle ? r['repeat_day_of_week'] : null,
            'repeatStart': !isSingle ? r['repeat_start'] : null,
            'repeatEnd': !isSingle ? r['repeat_end'] : null,
            'exceptions': !isSingle ? r['exceptions'] : null,
          },
        });

        await queueDs.addAction(
          SyncQueueItemModel(
            entityType: 'TASK',
            entityId: r['id'] as int,
            action: 'UPSERT',
            payload: payload,
          ),
        );
      }
    });

    // 2. Đẩy queue
    final res = await processSyncQueue();
    res.fold(
      (f) => print('[UploadGuestData] Process queue failed: $f'),
      (_) => print('[UploadGuestData] Queue processed OK'),
    );

    // 3. Nếu queue sạch -> xóa local thô để tải sạch
    final remaining = await db.query('sync_queue', limit: 1);
    if (remaining.isEmpty) {
      await db.transaction((txn) async {
        await txn.delete('task_tags_local');
        await txn.delete('tasks');
        await txn.delete('tags');
        await txn.delete('calendars');
      });
      print(
        '[UploadGuestData] Cleared local (tasks/tags/calendars) post upload',
      );
    } else {
      print('[UploadGuestData] Skip clearing local (queue still has items)');
    }
  }
}
