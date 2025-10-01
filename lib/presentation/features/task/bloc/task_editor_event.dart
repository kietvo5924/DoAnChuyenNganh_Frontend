import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../../../domain/task/entities/task_entity.dart';

abstract class TaskEditorEvent extends Equatable {
  const TaskEditorEvent();
  @override
  List<Object?> get props => [];
}

// Event duy nhất cho việc lưu, chứa tất cả các thông tin có thể có từ form
class SaveTaskSubmitted extends TaskEditorEvent {
  final int? taskId;
  final int calendarId;
  final String title;
  final String? description;
  final Set<int> tagIds;
  final RepeatType repeatType;
  final DateTime startTime;
  final DateTime endTime;
  final bool isAllDay;
  final TimeOfDay repeatStartTime;
  final TimeOfDay repeatEndTime;
  final int? repeatInterval;
  final String? repeatDays;
  final int? repeatDayOfMonth;
  final DateTime repeatStart;
  final DateTime? repeatEnd;

  const SaveTaskSubmitted({
    this.taskId,
    required this.calendarId,
    required this.title,
    this.description,
    required this.tagIds,
    required this.repeatType,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.repeatStartTime,
    required this.repeatEndTime,
    this.repeatInterval,
    this.repeatDays,
    this.repeatDayOfMonth,
    required this.repeatStart,
    this.repeatEnd,
  });
}
