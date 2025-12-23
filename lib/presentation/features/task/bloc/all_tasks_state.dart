import 'package:equatable/equatable.dart';
import 'package:planmate_app/domain/task/entities/task_with_calendar.dart';

abstract class AllTasksState extends Equatable {
  const AllTasksState();
  @override
  List<Object> get props => [];
}

class AllTasksInitial extends AllTasksState {}

class AllTasksLoading extends AllTasksState {}

class AllTasksLoaded extends AllTasksState {
  final List<TaskWithCalendar> tasks;
  final String date; // yyyy-MM-dd
  final Set<String> completedKeys; // TASKTYPE|TASKID|DATE

  const AllTasksLoaded({
    required this.tasks,
    required this.date,
    required this.completedKeys,
  });

  bool isCompleted({required String taskType, required int taskId}) {
    return completedKeys.contains('${taskType.toUpperCase()}|$taskId|$date');
  }

  @override
  List<Object> get props => [tasks, date, completedKeys];
}

class AllTasksError extends AllTasksState {
  final String message;
  const AllTasksError({required this.message});
}
