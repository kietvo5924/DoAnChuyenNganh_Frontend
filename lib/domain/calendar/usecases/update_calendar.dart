import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/calendar_entity.dart';
import '../repositories/calendar_repository.dart';

class UpdateCalendar {
  final CalendarRepository repository;
  UpdateCalendar(this.repository);

  Future<Either<Failure, CalendarEntity>> call(
    int id,
    String name,
    String? description,
  ) async {
    return await repository.updateCalendar(id, name, description);
  }
}
