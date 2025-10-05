import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/tag_model.dart';

abstract class TagLocalDataSource {
  Future<List<TagModel>> getAllTags();
  Future<void> cacheTags(List<TagModel> tags);
  Future<void> saveTag(TagModel tag, {required bool isSynced}); // NEW
  Future<void> deleteTag(int tagId); // NEW
  Future<void> migrateTagId({required int fromId, required int toId}); // NEW
  Future<int> countTasksUsingTag(int tagId); // NEW
}

class TagLocalDataSourceImpl implements TagLocalDataSource {
  final DatabaseService dbService;
  final String _tableName = 'tags';

  TagLocalDataSourceImpl({required this.dbService});

  @override
  Future<List<TagModel>> getAllTags() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(_tableName);
    return List.generate(maps.length, (i) => TagModel.fromDb(maps[i]));
  }

  @override
  Future<void> cacheTags(List<TagModel> tags) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      for (final tag in tags) {
        // Safe upsert
        final updated = await txn.update(
          _tableName,
          {'name': tag.name, 'color': tag.color, 'is_synced': 1},
          where: 'id = ?',
          whereArgs: [tag.id],
        );
        if (updated == 0) {
          await txn.insert(_tableName, {
            'id': tag.id,
            'name': tag.name,
            'color': tag.color,
            'is_synced': 1,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }

        // NEW: auto-migrate temp negative tag(s) with same name (and optionally same color) to this real id
        final dupes = await txn.query(
          _tableName,
          where: 'id < 0 AND LOWER(name) = LOWER(?)',
          whereArgs: [tag.name],
        );
        for (final d in dupes) {
          final tempId = d['id'] as int;
          if (tempId == tag.id) continue;
          // Move mappings
          await txn.update(
            'task_tags_local',
            {'tag_id': tag.id},
            where: 'tag_id = ?',
            whereArgs: [tempId],
          );
          // Remove temp tag
          await txn.delete(_tableName, where: 'id = ?', whereArgs: [tempId]);
        }
      }
    });
  }

  @override
  Future<void> saveTag(TagModel tag, {required bool isSynced}) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      final updated = await txn.update(
        _tableName,
        {'name': tag.name, 'color': tag.color, 'is_synced': isSynced ? 1 : 0},
        where: 'id = ?',
        whereArgs: [tag.id],
      );
      if (updated == 0) {
        await txn.insert(_tableName, {
          'id': tag.id,
          'name': tag.name,
          'color': tag.color,
          'is_synced': isSynced ? 1 : 0,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  @override
  Future<void> deleteTag(int tagId) async {
    final db = await dbService.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [tagId]);
  }

  @override
  Future<void> migrateTagId({required int fromId, required int toId}) async {
    // NEW: update mappings and remove temp row
    final db = await dbService.database;
    await db.transaction((txn) async {
      // Ensure target tag exists to satisfy FK before switching mappings
      final hasTarget =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM $_tableName WHERE id = ?',
              [toId],
            ),
          ) ??
          0;
      if (hasTarget == 0) {
        // If not present, create a minimal row (name may be updated later by cacheTags)
        await txn.insert(_tableName, {
          'id': toId,
          'name': '',
          'color': null,
          'is_synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await txn.update(
        'task_tags_local',
        {'tag_id': toId},
        where: 'tag_id = ?',
        whereArgs: [fromId],
      );
      await txn.delete(_tableName, where: 'id = ?', whereArgs: [fromId]);
    });
  }

  @override
  Future<int> countTasksUsingTag(int tagId) async {
    // NEW
    final db = await dbService.database;
    final int cnt =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM task_tags_local WHERE tag_id = ?',
            [tagId],
          ),
        ) ??
        0;
    return cnt;
  }
}
