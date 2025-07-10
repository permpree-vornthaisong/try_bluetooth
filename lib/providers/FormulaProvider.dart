import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'GenericCRUDProvider.dart';

/// Provider สำหรับจัดการ Formula และ Database ของตัวเอง
class FormulaProvider extends ChangeNotifier {
  // ========== DEPENDENCY INJECTION ==========
  GenericCRUDProvider? _crudProvider;

  // ========== PRIVATE STATE VARIABLES ==========
  bool _isInitialized = false;
  String? _lastError;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _formulas = [];
  List<Map<String, dynamic>> _databaseTables = [];
  String _searchQuery = '';

  // ========== CONFIGURATION ==========
  final String _formulaTableName = 'formulas';
  final String _entityDisplayName = 'Formulas';

  // ========== DEFAULT CONSTRUCTOR ==========
  FormulaProvider() {
    debugPrint('🚀 [FormulaProvider] Created (not initialized yet)');
  }

  // ========== PUBLIC GETTERS ==========
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isProcessing => _isProcessing;
  List<Map<String, dynamic>> get formulas => _formulas;
  List<Map<String, dynamic>> get databaseTables => _databaseTables;
  String get searchQuery => _searchQuery;
  String get entityDisplayName => _entityDisplayName;

  // ========== INITIALIZATION ==========

  /// เริ่มต้น provider
  Future<void> initialize(BuildContext context) async {
    try {
      // ดึง GenericCRUDProvider จาก context
      _crudProvider = Provider.of<GenericCRUDProvider>(context, listen: false);

      debugPrint('⚙️ [FormulaProvider] Initializing...');

      // Initialize database
      await _initializeDatabase();
    } catch (e) {
      _setError('Initialization failed: $e');
      debugPrint('❌ [FormulaProvider] Initialization error: $e');
    }
  }

  /// เริ่มต้น database
  Future<void> _initializeDatabase() async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return;
    }

    try {
      _setProcessing(true);
      _clearError();

      debugPrint('🚀 [FormulaProvider] Initializing database...');

      // สร้าง formula table schema
      final formulaTable = TableSchema.createGenericTable(
        _formulaTableName,
        extraColumns: {
          'formula_name': 'TEXT NOT NULL',
          'column_count': 'INTEGER NOT NULL',
          'column_names': 'TEXT NOT NULL', // JSON string of column names
          'description': 'TEXT',
          'status': 'TEXT DEFAULT "active"',
        },
      );

      // เรียกใช้ GenericCRUDProvider เพื่อ initialize database
      await _crudProvider!.initializeDatabase(
        customDatabaseName: 'formula_app.db',
        customVersion: 1,
        initialTables: [formulaTable],
      );

      _isInitialized = true;
      debugPrint('✅ [FormulaProvider] Database initialized');

      // โหลดข้อมูลเริ่มต้น
      await _loadFormulas();
      await _loadDatabaseTables();
    } catch (e) {
      _setError('Database initialization failed: $e');
      debugPrint('❌ [FormulaProvider] Init failed: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// Retry initialization
  Future<void> retryInitialization(BuildContext context) async {
    _isInitialized = false;
    await initialize(context);
  }

  // ========== FORMULA OPERATIONS ==========

  /// โหลด formulas ทั้งหมด
  Future<void> _loadFormulas() async {
    if (_crudProvider == null || !_isInitialized) return;

    try {
      debugPrint('📖 [FormulaProvider] Loading formulas...');

      final formulasList = await _crudProvider!.readAll(
        _formulaTableName,
        orderBy: 'created_at DESC',
      );

      _formulas = formulasList;

      debugPrint('📊 [FormulaProvider] Loaded ${_formulas.length} formulas');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load formulas: $e');
      debugPrint('❌ [FormulaProvider] Load formulas error: $e');
    }
  }

  /// รีเฟรช formulas
  Future<void> refreshFormulas() async {
    if (_isProcessing) return;

    _setProcessing(true);
    _clearError();

    try {
      await _loadFormulas();
      await _loadDatabaseTables();
      debugPrint('🔄 [FormulaProvider] Formulas refreshed');
    } finally {
      _setProcessing(false);
    }
  }

  /// สร้าง formula ใหม่
  Future<bool> createFormula({
    required String formulaName,
    required int columnCount,
    required List<String> columnNames,
    String? description,
  }) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      // Validation
      if (formulaName.trim().isEmpty) {
        _setError('Formula name is required');
        return false;
      }

      if (columnCount <= 0 || columnCount > 20) {
        _setError('Column count must be between 1 and 20');
        return false;
      }

      if (columnNames.length != columnCount) {
        _setError('Column names count must match column count');
        return false;
      }

      // ตรวจสอบชื่อซ้ำ
      final existingFormula = await _crudProvider!.search(
        _formulaTableName,
        'formula_name',
        formulaName.trim(),
      );

      if (existingFormula.isNotEmpty) {
        _setError('Formula name already exists');
        return false;
      }

      debugPrint('📝 [FormulaProvider] Creating formula: $formulaName');

      // เตรียมข้อมูล
      final formulaData = {
        'formula_name': formulaName.trim(),
        'column_count': columnCount,
        'column_names': columnNames.join('|'), // ใช้ | เป็น separator
        'description': description?.trim() ?? '',
        'status': 'active',
      };

      // สร้าง formula record
      final formulaId = await _crudProvider!.create(_formulaTableName, formulaData);

      if (formulaId != null) {
        debugPrint('✅ [FormulaProvider] Formula created with ID: $formulaId');

        // สร้าง table สำหรับ formula นี้
        await _createFormulaTable(formulaName, columnNames);

        await _loadFormulas();
        await _loadDatabaseTables();
        return true;
      } else {
        _setError('Failed to create formula');
        return false;
      }
    } catch (e) {
      _setError('Create formula failed: $e');
      debugPrint('❌ [FormulaProvider] Create formula error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// สร้าง table สำหรับ formula
  Future<void> _createFormulaTable(String formulaName, List<String> columnNames) async {
    try {
      final tableName = 'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';

      // สร้าง schema สำหรับ formula table
      final Map<String, String> extraColumns = {};
      for (int i = 0; i < columnNames.length; i++) {
        final columnName = columnNames[i].toLowerCase().replaceAll(' ', '_');
        extraColumns[columnName] = 'TEXT';
      }

      final formulaTable = TableSchema.createGenericTable(
        tableName,
        extraColumns: extraColumns,
      );

      // สร้าง table ใน database
      await _crudProvider!.createTable(formulaTable);

      debugPrint('✅ [FormulaProvider] Formula table created: $tableName');
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Create formula table error: $e');
      // ไม่ throw error เพราะ formula record ถูกสร้างแล้ว
    }
  }

  /// ลบ formula
  Future<bool> deleteFormula(int formulaId, String formulaName) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      debugPrint('🗑️ [FormulaProvider] Deleting formula: $formulaName');

      // ลบ formula record
      final success = await _crudProvider!.deleteById(_formulaTableName, formulaId);

      if (success) {
        // ลบ table ที่เกี่ยวข้อง (optional - อาจจะเก็บไว้)
        try {
          final tableName = 'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';
          await _crudProvider!.dropTable(tableName);
          debugPrint('✅ [FormulaProvider] Formula table dropped: $tableName');
        } catch (e) {
          debugPrint('⚠️ [FormulaProvider] Could not drop formula table: $e');
        }

        debugPrint('✅ [FormulaProvider] Formula deleted');
        await _loadFormulas();
        await _loadDatabaseTables();
        return true;
      } else {
        _setError('Failed to delete formula');
        return false;
      }
    } catch (e) {
      _setError('Delete formula failed: $e');
      debugPrint('❌ [FormulaProvider] Delete formula error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  // ========== DATABASE OPERATIONS ==========

  /// โหลดรายการ tables ใน database
  Future<void> _loadDatabaseTables() async {
    if (_crudProvider == null || !_isInitialized) return;

    try {
      debugPrint('📖 [FormulaProvider] Loading database tables...');

      // ดึงรายชื่อ tables จาก database
      final tables = await _crudProvider!.getAllTableNames();

      _databaseTables = tables.map((tableName) => {
        'table_name': tableName,
        'is_formula_table': tableName.startsWith('formula_'),
        'record_count': 0, // จะได้ count จริงใน future
      }).toList();

      // นับจำนวน records ในแต่ละ table
      for (int i = 0; i < _databaseTables.length; i++) {
        try {
          final tableName = _databaseTables[i]['table_name'] as String;
          final count = await _crudProvider!.count(tableName);
          _databaseTables[i]['record_count'] = count;
        } catch (e) {
          debugPrint('⚠️ [FormulaProvider] Could not count records in ${_databaseTables[i]['table_name']}: $e');
          _databaseTables[i]['record_count'] = 0;
        }
      }

      debugPrint('📊 [FormulaProvider] Loaded ${_databaseTables.length} tables');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load database tables: $e');
      debugPrint('❌ [FormulaProvider] Load tables error: $e');
    }
  }

  /// ดึงข้อมูลจาก table
  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    if (_crudProvider == null) return [];

    try {
      debugPrint('📖 [FormulaProvider] Getting data from table: $tableName');

      final data = await _crudProvider!.readAll(
        tableName,
        orderBy: 'created_at DESC',
        limit: 100, // จำกัดไม่เกิน 100 records เพื่อป้องกัน performance issue
      );

      debugPrint('📊 [FormulaProvider] Retrieved ${data.length} records from $tableName');
      return data;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get table data error: $e');
      return [];
    }
  }

  /// ดึง table schema
  Future<List<String>> getTableColumns(String tableName) async {
    if (_crudProvider == null) return [];

    try {
      debugPrint('📖 [FormulaProvider] Getting columns for table: $tableName');

      final columns = await _crudProvider!.getTableColumns(tableName);

      debugPrint('📊 [FormulaProvider] Retrieved ${columns.length} columns from $tableName');
      return columns;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get table columns error: $e');
      return [];
    }
  }

  /// ตรวจสอบว่า table มีอยู่หรือไม่
  Future<bool> tableExists(String tableName) async {
    if (_crudProvider == null) return false;
    return await _crudProvider!.tableExists(tableName);
  }

  /// สร้าง table ใหม่
  Future<bool> createTable(TableSchema schema) async {
    if (_crudProvider == null) return false;
    return await _crudProvider!.createTable(schema);
  }

  /// สร้างข้อมูลใหม่ใน table
  Future<bool> createRecord({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    if (_crudProvider == null) return false;

    try {
      final recordId = await _crudProvider!.create(tableName, data);
      return recordId != null;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Create record error: $e');
      return false;
    }
  }

  /// อัพเดทข้อมูลใน table
  Future<bool> updateRecord({
    required String tableName,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    if (_crudProvider == null) return false;

    try {
      final success = await _crudProvider!.updateById(tableName, recordId, data);
      return success;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Update record error: $e');
      return false;
    }
  }

  /// ลบข้อมูลใน table
  Future<bool> deleteRecord({
    required String tableName,
    required int recordId,
  }) async {
    if (_crudProvider == null) return false;

    try {
      final success = await _crudProvider!.deleteById(tableName, recordId);
      return success;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Delete record error: $e');
      return false;
    }
  }

  /// ลบข้อมูลทั้งหมดใน table
  Future<bool> deleteAllRecords(String tableName) async {
    if (_crudProvider == null) return false;

    try {
      final success = await _crudProvider!.deleteAll(tableName);
      return success;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Delete all records error: $e');
      return false;
    }
  }

  // ========== DROPDOWN & LIST FUNCTIONS ==========

  /// ดึงรายชื่อ formulas ทั้งหมดสำหรับ dropdown
  List<String> getFormulaNames() {
    try {
      final names = _formulas.map((formula) => formula.formulaName).toList();
      debugPrint('📝 [FormulaProvider] Got ${names.length} formula names: $names');
      return names;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula names error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ formulas พร้อม ID สำหรับ dropdown ที่ต้องการ value
  List<Map<String, dynamic>> getFormulaDropdownItems() {
    try {
      final items = _formulas.map((formula) => {
        'id': formula.formulaId,
        'name': formula.formulaName,
        'value': formula.formulaName, // สำหรับ DropdownButton value
        'columnCount': formula.columnCount,
        'description': formula.description,
      }).toList();
      
      debugPrint('📝 [FormulaProvider] Got ${items.length} formula dropdown items');
      return items;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula dropdown items error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ tables ทั้งหมดสำหรับ dropdown
  List<String> getTableNames() {
    try {
      final names = _databaseTables
          .map((table) => table['table_name'] as String)
          .toList();
      debugPrint('📝 [FormulaProvider] Got ${names.length} table names: $names');
      return names;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get table names error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ formula tables เท่านั้นสำหรับ dropdown
  List<String> getFormulaTableNames() {
    try {
      final names = _databaseTables
          .where((table) => table['is_formula_table'] as bool)
          .map((table) => table['table_name'] as String)
          .toList();
      debugPrint('📝 [FormulaProvider] Got ${names.length} formula table names: $names');
      return names;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula table names error: $e');
      return [];
    }
  }

  /// ดึงรายชื่อ category tables เท่านั้นสำหรับ dropdown
  List<String> getCategoryTableNames() {
    try {
      final names = _databaseTables
          .where((table) => !(table['is_formula_table'] as bool) && 
                           table['table_name'] != 'android_metadata')
          .map((table) => table['table_name'] as String)
          .toList();
      debugPrint('📝 [FormulaProvider] Got ${names.length} category table names: $names');
      return names;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get category table names error: $e');
      return [];
    }
  }

  /// ค้นหา formula โดยชื่อ
  Map<String, dynamic>? getFormulaByName(String formulaName) {
    try {
      final formula = _formulas.firstWhere(
        (f) => f.formulaName == formulaName,
        orElse: () => {},
      );
      
      if (formula.isEmpty) {
        debugPrint('⚠️ [FormulaProvider] Formula "$formulaName" not found');
        return null;
      }
      
      debugPrint('✅ [FormulaProvider] Found formula: $formulaName');
      return formula;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula by name error: $e');
      return null;
    }
  }

  /// ค้นหา formula โดย ID
  Map<String, dynamic>? getFormulaById(int formulaId) {
    try {
      final formula = _formulas.firstWhere(
        (f) => f.formulaId == formulaId,
        orElse: () => {},
      );
      
      if (formula.isEmpty) {
        debugPrint('⚠️ [FormulaProvider] Formula with ID $formulaId not found');
        return null;
      }
      
      debugPrint('✅ [FormulaProvider] Found formula ID $formulaId: ${formula.formulaName}');
      return formula;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula by ID error: $e');
      return null;
    }
  }

  /// ดึงข้อมูลสถิติของ formulas สำหรับแสดงผล
  Map<String, dynamic> getFormulaStatistics() {
    try {
      final totalFormulas = _formulas.length;
      final activeFormulas = _formulas.where((f) => f.isActive).length;
      final totalTables = _databaseTables.length;
      final formulaTables = _databaseTables.where((t) => t['is_formula_table'] as bool).length;
      
      final stats = {
        'totalFormulas': totalFormulas,
        'activeFormulas': activeFormulas,
        'inactiveFormulas': totalFormulas - activeFormulas,
        'totalTables': totalTables,
        'formulaTables': formulaTables,
        'categoryTables': totalTables - formulaTables - 1, // -1 for android_metadata
        'hasData': totalFormulas > 0,
      };
      
      debugPrint('📊 [FormulaProvider] Formula statistics: $stats');
      return stats;
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Get formula statistics error: $e');
      return {
        'totalFormulas': 0,
        'activeFormulas': 0,
        'inactiveFormulas': 0,
        'totalTables': 0,
        'formulaTables': 0,
        'categoryTables': 0,
        'hasData': false,
      };
    }
  }

  // ========== DEBUG & UTILITY FUNCTIONS ==========

  /// พิมพ์ข้อมูลทุก table ใน formula_app.db
  Future<void> printAllTables() async {
    if (_crudProvider == null || !_isInitialized) {
      debugPrint('❌ [FormulaProvider] Database not initialized');
      return;
    }

    try {
      debugPrint('🔍 [FormulaProvider] === PRINTING ALL TABLES FROM formula_app.db ===');
      
      // ดึงรายชื่อ tables ทั้งหมด
      final tables = await _crudProvider!.getAllTableNames();
      
      debugPrint('📊 [FormulaProvider] Found ${tables.length} tables in database');
      debugPrint('');
      
      for (int i = 0; i < tables.length; i++) {
        final tableName = tables[i];
        
        debugPrint('🏷️ [${ i + 1}/${tables.length}] TABLE: $tableName');
        debugPrint('─' * 50);
        
        try {
          // ดึง schema ของ table
          final columns = await _crudProvider!.getTableColumns(tableName);
          debugPrint('📋 Columns (${columns.length}): ${columns.join(", ")}');
          
          // นับจำนวน records
          final recordCount = await _crudProvider!.count(tableName);
          debugPrint('📊 Record Count: $recordCount');
          
          if (recordCount > 0) {
            // ดึงข้อมูลตัวอย่าง (แค่ 5 records แรก)
            final sampleData = await _crudProvider!.readAll(
              tableName,
              limit: 5,
              orderBy: 'created_at DESC',
            );
            
            debugPrint('📝 Sample Data (first ${sampleData.length} records):');
            
            for (int j = 0; j < sampleData.length; j++) {
              final record = sampleData[j];
              debugPrint('   [${ j + 1}] ${_formatRecord(record, columns)}');
            }
            
            if (recordCount > 5) {
              debugPrint('   ... และอีก ${recordCount - 5} records');
            }
          } else {
            debugPrint('📝 No data in this table');
          }
          
        } catch (e) {
          debugPrint('❌ Error reading table $tableName: $e');
        }
        
        debugPrint(''); // บรรทัดว่าง
      }
      
      debugPrint('✅ [FormulaProvider] === FINISHED PRINTING ALL TABLES ===');
      
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Print all tables error: $e');
    }
  }

  /// จัดรูปแบบ record สำหรับการแสดงผล
  String _formatRecord(Map<String, dynamic> record, List<String> columns) {
    final parts = <String>[];
    
    for (final column in columns) {
      final value = record[column];
      String displayValue;
      
      if (value == null) {
        displayValue = 'NULL';
      } else if (value is String && value.length > 20) {
        displayValue = '"${value.substring(0, 17)}..."';
      } else if (value is String) {
        displayValue = '"$value"';
      } else {
        displayValue = value.toString();
      }
      
      parts.add('$column: $displayValue');
    }
    
    return '{${parts.join(", ")}}';
  }

  /// พิมพ์ข้อมูลเฉพาะ table ที่ระบุ
  Future<void> printSpecificTable(String tableName) async {
    if (_crudProvider == null || !_isInitialized) {
      debugPrint('❌ [FormulaProvider] Database not initialized');
      return;
    }

    try {
      debugPrint('🔍 [FormulaProvider] === PRINTING TABLE: $tableName ===');
      
      // ตรวจสอบว่า table มีอยู่หรือไม่
      final tableExists = await _crudProvider!.tableExists(tableName);
      if (!tableExists) {
        debugPrint('❌ Table "$tableName" does not exist');
        return;
      }
      
      // ดึง schema
      final columns = await _crudProvider!.getTableColumns(tableName);
      debugPrint('📋 Columns (${columns.length}): ${columns.join(", ")}');
      
      // นับจำนวน records
      final recordCount = await _crudProvider!.count(tableName);
      debugPrint('📊 Total Records: $recordCount');
      debugPrint('');
      
      if (recordCount > 0) {
        // ดึงข้อมูลทั้งหมด
        final allData = await _crudProvider!.readAll(
          tableName,
          orderBy: 'created_at DESC',
        );
        
        debugPrint('📝 All Records:');
        for (int i = 0; i < allData.length; i++) {
          final record = allData[i];
          debugPrint('   [${i + 1}] ${_formatRecord(record, columns)}');
        }
      } else {
        debugPrint('📝 No data in this table');
      }
      
      debugPrint('✅ [FormulaProvider] === FINISHED PRINTING TABLE ===');
      
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Print table error: $e');
    }
  }

  /// พิมพ์เฉพาะ formula tables
  Future<void> printFormulaTables() async {
    if (_crudProvider == null || !_isInitialized) {
      debugPrint('❌ [FormulaProvider] Database not initialized');
      return;
    }

    try {
      debugPrint('🔍 [FormulaProvider] === PRINTING FORMULA TABLES ONLY ===');
      
      final tables = await _crudProvider!.getAllTableNames();
      final formulaTables = tables.where((name) => name.startsWith('formula_')).toList();
      
      debugPrint('📊 Found ${formulaTables.length} formula tables');
      debugPrint('');
      
      for (final tableName in formulaTables) {
        await printSpecificTable(tableName);
        debugPrint(''); // บรรทัดว่าง
      }
      
      debugPrint('✅ [FormulaProvider] === FINISHED PRINTING FORMULA TABLES ===');
      
    } catch (e) {
      debugPrint('❌ [FormulaProvider] Print formula tables error: $e');
    }
  }

  // ========== SEARCH OPERATIONS ==========

  /// ค้นหา formulas
  Future<void> searchFormulas(String searchTerm) async {
    if (_crudProvider == null) return;

    try {
      _setProcessing(true);
      _clearError();

      _searchQuery = searchTerm;

      if (searchTerm.trim().isEmpty) {
        await _loadFormulas();
        return;
      }

      debugPrint('🔍 [FormulaProvider] Searching formulas: $searchTerm');

      final results = await _crudProvider!.search(
        _formulaTableName,
        'formula_name',
        searchTerm.trim(),
      );

      _formulas = results;
      debugPrint('📊 [FormulaProvider] Found ${_formulas.length} matching formulas');
      notifyListeners();
    } catch (e) {
      _setError('Search failed: $e');
      debugPrint('❌ [FormulaProvider] Search error: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// ล้างการค้นหา
  Future<void> clearSearch() async {
    _searchQuery = '';
    await _loadFormulas();
  }

  // ========== HELPER METHODS ==========

  /// ตั้งค่าสถานะ processing และแจ้ง listeners
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// ตั้งค่า error message และแจ้ง listeners
  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ [FormulaProvider] Error: $error');
    }
    notifyListeners();
  }

  /// ล้าง error message
  void _clearError() {
    _lastError = null;
  }

  // ========== LIFECYCLE MANAGEMENT ==========

  @override
  void dispose() {
    debugPrint('🧹 [FormulaProvider] Disposing FormulaProvider');
    _formulas.clear();
    _databaseTables.clear();
    super.dispose();
  }
}

// ========== EXTENSION METHODS ==========

/// Extension สำหรับ Formula data
extension FormulaExtension on Map<String, dynamic> {
  /// ดึงชื่อ formula
  String get formulaName => this['formula_name']?.toString() ?? 'Unknown';

  /// ดึง ID
  int get formulaId => this['id'] as int? ?? 0;

  /// ดึงจำนวน columns
  int get columnCount => this['column_count'] as int? ?? 0;

  /// ดึงรายชื่อ columns
  List<String> get columnNames {
    final namesString = this['column_names']?.toString() ?? '';
    if (namesString.isEmpty) return [];
    return namesString.split('|');
  }

  /// ดึงคำอธิบาย
  String get description => this['description']?.toString() ?? '';

  /// ดึงสถานะ
  String get status => this['status']?.toString() ?? 'unknown';

  /// ตรวจสอบว่าเป็น active หรือไม่
  bool get isActive => status.toLowerCase() == 'active';

  /// ดึงตัวอักษรแรกสำหรับ avatar
  String get initials {
    final name = formulaName;
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  /// ดึง table name ที่เกี่ยวข้อง
  String get tableName {
    return 'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';
  }
}