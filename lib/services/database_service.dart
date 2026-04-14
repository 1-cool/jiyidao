import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/code_item.dart';

/// 数据库服务
/// 
/// 负责取件码数据的持久化存储
class DatabaseService {
  static Database? _database;
  static const String _tableName = 'codes';

  /// 获取数据库实例
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 初始化数据库
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pincode.db');
    
    return await openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// 创建表
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL,
        type TEXT NOT NULL,
        source TEXT NOT NULL,
        location TEXT,
        createTime TEXT NOT NULL,
        rawMessage TEXT,
        isUsed INTEGER DEFAULT 0
      )
    ''');
    
    // 创建索引
    await db.execute('CREATE INDEX idx_isUsed ON $_tableName(isUsed)');
  }

  /// 数据库升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 版本1到版本2：移除 expireTime 字段
      // SQLite 不支持 DROP COLUMN，需要重建表
      await db.execute('BEGIN TRANSACTION');
      
      // 创建新表
      await db.execute('''
        CREATE TABLE ${_tableName}_new (
          id TEXT PRIMARY KEY,
          code TEXT NOT NULL,
          type TEXT NOT NULL,
          source TEXT NOT NULL,
          location TEXT,
          createTime TEXT NOT NULL,
          rawMessage TEXT,
          isUsed INTEGER DEFAULT 0
        )
      ''');
      
      // 迁移数据
      await db.execute('''
        INSERT INTO ${_tableName}_new (id, code, type, source, location, createTime, rawMessage, isUsed)
        SELECT id, code, type, source, location, createTime, rawMessage, isUsed
        FROM $_tableName
      ''');
      
      // 删除旧表
      await db.execute('DROP TABLE $_tableName');
      
      // 重命名新表
      await db.execute('ALTER TABLE ${_tableName}_new RENAME TO $_tableName');
      
      // 创建索引
      await db.execute('CREATE INDEX idx_isUsed ON $_tableName(isUsed)');
      
      await db.execute('COMMIT');
    }
  }

  /// 插入取件码
  Future<void> insertCode(CodeItem code) async {
    final db = await database;
    await db.insert(
      _tableName,
      code.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 获取所有未使用的取件码（按创建时间倒序）
  Future<List<CodeItem>> getActiveCodes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'isUsed = ?',
      whereArgs: [0],
      orderBy: 'createTime DESC',
    );
    return maps.map((map) => CodeItem.fromJson(map)).toList();
  }

  /// 获取所有取件码（包括已使用的）
  Future<List<CodeItem>> getAllCodes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      orderBy: 'createTime DESC',
    );
    return maps.map((map) => CodeItem.fromJson(map)).toList();
  }

  /// 标记为已使用
  Future<void> markAsUsed(String id) async {
    final db = await database;
    await db.update(
      _tableName,
      {'isUsed': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 删除取件码
  Future<void> deleteCode(String id) async {
    final db = await database;
    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 清理已使用的取件码
  Future<int> cleanUsedCodes() async {
    final db = await database;
    return await db.delete(
      _tableName,
      where: 'isUsed = ?',
      whereArgs: [1],
    );
  }

  /// 获取取件码数量
  Future<int> getCodeCount({bool? onlyActive}) async {
    final db = await database;
    if (onlyActive == true) {
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE isUsed = 0',
      );
      return Sqflite.firstIntValue(result) ?? 0;
    }
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 检查码是否已存在
  Future<bool> codeExists(String code) async {
    final db = await database;
    final result = await db.query(
      _tableName,
      where: 'code = ? AND isUsed = 0',
      whereArgs: [code],
    );
    return result.isNotEmpty;
  }
}
