import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/task_occurrence_completion_model.dart';

abstract class TaskOccurrenceCompletionLocalDataSource {
  Future<void> upsertCompletion(
    TaskOccurrenceCompletionModel model, {
    required bool isSynced,
  });
  Future<void> deleteSyncedCompletionsForCalendarRange({
    required int calendarId,
    required String from,
    required String to,
  });
  Future<void> deleteCompletion({
    required int taskId,
    required String taskType,
    required String occurrenceDate,
  });
  Future<List<TaskOccurrenceCompletionModel>> getCompletionsForCalendar({
    required int calendarId,
    required String from,
    required String to,
  });
}

class TaskOccurrenceCompletionLocalDataSourceImpl
    implements TaskOccurrenceCompletionLocalDataSource {
  final DatabaseService dbService;
  final String _table = 'task_occurrence_completions';

  TaskOccurrenceCompletionLocalDataSourceImpl({required this.dbService});

  @override
  Future<void> upsertCompletion(
    TaskOccurrenceCompletionModel model, {
    required bool isSynced,
  }) async {
    final db = await dbService.database;
    await db.insert(
      _table,
      model.toDbMap(isSynced: isSynced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteSyncedCompletionsForCalendarRange({
    required int calendarId,
    required String from,
    required String to,
  }) async {
    final db = await dbService.database;
    await db.delete(
      _table,
      where:
          'calendar_id = ? AND occurrence_date >= ? AND occurrence_date <= ? AND is_synced = 1',
      whereArgs: [calendarId, from, to],
    );
  }

  @override
  Future<void> deleteCompletion({
    required int taskId,
    required String taskType,
    required String occurrenceDate,
  }) async {
    final db = await dbService.database;
    await db.delete(
      _table,
      where: 'task_id = ? AND task_type = ? AND occurrence_date = ?',
      whereArgs: [taskId, taskType.toUpperCase(), occurrenceDate],
    );
  }

  @override
  Future<List<TaskOccurrenceCompletionModel>> getCompletionsForCalendar({
    required int calendarId,
    required String from,
    required String to,
  }) async {
    final db = await dbService.database;
    final rows = await db.query(
      _table,
      where:
          'calendar_id = ? AND occurrence_date >= ? AND occurrence_date <= ? AND completed = 1',
      whereArgs: [calendarId, from, to],
    );
    return rows.map(TaskOccurrenceCompletionModel.fromDb).toList();
  }
}
