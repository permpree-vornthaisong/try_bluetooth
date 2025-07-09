import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'GenericCRUDProvider.dart';

/// Generic TestPageProvider - Compatible with ChangeNotifierProvider
/// สามารถใช้ได้กับทุกประเภทข้อมูล: คน, สัตว์, สิ่งของ, หรืออื่นๆ
class GenericTestPageProvider extends ChangeNotifier {
  // ========== DEPENDENCY INJECTION ==========
  GenericCRUDProvider? _crudProvider;

  // ========== CONFIGURATION ==========
  String _primaryTableName = 'records';
  String _entityDisplayName = 'Records';
  String _entitySingularName = 'Record';
  Map<String, String> _tableSchema = {};
  Map<String, String>? _defaultValues;

  // ========== PRIVATE STATE VARIABLES ==========
  bool _isInitialized = false;
  String? _lastError;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _records = [];
  String _searchQuery = '';
  String _currentTableName = '';

  // ========== DEFAULT CONSTRUCTOR (ไม่ต้องการ parameters) ==========
  GenericTestPageProvider() {
    // เริ่มต้นด้วยค่า default
    _currentTableName = _primaryTableName;
    debugPrint(
      '🚀 [Provider] GenericTestPageProvider created (not initialized yet)',
    );
  }

  // ========== CONFIGURATION METHODS ==========

  /// กำหนดค่า provider (เรียกหลังจากสร้าง instance แล้ว)
  Future<void> configure({
    required BuildContext context,
    required String primaryTableName,
    required String entityDisplayName,
    required String entitySingularName,
    required Map<String, String> tableSchema,
    Map<String, String>? defaultValues,
  }) async {
    try {
      // ดึง GenericCRUDProvider จาก context
      _crudProvider = Provider.of<GenericCRUDProvider>(context, listen: false);

      // กำหนดค่า configuration
      _primaryTableName = primaryTableName;
      _entityDisplayName = entityDisplayName;
      _entitySingularName = entitySingularName;
      _tableSchema = tableSchema;
      _defaultValues = defaultValues;
      _currentTableName = primaryTableName;

      debugPrint('⚙️ [Provider] Configured for $entityDisplayName');

      // Initialize database
      await _initializeDatabase();
    } catch (e) {
      _setError('Configuration failed: $e');
      debugPrint('❌ [Provider] Configuration error: $e');
    }
  }

  /// สร้างข้อมูลตัวอย่างหลายรายการ (Generic)
  Future<bool> createSampleRecords({
    required String tableName,
    required List<Map<String, dynamic>> sampleData,
  }) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    if (sampleData.isEmpty) {
      _setError('No sample data provided');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      debugPrint(
        '📝 [Provider] Creating ${sampleData.length} sample records in table: $tableName',
      );

      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < sampleData.length; i++) {
        final data = sampleData[i];

        try {
          // Validation
          if (!_validateRequiredFields(data)) {
            debugPrint(
              '⚠️ [Provider] Sample record ${i + 1} validation failed',
            );
            failCount++;
            continue;
          }

          // เพิ่ม default values ถ้ามี
          final finalData = {...data};
          if (_defaultValues != null) {
            for (final entry in _defaultValues!.entries) {
              if (!finalData.containsKey(entry.key)) {
                finalData[entry.key] = entry.value;
              }
            }
          }

          // เรียกใช้ GenericCRUDProvider สร้างข้อมูล
          final recordId = await _crudProvider!.create(tableName, finalData);

          if (recordId != null) {
            successCount++;
            debugPrint(
              '✅ [Provider] Sample record ${i + 1} created with ID: $recordId',
            );
          } else {
            failCount++;
            debugPrint('❌ [Provider] Sample record ${i + 1} failed to create');
          }
        } catch (e) {
          failCount++;
          debugPrint('❌ [Provider] Sample record ${i + 1} error: $e');
        }
      }

      debugPrint(
        '📊 [Provider] Sample creation completed: $successCount success, $failCount failed',
      );

      if (successCount > 0) {
        if (tableName == _currentTableName) {
          await _loadRecords(); // รีโหลดข้อมูลใหม่ถ้าเป็น table ปัจจุบัน
        }

        if (failCount > 0) {
          _setError('Created $successCount records, $failCount failed');
        }
        return true;
      } else {
        _setError('Failed to create any sample records in $tableName');
        return false;
      }
    } catch (e) {
      _setError('Create sample records failed in $tableName: $e');
      debugPrint('❌ [Provider] Create sample records error in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// กำหนดค่าสำหรับ Humans
  Future<void> configureForHumans(BuildContext context) async {
    await configure(
      context: context,
      primaryTableName: 'humans',
      entityDisplayName: 'Humans',
      entitySingularName: 'Human',
      tableSchema: {
        'name': 'TEXT NOT NULL',
        'email': 'TEXT UNIQUE',
        'age': 'INTEGER',
        'gender': 'TEXT',
        'height': 'REAL',
        'weight': 'REAL',
        'status': 'TEXT DEFAULT "active"',
      },
      defaultValues: {'status': 'active', 'gender': 'unknown'},
    );
  }

  /// กำหนดค่าสำหรับ Animals
  Future<void> configureForAnimals(BuildContext context) async {
    await configure(
      context: context,
      primaryTableName: 'animals',
      entityDisplayName: 'Animals',
      entitySingularName: 'Animal',
      tableSchema: {
        'species': 'TEXT NOT NULL',
        'breed': 'TEXT',
        'animal_id': 'TEXT UNIQUE',
        'name': 'TEXT',
        'age': 'INTEGER',
        'weight': 'REAL',
        'owner': 'TEXT',
        'vaccination_status': 'TEXT',
        'status': 'TEXT DEFAULT "healthy"',
      },
      defaultValues: {'status': 'healthy', 'vaccination_status': 'unknown'},
    );
  }

  /// กำหนดค่าสำหรับ Objects
  Future<void> configureForObjects(BuildContext context) async {
    await configure(
      context: context,
      primaryTableName: 'objects',
      entityDisplayName: 'Objects',
      entitySingularName: 'Object',
      tableSchema: {
        'object_name': 'TEXT NOT NULL',
        'category': 'TEXT',
        'barcode': 'TEXT UNIQUE',
        'weight': 'REAL',
        'material': 'TEXT',
        'color': 'TEXT',
        'manufacturer': 'TEXT',
        'batch_number': 'TEXT',
        'status': 'TEXT DEFAULT "active"',
      },
      defaultValues: {'status': 'active', 'category': 'general'},
    );
  }

  // ========== PUBLIC GETTERS ==========
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isProcessing => _isProcessing;
  List<Map<String, dynamic>> get records => _records;
  String get searchQuery => _searchQuery;
  String get currentTableName => _currentTableName;
  String get entityDisplayName => _entityDisplayName;
  String get entitySingularName => _entitySingularName;
  String get primaryTableName => _primaryTableName;
  Map<String, String> get tableSchema => _tableSchema;

  // ========== DATABASE INITIALIZATION ==========

  /// เริ่มต้น database
  Future<void> _initializeDatabase() async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return;
    }

    try {
      _setProcessing(true);
      _clearError();

      debugPrint(
        '🚀 [Provider] Initializing database for $_entityDisplayName...',
      );

      // สร้าง table schema
      final table = TableSchema.createGenericTable(
        _primaryTableName,
        extraColumns: _tableSchema,
      );

      // เรียกใช้ GenericCRUDProvider เพื่อ initialize database
      await _crudProvider!.initializeDatabase(
        customDatabaseName: 'generic_app.db',
        customVersion: 1,
        initialTables: [table],
      );

      _isInitialized = true;
      debugPrint('✅ [Provider] Database initialized for $_entityDisplayName');

      // โหลดข้อมูลเริ่มต้น
      await _loadRecords();
    } catch (e) {
      _setError('Database initialization failed: $e');
      debugPrint('❌ [Provider] Init failed: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// Retry initialization
  Future<void> retryInitialization() async {
    _isInitialized = false;
    await _initializeDatabase();
  }

  /// เปลี่ยน table ที่ใช้งาน
  Future<void> switchTable(String tableName) async {
    if (_currentTableName == tableName) return;

    _currentTableName = tableName;
    debugPrint('🔄 [Provider] Switched to table: $tableName');
    await _loadRecords();
  }

  // ========== DATA OPERATIONS ==========

  /// โหลดข้อมูลจาก table ปัจจุบัน
  Future<void> _loadRecords() async {
    if (_crudProvider == null || !_isInitialized) return;

    try {
      debugPrint('📖 [Provider] Loading records from $_currentTableName...');

      // เรียกใช้ GenericCRUDProvider อ่านข้อมูล
      final recordsList = await _crudProvider!.readAll(
        _currentTableName,
        orderBy: 'created_at DESC',
      );

      // อัพเดท internal state
      _records = recordsList;

      debugPrint(
        '📊 [Provider] Loaded ${_records.length} records from $_currentTableName',
      );

      // แจ้ง UI ว่าข้อมูลเปลี่ยน
      notifyListeners();
    } catch (e) {
      _setError('Failed to load records: $e');
      debugPrint('❌ [Provider] Load records error: $e');
    }
  }

  /// รีเฟรชข้อมูล
  Future<void> refreshRecords() async {
    if (_isProcessing) return; // ป้องกันการเรียกซ้ำ

    _setProcessing(true);
    _clearError();

    try {
      await _loadRecords();
      debugPrint('🔄 [Provider] Records refreshed');
    } finally {
      _setProcessing(false);
    }
  }

  /// สร้างข้อมูลใหม่ (Generic)
  Future<bool> createRecord({
    required String tableName,
    required Map<String, dynamic> data,
  }) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      // Validation
      if (!_validateRequiredFields(data)) {
        return false;
      }

      debugPrint('📝 [Provider] Creating record in table: $tableName');
      debugPrint('📝 [Provider] Record data: $data');

      // เพิ่ม default values ถ้ามี
      final finalData = {...data};
      if (_defaultValues != null) {
        for (final entry in _defaultValues!.entries) {
          if (!finalData.containsKey(entry.key)) {
            finalData[entry.key] = entry.value;
          }
        }
      }

      // เรียกใช้ GenericCRUDProvider สร้างข้อมูล
      final recordId = await _crudProvider!.create(tableName, finalData);

      if (recordId != null) {
        debugPrint(
          '✅ [Provider] Record created with ID: $recordId in table: $tableName',
        );
        if (tableName == _currentTableName) {
          await _loadRecords(); // รีโหลดข้อมูลใหม่ถ้าเป็น table ปัจจุบัน
        }
        return true;
      } else {
        _setError('Failed to create record in $tableName');
        return false;
      }
    } catch (e) {
      _setError('Create record failed in $tableName: $e');
      debugPrint('❌ [Provider] Create record error in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// อัพเดทข้อมูล (Generic)
  Future<bool> updateRecord({
    required String tableName,
    required int recordId,
    required Map<String, dynamic> data,
  }) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      // Validation
      if (!_validateUpdateData(data)) {
        return false;
      }

      debugPrint(
        '✏️ [Provider] Updating record ID: $recordId in table: $tableName',
      );

      // Clean และ prepare data
      final cleanData = _cleanUpdateData(data);

      final success = await _crudProvider!.updateById(
        tableName,
        recordId,
        cleanData,
      );

      if (success) {
        debugPrint('✅ [Provider] Record updated in table: $tableName');
        if (tableName == _currentTableName) {
          await _loadRecords(); // รีโหลดข้อมูลใหม่ถ้าเป็น table ปัจจุบัน
        }
        return true;
      } else {
        _setError('Failed to update record in $tableName');
        return false;
      }
    } catch (e) {
      _setError('Update record failed in $tableName: $e');
      debugPrint('❌ [Provider] Update record error in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ลบข้อมูล (Generic)
  Future<bool> deleteRecord({
    required String tableName,
    required int recordId,
  }) async {
    if (_crudProvider == null) {
      _setError('CrudProvider not configured');
      return false;
    }

    try {
      _setProcessing(true);
      _clearError();

      debugPrint(
        '🗑️ [Provider] Deleting record ID: $recordId from table: $tableName',
      );

      final success = await _crudProvider!.deleteById(tableName, recordId);

      if (success) {
        debugPrint('✅ [Provider] Record deleted from table: $tableName');
        if (tableName == _currentTableName) {
          await _loadRecords(); // รีโหลดข้อมูลใหม่ถ้าเป็น table ปัจจุบัน
        }
        return true;
      } else {
        _setError('Failed to delete record from $tableName');
        return false;
      }
    } catch (e) {
      _setError('Delete record failed from $tableName: $e');
      debugPrint('❌ [Provider] Delete record error from $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ค้นหาข้อมูล (Generic)
  Future<void> searchRecords({
    String? tableName,
    required String searchColumn,
    required String searchTerm,
  }) async {
    if (_crudProvider == null) return;

    try {
      _setProcessing(true);
      _clearError();

      final targetTable = tableName ?? _currentTableName;
      _searchQuery = searchTerm;

      if (searchTerm.trim().isEmpty) {
        await _loadRecords(); // โหลดข้อมูลทั้งหมด
        return;
      }

      debugPrint(
        '🔍 [Provider] Searching records in $targetTable: $searchTerm',
      );

      final results = await _crudProvider!.search(
        targetTable,
        searchColumn,
        searchTerm.trim(),
      );

      if (targetTable == _currentTableName) {
        _records = results;
        debugPrint('📊 [Provider] Found ${_records.length} matching records');
        notifyListeners();
      }
    } catch (e) {
      _setError('Search failed: $e');
      debugPrint('❌ [Provider] Search error: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// ล้างการค้นหา
  Future<void> clearSearch() async {
    _searchQuery = '';
    await _loadRecords();
  }

  /// ดึงสถิติข้อมูล (Generic)
  Future<Map<String, dynamic>> getRecordStatistics({String? tableName}) async {
    if (_crudProvider == null) {
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'tableName': tableName ?? _currentTableName,
      };
    }

    try {
      final targetTable = tableName ?? _currentTableName;
      final totalRecords = await _crudProvider!.count(targetTable);

      // พยายามนับตาม status ถ้ามี column นี้
      int activeRecords = 0;
      try {
        activeRecords = await _crudProvider!.count(
          targetTable,
          where: 'status = ?',
          whereArgs: ['active'],
        );
      } catch (e) {
        // ถ้าไม่มี status column ก็ไม่เป็นไร
        debugPrint('ℹ️ [Provider] No status column in $targetTable');
      }

      return {
        'total': totalRecords,
        'active': activeRecords,
        'inactive': totalRecords - activeRecords,
        'tableName': targetTable,
      };
    } catch (e) {
      debugPrint('❌ [Provider] Statistics error: $e');
      return {
        'total': 0,
        'active': 0,
        'inactive': 0,
        'tableName': tableName ?? _currentTableName,
      };
    }
  }

  // ========== VALIDATION HELPERS ==========

  /// ตรวจสอบ required fields
  bool _validateRequiredFields(Map<String, dynamic> data) {
    final requiredFields = _getRequiredFields();

    for (final field in requiredFields) {
      if (!data.containsKey(field) ||
          data[field] == null ||
          data[field].toString().trim().isEmpty) {
        _setError('$field is required');
        return false;
      }
    }

    return true;
  }

  /// ตรวจสอบข้อมูลสำหรับ update
  bool _validateUpdateData(Map<String, dynamic> data) {
    for (final entry in data.entries) {
      if (entry.value != null &&
          entry.value.toString().trim().isEmpty &&
          _getRequiredFields().contains(entry.key)) {
        _setError('${entry.key} cannot be empty');
        return false;
      }
    }

    return true;
  }

  /// ทำความสะอาดข้อมูลสำหรับ update
  Map<String, dynamic> _cleanUpdateData(Map<String, dynamic> data) {
    final cleanData = <String, dynamic>{};

    for (final entry in data.entries) {
      if (entry.value != null) {
        if (entry.value is String) {
          cleanData[entry.key] = entry.value.toString().trim();
        } else {
          cleanData[entry.key] = entry.value;
        }
      }
    }

    return cleanData;
  }

  /// ดึง required fields ตาม entity type
  List<String> _getRequiredFields() {
    if (_tableSchema.containsKey('name')) {
      return ['name'];
    } else if (_tableSchema.containsKey('species')) {
      return ['species'];
    } else if (_tableSchema.containsKey('object_name')) {
      return ['object_name'];
    }

    return []; // ไม่มี required fields
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
      debugPrint('❌ [Provider] Error: $error');
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
    debugPrint(
      '🧹 [Provider] Disposing GenericTestPageProvider for $_entityDisplayName',
    );
    _records.clear();
    super.dispose();
  }
}

// ========== SIMPLIFIED FACTORY PROVIDERS ==========

/// Provider สำหรับ Humans (ไม่ต้องการ parameters)
class HumanTestPageProvider extends GenericTestPageProvider {
  HumanTestPageProvider() : super();

  /// กำหนดค่าสำหรับ Humans (เรียกหลังจาก Provider ถูกสร้างแล้ว)
  Future<void> initialize(BuildContext context) async {
    await configureForHumans(context);
  }
}

/// Provider สำหรับ Animals (ไม่ต้องการ parameters)
class AnimalTestPageProvider extends GenericTestPageProvider {
  AnimalTestPageProvider() : super();

  /// กำหนดค่าสำหรับ Animals (เรียกหลังจาก Provider ถูกสร้างแล้ว)
  Future<void> initialize(BuildContext context) async {
    await configureForAnimals(context);
  }
}

/// Provider สำหรับ Objects (ไม่ต้องการ parameters)
class ObjectTestPageProvider extends GenericTestPageProvider {
  ObjectTestPageProvider() : super();

  /// กำหนดค่าสำหรับ Objects (เรียกหลังจาก Provider ถูกสร้างแล้ว)
  Future<void> initialize(BuildContext context) async {
    await configureForObjects(context);
  }
}

// ========== EXTENSION METHODS ==========

/// Extension สำหรับ Generic Record data
extension GenericRecordExtension on Map<String, dynamic> {
  /// ดึงชื่อ/ชื่อเต็ม
  String get displayName {
    if (containsKey('name')) return this['name']?.toString() ?? 'Unknown';
    if (containsKey('object_name'))
      return this['object_name']?.toString() ?? 'Unknown Object';
    if (containsKey('species'))
      return this['species']?.toString() ?? 'Unknown Species';
    return 'Unknown';
  }

  /// ดึง ID
  int get recordId => this['id'] as int? ?? 0;

  /// ดึงสถานะ
  String get status => this['status']?.toString() ?? 'unknown';

  /// ตรวจสอบว่าเป็น active หรือไม่
  bool get isActive => status.toLowerCase() == 'active';

  /// ดึงตัวอักษรแรกสำหรับ avatar
  String get initials {
    final name = displayName;
    if (name.isEmpty) return '?';

    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }

  /// ดึงข้อมูลแสดงรอง (subtitle)
  String get subtitle {
    final parts = <String>[];

    if (containsKey('email') && this['email'] != null) {
      parts.add(this['email'].toString());
    }
    if (containsKey('age') && this['age'] != null) {
      parts.add('Age: ${this['age']}');
    }
    if (containsKey('species') && this['species'] != null) {
      parts.add('Species: ${this['species']}');
    }
    if (containsKey('category') && this['category'] != null) {
      parts.add('Category: ${this['category']}');
    }

    return parts.join(' • ');
  }
}

/*
🎯 NOW COMPATIBLE WITH ChangeNotifierProvider!

✅ การใช้งานใน main.dart:
MultiProvider(
  providers: [
    ChangeNotifierProvider<GenericCRUDProvider>(
      create: (context) => GenericCRUDProvider(),
    ),
    ChangeNotifierProvider<GenericTestPageProvider>(
      create: (context) => GenericTestPageProvider(), // ✅ ไม่ต้องการ parameters!
    ),
    // หรือ
    ChangeNotifierProvider<HumanTestPageProvider>(
      create: (context) => HumanTestPageProvider(), // ✅ ไม่ต้องการ parameters!
    ),
  ],
  child: MyApp(),
)

✅ การใช้งานใน Widget:
class TestPage extends StatefulWidget {
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  @override
  void initState() {
    super.initState();
    
    // กำหนดค่าหลังจาก widget พร้อม
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GenericTestPageProvider>(context, listen: false);
      provider.configureForHumans(context); // หรือ configureForAnimals, configureForObjects
    });
  }
  
  // ... rest of widget
}

🔧 KEY CHANGES:
1. Constructor ไม่ต้องการ parameters
2. ใช้ configure() methods หลังจากสร้าง instance
3. _crudProvider เป็น nullable และดึงมาจาก context
4. Factory classes ที่ไม่ต้องการ parameters

🎉 ตอนนี้ใช้ ChangeNotifierProvider แบบง่ายได้แล้ว!
*/
