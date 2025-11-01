import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/calendar_repository.dart';

class UnshareCalendar {
  final CalendarRepository repository;
  UnshareCalendar(this.repository);

  Future<Either<Failure, Unit>> call({
    required int calendarId,
    required int userId,
  }) async {
    return await repository.unshareCalendar(calendarId, userId);
  }
}
