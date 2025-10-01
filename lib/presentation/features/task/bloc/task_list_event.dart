import 'package:equatable/equatable.dart';
import '../../../../domain/task/entities/task_entity.dart';

abstract class TaskListEvent extends Equatable {
  const TaskListEvent();
  @override
  List<Object> get props => [];
}

class FetchTasksInCalendar extends TaskListEvent {
  final int calendarId;
  const FetchTasksInCalendar({required this.calendarId});
}

class DeleteTaskFromList extends TaskListEvent {
  final TaskEntity task;
  final int calendarId; // Cần calendarId để tải lại danh sách sau khi xóa

  const DeleteTaskFromList({required this.task, required this.calendarId});

  @override
  List<Object> get props => [task, calendarId];
}
