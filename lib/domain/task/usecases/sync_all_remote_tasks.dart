import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/task/repositories/task_repository.dart';

class SyncAllRemoteTasks {
  final TaskRepository repository;
  SyncAllRemoteTasks(this.repository);

  Future<Either<Failure, Unit>> call() async {
    return await repository.syncAllRemoteTasks();
  }
}
