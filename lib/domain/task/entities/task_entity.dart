import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import '../../tag/entities/tag_entity.dart';

// Enum này khớp với backend, với NONE là task thường
enum RepeatType { NONE, DAILY, WEEKLY, MONTHLY, YEARLY }

class TaskEntity extends Equatable {
  final int id;
  final String title;
  final String? description;
  final Set<TagEntity> tags;
  final int calendarId;

  // --- Trường phân biệt ---
  final RepeatType repeatType;

  // --- Thuộc tính cho Task thường (khi repeatType == NONE) ---
  final DateTime? startTime;
  final DateTime? endTime;
  final bool? isAllDay;

  // --- Thuộc tính cho Recurring Task (khi repeatType != NONE) ---
  final TimeOfDay? repeatStartTime;
  final TimeOfDay? repeatEndTime;
  final String? timezone;
  final int? repeatInterval;
  final String? repeatDays;
  final int? repeatDayOfMonth;
  final int? repeatWeekOfMonth;
  final int? repeatDayOfWeek;
  final DateTime? repeatStart;
  final DateTime? repeatEnd;
  final String? exceptions;

  DateTime get sortDate {
    return startTime ?? repeatStart ?? DateTime.now();
  }

  const TaskEntity({
    required this.id,
    required this.title,
    this.description,
    required this.calendarId,
    required this.tags,
    required this.repeatType,
    // Task thường
    this.startTime,
    this.endTime,
    this.isAllDay,
    // Recurring Task
    this.repeatStartTime,
    this.repeatEndTime,
    this.timezone,
    this.repeatInterval,
    this.repeatDays,
    this.repeatDayOfMonth,
    this.repeatWeekOfMonth,
    this.repeatDayOfWeek,
    this.repeatStart,
    this.repeatEnd,
    this.exceptions,
  });

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    calendarId,
    tags,
    repeatType,
    startTime,
    endTime,
    isAllDay,
    repeatStartTime,
    repeatEndTime,
    timezone,
    repeatInterval,
    repeatDays,
    repeatDayOfMonth,
    repeatWeekOfMonth,
    repeatDayOfWeek,
    repeatStart,
    repeatEnd,
    exceptions,
  ];
}
