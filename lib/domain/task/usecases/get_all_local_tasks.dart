import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/task/entities/task_entity.dart';
import 'package:planmate_app/domain/task/repositories/task_repository.dart';

class GetAllLocalTasks {
  final TaskRepository repository;

  GetAllLocalTasks(this.repository);

  Future<Either<Failure, List<TaskEntity>>> call() async {
    return await repository.getAllLocalTasks();
  }
}
