import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class SyncRemoteCalendars {
  final CalendarRepository repository;
  SyncRemoteCalendars(this.repository);

  Future<Either<Failure, Unit>> call() async {
    print('[SyncCalendars] Start');
    final r = await repository.syncRemoteCalendars();
    r.fold(
      (_) => print('[SyncCalendars] FAIL'),
      (_) => print('[SyncCalendars] OK'),
    );
    return r;
  }
}
