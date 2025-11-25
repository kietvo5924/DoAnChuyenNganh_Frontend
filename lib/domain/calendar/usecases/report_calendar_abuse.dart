import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class ReportCalendarAbuse {
  final CalendarRepository repository;
  ReportCalendarAbuse(this.repository);

  Future<Either<Failure, Unit>> call({
    required int calendarId,
    required String reason,
    String? description,
  }) {
    return repository.reportCalendarAbuse(
      calendarId,
      reason,
      description: description,
    );
  }
}
