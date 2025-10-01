import 'dart:convert';
import 'package:dartz/dartz.dart';
import '../../../core/error/failures.dart';
import '../../../data/sync/datasources/sync_queue_local_data_source.dart';
import '../../../data/task/datasources/task_remote_data_source.dart';
import '../../../data/calendar/datasources/calendar_remote_data_source.dart';
import '../../../data/calendar/datasources/calendar_local_data_source.dart';
import '../../../data/tag/datasources/tag_remote_data_source.dart';
import '../../../data/tag/datasources/tag_local_data_source.dart';

class ProcessSyncQueue {
  final SyncQueueLocalDataSource localDataSource;
  final TaskRemoteDataSource taskRemoteDataSource;
  final CalendarRemoteDataSource calendarRemoteDataSource;
  final CalendarLocalDataSource calendarLocalDataSource;
  final TagRemoteDataSource tagRemoteDataSource;
  final TagLocalDataSource tagLocalDataSource;

  ProcessSyncQueue({
    required this.localDataSource,
    required this.taskRemoteDataSource,
    required this.calendarRemoteDataSource,
    required this.calendarLocalDataSource,
    required this.tagRemoteDataSource,
    required this.tagLocalDataSource,
  });

  @override
  Future<Either<Failure, Unit>> call() async {
    final actions = await localDataSource.getQueuedActions();
    if (actions.isEmpty) return Right(unit);
    print('Processing ${actions.length} actions in sync queue (phased)...');

    // PHÂN LOẠI
    final calendarUpserts = <dynamic>[];
    final calendarDeletes = <dynamic>[];
    final calendarSetDefault = <dynamic>[];
    final tagUpserts = <dynamic>[];
    final tagDeletes = <dynamic>[];
    final taskUpserts = <dynamic>[];
    final taskDeletes = <dynamic>[];

    for (final a in actions) {
      switch (a.entityType) {
        case 'CALENDAR':
          if (a.action == 'UPSERT')
            calendarUpserts.add(a);
          else if (a.action == 'DELETE')
            calendarDeletes.add(a);
          else if (a.action == 'SET_DEFAULT')
            calendarSetDefault.add(a);
          break;
        case 'TAG':
          if (a.action == 'UPSERT')
            tagUpserts.add(a);
          else if (a.action == 'DELETE')
            tagDeletes.add(a);
          break;
        case 'TASK':
          if (a.action == 'UPSERT')
            taskUpserts.add(a);
          else if (a.action == 'DELETE')
            taskDeletes.add(a);
          break;
      }
    }

    final Map<int, int> calendarIdMap = {}; // tempId -> realId
    final Map<int, int> tagIdMap = {}; // tempId -> realId

    bool calendarChanged = false;
    bool tagChanged = false;

    // 1. CALENDAR UPSERT (tạo trước để task dùng id dương)
    for (final a in calendarUpserts) {
      try {
        final payload = a.payload != null
            ? jsonDecode(a.payload!) as Map<String, dynamic>
            : {};
        final name = payload['name'] as String? ?? 'NoName';
        final desc = payload['description'] as String?;
        final isDefault = payload['isDefault'] == true;
        if (a.entityId <= 0) {
          final created = await calendarRemoteDataSource.createCalendar(
            name,
            desc,
          );
          calendarIdMap[a.entityId] = created.id;
          if (isDefault) {
            await calendarRemoteDataSource.setDefaultCalendar(created.id);
          }
          print(
            '[Queue] Created calendar temp=${a.entityId} -> id=${created.id}',
          );
        } else {
          await calendarRemoteDataSource.updateCalendar(a.entityId, name, desc);
          if (isDefault) {
            await calendarRemoteDataSource.setDefaultCalendar(a.entityId);
          }
        }
        calendarChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Calendar UPSERT fail id=${a.entityId}: $e');
      }
    }

    // 2. CALENDAR DELETE & SET_DEFAULT (sau khi tạo)
    for (final a in calendarDeletes) {
      try {
        if (a.entityId > 0) {
          await calendarRemoteDataSource.deleteCalendar(a.entityId);
        }
        calendarChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Calendar DELETE fail id=${a.entityId}: $e');
      }
    }
    for (final a in calendarSetDefault) {
      try {
        if (a.entityId > 0) {
          await calendarRemoteDataSource.setDefaultCalendar(a.entityId);
          calendarChanged = true;
          await localDataSource.deleteQueuedAction(a.id!);
        } else {
          // Nếu temp id -> thử map
          final mapped = calendarIdMap[a.entityId];
          if (mapped != null) {
            await calendarRemoteDataSource.setDefaultCalendar(mapped);
            calendarChanged = true;
            await localDataSource.deleteQueuedAction(a.id!);
          }
        }
      } catch (e) {
        print('[Queue] Calendar SET_DEFAULT fail id=${a.entityId}: $e');
      }
    }

    // 3. TAG UPSERT (tạo trước để task dùng id dương)
    for (final a in tagUpserts) {
      try {
        final payload = a.payload != null
            ? jsonDecode(a.payload!) as Map<String, dynamic>
            : {};
        final name = payload['name'] as String? ?? 'NoName';
        final color = payload['color'] as String?;
        if (a.entityId <= 0) {
          final created = await tagRemoteDataSource.createTag(name, color);
          tagIdMap[a.entityId] = created.id;
          print('[Queue] Created tag temp=${a.entityId} -> id=${created.id}');
        } else {
          await tagRemoteDataSource.updateTag(a.entityId, name, color);
        }
        tagChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Tag UPSERT fail id=${a.entityId}: $e');
      }
    }

    // 4. TAG DELETE
    for (final a in tagDeletes) {
      try {
        if (a.entityId > 0) {
          await tagRemoteDataSource.deleteTag(a.entityId);
        }
        tagChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Tag DELETE fail id=${a.entityId}: $e');
      }
    }

    // 5. TASK UPSERT (sau khi có mapping calendar & tag)
    for (final a in taskUpserts) {
      try {
        if (a.payload == null) {
          await localDataSource.deleteQueuedAction(a.id!);
          continue;
        }
        final data = jsonDecode(a.payload!) as Map<String, dynamic>;
        int calendarId = data['calendarId'] as int;
        final taskData = Map<String, dynamic>.from(data['taskData'] ?? {});
        // Map calendar
        if (calendarId <= 0 && calendarIdMap.containsKey(calendarId)) {
          calendarId = calendarIdMap[calendarId]!;
        }
        // Map tagIds
        if (taskData['tagIds'] is List) {
          final List raw = taskData['tagIds'] as List;
          final mapped = raw
              .map((id) {
                if (id is int && id <= 0 && tagIdMap.containsKey(id)) {
                  return tagIdMap[id];
                }
                return id;
              })
              .toSet()
              .toList();
          taskData['tagIds'] = mapped;
        }
        final isNew = a.entityId <= 0;
        await taskRemoteDataSource.saveTask(
          calendarId: calendarId,
          taskId: isNew ? null : a.entityId,
          taskData: taskData,
        );
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Task UPSERT fail id=${a.entityId}: $e');
      }
    }

    // 6. TASK DELETE
    for (final a in taskDeletes) {
      try {
        // Thử xóa dạng SINGLE trước, nếu không được có thể backend cần type khác
        try {
          await taskRemoteDataSource.deleteTask(
            taskId: a.entityId,
            type: 'SINGLE',
          );
        } catch (_) {
          await taskRemoteDataSource.deleteTask(
            taskId: a.entityId,
            type: 'RECURRING',
          );
        }
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Task DELETE fail id=${a.entityId}: $e');
      }
    }

    // 7. REFRESH LOCAL (calendars / tags) nếu có thay đổi
    if (calendarChanged) {
      try {
        final remoteCalendars = await calendarRemoteDataSource
            .getAllCalendars();
        await calendarLocalDataSource.cacheCalendars(remoteCalendars);
      } catch (e) {
        print('[ProcessSyncQueue] refresh calendars failed: $e');
      }
    }
    if (tagChanged) {
      try {
        final remoteTags = await tagRemoteDataSource.getAllTags();
        await tagLocalDataSource.cacheTags(remoteTags);
      } catch (e) {
        print('[ProcessSyncQueue] refresh tags failed: $e');
      }
    }

    return Right(unit);
  }
}
