import 'package:dartz/dartz.dart';
import 'package:planmate_app/core/error/failures.dart';
import 'package:planmate_app/core/network/network_info.dart';
import 'package:planmate_app/domain/calendar/entities/calendar_entity.dart';
import 'package:planmate_app/domain/calendar/repositories/calendar_repository.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'package:dio/dio.dart'; // NEW
import '../../sync/datasources/sync_queue_local_data_source.dart'; // NEW
import '../../sync/models/sync_queue_item_model.dart'; // NEW
import '../datasources/calendar_local_data_source.dart';
import '../datasources/calendar_remote_data_source.dart';
import '../models/calendar_model.dart';
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart'; // để dùng kAuthTokenKey

class CalendarRepositoryImpl implements CalendarRepository {
  final CalendarRemoteDataSource remoteDataSource;
  final CalendarLocalDataSource localDataSource;
  final NetworkInfo networkInfo;
  final SyncQueueLocalDataSource syncQueueLocalDataSource; // NEW
  final SharedPreferences _prefs; // NEW

  CalendarRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
    required this.syncQueueLocalDataSource,
    required SharedPreferences prefs, // NEW
  }) : _prefs = prefs; // NEW

  bool _hasToken() {
    final token = _prefs.getString(kAuthTokenKey);
    return token != null && token.isNotEmpty;
  }

  bool _isAuthRedirectOrUnauthorized(DioException e) {
    final code = e.response?.statusCode;
    return code == 302 || code == 401 || code == 403;
  }

  Future<void> _queueOfflineUpsert(CalendarEntity calendar, int localId) async {
    final temp = CalendarModel(
      id: localId,
      name: calendar.name,
      description: calendar.description,
      isDefault: calendar.isDefault,
    );
    await localDataSource.saveCalendar(temp, isSynced: false);
    await syncQueueLocalDataSource.addAction(
      SyncQueueItemModel(
        entityType: 'CALENDAR',
        entityId: localId,
        action: 'UPSERT',
        payload:
            '{"name":"${calendar.name}","description":"${calendar.description ?? ''}","isDefault":${calendar.isDefault}}',
      ),
    );
  }

  @override
  Future<Either<Failure, List<CalendarEntity>>> getLocalCalendars() async {
    try {
      final data = await localDataSource.getAllCalendars();
      return Right(data);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> syncRemoteCalendars() async {
    if (await networkInfo.isConnected && _hasToken()) {
      try {
        final remoteCalendars = await remoteDataSource.getAllCalendars();
        await localDataSource.cacheCalendars(remoteCalendars);
      } catch (e) {
        if (e is DioException && _isAuthRedirectOrUnauthorized(e)) {
          return Right(unit);
        }
        return Left(ServerFailure());
      }
    }
    return Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> saveCalendar(CalendarEntity calendar) async {
    try {
      final onlineAndAuthed =
          await networkInfo.isConnected && _hasToken(); // NEW
      if (onlineAndAuthed) {
        try {
          CalendarModel saved;
          if (calendar.id <= 0) {
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
        } on DioException catch (e) {
          if (_isAuthRedirectOrUnauthorized(e)) {
            int localId = calendar.id <= 0
                ? -DateTime.now().millisecondsSinceEpoch
                : calendar.id;
            await _queueOfflineUpsert(calendar, localId);
          } else {
            rethrow;
          }
        }
      } else {
        int localId = calendar.id;
        if (localId == 0) {
          localId = -DateTime.now().millisecondsSinceEpoch;
        }
        await _queueOfflineUpsert(calendar, localId);
      }
      return Right(unit);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteCalendar(int calendarId) async {
    try {
      final onlineAndAuthed =
          await networkInfo.isConnected && _hasToken(); // NEW
      if (onlineAndAuthed && calendarId > 0) {
        try {
          await remoteDataSource.deleteCalendar(calendarId);
        } on DioException catch (e) {
          if (_isAuthRedirectOrUnauthorized(e)) {
          } else {
            rethrow;
          }
        }
      }
      await localDataSource.deleteCalendar(calendarId);
      if (!onlineAndAuthed || calendarId <= 0) {
        await syncQueueLocalDataSource.addAction(
          SyncQueueItemModel(
            entityType: 'CALENDAR',
            entityId: calendarId,
            action: 'DELETE',
          ),
        );
      }
      return Right(unit);
    } catch (e) {
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> setDefaultCalendar(int calendarId) async {
    try {
      final onlineAndAuthed =
          await networkInfo.isConnected && _hasToken(); // NEW
      if (onlineAndAuthed && calendarId > 0) {
        try {
          await remoteDataSource.setDefaultCalendar(calendarId);
        } on DioException catch (e) {
          if (_isAuthRedirectOrUnauthorized(e)) {
          } else {
            rethrow;
          }
        }
      }
      await localDataSource.setDefaultCalendar(calendarId);
      if (!onlineAndAuthed || calendarId <= 0) {
        await syncQueueLocalDataSource.addAction(
          SyncQueueItemModel(
            entityType: 'CALENDAR',
            entityId: calendarId,
            action: 'SET_DEFAULT',
          ),
        );
      }
      return Right(unit);
    } catch (e) {
      return Left(ServerFailure());
    }
  }
}
