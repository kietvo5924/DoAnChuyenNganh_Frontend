import 'package:equatable/equatable.dart';

abstract class AllTasksEvent extends Equatable {
  const AllTasksEvent();
  @override
  List<Object> get props => [];
}

class FetchAllTasks extends AllTasksEvent {}
