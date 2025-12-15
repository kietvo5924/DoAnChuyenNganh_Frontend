import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../repositories/task_repository.dart';

class SetTaskOccurrenceCompleted {
  final TaskRepository repository;
  SetTaskOccurrenceCompleted(this.repository);

  Future<Either<Failure, Unit>> call({
    required int calendarId,
    required int taskId,
    required String taskType,
    required DateTime date,
    required bool completed,
  }) {
    return repository.setTaskOccurrenceCompleted(
      calendarId: calendarId,
      taskId: taskId,
      taskType: taskType,
      date: date,
      completed: completed,
    );
  }
}
