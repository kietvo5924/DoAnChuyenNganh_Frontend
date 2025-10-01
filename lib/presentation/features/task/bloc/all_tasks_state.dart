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
  const AllTasksLoaded({required this.tasks});

  @override
  List<Object> get props => [tasks];
}

class AllTasksError extends AllTasksState {
  final String message;
  const AllTasksError({required this.message});
}
