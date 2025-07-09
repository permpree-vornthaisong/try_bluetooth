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