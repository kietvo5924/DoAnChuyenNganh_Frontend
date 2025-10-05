import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../domain/tag/entities/tag_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';
import '../../../../domain/task/usecases/save_task.dart';
import '../../../../domain/task/usecases/delete_task.dart'; // NEW
import 'task_editor_event.dart';
import 'task_editor_state.dart';

class TaskEditorBloc extends Bloc<TaskEditorEvent, TaskEditorState> {
  final SaveTask _saveTask;
  final DeleteTask _deleteTask; // NEW

  TaskEditorBloc({
    required SaveTask saveTask,
    required DeleteTask deleteTask,
  }) // CHANGED
  : _saveTask = saveTask,
       _deleteTask = deleteTask, // NEW
       super(TaskEditorInitial()) {
    on<SaveTaskSubmitted>((event, emit) async {
      emit(TaskEditorLoading());

      // BLoC tạo đối tượng TaskEntity từ dữ liệu của Event
      final taskToSave = TaskEntity(
        id: event.taskId ?? 0, // ID tạm thời, backend sẽ xử lý
        title: event.title,
        description: event.description,
        calendarId: event.calendarId,
        tags: event.tagIds
            .map((id) => TagEntity(id: id, name: ''))
            .toSet(), // Tạo tag tạm thời
        repeatType: event.repeatType,
        startTime: event.startTime,
        endTime: event.endTime,
        isAllDay: event.isAllDay,
        repeatStartTime: event.repeatStartTime,
        repeatEndTime: event.repeatEndTime,
        repeatStart: event.repeatStart,
        repeatEnd: event.repeatEnd,
        repeatInterval: event.repeatInterval,
        repeatDays: event.repeatDays,
        repeatDayOfMonth: event.repeatDayOfMonth,
      );

      final result = await _saveTask(taskToSave);

      result.fold(
        (failure) =>
            emit(const TaskEditorFailure(message: 'Lưu công việc thất bại')),
        (_) => emit(const TaskEditorSuccess(message: 'Đã lưu công việc!')),
      );
    });

    // NEW: xử lý xóa task
    on<DeleteTaskSubmitted>((event, emit) async {
      emit(TaskEditorLoading());
      final result = await _deleteTask(
        taskId: event.taskId,
        type: event.repeatType,
      );
      result.fold(
        (failure) =>
            emit(const TaskEditorFailure(message: 'Xóa công việc thất bại')),
        (_) => emit(const TaskEditorSuccess(message: 'Đã xóa công việc!')),
      );
    });
  }
}
