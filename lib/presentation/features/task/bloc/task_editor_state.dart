import 'package:equatable/equatable.dart';

abstract class TaskEditorState extends Equatable {
  const TaskEditorState();
  @override
  List<Object> get props => [];
}

class TaskEditorInitial extends TaskEditorState {}

class TaskEditorLoading extends TaskEditorState {}

class TaskEditorSuccess extends TaskEditorState {
  final String message;
  const TaskEditorSuccess({required this.message});
}

class TaskEditorFailure extends TaskEditorState {
  final String message;
  const TaskEditorFailure({required this.message});
}
