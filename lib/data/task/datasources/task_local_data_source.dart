import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import '../../../core/services/database_service.dart';
import '../../tag/models/tag_model.dart';
import '../models/task_model.dart';
import '../../../domain/tag/entities/tag_entity.dart'; // NEW for fallback

abstract class TaskLocalDataSource {
  Future<List<TaskModel>> getAllTasks();
  Future<List<TaskModel>> getTasksInCalendar(int calendarId);
  Future<void> cacheTasks(List<TaskModel> tasks);
  // --- Bổ sung ---
  Future<void> saveTask(TaskModel task, {required bool isSynced});
  Future<void> deleteTask(int taskId);
}

class TaskLocalDataSourceImpl implements TaskLocalDataSource {
  final DatabaseService dbService;
  final String _taskTable = 'tasks';
  final String _taskTagTable = 'task_tags_local';

  TaskLocalDataSourceImpl({required this.dbService});

  // REPLACE old _ensureRawTagIdsColumn bằng version mới hỗ trợ thêm raw_tag_meta
  Future<void> _ensureTagMetaColumns(DatabaseExecutor db) async {
    try {
      final cols = await db.rawQuery("PRAGMA table_info(tasks)");
      final hasIds = cols.any((c) => c['name'] == 'raw_tag_ids');
      final hasMeta = cols.any((c) => c['name'] == 'raw_tag_meta');
      if (!hasIds) {
        await db.execute("ALTER TABLE tasks ADD COLUMN raw_tag_ids TEXT");
      }
      if (!hasMeta) {
        await db.execute("ALTER TABLE tasks ADD COLUMN raw_tag_meta TEXT");
      }
    } catch (_) {}
  }

  // NEW: Rebuild mapping từ raw_tag_ids nếu mất
  Future<int> _rebuildMappingsFromRawTagIds(Transaction txn, int taskId) async {
    try {
      final row = await txn.query(
        _taskTable,
        columns: ['raw_tag_ids'],
        where: 'id = ?',
        whereArgs: [taskId],
        limit: 1,
      );
      if (row.isEmpty) return 0;
      final raw = row.first['raw_tag_ids'];
      if (raw == null) return 0;
      final List<dynamic> list = jsonDecode(raw as String);
      int inserted = 0;
      for (final v in list) {
        if (v is int) {
          await txn.insert(_taskTagTable, {
            'task_id': taskId,
            'tag_id': v,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          inserted++;
        }
      }
      return inserted;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<List<TaskModel>> getAllTasks() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> taskMaps = await db.query(_taskTable);
    return _mapsToTasksWithTags(taskMaps, db);
  }

  @override
  Future<List<TaskModel>> getTasksInCalendar(int calendarId) async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> taskMaps = await db.query(
      _taskTable,
      where: 'calendar_id = ?',
      whereArgs: [calendarId],
    );
    return _mapsToTasksWithTags(taskMaps, db);
  }

  // CHANGED: fallback nếu không có mapping + add debug logs
  Future<List<TaskModel>> _mapsToTasksWithTags(
    List<Map<String, dynamic>> taskMaps,
    Database db,
  ) async {
    List<TaskModel> tasks = [];
    for (var taskMap in taskMaps) {
      // NEW: debug raw columns for recurring time
      try {
        final rid = taskMap['id'];
        final rtype = taskMap['repeat_type'];
        final rstartTimeStr = taskMap['repeat_start_time'];
        print(
          '[TaskLocal][DBG] id=$rid repeat_type=$rtype repeat_start_time="$rstartTimeStr"',
        );
      } catch (_) {}
      final List<Map<String, dynamic>> tagMaps = await db.rawQuery(
        'SELECT T.* FROM tags T INNER JOIN task_tags_local TT ON T.id = TT.tag_id WHERE TT.task_id = ?',
        [taskMap['id']],
      );

      Set<TagEntity> tags;
      if (tagMaps.isNotEmpty) {
        tags = tagMaps.map((t) => TagModel.fromDb(t)).toSet();
      } else {
        // Fallback dùng raw_tag_meta trước, nếu null dùng raw_tag_ids
        tags = {};
        try {
          if (taskMap['raw_tag_meta'] != null) {
            final metaList = jsonDecode(taskMap['raw_tag_meta']);
            if (metaList is List) {
              for (final m in metaList) {
                if (m is Map && m['id'] is int) {
                  tags.add(
                    TagEntity(
                      id: m['id'] as int,
                      name: (m['name'] as String?) ?? '',
                      color: m['color'] as String?,
                    ),
                  );
                }
              }
            }
          } else if (taskMap['raw_tag_ids'] != null) {
            final idList = jsonDecode(taskMap['raw_tag_ids']);
            if (idList is List) {
              for (final v in idList) {
                if (v is int) {
                  tags.add(TagEntity(id: v, name: '', color: null));
                }
              }
            }
          }

          // NEW: lọc các tag fallback theo các id còn tồn tại trong bảng tags
          if (tags.isNotEmpty) {
            final ids = tags.map((e) => e.id).toList();
            final placeholders = List.filled(ids.length, '?').join(',');
            final existingRows = await db.query(
              'tags',
              columns: ['id'],
              where: 'id IN ($placeholders)',
              whereArgs: ids,
            );
            final existingIds = existingRows.map((r) => r['id'] as int).toSet();
            tags = tags.where((t) => existingIds.contains(t.id)).toSet();
          }
        } catch (e) {
          print('[TaskLocal][FALLBACK][ERR] task_id=${taskMap['id']} $e');
        }
      }

      tasks.add(TaskModel.fromDb(taskMap, tags));
    }
    return tasks;
  }

  @override
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    final db = await dbService.database;

    // NEW: disable FK at connection-level for the whole cache operation
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      await db.transaction((txn) async {
        await txn.execute(
          'PRAGMA foreign_keys = ON',
        ); // keep FK ON inside txn for other tables
        await _ensureTagMetaColumns(txn);

        // Thu thập tag
        final Map<int, TagModel> allTags = {};
        for (final task in tasks) {
          for (final tag in task.tags) {
            allTags.putIfAbsent(tag.id, () {
              if (tag is TagModel) return tag;
              return TagModel(id: tag.id, name: tag.name, color: tag.color);
            });
          }
        }
        // CHANGED: update-first, then insert IGNORE (tránh REPLACE gây cascade)
        for (final tag in allTags.values) {
          final updated = await txn.update(
            'tags',
            {'name': tag.name, 'color': tag.color, 'is_synced': 1},
            where: 'id = ?',
            whereArgs: [tag.id],
          );
          if (updated == 0) {
            await txn.insert('tags', {
              'id': tag.id,
              'name': tag.name,
              'color': tag.color,
              'is_synced': 1,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        }

        int totalMappingInserted = 0;

        for (final task in tasks) {
          try {
            // KEEP: no placeholder calendar creation
            final rawIds = task.tags.map((e) => e.id).toList();
            final rawMeta = task.tags
                .map(
                  (e) => {
                    'id': e.id,
                    'name': (e is TagModel) ? e.name : e.name,
                    'color': (e is TagModel) ? e.color : e.color,
                  },
                )
                .toList();

            final taskMap = task.toDbMap()
              ..['is_synced'] = 1
              ..['raw_tag_ids'] = jsonEncode(rawIds)
              ..['raw_tag_meta'] = jsonEncode(rawMeta);

            // NEW: preserve existing pre_day_notify if remote didn’t provide
            if (task.preDayNotify == null) {
              final existing = await txn.query(
                _taskTable,
                columns: ['pre_day_notify'],
                where: 'id = ?',
                whereArgs: [task.id],
                limit: 1,
              );
              if (existing.isNotEmpty) {
                taskMap['pre_day_notify'] = existing.first['pre_day_notify'];
              }
            }

            await txn.insert(
              _taskTable,
              taskMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            final deleted = await txn.delete(
              _taskTagTable,
              where: 'task_id = ?',
              whereArgs: [task.id],
            );
            if (deleted > 0) {
              // silent
            }

            int localInserted = 0;
            for (final tag in task.tags) {
              try {
                await txn.insert(_taskTagTable, {
                  'task_id': task.id,
                  'tag_id': tag.id,
                }, conflictAlgorithm: ConflictAlgorithm.replace);
                localInserted++;
              } catch (e) {
                print(
                  '[TaskLocal][MAP-ERR] task=${task.id} tag=${tag.id} err=$e',
                );
              }
            }
            totalMappingInserted += localInserted;

            final count =
                Sqflite.firstIntValue(
                  await txn.rawQuery(
                    'SELECT COUNT(*) FROM $_taskTagTable WHERE task_id = ?',
                    [task.id],
                  ),
                ) ??
                0;

            if (count == 0 && task.tags.isNotEmpty) {
              print(
                '[TaskLocal][WARN] Mapping still empty after insert for task=${task.id}, attempting rebuild from raw_tag_ids',
              );
              final rebuilt = await _rebuildMappingsFromRawTagIds(txn, task.id);
              totalMappingInserted += rebuilt;
              if (rebuilt == 0) {
                print(
                  '[TaskLocal][FATAL] Cannot create mappings for task=${task.id} (tag ids=${task.tags.map((e) => e.id).toList()})',
                );
              }
            } else {
              print(
                '[TaskLocal] task=${task.id} mappingCount=$count (expected=${task.tags.length})',
              );
            }
          } catch (e) {
            print('[TaskLocal][ERROR] cache task id=${task.id}: $e');
          }
        }

        print(
          '[TaskLocal] Upserted ${tasks.length} task(s); total tagMappings=$totalMappingInserted',
        );
        await _logCurrentMappings(txn);
      });
    } finally {
      // NEW: re-enable FK after cache completes
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  // NEW: hàm hỗ trợ debug tổng quan sau khi cache
  Future<void> _logCurrentMappings(Transaction txn) async {
    // make no-op (silent)
    return;
  }

  // -- PHẦN BỔ SUNG --

  @override
  Future<void> saveTask(TaskModel task, {required bool isSynced}) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      final taskMap = task.toDbMap()..['is_synced'] = isSynced ? 1 : 0;
      await txn.insert(
        _taskTable,
        taskMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final deleted = await txn.delete(
        _taskTagTable,
        where: 'task_id = ?',
        whereArgs: [task.id],
      );
      if (deleted > 0) {
        // silent
      }
      for (final tag in task.tags) {
        await txn.insert(_taskTagTable, {
          'task_id': task.id,
          'tag_id': tag.id,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      // removed print
    });
  }

  @override
  Future<void> deleteTask(int taskId) async {
    final db = await dbService.database;
    // Xóa task trong bảng chính, các liên kết trong task_tags_local sẽ tự động được xóa
    // nhờ có `ON DELETE CASCADE` trong câu lệnh CREATE TABLE.
    await db.delete(_taskTable, where: 'id = ?', whereArgs: [taskId]);
  }

  // REMOVE: placeholder calendar creator to avoid polluting "Lịch của tôi"
  // Future<void> _ensureCalendarExists(Transaction txn, int calendarId) async { ... }
}
