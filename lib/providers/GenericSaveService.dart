import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'DisplayMainProvider.dart';
import 'CRUD_Services_Providers.dart';

/// Generic Save Service ที่สามารถใช้กับ table ต่างๆ ได้
class GenericSaveService extends ChangeNotifier {
  final CRUD_Services_Provider _crudServices;
  final DisplayMainProvider _displayProvider;

  // Status tracking
  bool _isProcessing = false;
  String? _lastError;
  DateTime? _lastSaveTime;

  // Constructor
  GenericSaveService(this._crudServices, this._displayProvider);

  // ========== GETTERS ==========
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  DateTime? get lastSaveTime => _lastSaveTime;

  // ========== GENERIC SAVE FUNCTIONS ==========

  /// Save weight data to any table
  /// [tableName] - ชื่อ table ที่ต้องการบันทึก
  /// [saveType] - ประเภทการบันทึก (auto, manual, animal, human, object)
  /// [customNotes] - หมายเหตุเพิ่มเติม
  /// [additionalData] - ข้อมูลเพิ่มเติมตาม table ที่เลือก
  Future<bool> saveWeightToTable({
    required String tableName,
    required String saveType,
    String? customNotes,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      _setProcessing(true);
      _clearError();

      debugPrint('💾 Starting save to table: $tableName');

      // ตรวจสอบว่า database และ table พร้อม
      if (!await _verifyDatabaseAndTable(tableName)) {
        return false;
      }

      // ดึงน้ำหนักปัจจุบัน
      final currentWeight = _displayProvider.netWeight;
      if (currentWeight == null || currentWeight <= 0) {
        _setError('No valid weight to save');
        return false;
      }

      // เตรียมข้อมูลพื้นฐาน
      final baseData = _prepareBaseWeightData(
        currentWeight,
        saveType,
        customNotes,
      );

      // รวมข้อมูลเพิ่มเติม (ถ้ามี)
      final finalData = {...baseData, ...?additionalData};

      debugPrint('📝 Save data prepared for $tableName: $finalData');

      // บันทึกลง database
      final success = await _crudServices.insertRecord(tableName, finalData);

      if (success) {
        _lastSaveTime = DateTime.now();
        debugPrint(
          '✅ Successfully saved to $tableName: ${currentWeight.toStringAsFixed(1)} kg',
        );
      }

      return success;
    } catch (e) {
      _setError('Save failed: $e');
      debugPrint('❌ Save error for $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// เตรียมข้อมูลพื้นฐานของน้ำหนัก (ใช้ร่วมกันทุก table)
  Map<String, dynamic> _prepareBaseWeightData(
    double weight,
    String saveType,
    String? notes,
  ) {
    return {
      'weight': weight,
      'raw_weight': _displayProvider.rawWeightWithoutTare ?? 0.0,
      'tare_offset': _displayProvider.tareOffset,
      'device_name': _displayProvider.deviceName,
      'timestamp': DateTime.now().toIso8601String(),
      'session_id': DateTime.now().millisecondsSinceEpoch,
      'notes': notes ?? 'Saved via $saveType',
      'save_type': saveType,
    };
  }

  /// ตรวจสอบ database และ table
  Future<bool> _verifyDatabaseAndTable(String tableName) async {
    if (!_crudServices.isDatabaseReady) {
      _setError('Database not ready');
      return false;
    }

    final tableExists = await _crudServices.doesTableExist(tableName);
    if (!tableExists) {
      _setError('Table $tableName does not exist');
      return false;
    }

    return true;
  }

  // ========== SPECIALIZED SAVE FUNCTIONS ==========

  /// บันทึกข้อมูลมนุษย์
  Future<bool> saveHumanWeight({
    String? name,
    int? age,
    String? gender,
    String? notes,
  }) async {
    final additionalData = <String, dynamic>{};

    if (name != null) additionalData['name'] = name;
    if (age != null) additionalData['age'] = age;
    if (gender != null) additionalData['gender'] = gender;

    return await saveWeightToTable(
      tableName: 'human_weights',
      saveType: 'human',
      customNotes: notes,
      additionalData: additionalData,
    );
  }

  /// บันทึกข้อมูลสัตว์
  Future<bool> saveAnimalWeight({
    String? species,
    String? breed,
    String? animalId,
    String? notes,
  }) async {
    final additionalData = <String, dynamic>{};

    if (species != null) additionalData['species'] = species;
    if (breed != null) additionalData['breed'] = breed;
    if (animalId != null) additionalData['animal_id'] = animalId;

    return await saveWeightToTable(
      tableName: 'animal_weights',
      saveType: 'animal',
      customNotes: notes,
      additionalData: additionalData,
    );
  }

  /// บันทึกข้อมูลวัตถุ
  Future<bool> saveObjectWeight({
    String? objectName,
    String? category,
    String? barcode,
    String? notes,
  }) async {
    final additionalData = <String, dynamic>{};

    if (objectName != null) additionalData['object_name'] = objectName;
    if (category != null) additionalData['category'] = category;
    if (barcode != null) additionalData['barcode'] = barcode;

    return await saveWeightToTable(
      tableName: 'object_weights',
      saveType: 'object',
      customNotes: notes,
      additionalData: additionalData,
    );
  }

  /// บันทึก Auto Save
  Future<bool> saveAutoWeight({String? notes}) async {
    return await saveWeightToTable(
      tableName: 'auto_saved_weights',
      saveType: 'auto',
      customNotes: notes ?? 'Auto saved weight',
    );
  }

  // ========== GENERIC DATA RETRIEVAL ==========

  /// ดึงข้อมูลจาก table ใดๆ
  Future<List<Map<String, dynamic>>> getRecordsFromTable({
    required String tableName,
    String? orderBy,
    String? where,
    List<dynamic>? whereArgs,
    int? limit,
  }) async {
    try {
      _clearError();

      if (where != null) {
        return await _crudServices.getRecordsWhere(
          tableName,
          where: where,
          whereArgs: whereArgs,
          orderBy: orderBy ?? 'timestamp DESC',
          limit: limit,
        );
      } else {
        return await _crudServices.getAllRecords(
          tableName,
          orderBy: orderBy ?? 'timestamp DESC',
        );
      }
    } catch (e) {
      _setError('Failed to load records from $tableName: $e');
      return [];
    }
  }

  /// ดึงข้อมูลวันนี้จาก table ใดๆ
  Future<List<Map<String, dynamic>>> getTodayRecordsFromTable(
    String tableName,
  ) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getRecordsFromTable(
      tableName: tableName,
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
  }

  /// ดึงข้อมูลตามประเภทจาก table ใดๆ
  Future<List<Map<String, dynamic>>> getRecordsByTypeFromTable({
    required String tableName,
    required String saveType,
  }) async {
    return await getRecordsFromTable(
      tableName: tableName,
      where: 'save_type = ?',
      whereArgs: [saveType],
    );
  }

  // ========== GENERIC DELETE FUNCTIONS ==========

  /// ลบข้อมูลจาก table ใดๆ
  Future<bool> deleteRecordFromTable({
    required String tableName,
    required int id,
  }) async {
    try {
      _clearError();
      return await _crudServices.deleteRecordById(tableName, id);
    } catch (e) {
      _setError('Failed to delete record from $tableName: $e');
      return false;
    }
  }

  /// ลบข้อมูลทั้งหมดจาก table ใดๆ
  Future<bool> deleteAllRecordsFromTable(String tableName) async {
    try {
      _clearError();
      return await _crudServices.deleteAllRecords(tableName);
    } catch (e) {
      _setError('Failed to delete all records from $tableName: $e');
      return false;
    }
  }

  // ========== TABLE MANAGEMENT ==========

  /// สร้าง table ใหม่ตาม schema ที่กำหนด
  Future<bool> createTableWithSchema({
    required String tableName,
    required Map<String, String> columns,
    List<String>? primaryKeys,
    Map<String, String>? defaultValues,
  }) async {
    try {
      _clearError();

      // สร้าง SQL schema
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

      final schema = columnDefinitions.join(', ');
      debugPrint('📋 Creating table $tableName with schema: $schema');

      return await _crudServices.createTable(tableName, schema);
    } catch (e) {
      _setError('Failed to create table $tableName: $e');
      return false;
    }
  }

  /// สร้าง table สำหรับน้ำหนักแต่ละประเภท
  Future<bool> createWeightTable({
    required String tableName,
    Map<String, String>? extraColumns,
  }) async {
    final baseColumns = {
      'id': 'INTEGER',
      'weight': 'REAL NOT NULL',
      'raw_weight': 'REAL',
      'tare_offset': 'REAL',
      'device_name': 'TEXT',
      'timestamp': 'TEXT NOT NULL',
      'session_id': 'INTEGER',
      'notes': 'TEXT',
      'save_type': 'TEXT',
      'created_at': 'DATETIME',
    };

    // รวม columns พิเศษ (ถ้ามี)
    final allColumns = {...baseColumns, ...?extraColumns};

    return await createTableWithSchema(
      tableName: tableName,
      columns: allColumns,
      primaryKeys: ['id'],
      defaultValues: {'save_type': "'auto'", 'created_at': 'CURRENT_TIMESTAMP'},
    );
  }

  // ========== UTILITY METHODS ==========

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ Generic Save Service Error: $error');
    }
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  /// ดึงสถิติการใช้งาน
  Future<Map<String, dynamic>> getTableStatistics(String tableName) async {
    try {
      final totalRecords = await _crudServices.countRecords(tableName);
      final todayRecords = await getTodayRecordsFromTable(tableName);

      return {
        'tableName': tableName,
        'totalRecords': totalRecords,
        'todayRecords': todayRecords.length,
        'lastSaveTime': _lastSaveTime?.toIso8601String(),
        'isProcessing': _isProcessing,
        'lastError': _lastError,
      };
    } catch (e) {
      return {'tableName': tableName, 'error': e.toString()};
    }
  }
}

// ========== USAGE EXAMPLES ==========

/// ตัวอย่างการใช้งานใน UI
class WeightSaveExamples {
  final GenericSaveService saveService;

  WeightSaveExamples(this.saveService);

  /// ตัวอย่างการบันทึกข้อมูลมนุษย์
  Future<void> saveHumanExample() async {
    final success = await saveService.saveHumanWeight(
      name: 'John Doe',
      age: 30,
      gender: 'Male',
      notes: 'Regular checkup',
    );

    if (success) {
      debugPrint('✅ Human weight saved successfully');
    } else {
      debugPrint('❌ Failed to save human weight: ${saveService.lastError}');
    }
  }

  /// ตัวอย่างการบันทึกข้อมูลสัตว์
  Future<void> saveAnimalExample() async {
    final success = await saveService.saveAnimalWeight(
      species: 'Dog',
      breed: 'Golden Retriever',
      animalId: 'DOG001',
      notes: 'Vaccination checkup',
    );

    if (success) {
      debugPrint('✅ Animal weight saved successfully');
    }
  }

  /// ตัวอย่างการบันทึกข้อมูลวัตถุ
  Future<void> saveObjectExample() async {
    final success = await saveService.saveObjectWeight(
      objectName: 'Package',
      category: 'Delivery',
      barcode: '1234567890',
      notes: 'Express delivery',
    );

    if (success) {
      debugPrint('✅ Object weight saved successfully');
    }
  }

  /// ตัวอย่างการบันทึกแบบ custom
  Future<void> saveCustomExample() async {
    final success = await saveService.saveWeightToTable(
      tableName: 'custom_weights',
      saveType: 'custom',
      customNotes: 'Custom measurement',
      additionalData: {
        'measurement_type': 'precision',
        'operator': 'Lab Tech',
        'lab_id': 'LAB001',
      },
    );

    if (success) {
      debugPrint('✅ Custom weight saved successfully');
    }
  }

  /// ตัวอย่างการดึงข้อมูล
  Future<void> loadDataExample() async {
    // ดึงข้อมูลทั้งหมดจาก table
    final allRecords = await saveService.getRecordsFromTable(
      tableName: 'human_weights',
    );

    // ดึงข้อมูลวันนี้
    final todayRecords = await saveService.getTodayRecordsFromTable(
      'human_weights',
    );

    // ดึงข้อมูลตามเงื่อนไข
    final maleRecords = await saveService.getRecordsFromTable(
      tableName: 'human_weights',
      where: 'gender = ?',
      whereArgs: ['Male'],
    );

    debugPrint('Total records: ${allRecords.length}');
    debugPrint('Today records: ${todayRecords.length}');
    debugPrint('Male records: ${maleRecords.length}');
  }

  /// สร้าง table ใหม่
  Future<void> createCustomTableExample() async {
    final success = await saveService.createWeightTable(
      tableName: 'lab_weights',
      extraColumns: {
        'lab_id': 'TEXT',
        'operator': 'TEXT',
        'equipment_id': 'TEXT',
        'temperature': 'REAL',
        'humidity': 'REAL',
      },
    );

    if (success) {
      debugPrint('✅ Lab weights table created successfully');
    }
  }
}
