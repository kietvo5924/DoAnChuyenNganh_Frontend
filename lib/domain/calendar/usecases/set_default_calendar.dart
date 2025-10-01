import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class SetDefaultCalendar {
  final CalendarRepository repository;
  SetDefaultCalendar(this.repository);

  Future<Either<Failure, Unit>> call(int id) async {
    return await repository.setDefaultCalendar(id);
  }
}
