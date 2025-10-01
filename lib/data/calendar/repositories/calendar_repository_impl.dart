import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/core/network/network_info.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';
import '../datasources/calendar_local_data_source.dart';
import '../datasources/calendar_remote_data_source.dart';
import '../models/calendar_model.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource remoteDataSource;
  final CalendarLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  CalendarRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<CalendarEntity>>> getLocalCalendars() async {
    try {
      final data = await localDataSource.getAllCalendars();
      return Right(data);
    } catch (e) {
      print('[CalendarRepo] getLocalCalendars error: $e');
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> syncRemoteCalendars() async {
    // Chỉ cố gắng đồng bộ khi có mạng
    if (await networkInfo.isConnected) {
      try {
        final remoteCalendars = await remoteDataSource.getAllCalendars();
        await localDataSource.cacheCalendars(remoteCalendars);
      } catch (e) {
        return Left(ServerFailure()); // Báo lỗi nếu API thất bại
      }
    }
    return Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> saveCalendar(CalendarEntity calendar) async {
    try {
      if (await networkInfo.isConnected) {
        CalendarModel saved;
        if (calendar.id == 0) {
          saved = await remoteDataSource.createCalendar(
            calendar.name,
            calendar.description,
          );
        } else {
          saved = await remoteDataSource.updateCalendar(
            calendar.id,
            calendar.name,
            calendar.description,
          );
        }
        await localDataSource.saveCalendar(saved, isSynced: true);
      } else {
        // Offline: lưu tạm (id phải là >0 nếu muốn replace)
        final temp = CalendarModel(
          id: calendar.id,
          name: calendar.name,
          description: calendar.description,
          isDefault: calendar.isDefault,
        );
        await localDataSource.saveCalendar(temp, isSynced: false);
        // TODO: thêm vào sync_queue
      }
      return Right(unit);
    } catch (e) {
      print('[CalendarRepo] saveCalendar error: $e');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCalendar(int calendarId) async {
    try {
      if (await networkInfo.isConnected) {
        await remoteDataSource.deleteCalendar(calendarId);
      }
      await localDataSource.deleteCalendar(calendarId);
      return Right(unit);
    } catch (e) {
      print('[CalendarRepo] deleteCalendar error: $e');
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setDefaultCalendar(int calendarId) async {
    try {
      if (await networkInfo.isConnected) {
        await remoteDataSource.setDefaultCalendar(calendarId);
      }
      await localDataSource.setDefaultCalendar(calendarId);
      return Right(unit);
    } catch (e) {
      print('[CalendarRepo] setDefaultCalendar error: $e');
      return Left(ServerFailure());
    }
  }
}
