import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../../tag/models/tag_model.dart';
import '../models/task_model.dart';

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

  // Hàm helper để tránh lặp code lấy tag
  Future<List<TaskModel>> _mapsToTasksWithTags(
    List<Map<String, dynamic>> taskMaps,
    Database db,
  ) async {
    List<TaskModel> tasks = [];
    for (var taskMap in taskMaps) {
      final List<Map<String, dynamic>> tagMaps = await db.rawQuery(
        'SELECT T.* FROM tags T INNER JOIN task_tags_local TT ON T.id = TT.tag_id WHERE TT.task_id = ?',
        [taskMap['id']],
      );
      final tags = tagMaps.map((tagMap) => TagModel.fromDb(tagMap)).toSet();
      tasks.add(TaskModel.fromDb(taskMap, tags));
    }
    return tasks;
  }

  @override
  Future<void> cacheTasks(List<TaskModel> tasks) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      txn.delete(_taskTable);
      txn.delete(_taskTagTable);

      for (final task in tasks) {
        // Chuyển đổi task sang map và đảm bảo is_synced = 1
        var taskMap = task.toDbMap();
        taskMap['is_synced'] = 1;

        txn.insert(
          _taskTable,
          taskMap,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        for (final tag in task.tags) {
          txn.insert(_taskTagTable, {'task_id': task.id, 'tag_id': tag.id});
        }
      }
    });
  }

  // -- PHẦN BỔ SUNG --

  @override
  Future<void> saveTask(TaskModel task, {required bool isSynced}) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      var taskMap = task.toDbMap();
      taskMap['is_synced'] = isSynced ? 1 : 0; // Gán cờ đồng bộ

      // Dùng replace để xử lý cả trường hợp Tạo mới và Cập nhật
      txn.insert(
        _taskTable,
        taskMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Xóa các liên kết tag cũ và cập nhật lại
      txn.delete(_taskTagTable, where: 'task_id = ?', whereArgs: [task.id]);
      for (final tag in task.tags) {
        txn.insert(_taskTagTable, {'task_id': task.id, 'tag_id': tag.id});
      }
    });
  }

  @override
  Future<void> deleteTask(int taskId) async {
    final db = await dbService.database;
    // Xóa task trong bảng chính, các liên kết trong task_tags_local sẽ tự động được xóa
    // nhờ có `ON DELETE CASCADE` trong câu lệnh CREATE TABLE.
    await db.delete(_taskTable, where: 'id = ?', whereArgs: [taskId]);
  }
}
