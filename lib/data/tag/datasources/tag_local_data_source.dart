import '../../../core/services/database_service.dart';
import '../models/tag_model.dart';

abstract class TagLocalDataSource {
  Future<List<TagModel>> getAllTags();
  Future<void> cacheTags(List<TagModel> tags);
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
    final batch = db.batch();

    batch.delete(_tableName); // Xóa dữ liệu cũ

    for (final tag in tags) {
      batch.insert(_tableName, tag.toDbMap());
    }
    await batch.commit(noResult: true);
  }
}
