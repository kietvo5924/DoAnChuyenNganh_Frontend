import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:planmate_app/data/sync/datasources/sync_queue_local_data_source.dart';
import 'package:planmate_app/data/sync/models/sync_queue_item_model.dart';
import 'package:shared_preferences/shared_preferences.dart'; // NEW
import 'package:planmate_app/data/auth/repositories/auth_repository_impl.dart'; // NEW kAuthTokenKey
import '../../../core/error/failures.dart';
import '../../../core/network/network_info.dart';
import '../../../domain/calendar/repositories/calendar_repository.dart';
import '../../../domain/task/entities/task_entity.dart';
import '../../../domain/task/repositories/task_repository.dart';
import '../datasources/task_local_data_source.dart';
import '../datasources/task_remote_data_source.dart';
import '../models/task_model.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TaskRemoteDataSource remoteDataSource;
  final TaskLocalDataSource localDataSource;
  final CalendarRepository calendarRepository;
  final NetworkInfo networkInfo;
  final SyncQueueLocalDataSource syncQueueLocalDataSource;
  final SharedPreferences _prefs; // NEW

  TaskRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.calendarRepository,
    required this.networkInfo,
    required this.syncQueueLocalDataSource,
    required SharedPreferences prefs, // NEW
  }) : _prefs = prefs; // NEW

  bool _hasToken() {
    final t = _prefs.getString(kAuthTokenKey);
    return t != null && t.isNotEmpty;
  }

  bool _isAuthRedirectOrUnauthorized(DioException e) {
    final c = e.response?.statusCode;
    return c == 302 || c == 401 || c == 403;
  }

  @override
  Future<Either<Failure, List<TaskEntity>>> getLocalTasksInCalendar(
    int calendarId,
  ) async {
    try {
      final localTasks = await localDataSource.getTasksInCalendar(calendarId);
      return Right(localTasks);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, List<TaskEntity>>> getAllLocalTasks() async {
    try {
      final localTasks = await localDataSource.getAllTasks();
      return Right(localTasks);
    } catch (e) {
      return Left(CacheFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> syncAllRemoteTasks() async {
    if (!_hasToken()) {
      return Right(unit);
    }
    final connectedFlag = await networkInfo.isConnected;
    try {
      final calendarsResult = await calendarRepository.getLocalCalendars();
      if (calendarsResult.isLeft()) return Left(CacheFailure());
      final calendars = calendarsResult.getOrElse(() => []);

      // Bỏ qua nếu không có calendar dương (chưa đồng bộ xong)
      final positiveCalendars = calendars.where((c) => c.id > 0).toList();
      if (positiveCalendars.isEmpty) {
        return Right(unit);
      }

      final List<TaskModel> allRemote = [];
      for (final cal in positiveCalendars) {
        try {
          final remoteTasks = await remoteDataSource.getAllTasksInCalendar(
            cal.id,
          );
          allRemote.addAll(remoteTasks);
        } on DioException {
          continue;
        } catch (_) {
          continue;
        }
      }
      await localDataSource.cacheTasks(allRemote);
      return Right(unit);
    } catch (e) {
      if (e is DioException) {
        final netLike =
            e.type == DioExceptionType.connectionError ||
            e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout ||
            e.type == DioExceptionType.unknown;
        if (!connectedFlag && netLike) {
          print('[TaskRepository] treat as offline skip (no failure)');
          return Right(unit);
        }
      }
      return Left(ServerFailure());
    }
  }

  @override
  Future<Either<Failure, Unit>> saveTask(TaskEntity task) async {
    // Chuyển đổi TaskEntity thành Map để remoteDataSource có thể sử dụng
    final taskData = {
      'title': task.title,
      'description': task.description,
      'tagIds': task.tags.map((t) => t.id).toList(),
      'repeatType': task.repeatType.name,
      'startTime': task.repeatType == RepeatType.NONE
          ? task.startTime?.toUtc().toIso8601String()
          : null,
      'endTime': task.repeatType == RepeatType.NONE
          ? task.endTime?.toUtc().toIso8601String()
          : null,
      'allDay': task.isAllDay,
      'repeatStartTime': task.repeatType != RepeatType.NONE
          ? '${task.repeatStartTime!.hour.toString().padLeft(2, '0')}:${task.repeatStartTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'repeatEndTime': task.repeatType != RepeatType.NONE
          ? '${task.repeatEndTime!.hour.toString().padLeft(2, '0')}:${task.repeatEndTime!.minute.toString().padLeft(2, '0')}:00'
          : null,
      'timezone': task.timezone,
      'repeatInterval': task.repeatInterval,
      'repeatDays': task.repeatDays,
      'repeatDayOfMonth': task.repeatDayOfMonth,
      'repeatWeekOfMonth': task.repeatWeekOfMonth,
      'repeatDayOfWeek': task.repeatDayOfWeek,
      'repeatStart': task.repeatType != RepeatType.NONE
          ? DateFormat('yyyy-MM-dd').format(task.repeatStart!)
          : null,
      'repeatEnd': task.repeatEnd != null
          ? DateFormat('yyyy-MM-dd').format(task.repeatEnd!)
          : null,
      'exceptions': task.exceptions,
    };
    final taskId = (task.id == 0) ? null : task.id;

    final hasToken = _hasToken(); // NEW
    final isOnline = await networkInfo.isConnected;
    final onlineAndAuthed = hasToken && isOnline; // NEW

    if (onlineAndAuthed) {
      try {
        await remoteDataSource.saveTask(
          calendarId: task.calendarId,
          taskId: taskId,
          taskData: taskData,
        );
        await syncAllRemoteTasks();
        return Right(unit);
      } on DioException catch (e) {
        if (_isAuthRedirectOrUnauthorized(e)) {
          // silent fallback
        } else {
          return Left(ServerFailure());
        }
      } catch (_) {
        return Left(ServerFailure());
      }
    }
    // OFFLINE hoặc guest fallback
    // NEW: generate temp negative id if creating offline
    int localId = task.id;
    if (localId == 0) {
      localId = -DateTime.now()
          .millisecondsSinceEpoch; // temp negative id for offline create
    }
    final taskModelToSave = TaskModel(
      id: localId, // CHANGED
      title: task.title,
      description: task.description,
      tags: task.tags,
      calendarId: task.calendarId,
      repeatType: task.repeatType,
      startTime: task.startTime,
      endTime: task.endTime,
      isAllDay: task.isAllDay,
      repeatStartTime: task.repeatStartTime,
      repeatEndTime: task.repeatEndTime,
      timezone: task.timezone,
      repeatInterval: task.repeatInterval,
      repeatDays: task.repeatDays,
      repeatDayOfMonth: task.repeatDayOfMonth,
      repeatWeekOfMonth: task.repeatWeekOfMonth,
      repeatDayOfWeek: task.repeatDayOfWeek,
      repeatStart: task.repeatStart,
      repeatEnd: task.repeatEnd,
      exceptions: task.exceptions,
    );
    await localDataSource.saveTask(taskModelToSave, isSynced: false);

    // NEW: push UPSERT action with payload
    final payload = jsonEncode({
      'calendarId': task.calendarId,
      // reuse taskData but ensure nulls handled
      'taskData': taskData,
    });
    await syncQueueLocalDataSource.addAction(
      SyncQueueItemModel(
        entityType: 'TASK',
        entityId: localId,
        action: 'UPSERT',
        payload: payload,
      ),
    );

    return Right(unit);
  }

  @override
  Future<Either<Failure, Unit>> deleteTask({
    required int taskId,
    required String type,
  }) async {
    final hasToken = _hasToken();
    final isOnline = await networkInfo.isConnected;
    final onlineAndAuthed = hasToken && isOnline;
    if (onlineAndAuthed) {
      try {
        await remoteDataSource.deleteTask(taskId: taskId, type: type);
        await localDataSource.deleteTask(taskId);
        return Right(unit);
      } on DioException catch (e) {
        if (_isAuthRedirectOrUnauthorized(e)) {
          // silent
        } else {
          await localDataSource.deleteTask(taskId);
          await syncQueueLocalDataSource.addAction(
            SyncQueueItemModel(
              entityType: 'TASK',
              entityId: taskId,
              action: 'DELETE',
            ),
          );
          return Left(ServerFailure());
        }
      } catch (_) {
        await localDataSource.deleteTask(taskId);
        await syncQueueLocalDataSource.addAction(
          SyncQueueItemModel(
            entityType: 'TASK',
            entityId: taskId,
            action: 'DELETE',
          ),
        );
        return Left(ServerFailure());
      }
    }
    // offline hoặc guest
    await localDataSource.deleteTask(taskId);
    await syncQueueLocalDataSource.addAction(
      SyncQueueItemModel(
        entityType: 'TASK',
        entityId: taskId,
        action: 'DELETE',
      ),
    );
    return Right(unit);
  }
}
