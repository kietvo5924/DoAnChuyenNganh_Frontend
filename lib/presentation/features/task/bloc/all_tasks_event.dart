import 'package:equatable/equatable.dart';
import '../../../../domain/task/entities/task_entity.dart';

abstract class AllTasksEvent extends Equatable {
  const AllTasksEvent();
  @override
  List<Object> get props => [];
}

class FetchAllTasks extends AllTasksEvent {
  final DateTime? date;

  const FetchAllTasks({this.date});

  @override
  List<Object> get props => [date?.millisecondsSinceEpoch ?? -1];
}

class ToggleAllTasksCompletionForDate extends AllTasksEvent {
  final int calendarId;
  final int taskId;
  final RepeatType repeatType;
  final DateTime date;
  final bool completed;

  const ToggleAllTasksCompletionForDate({
    required this.calendarId,
    required this.taskId,
    required this.repeatType,
    required this.date,
    required this.completed,
  });

  @override
  List<Object> get props => [calendarId, taskId, repeatType, date, completed];
}
