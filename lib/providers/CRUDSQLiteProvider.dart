import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CRUDSQLiteProvider extends ChangeNotifier {
  Database? _database;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Getters
  Database? get database => _database;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  // Constructor - สามารถ auto-init ได้
  CRUDSQLiteProvider({String? databaseName}) {
    if (databaseName != null) {
      initDatabase(databaseName);
    }
  }

  // Initialize database
  Future<void> initDatabase(String databaseName, {int version = 1}) async {
    if (_isInitialized) {
      debugPrint('Database already initialized');
      return;
    }

    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, '$databaseName.db');

      _database = await openDatabase(
        path,
        version: version,
        onCreate: (db, version) async {
          // Database will be created but tables need to be created separately
          debugPrint('Database $databaseName created with version $version');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('Database upgraded from $oldVersion to $newVersion');
        },
      );

      _isInitialized = true;
      debugPrint('✅ Database initialized: $databaseName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
    }
  }

  // Auto-initialize if not initialized
  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initDatabase('default_database');
    }
  }

  // Create table
  Future<bool> createTable(String tableName, String tableSchema) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      await _database!.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          $tableSchema
        )
      ''');
      debugPrint('Table $tableName created successfully');
      return true;
    } catch (e) {
      debugPrint('Error creating table $tableName: $e');
      return false;
    }
  }

  // Insert data
  Future<bool> insert(String tableName, Map<String, dynamic> data) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      await _database!.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _isLoading = false;
      notifyListeners();
      debugPrint('Data inserted into $tableName successfully');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error inserting data into $tableName: $e');
      return false;
    }
  }

  // Select all data
  Future<List<Map<String, dynamic>>> selectAll(String tableName, {String? orderBy}) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return [];
    }

    try {
      // ✅ ไม่เรียก notifyListeners() ใน select เพื่อหลีกเลี่ยง setState during build
      final List<Map<String, dynamic>> result = await _database!.query(
        tableName,
        orderBy: orderBy,
      );

      debugPrint('Selected ${result.length} records from $tableName');
      return result;
    } catch (e) {
      debugPrint('Error selecting data from $tableName: $e');
      return [];
    }
  }

  // Select data with condition
  Future<List<Map<String, dynamic>>> selectWhere(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return [];
    }

    try {
      // ✅ ไม่เรียก notifyListeners() ใน select
      final List<Map<String, dynamic>> result = await _database!.query(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );

      debugPrint('Selected ${result.length} records from $tableName with condition');
      return result;
    } catch (e) {
      debugPrint('Error selecting data from $tableName: $e');
      return [];
    }
  }

  // Update data
  Future<bool> update(
    String tableName,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final count = await _database!.update(
        tableName,
        data,
        where: where,
        whereArgs: whereArgs,
      );

      _isLoading = false;
      notifyListeners();
      debugPrint('Updated $count records in $tableName');
      return count > 0;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error updating data in $tableName: $e');
      return false;
    }
  }

  // Delete data
  Future<bool> delete(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final count = await _database!.delete(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );

      _isLoading = false;
      notifyListeners();
      debugPrint('Deleted $count records from $tableName');
      return count > 0;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error deleting data from $tableName: $e');
      return false;
    }
  }

  // Delete all data from table
  Future<bool> deleteAll(String tableName) async {
    return await delete(tableName);
  }

  // Count records
  Future<int> count(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return 0;
    }

    try {
      final result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName${where != null ? ' WHERE $where' : ''}',
        whereArgs,
      );
      return (result.first['count'] as int?) ?? 0;
    } catch (e) {
      debugPrint('Error counting records in $tableName: $e');
      return 0;
    }
  }

  // Check if table exists
  Future<bool> tableExists(String tableName) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName'",
      );
      return result.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if table $tableName exists: $e');
      return false;
    }
  }

  // Execute raw SQL
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return [];
    }

    try {
      _isLoading = true;
      notifyListeners();

      final result = await _database!.rawQuery(sql, arguments);

      _isLoading = false;
      notifyListeners();
      debugPrint('Raw query executed successfully');
      return result;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error executing raw query: $e');
      return [];
    }
  }

  // Execute raw SQL without return
  Future<bool> rawExecute(String sql, [List<dynamic>? arguments]) async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      await _database!.rawQuery(sql, arguments);
      debugPrint('Raw execute completed successfully');
      return true;
    } catch (e) {
      debugPrint('Error executing raw SQL: $e');
      return false;
    }
  }

  // Drop table
  Future<bool> dropTable(String tableName) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      await _database!.execute('DROP TABLE IF EXISTS $tableName');
      debugPrint('Table $tableName dropped successfully');
      return true;
    } catch (e) {
      debugPrint('Error dropping table $tableName: $e');
      return false;
    }
  }

  // Get all table names
  Future<List<String>> getAllTableNames() async {
    await _ensureInitialized();
    
    if (_database == null) {
      debugPrint('Database not initialized');
      return [];
    }

    try {
      final result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      return result.map((table) => table['name'] as String).toList();
    } catch (e) {
      debugPrint('Error getting table names: $e');
      return [];
    }
  }

  // Safe select all - ตรวจสอบ table ก่อน
  Future<List<Map<String, dynamic>>> safeSelectAll(String tableName, {String? orderBy}) async {
    await _ensureInitialized();
    
    // ✅ ตรวจสอบว่า table มีอยู่หรือไม่ก่อน
    final exists = await tableExists(tableName);
    if (!exists) {
      debugPrint('⚠️ Table $tableName does not exist');
      return [];
    }

    return await selectAll(tableName, orderBy: orderBy);
  }

  // Safe select with condition - ตรวจสอบ table ก่อน
  Future<List<Map<String, dynamic>>> safeSelectWhere(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    await _ensureInitialized();
    
    final exists = await tableExists(tableName);
    if (!exists) {
      debugPrint('⚠️ Table $tableName does not exist');
      return [];
    }

    return await selectWhere(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  // Backup data as Map
  Future<Map<String, List<Map<String, dynamic>>>> backupAllTables() async {
    final backup = <String, List<Map<String, dynamic>>>{};
    final tableNames = await getAllTableNames();

    for (final tableName in tableNames) {
      backup[tableName] = await selectAll(tableName);
    }

    debugPrint('Backup completed for ${tableNames.length} tables');
    return backup;
  }

  // Close database
  Future<void> closeDatabase() async {
    await _database?.close();
    _database = null;
    debugPrint('Database closed');
  }

  @override
  void dispose() {
    closeDatabase();
    super.dispose();
  }
}