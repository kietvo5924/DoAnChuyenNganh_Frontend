import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/sync_queue_item_model.dart';

abstract class SyncQueueLocalDataSource {
  Future<void> addAction(SyncQueueItemModel item);
  Future<List<SyncQueueItemModel>> getQueuedActions();
  Future<void> deleteQueuedAction(int id);
}

class SyncQueueLocalDataSourceImpl implements SyncQueueLocalDataSource {
  final DatabaseService dbService;
  final String _tableName = 'sync_queue';

  SyncQueueLocalDataSourceImpl({required this.dbService});

  @override
  Future<void> addAction(SyncQueueItemModel item) async {
    final db = await dbService.database;
    await db.insert(
      _tableName,
      item.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> deleteQueuedAction(int id) async {
    final db = await dbService.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<SyncQueueItemModel>> getQueuedActions() async {
    final db = await dbService.database;
    final maps = await db.query(_tableName, orderBy: 'created_at ASC');
    return maps.map((map) => SyncQueueItemModel.fromMap(map)).toList();
  }
}
