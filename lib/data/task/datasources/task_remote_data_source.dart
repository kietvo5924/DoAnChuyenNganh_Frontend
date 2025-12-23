import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../models/task_model.dart';
import '../models/task_occurrence_completion_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getAllTasksInCalendar(int calendarId);
  Future<TaskModel?> saveTask({
    required int calendarId,
    int? taskId,
    required Map<String, dynamic> taskData,
  });
  Future<void> deleteTask({required int taskId, required String type});

  Future<void> setOccurrenceCompleted({
    required int taskId,
    required String taskType, // SINGLE | RECURRING
    required String date, // yyyy-MM-dd
    required bool completed,
  });

  Future<List<TaskOccurrenceCompletionModel>> getOccurrenceCompletions({
    required int calendarId,
    required String from,
    required String to,
  });
}

class TaskRemoteDataSourceImpl implements TaskRemoteDataSource {
  final Dio dio;
  TaskRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<TaskModel>> getAllTasksInCalendar(int calendarId) async {
    final response = await dio.get(
      '${ApiConfig.baseUrl}/calendars/$calendarId/tasks',
    );
    // Ensure calendarId exists in each json object (backend may omit it)
    final list = (response.data as List).map((raw) {
      final map = Map<String, dynamic>.from(raw as Map);
      map['calendarId'] = map['calendarId'] ?? calendarId;
      return TaskModel.fromJson(map);
    }).toList();
    print(
      '[TaskRemoteDataSource] fetched ${list.length} tasks for calendar=$calendarId',
    );
    return list;
  }

  @override
  Future<TaskModel?> saveTask({
    required int calendarId,
    int? taskId,
    required Map<String, dynamic> taskData,
  }) async {
    if (taskId == null) {
      // Logic để Tạo mới công việc
      final res = await dio.post(
        '${ApiConfig.baseUrl}/calendars/$calendarId/tasks',
        data: taskData,
      );
      if (res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        map['calendarId'] = map['calendarId'] ?? calendarId;
        return TaskModel.fromJson(map);
      }
      return null;
    } else {
      // Logic để Cập nhật công việc
      final res = await dio.put(
        '${ApiConfig.baseUrl}/tasks/$taskId?calendarId=$calendarId',
        data: taskData,
      );
      if (res.data is Map) {
        final map = Map<String, dynamic>.from(res.data as Map);
        map['calendarId'] = map['calendarId'] ?? calendarId;
        return TaskModel.fromJson(map);
      }
      return null;
    }
  }

  @override
  Future<void> deleteTask({required int taskId, required String type}) async {
    await dio.delete(
      '${ApiConfig.baseUrl}/tasks/$taskId',
      queryParameters: {'type': type},
    );
  }

  @override
  Future<void> setOccurrenceCompleted({
    required int taskId,
    required String taskType,
    required String date,
    required bool completed,
  }) async {
    final type = taskType.toUpperCase();
    final url = '${ApiConfig.baseUrl}/tasks/$taskId/occurrences/$date/complete';
    if (completed) {
      await dio.put(url, queryParameters: {'type': type});
    } else {
      await dio.delete(url, queryParameters: {'type': type});
    }
  }

  @override
  Future<List<TaskOccurrenceCompletionModel>> getOccurrenceCompletions({
    required int calendarId,
    required String from,
    required String to,
  }) async {
    final res = await dio.get(
      '${ApiConfig.baseUrl}/calendars/$calendarId/occurrences/completions',
      queryParameters: {'from': from, 'to': to},
    );
    final list = (res.data as List)
        .map(
          (e) => TaskOccurrenceCompletionModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
    return list;
  }
}
