import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/task_entity.dart';
import '../entities/task_occurrence_completion.dart';

abstract class TaskRepository {
  Future<Either<Failure, List<TaskEntity>>> getLocalTasksInCalendar(
    int calendarId,
  );
  Future<Either<Failure, List<TaskEntity>>>
  getAllLocalTasks(); // Lấy tất cả task cho trang AllTasksPage
  Future<Either<Failure, Unit>> syncAllRemoteTasks();
  Future<Either<Failure, Unit>> saveTask(TaskEntity task);

  Future<Either<Failure, Unit>> deleteTask({
    required int taskId,
    required String type,
  });

  Future<Either<Failure, Unit>> setTaskOccurrenceCompleted({
    required int calendarId,
    required int taskId,
    required String taskType, // SINGLE | RECURRING
    required DateTime date,
    required bool completed,
  });

  Future<Either<Failure, List<TaskOccurrenceCompletion>>>
  getTaskOccurrenceCompletions({
    required int calendarId,
    required DateTime from,
    required DateTime to,
  });
}
