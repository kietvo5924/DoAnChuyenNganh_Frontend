import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';

abstract class CalendarRepository {
  Future<Either<Failure, List<CalendarEntity>>> getLocalCalendars();
  Future<Either<Failure, Unit>> syncRemoteCalendars();
  Future<Either<Failure, Unit>> saveCalendar(CalendarEntity calendar);
  Future<Either<Failure, Unit>> deleteCalendar(int calendarId);
  Future<Either<Failure, Unit>> setDefaultCalendar(int calendarId);
}
