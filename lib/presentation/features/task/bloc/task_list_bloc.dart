import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/task/usecases/delete_task.dart';
import '../../../../domain/task/usecases/get_local_tasks_in_calendar.dart';
import 'task_list_event.dart';
import 'task_list_state.dart';

class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  final GetLocalTasksInCalendar _getLocalTasksInCalendar;
  final DeleteTask _deleteTask;

  TaskListBloc({
    required GetLocalTasksInCalendar getLocalTasksInCalendar,
    required DeleteTask deleteTask,
  }) : _getLocalTasksInCalendar = getLocalTasksInCalendar,
       _deleteTask = deleteTask,
       super(TaskListInitial()) {
    on<FetchTasksInCalendar>((event, emit) async {
      emit(TaskListLoading());
      final result = await _getLocalTasksInCalendar(event.calendarId);
      result.fold(
        (failure) =>
            emit(const TaskListError(message: 'Tải công việc thất bại')),
        (tasks) => emit(TaskListLoaded(tasks: tasks)),
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
