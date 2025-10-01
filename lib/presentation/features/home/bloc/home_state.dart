import 'package:equatable/equatable.dart';
import '../../../../domain/calendar/entities/calendar_entity.dart';
import '../../../../domain/task/entities/task_entity.dart';

abstract class HomeState extends Equatable {
  const HomeState();
  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeError extends HomeState {
  final String message;
  const HomeError({required this.message});
}

// Trạng thái thành công, chứa danh sách công việc và thông tin về lịch mặc định
class HomeLoaded extends HomeState {
  final List<TaskEntity> tasks;
  final CalendarEntity defaultCalendar;

  const HomeLoaded({required this.tasks, required this.defaultCalendar});

  @override
  List<Object?> get props => [tasks, defaultCalendar];
}
