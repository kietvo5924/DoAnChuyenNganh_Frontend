import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../entities/calendar_entity.dart';
import '../repositories/calendar_repository.dart';

// Đổi tên lớp từ GetAllCalendars thành GetLocalCalendars
class GetLocalCalendars {
  final CalendarRepository repository;
  GetLocalCalendars(this.repository);

  Future<Either<Failure, List<CalendarEntity>>> call() async {
    return await repository.getLocalCalendars();
  }
}
