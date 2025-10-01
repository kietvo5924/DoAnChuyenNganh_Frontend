import 'package:equatable/equatable.dart';
import '../../../domain/calendar/entities/calendar_entity.dart';
import 'task_entity.dart';

class TaskWithCalendar extends Equatable {
  final TaskEntity task;
  final CalendarEntity calendar;

  const TaskWithCalendar({required this.task, required this.calendar});

  @override
  List<Object?> get props => [task, calendar];
}
