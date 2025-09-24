import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/data/calendar/datasources/calendar_remote_data_source.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource remoteDataSource;
  CalendarRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, List<CalendarEntity>>> getAllCalendars() async {
    try {
      final calendars = await remoteDataSource.getAllCalendars();
      return Right(calendars);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, CalendarEntity>> createCalendar(
    String name,
    String? description,
  ) async {
    try {
      final calendar = await remoteDataSource.createCalendar(name, description);
      return Right(calendar);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, CalendarEntity>> updateCalendar(
    int id,
    String name,
    String? description,
  ) async {
    try {
      final calendar = await remoteDataSource.updateCalendar(
        id,
        name,
        description,
      );
      return Right(calendar);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCalendar(int id) async {
    try {
      await remoteDataSource.deleteCalendar(id);
      return Right(unit);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setDefaultCalendar(int id) async {
    try {
      await remoteDataSource.setDefaultCalendar(id);
      return Right(unit);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
