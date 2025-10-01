import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/task/entities/task_entity.dart';
import 'package:planmate_app/domain/task/repositories/task_repository.dart';

class SaveTask {
  final TaskRepository repository;

  SaveTask(this.repository);

  Future<Either<Failure, Unit>> call(TaskEntity task) {
    return repository.saveTask(task);
  }
}
