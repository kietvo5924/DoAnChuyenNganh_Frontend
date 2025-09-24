import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';

abstract class CalendarRepository {
  Future<Either<Failure, List<CalendarEntity>>> getAllCalendars();
  Future<Either<Failure, CalendarEntity>> createCalendar(
    String name,
    String? description,
  );
  Future<Either<Failure, CalendarEntity>> updateCalendar(
    int id,
    String name,
    String? description,
  );
  Future<Either<Failure, Unit>> deleteCalendar(int id);
  Future<Either<Failure, Unit>> setDefaultCalendar(int id);
}
