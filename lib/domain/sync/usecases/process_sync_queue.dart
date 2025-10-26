import 'dart:convert';
import 'package:dartz/dartz.dart';
import 'package:planmate_app/data/tag/models/tag_model.dart';
import '../../../core/error/failures.dart';
import '../../../data/sync/datasources/sync_queue_local_data_source.dart';
import '../../../data/task/datasources/task_remote_data_source.dart';
import '../../../data/task/datasources/task_local_data_source.dart'; // NEW
import '../../../data/calendar/datasources/calendar_remote_data_source.dart';
import '../../../data/calendar/datasources/calendar_local_data_source.dart';
import '../../../data/tag/datasources/tag_remote_data_source.dart';
import '../../../data/tag/datasources/tag_local_data_source.dart';

class ProcessSyncQueue {
  final SyncQueueLocalDataSource localDataSource;
  final TaskRemoteDataSource taskRemoteDataSource;
  final TaskLocalDataSource taskLocalDataSource; // NEW
  final CalendarRemoteDataSource calendarRemoteDataSource;
  final CalendarLocalDataSource calendarLocalDataSource;
  final TagRemoteDataSource tagRemoteDataSource;
  final TagLocalDataSource tagLocalDataSource;

  ProcessSyncQueue({
    required this.localDataSource,
    required this.taskRemoteDataSource,
    required this.taskLocalDataSource, // NEW
    required this.calendarRemoteDataSource,
    required this.calendarLocalDataSource,
    required this.tagRemoteDataSource,
    required this.tagLocalDataSource,
  });

  @override
  // ignore: override_on_non_overriding_member
  Future<Either<Failure, Unit>> call() async {
    // NEW: prune duplicates so only the latest action per key remains
    await localDataSource.pruneDuplicates();

    final actions = await localDataSource.getQueuedActions();
    if (actions.isEmpty) return Right(unit);
    print('Processing ${actions.length} actions in sync queue (phased)...');

    // NEW: determine final action per TAG (keep only the last one per entityId)
    final Map<int, String> tagFinalAction = {};
    for (final a in actions) {
      if (a.entityType == 'TAG') {
        tagFinalAction[a.entityId] = a.action; // created_at is ASC -> last wins
      }
    }
    // NEW: purge older TAG actions that are not the last one
    for (final a in actions) {
      if (a.entityType == 'TAG' && tagFinalAction[a.entityId] != a.action) {
        if (a.id != null) {
          await localDataSource.deleteQueuedAction(a.id!);
        }
      }
    }

    // PHÂN LOẠI (dedupe UPSERTs in-memory as extra safety)
    final calendarUpsertMap = <int, dynamic>{}; // key: entityId
    final calendarDeletes = <dynamic>[];
    final calendarSetDefault = <dynamic>[];
    final tagUpsertMap = <int, dynamic>{};
    final tagDeletes = <dynamic>[];
    final taskUpsertMap = <int, dynamic>{};
    final taskDeletes = <dynamic>[];

    for (final a in actions) {
      switch (a.entityType) {
        case 'CALENDAR':
          if (a.action == 'UPSERT') {
            // keep last occurrence
            calendarUpsertMap[a.entityId] = a;
          } else if (a.action == 'DELETE') {
            calendarDeletes.add(a);
          } else if (a.action == 'SET_DEFAULT') {
            calendarSetDefault.add(a);
          }
          break;
        case 'TAG':
          // CHANGED: only keep last action for each entityId
          if (tagFinalAction[a.entityId] == 'UPSERT' && a.action == 'UPSERT') {
            tagUpsertMap[a.entityId] = a;
          } else if (tagFinalAction[a.entityId] == 'DELETE' &&
              a.action == 'DELETE') {
            tagDeletes.add(a);
          }
          break;
        case 'TASK':
          if (a.action == 'UPSERT') {
            taskUpsertMap[a.entityId] = a;
          } else if (a.action == 'DELETE') {
            taskDeletes.add(a);
          }
          break;
      }
    }

    final calendarUpserts = calendarUpsertMap.values.toList();
    final tagUpserts = tagUpsertMap.values.toList();
    final taskUpserts = taskUpsertMap.values.toList();

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
          // NEW: persist real tag locally and migrate temp usages
          await tagLocalDataSource.saveTag(created, isSynced: true);
          await tagLocalDataSource.migrateTagId(
            fromId: a.entityId,
            toId: created.id,
          );
          print('[Queue] Created tag temp=${a.entityId} -> id=${created.id}');
        } else {
          await tagRemoteDataSource.updateTag(a.entityId, name, color);
          // NEW: also ensure local upsert (in case offline edits were pending)
          await tagLocalDataSource.saveTag(
            TagModel(id: a.entityId, name: name, color: color),
            isSynced: true,
          );
        }
        tagChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Tag UPSERT fail id=${a.entityId}: $e');
      }
    }

    // 4. TAG DELETE (only final deletes survive)
    for (final a in tagDeletes) {
      try {
        // Map temp id if it was created earlier in this run (rare, but safe)
        int toDeleteId = a.entityId;
        if (toDeleteId <= 0 && tagIdMap.containsKey(toDeleteId)) {
          toDeleteId = tagIdMap[toDeleteId]!;
        }
        if (toDeleteId > 0) {
          await tagRemoteDataSource.deleteTag(toDeleteId);
        }
        // Local row was already removed on user action; just clear queue item
        tagChanged = true;
        await localDataSource.deleteQueuedAction(a.id!);
      } catch (e) {
        print('[Queue] Tag DELETE fail id=${a.entityId}: $e');
      }
    }

    // 5. TASK UPSERT (deduped)
    for (final a in taskUpserts) {
      try {
        if (a.payload == null) {
          await localDataSource.deleteQueuedAction(a.id!);
          continue;
        }
        final data = jsonDecode(a.payload!) as Map<String, dynamic>;
        int calendarId = data['calendarId'] as int;
        final taskData = Map<String, dynamic>.from(data['taskData'] ?? {});
        // Map calendar if needed
        if (calendarId <= 0 && calendarIdMap.containsKey(calendarId)) {
          calendarId = calendarIdMap[calendarId]!;
        }
        // Map tagIds if needed
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

        // POST or PUT to server
        await taskRemoteDataSource.saveTask(
          calendarId: calendarId,
          taskId: isNew ? null : a.entityId,
          taskData: taskData,
        );

        // NEW: if this was created from a temp local task, remove temp to avoid duplicates
        if (isNew) {
          await taskLocalDataSource.deleteTask(a.entityId);
        }

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
