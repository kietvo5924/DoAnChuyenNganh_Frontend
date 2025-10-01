import 'package:equatable/equatable.dart';
import '../../../../domain/task/entities/task_entity.dart';

abstract class TaskListState extends Equatable {
  const TaskListState();
  @override
  List<Object> get props => [];
}

class TaskListInitial extends TaskListState {}

class TaskListLoading extends TaskListState {}

class TaskListLoaded extends TaskListState {
  final List<TaskEntity> tasks;
  const TaskListLoaded({required this.tasks});
}

class TaskListOperationSuccess extends TaskListState {
  final String message;
  const TaskListOperationSuccess({required this.message});
}

class TaskListError extends TaskListState {
  final String message;
  const TaskListError({required this.message});
}
