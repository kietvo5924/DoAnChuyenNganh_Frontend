import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../../../data/sync/datasources/sync_queue_local_data_source.dart';
import '../../../data/task/datasources/task_remote_data_source.dart';

class ProcessSyncQueue {
  final SyncQueueLocalDataSource localDataSource;
  final TaskRemoteDataSource taskRemoteDataSource;
  // Inject các remote data source khác nếu cần

  ProcessSyncQueue({
    required this.localDataSource,
    required this.taskRemoteDataSource,
  });

  Future<Either<Failure, Unit>> call() async {
    final actions = await localDataSource.getQueuedActions();
    if (actions.isEmpty) return Right(unit);

    print('Processing ${actions.length} actions in sync queue...');

    for (var action in actions) {
      try {
        if (action.entityType == 'TASK') {
          if (action.action == 'DELETE') {
            // Backend yêu cầu 'SINGLE' hoặc 'RECURRING', nhưng ta không có thông tin này
            // trong queue. Đây là một điểm cần cải tiến sau.
            // Tạm thời, ta thử xóa cả hai.
            try {
              await taskRemoteDataSource.deleteTask(
                taskId: action.entityId,
                type: 'SINGLE',
              );
            } catch (e) {
              await taskRemoteDataSource.deleteTask(
                taskId: action.entityId,
                type: 'RECURRING',
              );
            }
          } else if (action.action == 'UPSERT') {
            if (action.payload != null) {
              final data = jsonDecode(action.payload!) as Map<String, dynamic>;
              final calendarId = data['calendarId'] as int;
              final taskData = Map<String, dynamic>.from(
                data['taskData'] ?? {},
              );
              final bool isNew = action.entityId <= 0;
              await taskRemoteDataSource.saveTask(
                calendarId: calendarId,
                taskId: isNew ? null : action.entityId,
                taskData: taskData,
              );
            }
          }
        }
        // Nếu không có lỗi, xóa action khỏi queue
        await localDataSource.deleteQueuedAction(action.id!);
      } catch (e) {
        print('Failed to sync action ${action.id}: $e');
        // Bỏ qua và tiếp tục với action tiếp theo
      }
    }
    return Right(unit);
  }
}
