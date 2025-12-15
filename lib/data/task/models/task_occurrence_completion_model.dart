import '../../../domain/task/entities/task_occurrence_completion.dart';

class TaskOccurrenceCompletionModel extends TaskOccurrenceCompletion {
  const TaskOccurrenceCompletionModel({
    required super.calendarId,
    required super.taskId,
    required super.taskType,
    required super.occurrenceDate,
    required super.completed,
  });

  factory TaskOccurrenceCompletionModel.fromJson(Map<String, dynamic> json) {
    return TaskOccurrenceCompletionModel(
      calendarId: (json['calendarId'] as num).toInt(),
      taskId: (json['taskId'] as num).toInt(),
      taskType: (json['taskType'] as String).toUpperCase(),
      occurrenceDate: (json['occurrenceDate'] as String),
      completed: json['completed'] == true,
    );
  }

  factory TaskOccurrenceCompletionModel.fromDb(Map<String, dynamic> map) {
    return TaskOccurrenceCompletionModel(
      calendarId: (map['calendar_id'] as num).toInt(),
      taskId: (map['task_id'] as num).toInt(),
      taskType: (map['task_type'] as String).toUpperCase(),
      occurrenceDate: map['occurrence_date'] as String,
      completed: ((map['completed'] as int?) ?? 1) == 1,
    );
  }

  Map<String, dynamic> toDbMap({required bool isSynced}) {
    return {
      'calendar_id': calendarId,
      'task_id': taskId,
      'task_type': taskType.toUpperCase(),
      'occurrence_date': occurrenceDate,
      'completed': completed ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
