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
  final List<TaskEntity> tasks; // Tất cả task của mọi calendar
  final List<CalendarEntity> calendars; // Danh sách calendar để tra tên

  const HomeLoaded({required this.tasks, required this.calendars});

  @override
  List<Object?> get props => [tasks, calendars];
}
