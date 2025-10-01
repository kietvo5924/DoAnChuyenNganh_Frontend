import 'package:flutter/material.dart';
import 'dart:convert'; // NEW
import '../../../domain/tag/entities/tag_entity.dart';
import '../../../domain/task/entities/task_entity.dart';
import '../../tag/models/tag_model.dart';

class TaskModel extends TaskEntity {
  const TaskModel({
    required int id,
    required String title,
    String? description,
    required int calendarId,
    required Set<TagEntity> tags,
    required RepeatType repeatType,
    // Task thường
    DateTime? startTime,
    DateTime? endTime,
    bool? isAllDay,
    // Recurring Task
    TimeOfDay? repeatStartTime,
    TimeOfDay? repeatEndTime,
    String? timezone,
    int? repeatInterval,
    String? repeatDays,
    int? repeatDayOfMonth,
    int? repeatWeekOfMonth,
    int? repeatDayOfWeek,
    DateTime? repeatStart,
    DateTime? repeatEnd,
    String? exceptions,
  }) : super(
         id: id,
         title: title,
         description: description,
         calendarId: calendarId,
         tags: tags,
         repeatType: repeatType,
         startTime: startTime,
         endTime: endTime,
         isAllDay: isAllDay,
         repeatStartTime: repeatStartTime,
         repeatEndTime: repeatEndTime,
         timezone: timezone,
         repeatInterval: repeatInterval,
         repeatDays: repeatDays,
         repeatDayOfMonth: repeatDayOfMonth,
         repeatWeekOfMonth: repeatWeekOfMonth,
         repeatDayOfWeek: repeatDayOfWeek,
         repeatStart: repeatStart,
         repeatEnd: repeatEnd,
         exceptions: exceptions,
       );

  static TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final parts = timeStr.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static RepeatType _parseRepeatType(String typeStr) {
    return RepeatType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => RepeatType.NONE,
    );
  }

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    // NEW: build tags from multiple possible formats
    Set<TagEntity> parsedTags = {};
    final rawTags = json['tags'];
    // Case 1: 'tags' là list object
    if (rawTags is List && rawTags.isNotEmpty) {
      parsedTags = rawTags
          .map((tagJson) {
            if (tagJson is Map) {
              final map = Map<String, dynamic>.from(tagJson as Map);
              // chấp nhận cả key 'tagId'
              final id = map['id'] ?? map['tagId'];
              if (id is int) {
                return TagModel.fromJson({
                  'id': id,
                  'name': map['name'] ?? '',
                  'color': map['color'],
                });
              }
            } else if (tagJson is int) {
              return TagEntity(id: tagJson, name: '');
            }
            return null;
          })
          .whereType<TagEntity>()
          .toSet();
    } else {
      // Case 2: 'tagIds' đủ kiểu
      final rawTagIds = json['tagIds'];
      List<int> ids = [];
      if (rawTagIds is List) {
        ids = rawTagIds.where((e) => e is int).cast<int>().toList();
      } else if (rawTagIds is String) {
        final s = rawTagIds.trim();
        if (s.startsWith('[') && s.endsWith(']')) {
          // JSON array string
          try {
            final decoded = jsonDecode(s);
            if (decoded is List) {
              ids = decoded.where((e) => e is int).cast<int>().toList();
            }
          } catch (_) {}
        }
        if (ids.isEmpty && s.contains(RegExp(r'[;,]'))) {
          ids = s
              .split(RegExp(r'[;,]'))
              .map((e) => int.tryParse(e.trim()))
              .whereType<int>()
              .toList();
        }
        if (ids.isEmpty && RegExp(r'^\d+$').hasMatch(s)) {
          // Chuỗi toàn số liền nhau, thử tách 2 ký tự
          if (s.length % 2 == 0) {
            for (var i = 0; i < s.length; i += 2) {
              final part = s.substring(i, i + 2);
              final v = int.tryParse(part);
              if (v != null) ids.add(v);
            }
          }
        }
      }
      if (ids.isNotEmpty) {
        parsedTags = ids.map((e) => TagEntity(id: e, name: '')).toSet();
      }
    }

    return TaskModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      repeatType: _parseRepeatType(json['repeatType']),
      calendarId: json['calendarId'] ?? 0,
      // Parse các trường cho task thường
      startTime: json['startTime'] != null
          ? DateTime.parse(json['startTime'])
          : null,
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      isAllDay: json['allDay'],
      // Parse các trường cho task lặp lại
      repeatStartTime: _parseTime(json['repeatStartTime']),
      repeatEndTime: _parseTime(json['repeatEndTime']),
      timezone: json['timezone'],
      repeatInterval: json['repeatInterval'],
      repeatDays: json['repeatDays'],
      repeatDayOfMonth: json['repeatDayOfMonth'],
      repeatWeekOfMonth: json['repeatWeekOfMonth'],
      repeatDayOfWeek: json['repeatDayOfWeek'],
      repeatStart: json['repeatStart'] != null
          ? DateTime.parse(json['repeatStart'])
          : null,
      repeatEnd: json['repeatEnd'] != null
          ? DateTime.parse(json['repeatEnd'])
          : null,
      exceptions: json['exceptions'],
      tags: parsedTags, // CHANGED
    );
  }

  factory TaskModel.fromDb(Map<String, dynamic> map, Set<TagEntity> tags) {
    return TaskModel(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      repeatType: _parseRepeatType(map['repeat_type']),
      calendarId: map['calendar_id'],
      // Trường cho task thường
      startTime: map['start_time'] != null
          ? DateTime.parse(map['start_time'])
          : null,
      endTime: map['end_time'] != null ? DateTime.parse(map['end_time']) : null,
      isAllDay: map['is_all_day'] == 1,
      // Trường cho task lặp lại
      repeatStartTime: _parseTime(map['repeat_start_time']),
      repeatEndTime: _parseTime(map['repeat_end_time']),
      timezone: map['timezone'],
      repeatInterval: map['repeat_interval'],
      repeatDays: map['repeat_days'],
      repeatDayOfMonth: map['repeat_day_of_month'],
      repeatWeekOfMonth: map['repeat_week_of_month'],
      repeatDayOfWeek: map['repeat_day_of_week'],
      repeatStart: map['repeat_start'] != null
          ? DateTime.parse(map['repeat_start'])
          : null,
      repeatEnd: map['repeat_end'] != null
          ? DateTime.parse(map['repeat_end'])
          : null,
      exceptions: map['exceptions'],
      tags: tags,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'calendar_id': calendarId,
      'repeat_type': repeatType.name,
      // Trường cho task thường
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'is_all_day': isAllDay == true ? 1 : 0,
      // Trường cho task lặp lại
      'repeat_start_time': repeatStartTime != null
          ? '${repeatStartTime!.hour}:${repeatStartTime!.minute}'
          : null,
      'repeat_end_time': repeatEndTime != null
          ? '${repeatEndTime!.hour}:${repeatEndTime!.minute}'
          : null,
      'timezone': timezone,
      'repeat_interval': repeatInterval,
      'repeat_days': repeatDays,
      'repeat_day_of_month': repeatDayOfMonth,
      'repeat_week_of_month': repeatWeekOfMonth,
      'repeat_day_of_week': repeatDayOfWeek,
      'repeat_start': repeatStart?.toIso8601String(),
      'repeat_end': repeatEnd?.toIso8601String(),
      'exceptions': exceptions,
      'is_synced': 1, // Mặc định là đã đồng bộ khi cache
    };
  }
}
