import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/task_occurrence_completion.dart';
import '../repositories/task_repository.dart';

class GetTaskOccurrenceCompletions {
  final TaskRepository repository;
  GetTaskOccurrenceCompletions(this.repository);

  Future<Either<Failure, List<TaskOccurrenceCompletion>>> call({
    required int calendarId,
    required DateTime from,
    required DateTime to,
  }) {
    return repository.getTaskOccurrenceCompletions(
      calendarId: calendarId,
      from: from,
      to: to,
    );
  }
}
