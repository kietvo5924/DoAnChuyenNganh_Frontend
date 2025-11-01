import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../domain/user/entities/user_entity.dart'; // Sử dụng UserEntity
import '../repositories/calendar_repository.dart';

class GetUsersSharingCalendar {
  final CalendarRepository repository;
  GetUsersSharingCalendar(this.repository);

  Future<Either<Failure, List<UserEntity>>> call(int calendarId) async {
    return await repository.getUsersSharingCalendar(calendarId);
  }
}
