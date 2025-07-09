import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Generic CRUD Provider สำหรับจัดการ SQLite Database
/// สามารถใช้กับ table ใดๆ ได้โดยไม่ต้องเขียนโค้ดซ้ำ
class GenericCRUDProvider extends ChangeNotifier {
  // ========== DATABASE VARIABLES ==========
  Database? _database;
  String _databaseName = 'generic_app.db';
  int _databaseVersion = 1;

  // ========== STATUS TRACKING ==========
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _lastError;
  Map<String, List<Map<String, dynamic>>> _cachedData = {};

  // ========== GETTERS ==========
  Database? get database => _database;
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isDatabaseReady => _database != null && _isInitialized;

  // ========== DATABASE INITIALIZATION ==========

  /// เริ่มต้น database
  Future<bool> initializeDatabase({
    String? customDatabaseName,
    int? customVersion,
    List<TableSchema>? initialTables,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      if (customDatabaseName != null) _databaseName = customDatabaseName;
      if (customVersion != null) _databaseVersion = customVersion;

      debugPrint('🗄️ Initializing database: $_databaseName');

      final databasePath = await getDatabasesPath();
      final path = join(databasePath, _databaseName);

      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: (db, version) async {
          debugPrint('📋 Creating database tables...');

          // สร้าง tables ตามที่กำหนด
          if (initialTables != null) {
            for (final table in initialTables) {
              await _createTableFromSchema(db, table);
            }
          }
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint('⬆️ Upgrading database from $oldVersion to $newVersion');
          // จัดการ database upgrade ถ้าจำเป็น
        },
      );

      _isInitialized = true;
      debugPrint('✅ Database initialized successfully');
      return true;
    } catch (e) {
      _setError('Database initialization failed: $e');
      debugPrint('❌ Database initialization error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// สร้าง table จาก schema
  Future<void> _createTableFromSchema(Database db, TableSchema schema) async {
    try {
      final sql = schema.toCreateSQL();
      debugPrint('📋 Creating table: ${schema.tableName}');
      debugPrint('SQL: $sql');
      await db.execute(sql);
    } catch (e) {
      debugPrint('❌ Failed to create table ${schema.tableName}: $e');
      rethrow;
    }
  }

  // ========== GENERIC CRUD OPERATIONS ==========

  /// CREATE - เพิ่มข้อมูลใหม่
  Future<int?> create(String tableName, Map<String, dynamic> data) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return null;
      if (!await _verifyTable(tableName)) return null;

      debugPrint('➕ Creating record in $tableName: $data');

      // เพิ่ม timestamp ถ้ายังไม่มี
      if (!data.containsKey('created_at')) {
        data['created_at'] = DateTime.now().toIso8601String();
      }
      if (!data.containsKey('updated_at')) {
        data['updated_at'] = DateTime.now().toIso8601String();
      }

      final id = await _database!.insert(
        tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('✅ Created record with ID: $id');

      // อัพเดท cache
      _invalidateCache(tableName);

      notifyListeners();
      return id;
    } catch (e) {
      _setError('Create failed: $e');
      debugPrint('❌ Create error: $e');
      return null;
    }
  }

  /// READ - อ่านข้อมูลทั้งหมด
  Future<List<Map<String, dynamic>>> readAll(
    String tableName, {
    String? orderBy,
    int? limit,
    int? offset,
    bool useCache = true,
  }) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return [];
      if (!await _verifyTable(tableName)) return [];

      // ใช้ cache ถ้ามี
      final cacheKey =
          '${tableName}_all_${orderBy ?? ''}_${limit ?? ''}_${offset ?? ''}';
      if (useCache && _cachedData.containsKey(cacheKey)) {
        debugPrint('📦 Using cached data for $tableName');
        return _cachedData[cacheKey]!;
      }

      debugPrint('📖 Reading all records from $tableName');

      final List<Map<String, dynamic>> results = await _database!.query(
        tableName,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

      debugPrint('📊 Found ${results.length} records in $tableName');

      // เก็บใน cache
      if (useCache) {
        _cachedData[cacheKey] = results;
      }

      return results;
    } catch (e) {
      _setError('Read all failed: $e');
      debugPrint('❌ Read all error: $e');
      return [];
    }
  }

  /// READ - อ่านข้อมูลตาม ID
  Future<Map<String, dynamic>?> readById(String tableName, int id) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return null;
      if (!await _verifyTable(tableName)) return null;

      debugPrint('🔍 Reading record from $tableName with ID: $id');

      final List<Map<String, dynamic>> results = await _database!.query(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (results.isNotEmpty) {
        debugPrint('✅ Found record with ID: $id');
        return results.first;
      } else {
        debugPrint('ℹ️ No record found with ID: $id');
        return null;
      }
    } catch (e) {
      _setError('Read by ID failed: $e');
      debugPrint('❌ Read by ID error: $e');
      return null;
    }
  }

  /// READ - อ่านข้อมูลตามเงื่อนไข
  Future<List<Map<String, dynamic>>> readWhere(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return [];
      if (!await _verifyTable(tableName)) return [];

      debugPrint('🔍 Reading records from $tableName with condition: $where');

      final List<Map<String, dynamic>> results = await _database!.query(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );

      debugPrint('📊 Found ${results.length} records matching condition');
      return results;
    } catch (e) {
      _setError('Read where failed: $e');
      debugPrint('❌ Read where error: $e');
      return [];
    }
  }

  /// UPDATE - อัพเดทข้อมูลตาม ID
  Future<bool> updateById(
    String tableName,
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return false;
      if (!await _verifyTable(tableName)) return false;

      debugPrint('✏️ Updating record in $tableName with ID: $id');

      // เพิ่ม updated_at timestamp
      data['updated_at'] = DateTime.now().toIso8601String();

      final count = await _database!.update(
        tableName,
        data,
        where: 'id = ?',
        whereArgs: [id],
      );

      final success = count > 0;
      if (success) {
        debugPrint('✅ Updated $count record(s)');
        _invalidateCache(tableName);
        notifyListeners();
      } else {
        debugPrint('ℹ️ No records updated (ID may not exist)');
      }

      return success;
    } catch (e) {
      _setError('Update failed: $e');
      debugPrint('❌ Update error: $e');
      return false;
    }
  }

  /// UPDATE - อัพเดทข้อมูลตามเงื่อนไข
  Future<int> updateWhere(
    String tableName,
    Map<String, dynamic> data, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return 0;
      if (!await _verifyTable(tableName)) return 0;

      debugPrint('✏️ Updating records in $tableName with condition: $where');

      // เพิ่ม updated_at timestamp
      data['updated_at'] = DateTime.now().toIso8601String();

      final count = await _database!.update(
        tableName,
        data,
        where: where,
        whereArgs: whereArgs,
      );

      if (count > 0) {
        debugPrint('✅ Updated $count record(s)');
        _invalidateCache(tableName);
        notifyListeners();
      } else {
        debugPrint('ℹ️ No records updated');
      }

      return count;
    } catch (e) {
      _setError('Update where failed: $e');
      debugPrint('❌ Update where error: $e');
      return 0;
    }
  }

  /// DELETE - ลบข้อมูลตาม ID
  Future<bool> deleteById(String tableName, int id) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return false;
      if (!await _verifyTable(tableName)) return false;

      debugPrint('🗑️ Deleting record from $tableName with ID: $id');

      final count = await _database!.delete(
        tableName,
        where: 'id = ?',
        whereArgs: [id],
      );

      final success = count > 0;
      if (success) {
        debugPrint('✅ Deleted $count record(s)');
        _invalidateCache(tableName);
        notifyListeners();
      } else {
        debugPrint('ℹ️ No records deleted (ID may not exist)');
      }

      return success;
    } catch (e) {
      _setError('Delete failed: $e');
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  /// DELETE - ลบข้อมูลตามเงื่อนไข
  Future<int> deleteWhere(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return 0;
      if (!await _verifyTable(tableName)) return 0;

      debugPrint('🗑️ Deleting records from $tableName with condition: $where');

      final count = await _database!.delete(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );

      if (count > 0) {
        debugPrint('✅ Deleted $count record(s)');
        _invalidateCache(tableName);
        notifyListeners();
      } else {
        debugPrint('ℹ️ No records deleted');
      }

      return count;
    } catch (e) {
      _setError('Delete where failed: $e');
      debugPrint('❌ Delete where error: $e');
      return 0;
    }
  }

  /// DELETE - ลบข้อมูลทั้งหมดใน table
  Future<bool> deleteAll(String tableName) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return false;
      if (!await _verifyTable(tableName)) return false;

      debugPrint('🗑️ Deleting all records from $tableName');

      final count = await _database!.delete(tableName);

      debugPrint('✅ Deleted $count record(s) from $tableName');
      _invalidateCache(tableName);
      notifyListeners();

      return true;
    } catch (e) {
      _setError('Delete all failed: $e');
      debugPrint('❌ Delete all error: $e');
      return false;
    }
  }

  // ========== TABLE MANAGEMENT ==========

  /// สร้าง table ใหม่
  Future<bool> createTable(TableSchema schema) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return false;

      debugPrint('📋 Creating table: ${schema.tableName}');

      await _createTableFromSchema(_database!, schema);

      debugPrint('✅ Table ${schema.tableName} created successfully');
      return true;
    } catch (e) {
      _setError('Create table failed: $e');
      debugPrint('❌ Create table error: $e');
      return false;
    }
  }

  /// ตรวจสอบว่า table มีอยู่หรือไม่
  Future<bool> tableExists(String tableName) async {
    try {
      if (!_verifyDatabase()) return false;

      final List<Map<String, dynamic>> result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );

      return result.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Table exists check error: $e');
      return false;
    }
  }

  /// ลบ table
  Future<bool> dropTable(String tableName) async {
    try {
      _clearError();

      if (!_verifyDatabase()) return false;

      debugPrint('🗑️ Dropping table: $tableName');

      await _database!.execute('DROP TABLE IF EXISTS $tableName');

      _invalidateCache(tableName);
      debugPrint('✅ Table $tableName dropped successfully');
      return true;
    } catch (e) {
      _setError('Drop table failed: $e');
      debugPrint('❌ Drop table error: $e');
      return false;
    }
  }

  // ========== UTILITY METHODS ==========

  /// นับจำนวนข้อมูลใน table
  Future<int> count(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    try {
      if (!_verifyDatabase()) return 0;
      if (!await _verifyTable(tableName)) return 0;

      final List<Map<String, dynamic>> result = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $tableName ${where != null ? 'WHERE $where' : ''}',
        whereArgs,
      );

      return result.first['count'] as int;
    } catch (e) {
      debugPrint('❌ Count error: $e');
      return 0;
    }
  }

  /// ดึงข้อมูลแบบ pagination
  Future<PaginatedResult> paginate(
    String tableName, {
    int page = 1,
    int itemsPerPage = 10,
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    try {
      final offset = (page - 1) * itemsPerPage;

      // ดึงข้อมูลตาม page
      final data = await readWhere(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: itemsPerPage,
        offset: offset,
      );

      // นับจำนวนทั้งหมด
      final totalItems = await count(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );
      final totalPages = (totalItems / itemsPerPage).ceil();

      return PaginatedResult(
        data: data,
        currentPage: page,
        totalPages: totalPages,
        totalItems: totalItems,
        itemsPerPage: itemsPerPage,
        hasNextPage: page < totalPages,
        hasPreviousPage: page > 1,
      );
    } catch (e) {
      _setError('Pagination failed: $e');
      return PaginatedResult.empty();
    }
  }

  /// ดึงข้อมูลล่าสุด
  Future<List<Map<String, dynamic>>> getLatest(
    String tableName, {
    int limit = 10,
    String timestampColumn = 'created_at',
  }) async {
    return await readAll(
      tableName,
      orderBy: '$timestampColumn DESC',
      limit: limit,
    );
  }

  /// ค้นหาข้อมูล
  Future<List<Map<String, dynamic>>> search(
    String tableName,
    String searchColumn,
    String searchTerm, {
    String? orderBy,
    int? limit,
  }) async {
    return await readWhere(
      tableName,
      where: '$searchColumn LIKE ?',
      whereArgs: ['%$searchTerm%'],
      orderBy: orderBy,
      limit: limit,
    );
  }

  // ========== PRIVATE METHODS ==========

  bool _verifyDatabase() {
    if (_database == null || !_isInitialized) {
      _setError('Database not initialized');
      return false;
    }
    return true;
  }

  Future<bool> _verifyTable(String tableName) async {
    if (!await tableExists(tableName)) {
      _setError('Table $tableName does not exist');
      return false;
    }
    return true;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ GenericCRUDProvider Error: $error');
    }
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  void _invalidateCache(String tableName) {
    _cachedData.removeWhere((key, value) => key.startsWith(tableName));
  }

  /// ปิด database
  Future<void> closeDatabase() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        _isInitialized = false;
        _cachedData.clear();
        debugPrint('🔒 Database closed successfully');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Close database error: $e');
    }
  }

  // ========== DATABASE SCHEMA OPERATIONS (เพิ่มใหม่) ==========

  /// ดึงรายชื่อ tables ทั้งหมดใน database
  Future<List<String>> getAllTableNames() async {
    try {
      if (!_verifyDatabase()) return [];

      debugPrint('📋 Getting all table names from database');

      final List<Map<String, dynamic>> result = await _database!.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );

      final tableNames = result.map((row) => row['name'] as String).toList();

      debugPrint('📊 Found ${tableNames.length} tables: $tableNames');
      return tableNames;
    } catch (e) {
      _setError('Get table names failed: $e');
      debugPrint('❌ Get table names error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ columns ของ table
  Future<List<String>> getTableColumns(String tableName) async {
    try {
      if (!_verifyDatabase()) return [];
      if (!await _verifyTable(tableName)) return [];

      debugPrint('📋 Getting columns for table: $tableName');

      final List<Map<String, dynamic>> result = await _database!.rawQuery(
        "PRAGMA table_info($tableName)",
      );

      final columnNames = result.map((row) => row['name'] as String).toList();

      debugPrint(
        '📊 Found ${columnNames.length} columns in $tableName: $columnNames',
      );
      return columnNames;
    } catch (e) {
      _setError('Get table columns failed: $e');
      debugPrint('❌ Get table columns error: $e');
      return [];
    }
  }

  /// ดึงข้อมูล schema แบบละเอียดของ table
  Future<List<Map<String, dynamic>>> getTableSchema(String tableName) async {
    try {
      if (!_verifyDatabase()) return [];
      if (!await _verifyTable(tableName)) return [];

      debugPrint('📋 Getting detailed schema for table: $tableName');

      final List<Map<String, dynamic>> result = await _database!.rawQuery(
        "PRAGMA table_info($tableName)",
      );

      debugPrint(
        '📊 Retrieved schema for $tableName: ${result.length} columns',
      );
      return result;
    } catch (e) {
      _setError('Get table schema failed: $e');
      debugPrint('❌ Get table schema error: $e');
      return [];
    }
  }

  @override
  void dispose() {
    closeDatabase();
    super.dispose();
  }
}

// ========== HELPER CLASSES ==========

/// Schema สำหรับสร้าง table
class TableSchema {
  final String tableName;
  final Map<String, String> columns;
  final List<String>? primaryKeys;
  final Map<String, String>? defaultValues;
  final List<String>? indexes;

  TableSchema({
    required this.tableName,
    required this.columns,
    this.primaryKeys,
    this.defaultValues,
    this.indexes,
  });

  String toCreateSQL() {
    final columnDefinitions = <String>[];

    for (final entry in columns.entries) {
      final columnName = entry.key;
      final columnType = entry.value;
      final defaultValue = defaultValues?[columnName];

      String columnDef = '$columnName $columnType';

      if (primaryKeys?.contains(columnName) == true) {
        columnDef += ' PRIMARY KEY';
        if (columnName == 'id' && columnType.contains('INTEGER')) {
          columnDef += ' AUTOINCREMENT';
        }
      }

      if (defaultValue != null) {
        columnDef += ' DEFAULT $defaultValue';
      }

      columnDefinitions.add(columnDef);
    }

    return 'CREATE TABLE $tableName (${columnDefinitions.join(', ')})';
  }

  /// สร้าง schema สำหรับ table ทั่วไป
  static TableSchema createGenericTable(
    String tableName, {
    Map<String, String>? extraColumns,
  }) {
    final baseColumns = {
      'id': 'INTEGER',
      'created_at': 'TEXT',
      'updated_at': 'TEXT',
    };

    final allColumns = {...baseColumns, ...?extraColumns};

    return TableSchema(
      tableName: tableName,
      columns: allColumns,
      primaryKeys: ['id'],
      defaultValues: {
        'created_at': 'CURRENT_TIMESTAMP',
        'updated_at': 'CURRENT_TIMESTAMP',
      },
    );
  }
}

/// ผลลัพธ์แบบ pagination
class PaginatedResult {
  final List<Map<String, dynamic>> data;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;
  final bool hasNextPage;
  final bool hasPreviousPage;

  PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
    required this.hasNextPage,
    required this.hasPreviousPage,
  });

  factory PaginatedResult.empty() {
    return PaginatedResult(
      data: [],
      currentPage: 1,
      totalPages: 0,
      totalItems: 0,
      itemsPerPage: 10,
      hasNextPage: false,
      hasPreviousPage: false,
    );
  }
}

// ========== EXAMPLE USAGE ==========

/// ตัวอย่างการใช้งาน GenericCRUDProvider
class CRUDExamples {
  final GenericCRUDProvider crudProvider;

  CRUDExamples(this.crudProvider);

  /// ตัวอย่างการเริ่มต้น database พร้อม tables
  Future<void> initializeExample() async {
    final tables = [
      TableSchema.createGenericTable(
        'users',
        extraColumns: {
          'name': 'TEXT NOT NULL',
          'email': 'TEXT UNIQUE',
          'age': 'INTEGER',
        },
      ),
      TableSchema.createGenericTable(
        'products',
        extraColumns: {
          'name': 'TEXT NOT NULL',
          'price': 'REAL',
          'category': 'TEXT',
        },
      ),
    ];

    await crudProvider.initializeDatabase(
      customDatabaseName: 'my_app.db',
      customVersion: 1,
      initialTables: tables,
    );
  }

  /// ตัวอย่าง CRUD operations
  Future<void> crudExample() async {
    // CREATE
    final userId = await crudProvider.create('users', {
      'name': 'John Doe',
      'email': 'john@example.com',
      'age': 30,
    });

    // READ
    final user = await crudProvider.readById('users', userId!);
    final allUsers = await crudProvider.readAll('users');
    final youngUsers = await crudProvider.readWhere(
      'users',
      where: 'age < ?',
      whereArgs: [25],
    );

    // UPDATE
    await crudProvider.updateById('users', userId, {'age': 31});

    // DELETE
    await crudProvider.deleteById('users', userId);
  }
}
