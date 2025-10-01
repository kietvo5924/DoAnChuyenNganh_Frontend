import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseService {
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'myschedule.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      // Bật foreign key cho SQLite
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // Hàm được gọi khi database được tạo lần đầu tiên
  Future<void> _onCreate(Database db, int version) async {
    // Bảng lưu thông tin người dùng
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY,
        fullName TEXT NOT NULL,
        email TEXT NOT NULL
      )
    ''');

    // Bảng lưu các bộ lịch
    await db.execute('''
      CREATE TABLE calendars (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Bảng lưu các nhãn
    await db.execute('''
      CREATE TABLE tags (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        color TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Bảng lưu hàng đợi đồng bộ
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entity_type TEXT NOT NULL, 
        entity_id INTEGER NOT NULL, 
        action TEXT NOT NULL, 
        payload TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // -- PHẦN BỔ SUNG --

    // Bảng lưu công việc (hợp nhất)
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT,
        calendar_id INTEGER NOT NULL,
        repeat_type TEXT NOT NULL,
        start_time TEXT,
        end_time TEXT,
        is_all_day INTEGER,
        repeat_start_time TEXT,
        repeat_end_time TEXT,
        timezone TEXT,
        repeat_interval INTEGER,
        repeat_days TEXT,
        repeat_day_of_month INTEGER,
        repeat_week_of_month INTEGER,
        repeat_day_of_week INTEGER,
        repeat_start TEXT,
        repeat_end TEXT,
        exceptions TEXT,
        is_synced INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (calendar_id) REFERENCES calendars (id) ON DELETE CASCADE
      )
    ''');

    // Bảng nối giữa công việc và nhãn
    await db.execute('''
      CREATE TABLE task_tags_local (
        task_id INTEGER NOT NULL,
        tag_id INTEGER NOT NULL,
        PRIMARY KEY (task_id, tag_id),
        FOREIGN KEY (task_id) REFERENCES tasks (id) ON DELETE CASCADE,
        FOREIGN KEY (tag_id) REFERENCES tags (id) ON DELETE CASCADE
      )
    ''');
  }

  // Hàm tiện ích để xóa toàn bộ dữ liệu khi người dùng đăng xuất
  Future<void> clearAllTables() async {
    final db = await instance.database;
    // Xóa theo thứ tự ngược lại của quan hệ để đảm bảo an toàn
    await db.delete('task_tags_local');
    await db.delete('tasks');
    await db.delete('tags');
    await db.delete('calendars');
    await db.delete('user_profile');
    await db.delete('sync_queue');
    print("Local database cleared!");
  }
}
