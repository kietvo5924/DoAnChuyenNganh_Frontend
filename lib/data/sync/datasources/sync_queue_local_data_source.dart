import 'package:sqflite/sqflite.dart';
import '../../../core/services/database_service.dart';
import '../models/sync_queue_item_model.dart';

abstract class SyncQueueLocalDataSource {
  Future<void> addAction(SyncQueueItemModel item);
  Future<List<SyncQueueItemModel>> getQueuedActions();
  Future<void> deleteQueuedAction(int id);
  Future<void> pruneDuplicates(); // NEW
}

class SyncQueueLocalDataSourceImpl implements SyncQueueLocalDataSource {
  final DatabaseService dbService;
  final String _tableName = 'sync_queue';

  SyncQueueLocalDataSourceImpl({required this.dbService});

  @override
  Future<void> addAction(SyncQueueItemModel item) async {
    final db = await dbService.database;
    await db.transaction((txn) async {
      // NEW: idempotent insert by key (entity_type, entity_id, action)
      await txn.delete(
        _tableName,
        where: 'entity_type = ? AND entity_id = ? AND action = ?',
        whereArgs: [item.entityType, item.entityId, item.action],
      );
      await txn.insert(
        _tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> deleteQueuedAction(int id) async {
    final db = await dbService.database;
    await db.delete(_tableName, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<SyncQueueItemModel>> getQueuedActions() async {
    final db = await dbService.database;
    final maps = await db.query(_tableName, orderBy: 'created_at ASC, id ASC');
    return maps.map((map) => SyncQueueItemModel.fromMap(map)).toList();
  }

  @override
  Future<void> pruneDuplicates() async {
    final db = await dbService.database;
    // NEW: keep only the latest id per (entity_type, entity_id, action)
    await db.execute('''
      DELETE FROM $_tableName
      WHERE id NOT IN (
        SELECT MAX(id) FROM $_tableName
        GROUP BY entity_type, entity_id, action
      )
    ''');
  }
}
