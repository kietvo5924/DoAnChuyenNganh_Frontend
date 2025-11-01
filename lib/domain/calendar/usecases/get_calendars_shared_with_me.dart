import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/calendar_entity.dart';
import '../repositories/calendar_repository.dart';

class GetCalendarsSharedWithMe {
  final CalendarRepository repository;
  GetCalendarsSharedWithMe(this.repository);

  Future<Either<Failure, List<CalendarEntity>>> call() async {
    return await repository.getCalendarsSharedWithMe();
  }
}
