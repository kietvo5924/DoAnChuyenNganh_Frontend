import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/task/usecases/delete_task.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import '../../../../domain/task/usecases/get_task_occurrence_completions.dart';
import '../../../../domain/task/usecases/set_task_occurrence_completed.dart';
import 'package:intl/intl.dart';
import 'task_list_event.dart';
import 'task_list_state.dart';

// NEW: remote fallback + cache
import 'package:planmate_app/injection.dart';
import 'package:planmate_app/data/task/datasources/task_remote_data_source.dart';
import 'package:planmate_app/data/task/datasources/task_local_data_source.dart';
// NEW: check local calendars to detect "shared-with-me"
import 'package:planmate_app/core/services/database_service.dart';

class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  final GetLocalTasksInCalendar _getLocalTasksInCalendar;
  final DeleteTask _deleteTask;
  final GetTaskOccurrenceCompletions _getCompletions;
  final SetTaskOccurrenceCompleted _setCompletion;

  TaskListBloc({
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
    required DeleteTask deleteTask,
    required GetTaskOccurrenceCompletions getCompletions,
    required SetTaskOccurrenceCompleted setCompletion,
  }) : _getLocalTasksInCalendar = getLocalTasksInCalendar,
       _deleteTask = deleteTask,
       _getCompletions = getCompletions,
       _setCompletion = setCompletion,
       super(TaskListInitial()) {
    on<FetchTasksInCalendar>((event, emit) async {
      emit(TaskListLoading());

      final date = (event.date ?? DateTime.now()).toLocal();
      final ymd = DateFormat('yyyy-MM-dd').format(date);

      // NEW: if this calendar id is NOT in local "calendars" table,
      // treat it as "shared-with-me" and fetch remote first.
      try {
        final db = await getIt<DatabaseService>().database;
        final exists = await db.query(
          'calendars',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [event.calendarId],
          limit: 1,
        );
        if (exists.isEmpty) {
          try {
            final remote = getIt<TaskRemoteDataSource>();
            final local = getIt<TaskLocalDataSource>();
            final models = await remote.getAllTasksInCalendar(event.calendarId);
            if (models.isNotEmpty) {
              await local.cacheTasks(models);
            }
            final result2 = await _getLocalTasksInCalendar(event.calendarId);
            return result2.fold(
              (_) =>
                  emit(const TaskListError(message: 'Tải công việc thất bại')),
              (tasks2) async {
                final compsRes = await _getCompletions(
                  calendarId: event.calendarId,
                  from: date,
                  to: date,
                );
                final completedKeys = compsRes.fold<Set<String>>(
                  (_) => <String>{},
                  (items) => items
                      .where((e) => e.completed)
                      .map(
                        (e) =>
                            '${e.taskType.toUpperCase()}|${e.taskId}|${e.occurrenceDate}',
                      )
                      .toSet(),
                );
                emit(
                  TaskListLoaded(
                    tasks: tasks2,
                    date: ymd,
                    completedKeys: completedKeys,
                  ),
                );
              },
            );
          } catch (_) {
            // fall through to normal flow if remote-first fails
          }
        }
      } catch (_) {
        // ignore calendar existence errors and continue
      }

      // Normal flow: local-first, then remote fallback if empty
      final result = await _getLocalTasksInCalendar(event.calendarId);
      await result.fold(
        (failure) async {
          emit(const TaskListError(message: 'Tải công việc thất bại'));
        },
        (tasks) async {
          if (tasks.isEmpty) {
            try {
              final remote = getIt<TaskRemoteDataSource>();
              final local = getIt<TaskLocalDataSource>();
              final models = await remote.getAllTasksInCalendar(
                event.calendarId,
              );
              if (models.isNotEmpty) {
                await local.cacheTasks(models);
                final result2 = await _getLocalTasksInCalendar(
                  event.calendarId,
                );
                result2.fold(
                  (_) => emit(
                    const TaskListError(message: 'Tải công việc thất bại'),
                  ),
                  (tasks2) async {
                    final compsRes = await _getCompletions(
                      calendarId: event.calendarId,
                      from: date,
                      to: date,
                    );
                    final completedKeys = compsRes.fold<Set<String>>(
                      (_) => <String>{},
                      (items) => items
                          .where((e) => e.completed)
                          .map(
                            (e) =>
                                '${e.taskType.toUpperCase()}|${e.taskId}|${e.occurrenceDate}',
                          )
                          .toSet(),
                    );
                    emit(
                      TaskListLoaded(
                        tasks: tasks2,
                        date: ymd,
                        completedKeys: completedKeys,
                      ),
                    );
                  },
                );
                return;
              }
            } catch (_) {
              // silent; fall through to emit empty state
            }
          }
          // Load completion keys for this calendar/date
          final compsRes = await _getCompletions(
            calendarId: event.calendarId,
            from: date,
            to: date,
          );
          final completedKeys = compsRes.fold<Set<String>>(
            (_) => <String>{},
            (items) => items
                .where((e) => e.completed)
                .map(
                  (e) =>
                      '${e.taskType.toUpperCase()}|${e.taskId}|${e.occurrenceDate}',
                )
                .toSet(),
          );
          emit(
            TaskListLoaded(
              tasks: tasks,
              date: ymd,
              completedKeys: completedKeys,
            ),
          );
        },
      );
    });

    on<ToggleTaskCompletionForDate>((event, emit) async {
      final current = state;
      if (current is! TaskListLoaded) return;
      final ymd = DateFormat('yyyy-MM-dd').format(event.date.toLocal());
      final taskType = (event.task.repeatType == RepeatType.NONE)
          ? 'SINGLE'
          : 'RECURRING';
      final key = '$taskType|${event.task.id}|$ymd';

      // optimistic update
      final nextKeys = Set<String>.from(current.completedKeys);
      if (event.completed) {
        nextKeys.add(key);
      } else {
        nextKeys.remove(key);
      }
      emit(
        TaskListLoaded(
          tasks: current.tasks,
          date: current.date,
          completedKeys: nextKeys,
        ),
      );

      final res = await _setCompletion(
        calendarId: event.task.calendarId,
        taskId: event.task.id,
        taskType: taskType,
        date: event.date,
        completed: event.completed,
      );
      res.fold(
        (_) =>
            emit(const TaskListError(message: 'Cập nhật trạng thái thất bại')),
        (_) {
          // refresh completions for day
          add(
            FetchTasksInCalendar(
              calendarId: event.task.calendarId,
              date: event.date,
            ),
          );
        },
      );
    });

    on<DeleteTaskFromList>((event, emit) async {
      final result = await _deleteTask(
        taskId: event.task.id,
        type: event.task.repeatType,
      );
      result.fold(
        (failure) =>
            emit(const TaskListError(message: 'Xóa công việc thất bại')),
        (_) {
          emit(const TaskListOperationSuccess(message: 'Đã xóa công việc!'));
          // Sau khi xóa thành công, gọi lại event để làm mới danh sách
          add(FetchTasksInCalendar(calendarId: event.task.calendarId));
        },
      );
    });
  }
}
