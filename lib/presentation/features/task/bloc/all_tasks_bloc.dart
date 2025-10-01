import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/calendar/usecases/get_local_calendars.dart';
import '../../../../domain/task/entities/task_with_calendar.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import 'all_tasks_event.dart';
import 'all_tasks_state.dart';

class AllTasksBloc extends Bloc<AllTasksEvent, AllTasksState> {
  // Sửa lại tên các Use Case cho đúng
  final GetLocalCalendars _getLocalCalendars;
  final GetLocalTasksInCalendar _getLocalTasksInCalendar;

  AllTasksBloc({
    // Sửa lại tên các tham số cho đúng
    required GetLocalCalendars getLocalCalendars,
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
  }) : _getLocalCalendars = getLocalCalendars,
       _getLocalTasksInCalendar = getLocalTasksInCalendar,
       super(AllTasksInitial()) {
    on<FetchAllTasks>((event, emit) async {
      emit(AllTasksLoading());
      final calendarsResult = await _getLocalCalendars();
      await calendarsResult.fold(
        (failure) async =>
            emit(const AllTasksError(message: 'Không thể tải lịch')),
        (calendars) async {
          if (calendars.isEmpty) {
            emit(const AllTasksLoaded(tasks: []));
            return;
          }
          List<TaskWithCalendar> allTasksWithCalendar = [];
          for (var calendar in calendars) {
            final tasksResult = await _getLocalTasksInCalendar(calendar.id);
            tasksResult.fold((l) => null, (tasks) {
              for (var task in tasks) {
                allTasksWithCalendar.add(
                  TaskWithCalendar(task: task, calendar: calendar),
                );
              }
            });
          }
          allTasksWithCalendar.sort(
            (a, b) => a.task.sortDate.compareTo(b.task.sortDate),
          );
          emit(AllTasksLoaded(tasks: allTasksWithCalendar));
        },
      );
    });
  }
}
