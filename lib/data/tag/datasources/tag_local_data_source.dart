import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/tag_model.dart';

abstract class TagLocalDataSource {
  Future<List<TagModel>> getAllTags();
  Future<void> cacheTags(List<TagModel> tags);
  Future<void> saveTag(TagModel tag, {required bool isSynced}); // NEW
  Future<void> deleteTag(int tagId); // NEW
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
        await txn.insert(_tableName, {
          'id': tag.id,
          'name': tag.name,
          'color': tag.color,
          'is_synced': 1,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      print(
        '[TagLocal] Upserted ${tags.length} remote tag(s) (preserve offline unsynced)',
      );
    });
  }

  @override
  Future<void> saveTag(TagModel tag, {required bool isSynced}) async {
    final db = await dbService.database;
    await db.insert(_tableName, {
      'id': tag.id,
      'name': tag.name,
      'color': tag.color,
      'is_synced': isSynced ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<void> deleteTag(int tagId) async {
    final db = await dbService.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [tagId]);
  }
}
