import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/task_entity.dart';
import '../repositories/task_repository.dart';

class GetAllTasksInCalendar {
  final TaskRepository repository;
  GetAllTasksInCalendar(this.repository);

  Future<Either<Failure, List<TaskEntity>>> call(int calendarId) async {
    return await repository.getLocalTasksInCalendar(calendarId);
  }
}
