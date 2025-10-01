import '../../../core/services/database_service.dart';
import '../models/user_model.dart';

abstract class UserLocalDataSource {
  Future<UserModel?> getUser();
  Future<void> cacheUser(UserModel user);
  Future<void> clearUser();
}

class UserLocalDataSourceImpl implements UserLocalDataSource {
  final DatabaseService dbService;
  UserLocalDataSourceImpl({required this.dbService});

  // Tên bảng để lưu thông tin người dùng
  final String _tableName = 'user_profile';

  @override
  Future<void> cacheUser(UserModel user) async {
    final db = await dbService.database;
    // Xóa người dùng cũ trước khi lưu người dùng mới
    await db.delete(_tableName);
    await db.insert(_tableName, {
      'id': user.id,
      'fullName': user.fullName,
      'email': user.email,
    });
  }

  @override
  Future<void> clearUser() async {
    final db = await dbService.database;
    await db.delete(_tableName);
  }

  @override
  Future<UserModel?> getUser() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return UserModel.fromDb(maps.first);
    }
    return null;
  }
}
