import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/task_entity.dart'; // Cần để lấy RepeatType
import '../repositories/task_repository.dart';

class DeleteTask {
  final TaskRepository repository;
  DeleteTask(this.repository);

  Future<Either<Failure, Unit>> call({
    required int taskId,
    required RepeatType type,
  }) async {
    final String typeString = (type == RepeatType.NONE)
        ? "SINGLE"
        : "RECURRING";

    return await repository.deleteTask(taskId: taskId, type: typeString);
  }
}
