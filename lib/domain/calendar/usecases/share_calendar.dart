import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/calendar_repository.dart';

class ShareCalendar {
  final CalendarRepository repository;
  ShareCalendar(this.repository);

  Future<Either<Failure, Unit>> call({
    required int calendarId,
    required String email,
    required String permissionLevel, // "VIEW_ONLY" hoặc "EDIT"
  }) async {
    return await repository.shareCalendar(calendarId, email, permissionLevel);
  }
}
