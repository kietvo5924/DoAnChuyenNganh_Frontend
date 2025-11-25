import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/user/entities/user_entity.dart';

abstract class CalendarRepository {
  Future<Either<Failure, List<CalendarEntity>>> getLocalCalendars();
  Future<Either<Failure, Unit>> syncRemoteCalendars();
  Future<Either<Failure, Unit>> saveCalendar(CalendarEntity calendar);
  Future<Either<Failure, Unit>> deleteCalendar(int calendarId);
  Future<Either<Failure, Unit>> setDefaultCalendar(int calendarId);
  Future<Either<Failure, Unit>> shareCalendar(
    int calendarId,
    String email,
    String permissionLevel,
  );
  Future<Either<Failure, Unit>> unshareCalendar(int calendarId, int userId);
  Future<Either<Failure, List<UserEntity>>> getUsersSharingCalendar(
    int calendarId,
  ); // Trả về UserEntity
  Future<Either<Failure, List<CalendarEntity>>> getCalendarsSharedWithMe();
  Future<Either<Failure, Unit>> reportCalendarAbuse(
    int calendarId,
    String reason, {
    String? description,
  });
}
