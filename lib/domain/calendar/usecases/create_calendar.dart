import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class CreateCalendar {
  final CalendarRepository repository;
  CreateCalendar(this.repository);

  Future<Either<Failure, CalendarEntity>> call(
    String name,
    String? description,
  ) async {
    return await repository.createCalendar(name, description);
  }
}
