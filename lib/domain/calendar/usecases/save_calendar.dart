import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class SaveCalendar {
  final CalendarRepository repository;

  SaveCalendar(this.repository);

  Future<Either<Failure, Unit>> call(CalendarEntity calendar) {
    return repository.saveCalendar(calendar);
  }
}
