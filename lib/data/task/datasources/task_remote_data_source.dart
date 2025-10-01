import 'package:dio/dio.dart';
import '../../../core/config/api_config.dart';
import '../models/task_model.dart';

abstract class TaskRemoteDataSource {
  Future<List<TaskModel>> getAllTasksInCalendar(int calendarId);
  Future<void> saveTask({
    required int calendarId,
    int? taskId,
    required Map<String, dynamic> taskData,
  });
  Future<void> deleteTask({required int taskId, required String type});
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
  Future<void> saveTask({
    required int calendarId,
    int? taskId,
    required Map<String, dynamic> taskData,
  }) async {
    if (taskId == null) {
      // Logic để Tạo mới công việc
      await dio.post(
        '${ApiConfig.baseUrl}/calendars/$calendarId/tasks',
        data: taskData,
      );
    } else {
      // Logic để Cập nhật công việc
      await dio.put(
        '${ApiConfig.baseUrl}/tasks/$taskId?calendarId=$calendarId',
        data: taskData,
      );
    }
  }

  @override
  Future<void> deleteTask({required int taskId, required String type}) async {
    await dio.delete(
      '${ApiConfig.baseUrl}/tasks/$taskId',
      queryParameters: {'type': type},
    );
  }
}
