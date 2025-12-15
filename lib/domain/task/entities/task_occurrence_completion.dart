import 'package:equatable/equatable.dart';

class TaskOccurrenceCompletion extends Equatable {
  final int calendarId;
  final int taskId;

  /// 'SINGLE' | 'RECURRING'
  final String taskType;

  /// yyyy-MM-dd (local)
  final String occurrenceDate;
  final bool completed;

  const TaskOccurrenceCompletion({
    required this.calendarId,
    required this.taskId,
    required this.taskType,
    required this.occurrenceDate,
    required this.completed,
  });

  @override
  List<Object?> get props => [
    calendarId,
    taskId,
    taskType,
    occurrenceDate,
    completed,
  ];
}
