import 'package:flutter/foundation.dart';
import 'CRUDSQLiteProvider.dart';

class CRUD_Services_Provider extends ChangeNotifier {
  final CRUDSQLiteProvider _database;
  
  // Track operations state
  bool _isProcessing = false;
  String? _lastError;
  String? _lastOperation;
  
  // Statistics
  int _totalOperations = 0;
  Map<String, int> _operationCounts = {};

  // Constructor
  CRUD_Services_Provider(this._database);

  // Getters
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  String? get lastOperation => _lastOperation;
  int get totalOperations => _totalOperations;
  Map<String, int> get operationCounts => Map.unmodifiable(_operationCounts);
  bool get isDatabaseReady => _database.isInitialized;

  // Private methods
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ CRUD Service Error: $error');
    }
    notifyListeners();
  }

  void _setLastOperation(String operation) {
    _lastOperation = operation;
    _totalOperations++;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  // ========== TABLE MANAGEMENT SERVICES ==========
  
  /// สร้าง table ใหม่
  /// [tableName] ชื่อ table
  /// [schema] SQL schema สำหรับสร้าง table
  Future<bool> createTable(String tableName, String schema) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final success = await _database.createTable(tableName, schema);
      _setLastOperation('CREATE_TABLE');
      
      if (success) {
        debugPrint('✅ Table $tableName created successfully');
      } else {
        _setError('Failed to create table $tableName');
      }
      
      return success;
    } catch (e) {
      _setError('Error creating table $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ตรวจสอบว่า table มีอยู่หรือไม่
  /// [tableName] ชื่อ table ที่ต้องการตรวจสอบ
  Future<bool> doesTableExist(String tableName) async {
    _clearError();
    
    try {
      final exists = await _database.tableExists(tableName);
      _setLastOperation('CHECK_TABLE_EXISTS');
      return exists;
    } catch (e) {
      _setError('Error checking if table $tableName exists: $e');
      return false;
    }
  }

  /// ลบ table
  /// [tableName] ชื่อ table ที่ต้องการลบ
  Future<bool> dropTable(String tableName) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final success = await _database.dropTable(tableName);
      _setLastOperation('DROP_TABLE');
      
      if (success) {
        debugPrint('✅ Table $tableName dropped successfully');
      } else {
        _setError('Failed to drop table $tableName');
      }
      
      return success;
    } catch (e) {
      _setError('Error dropping table $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ========== CREATE SERVICES ==========
  
  /// เพิ่มข้อมูลเดี่ยวลงใน table
  /// [tableName] ชื่อ table
  /// [data] ข้อมูลที่ต้องการเพิ่ม
  Future<bool> insertRecord(String tableName, Map<String, dynamic> data) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final success = await _database.insert(tableName, data);
      _setLastOperation('INSERT');
      
      if (success) {
        debugPrint('✅ Record inserted into $tableName successfully');
      } else {
        _setError('Failed to insert record into $tableName');
      }
      
      return success;
    } catch (e) {
      _setError('Error inserting record into $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// เพิ่มข้อมูลหลายรายการลงใน table
  /// [tableName] ชื่อ table
  /// [dataList] รายการข้อมูลที่ต้องการเพิ่ม
  Future<bool> insertMultipleRecords(String tableName, List<Map<String, dynamic>> dataList) async {
    _clearError();
    _setProcessing(true);
    
    try {
      int successCount = 0;
      
      for (final data in dataList) {
        final success = await _database.insert(tableName, data);
        if (success) successCount++;
      }
      
      _setLastOperation('INSERT_MULTIPLE');
      
      if (successCount == dataList.length) {
        debugPrint('✅ All ${dataList.length} records inserted into $tableName successfully');
        return true;
      } else {
        _setError('Only $successCount out of ${dataList.length} records inserted into $tableName');
        return false;
      }
    } catch (e) {
      _setError('Error inserting multiple records into $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ========== READ SERVICES ==========
  
  /// อ่านข้อมูลทั้งหมดจาก table
  /// [tableName] ชื่อ table
  /// [orderBy] การเรียงลำดับ (เช่น 'id DESC')
  Future<List<Map<String, dynamic>>> getAllRecords(String tableName, {String? orderBy}) async {
    _clearError();
    
    try {
      final records = await _database.safeSelectAll(tableName, orderBy: orderBy);
      _setLastOperation('SELECT_ALL');
      
      debugPrint('✅ Retrieved ${records.length} records from $tableName');
      return records;
    } catch (e) {
      _setError('Error getting all records from $tableName: $e');
      return [];
    }
  }

  /// อ่านข้อมูลตามเงื่อนไข
  /// [tableName] ชื่อ table
  /// [where] เงื่อนไขการค้นหา (เช่น 'id = ?')
  /// [whereArgs] ค่าที่ใช้ในเงื่อนไข
  /// [orderBy] การเรียงลำดับ
  /// [limit] จำกัดจำนวนผลลัพธ์
  Future<List<Map<String, dynamic>>> getRecordsWhere(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    _clearError();
    
    try {
      final records = await _database.safeSelectWhere(
        tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy,
        limit: limit,
      );
      _setLastOperation('SELECT_WHERE');
      
      debugPrint('✅ Retrieved ${records.length} records from $tableName with condition');
      return records;
    } catch (e) {
      _setError('Error getting records from $tableName with condition: $e');
      return [];
    }
  }

  /// อ่านข้อมูลรายการเดียวตาม ID
  /// [tableName] ชื่อ table
  /// [id] ค่า ID ที่ต้องการค้นหา
  /// [idColumnName] ชื่อคอลัมน์ ID (default: 'id')
  Future<Map<String, dynamic>?> getRecordById(String tableName, dynamic id, {String idColumnName = 'id'}) async {
    _clearError();
    
    try {
      final records = await _database.safeSelectWhere(
        tableName,
        where: '$idColumnName = ?',
        whereArgs: [id],
        limit: 1,
      );
      _setLastOperation('SELECT_BY_ID');
      
      if (records.isNotEmpty) {
        debugPrint('✅ Retrieved record with $idColumnName=$id from $tableName');
        return records.first;
      } else {
        debugPrint('⚠️ No record found with $idColumnName=$id in $tableName');
        return null;
      }
    } catch (e) {
      _setError('Error getting record by ID from $tableName: $e');
      return null;
    }
  }

  /// นับจำนวนข้อมูลใน table
  /// [tableName] ชื่อ table
  /// [where] เงื่อนไขการนับ (optional)
  /// [whereArgs] ค่าที่ใช้ในเงื่อนไข
  Future<int> countRecords(String tableName, {String? where, List<dynamic>? whereArgs}) async {
    _clearError();
    
    try {
      final count = await _database.count(tableName, where: where, whereArgs: whereArgs);
      _setLastOperation('COUNT');
      
      debugPrint('✅ Counted $count records in $tableName');
      return count;
    } catch (e) {
      _setError('Error counting records in $tableName: $e');
      return 0;
    }
  }

  // ========== UPDATE SERVICES ==========
  
  /// อัพเดทข้อมูลตามเงื่อนไข
  /// [tableName] ชื่อ table
  /// [data] ข้อมูลใหม่ที่ต้องการอัพเดท
  /// [where] เงื่อนไขการอัพเดท
  /// [whereArgs] ค่าที่ใช้ในเงื่อนไข
  Future<bool> updateRecords(
    String tableName,
    Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final success = await _database.update(
        tableName,
        data,
        where: where,
        whereArgs: whereArgs,
      );
      _setLastOperation('UPDATE');
      
      if (success) {
        debugPrint('✅ Records updated in $tableName successfully');
      } else {
        _setError('Failed to update records in $tableName');
      }
      
      return success;
    } catch (e) {
      _setError('Error updating records in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// อัพเดทข้อมูลตาม ID
  /// [tableName] ชื่อ table
  /// [id] ค่า ID ที่ต้องการอัพเดท
  /// [data] ข้อมูลใหม่
  /// [idColumnName] ชื่อคอลัมน์ ID (default: 'id')
  Future<bool> updateRecordById(
    String tableName,
    dynamic id,
    Map<String, dynamic> data, {
    String idColumnName = 'id',
  }) async {
    return await updateRecords(
      tableName,
      data,
      where: '$idColumnName = ?',
      whereArgs: [id],
    );
  }

  // ========== DELETE SERVICES ==========
  
  /// ลบข้อมูลตามเงื่อนไข
  /// [tableName] ชื่อ table
  /// [where] เงื่อนไขการลบ
  /// [whereArgs] ค่าที่ใช้ในเงื่อนไข
  Future<bool> deleteRecords(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final success = await _database.delete(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );
      _setLastOperation('DELETE');
      
      if (success) {
        debugPrint('✅ Records deleted from $tableName successfully');
      } else {
        _setError('Failed to delete records from $tableName');
      }
      
      return success;
    } catch (e) {
      _setError('Error deleting records from $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ลบข้อมูลตาม ID
  /// [tableName] ชื่อ table
  /// [id] ค่า ID ที่ต้องการลบ
  /// [idColumnName] ชื่อคอลัมน์ ID (default: 'id')
  Future<bool> deleteRecordById(String tableName, dynamic id, {String idColumnName = 'id'}) async {
    return await deleteRecords(
      tableName,
      where: '$idColumnName = ?',
      whereArgs: [id],
    );
  }

  /// ลบข้อมูลทั้งหมดใน table
  /// [tableName] ชื่อ table
  Future<bool> deleteAllRecords(String tableName) async {
    return await deleteRecords(tableName);
  }

  // ========== ADVANCED SERVICES ==========
  
  /// ค้นหาข้อมูลแบบ LIKE
  /// [tableName] ชื่อ table
  /// [column] ชื่อคอลัมน์ที่ต้องการค้นหา
  /// [searchText] ข้อความที่ต้องการค้นหา
  /// [orderBy] การเรียงลำดับ
  Future<List<Map<String, dynamic>>> searchRecords(
    String tableName,
    String column,
    String searchText, {
    String? orderBy,
  }) async {
    return await getRecordsWhere(
      tableName,
      where: '$column LIKE ?',
      whereArgs: ['%$searchText%'],
      orderBy: orderBy,
    );
  }

  /// ค้นหาข้อมูลในหลายคอลัมน์
  /// [tableName] ชื่อ table
  /// [columns] รายการคอลัมน์ที่ต้องการค้นหา
  /// [searchText] ข้อความที่ต้องการค้นหา
  /// [orderBy] การเรียงลำดับ
  Future<List<Map<String, dynamic>>> searchMultipleColumns(
    String tableName,
    List<String> columns,
    String searchText, {
    String? orderBy,
  }) async {
    final whereConditions = columns.map((col) => '$col LIKE ?').join(' OR ');
    final whereArgs = List.filled(columns.length, '%$searchText%');
    
    return await getRecordsWhere(
      tableName,
      where: whereConditions,
      whereArgs: whereArgs,
      orderBy: orderBy,
    );
  }

  /// อัพเดทหรือสร้างใหม่ (Upsert)
  /// [tableName] ชื่อ table
  /// [data] ข้อมูล
  /// [uniqueColumn] คอลัมน์ที่ใช้ตรวจสอบ
  /// [uniqueValue] ค่าที่ใช้ตรวจสอบ
  Future<bool> upsertRecord(
    String tableName,
    Map<String, dynamic> data,
    String uniqueColumn,
    dynamic uniqueValue,
  ) async {
    final existing = await getRecordsWhere(
      tableName,
      where: '$uniqueColumn = ?',
      whereArgs: [uniqueValue],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      // Update existing record
      return await updateRecords(
        tableName,
        data,
        where: '$uniqueColumn = ?',
        whereArgs: [uniqueValue],
      );
    } else {
      // Insert new record
      return await insertRecord(tableName, data);
    }
  }

  /// รับข้อมูลแบบ pagination
  /// [tableName] ชื่อ table
  /// [page] หน้าที่ต้องการ (เริ่มจาก 0)
  /// [pageSize] จำนวนรายการต่อหน้า
  /// [orderBy] การเรียงลำดับ
  Future<List<Map<String, dynamic>>> getRecordsPaginated(
    String tableName,
    int page,
    int pageSize, {
    String? orderBy,
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final offset = page * pageSize;
    
    return await getRecordsWhere(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: pageSize,
    );
  }

  // ========== UTILITY SERVICES ==========
  
  /// รับรายชื่อ table ทั้งหมด
  Future<List<String>> getAllTableNames() async {
    _clearError();
    
    try {
      final tables = await _database.getAllTableNames();
      _setLastOperation('GET_ALL_TABLES');
      
      debugPrint('✅ Retrieved ${tables.length} table names');
      return tables;
    } catch (e) {
      _setError('Error getting table names: $e');
      return [];
    }
  }

  /// สำรองข้อมูลทั้งหมด
  Future<Map<String, List<Map<String, dynamic>>>> backupAllData() async {
    _clearError();
    _setProcessing(true);
    
    try {
      final backup = await _database.backupAllTables();
      _setLastOperation('BACKUP_ALL');
      
      debugPrint('✅ Backup completed for ${backup.length} tables');
      return backup;
    } catch (e) {
      _setError('Error creating backup: $e');
      return {};
    } finally {
      _setProcessing(false);
    }
  }

  /// ดำเนินการ SQL แบบ custom
  /// [sql] คำสั่ง SQL
  /// [arguments] arguments สำหรับ SQL
  Future<List<Map<String, dynamic>>> executeCustomQuery(String sql, [List<dynamic>? arguments]) async {
    _clearError();
    _setProcessing(true);
    
    try {
      final result = await _database.rawQuery(sql, arguments);
      _setLastOperation('CUSTOM_QUERY');
      
      debugPrint('✅ Custom query executed successfully');
      return result;
    } catch (e) {
      _setError('Error executing custom query: $e');
      return [];
    } finally {
      _setProcessing(false);
    }
  }

  /// ล้างสถิติการทำงาน
  void clearStatistics() {
    _totalOperations = 0;
    _operationCounts.clear();
    _lastError = null;
    _lastOperation = null;
    notifyListeners();
  }

  /// รับสถิติการทำงาน
  Map<String, dynamic> getStatistics() {
    return {
      'totalOperations': _totalOperations,
      'operationCounts': Map.from(_operationCounts),
      'lastError': _lastError,
      'lastOperation': _lastOperation,
      'isProcessing': _isProcessing,
      'isDatabaseReady': isDatabaseReady,
    };
  }
}