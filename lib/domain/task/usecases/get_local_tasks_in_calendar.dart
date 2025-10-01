import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/task/entities/task_entity.dart';
import 'package:planmate_app/domain/task/repositories/task_repository.dart';

class GetLocalTasksInCalendar {
  final TaskRepository repository;
  GetLocalTasksInCalendar(this.repository);

  Future<Either<Failure, List<TaskEntity>>> call(int calendarId) async {
    return await repository.getLocalTasksInCalendar(calendarId);
  }
}
