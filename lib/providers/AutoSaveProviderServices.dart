import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'DisplayMainProvider.dart';
import 'CRUD_Services_Providers.dart';

class AutoSaveProviderServices extends ChangeNotifier {
  final CRUD_Services_Provider _crudServices;
  final DisplayMainProvider _displayProvider;

  // Table configuration
  static const String _tableName = 'auto_saved_weights';

  // Updated table schema - consistent across all files
  static const String _tableSchema = '''
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    weight REAL NOT NULL,
    raw_weight REAL,
    tare_offset REAL,
    device_name TEXT,
    timestamp TEXT NOT NULL,
    auto_save_session INTEGER,
    notes TEXT,
    save_type TEXT DEFAULT 'auto',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  ''';

  // Auto Save State
  bool _isAutoSaveActive = false;
  double? _currentWeight;
  int _stableCount = 0;
  int _stableCountThreshold = 10;
  double _weightTolerance = 0.1;
  bool _waitingForZeroWeight = false;
  double _zeroWeightThreshold = 0.5;

  // Status tracking
  bool _isInitialized = false;
  String? _lastError;
  bool _isProcessing = false;
  DateTime? _lastSaveTime;
  int _totalAutoSaves = 0;
  int _totalManualSaves = 0;

  // Constructor
  AutoSaveProviderServices(this._crudServices, this._displayProvider) {
    debugPrint('🔧 AutoSaveProviderServices constructor called');

    // Initialize asynchronously to avoid blocking the constructor
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  // ========== GETTERS ==========

  bool get isAutoSaveActive => _isAutoSaveActive;
  bool get isInitialized => _isInitialized;
  bool get waitingForZeroWeight => _waitingForZeroWeight;
  bool get isProcessing => _isProcessing;
  String? get lastError => _lastError;
  DateTime? get lastSaveTime => _lastSaveTime;
  int get stableCount => _stableCount;
  int get stableCountThreshold => _stableCountThreshold;
  double get weightTolerance => _weightTolerance;
  double get zeroWeightThreshold => _zeroWeightThreshold;
  int get totalAutoSaves => _totalAutoSaves;
  int get totalManualSaves => _totalManualSaves;
  String get tableName => _tableName;

  // Current weight info
  double? get currentWeight => _displayProvider.netWeight;
  double? get rawWeight => _displayProvider.rawWeightWithoutTare;
  double get tareOffset => _displayProvider.tareOffset;
  String? get deviceName => _displayProvider.deviceName;
  String get formattedWeight => _displayProvider.formattedWeight;

  // ========== SETTERS ==========

  void setStableCountThreshold(int threshold) {
    if (threshold > 0) {
      _stableCountThreshold = threshold;
      notifyListeners();
    }
  }

  void setWeightTolerance(double tolerance) {
    if (tolerance >= 0) {
      _weightTolerance = tolerance;
      notifyListeners();
    }
  }

  void setZeroWeightThreshold(double threshold) {
    if (threshold >= 0) {
      _zeroWeightThreshold = threshold;
      notifyListeners();
    }
  }

  // ========== INITIALIZATION ==========

  Future<void> _initialize() async {
    try {
      _setProcessing(true);
      _clearError();

      debugPrint('🚀 Initializing AutoSaveProviderServices...');

      // Wait for CRUD services to be ready
      await _waitForDatabase();

      // Initialize table with enhanced error handling
      await _initializeTable();

      _isInitialized = true;
      debugPrint('✅ AutoSaveProviderServices initialized successfully');
    } catch (e) {
      _setError('Initialization failed: $e');
      debugPrint('❌ AutoSaveProviderServices initialization failed: $e');
    } finally {
      _setProcessing(false);
    }
  }

  Future<void> _waitForDatabase() async {
    int attempts = 0;
    const maxAttempts = 20;

    while (!_crudServices.isDatabaseReady && attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 500));
      attempts++;
      debugPrint('⏳ Waiting for database... attempt $attempts/$maxAttempts');
    }

    if (!_crudServices.isDatabaseReady) {
      throw Exception(
        'Database initialization timeout after $maxAttempts attempts',
      );
    }

    debugPrint('✅ Database is ready');
  }

  Future<void> _initializeTable() async {
    try {
      debugPrint('🔍 Checking if table $_tableName exists...');

      final tableExists = await _crudServices.doesTableExist(_tableName);
      debugPrint('📋 Table $_tableName exists: $tableExists');

      if (!tableExists) {
        debugPrint('🔨 Creating table $_tableName...');
        await _createTable();
      } else {
        // Check if existing table has all required columns
        debugPrint('🔍 Verifying table schema...');
        await _verifyAndUpdateTableSchema();
      }

      // Get all table names for debugging
      final allTables = await _crudServices.getAllTableNames();
      debugPrint('📋 All tables in database: $allTables');
    } catch (e) {
      throw Exception('Table initialization failed: $e');
    }
  }

  Future<void> _createTable() async {
    try {
      // Try custom query first
      final createTableSQL = '''
        CREATE TABLE IF NOT EXISTS $_tableName (
          $_tableSchema
        )
      ''';

      debugPrint('📝 Executing SQL: $createTableSQL');
      await _crudServices.executeCustomQuery(createTableSQL);

      // Verify table creation
      final verifyExists = await _crudServices.doesTableExist(_tableName);
      if (!verifyExists) {
        throw Exception('Table creation verification failed');
      }

      debugPrint('✅ Table $_tableName created successfully via custom query');
    } catch (e) {
      debugPrint('❌ Custom query failed, trying createTable method: $e');

      // Fallback to createTable method
      final success = await _crudServices.createTable(_tableName, _tableSchema);
      if (!success) {
        throw Exception('Failed to create table using createTable method');
      }

      debugPrint(
        '✅ Table $_tableName created successfully via createTable method',
      );
    }
  }

  Future<void> _verifyAndUpdateTableSchema() async {
    try {
      // Get table info to check columns
      final tableInfo = await _crudServices.executeCustomQuery(
        'PRAGMA table_info($_tableName)',
      );

      final existingColumns =
          tableInfo.map((col) => col['name'].toString()).toSet();
      debugPrint('📋 Existing columns: $existingColumns');

      // Check for missing columns
      final requiredColumns = {
        'id',
        'weight',
        'raw_weight',
        'tare_offset',
        'device_name',
        'timestamp',
        'auto_save_session',
        'notes',
        'save_type',
        'created_at',
      };

      final missingColumns = requiredColumns.difference(existingColumns);

      if (missingColumns.isNotEmpty) {
        debugPrint('⚠️ Missing columns detected: $missingColumns');
        await _addMissingColumns(missingColumns);
      } else {
        debugPrint('✅ All required columns exist');
      }
    } catch (e) {
      debugPrint('❌ Schema verification failed: $e');
      // If verification fails, try to recreate the table
      await _recreateTable();
    }
  }

  Future<void> _addMissingColumns(Set<String> missingColumns) async {
    try {
      for (final column in missingColumns) {
        String columnDef;
        switch (column) {
          case 'save_type':
            columnDef = 'TEXT DEFAULT \'auto\'';
            break;
          case 'created_at':
            columnDef = 'DATETIME DEFAULT CURRENT_TIMESTAMP';
            break;
          case 'raw_weight':
          case 'tare_offset':
            columnDef = 'REAL';
            break;
          case 'auto_save_session':
            columnDef = 'INTEGER';
            break;
          case 'device_name':
          case 'notes':
            columnDef = 'TEXT';
            break;
          default:
            continue; // Skip unknown columns
        }

        final alterSQL =
            'ALTER TABLE $_tableName ADD COLUMN $column $columnDef';
        debugPrint('📝 Adding column: $alterSQL');
        await _crudServices.executeCustomQuery(alterSQL);
      }

      debugPrint('✅ Missing columns added successfully');
    } catch (e) {
      debugPrint('❌ Failed to add missing columns: $e');
      throw Exception('Failed to update table schema: $e');
    }
  }

  Future<void> _recreateTable() async {
    try {
      debugPrint('🔄 Recreating table $_tableName...');

      // Backup existing data
      final existingData = await _crudServices.getAllRecords(_tableName);
      debugPrint('💾 Backing up ${existingData.length} existing records');

      // Drop existing table
      await _crudServices.dropTable(_tableName);

      // Create new table with correct schema
      await _createTable();

      // Restore data (with schema conversion if needed)
      if (existingData.isNotEmpty) {
        debugPrint(
          '🔄 Restoring ${existingData.length} records with new schema',
        );

        for (final record in existingData) {
          // Ensure all required fields exist with defaults
          final convertedRecord = {
            'weight': record['weight'] ?? 0.0,
            'raw_weight': record['raw_weight'] ?? record['weight'] ?? 0.0,
            'tare_offset': record['tare_offset'] ?? 0.0,
            'device_name': record['device_name'] ?? 'Unknown',
            'timestamp':
                record['timestamp'] ?? DateTime.now().toIso8601String(),
            'auto_save_session':
                record['auto_save_session'] ??
                DateTime.now().millisecondsSinceEpoch,
            'notes': record['notes'] ?? 'Migrated record',
            'save_type': record['save_type'] ?? 'auto',
          };

          await _crudServices.insertRecord(_tableName, convertedRecord);
        }

        debugPrint('✅ Data migration completed successfully');
      }
    } catch (e) {
      throw Exception('Table recreation failed: $e');
    }
  }

  // ========== AUTO SAVE CONTROL ==========

  void startAutoSave() {
    if (!_isInitialized) {
      _setError('Service not initialized');
      return;
    }

    _isAutoSaveActive = true;
    _clearError();
    _monitorWeightChanges();
    notifyListeners();
    debugPrint('✅ Auto save monitoring started');
  }

  void stopAutoSave() {
    _isAutoSaveActive = false;
    _resetStableTracking();
    notifyListeners();
    debugPrint('⏹️ Auto save monitoring stopped');
  }

  void toggleAutoSave() {
    if (_isAutoSaveActive) {
      stopAutoSave();
    } else {
      startAutoSave();
    }
  }

  // ========== WEIGHT MONITORING ==========

  void _monitorWeightChanges() {
    if (!_isAutoSaveActive) return;

    try {
      final currentWeight = _displayProvider.netWeight;

      if (currentWeight != null) {
        if (currentWeight <= _zeroWeightThreshold) {
          // Weight is zero - ready for next save
          if (_waitingForZeroWeight) {
            _waitingForZeroWeight = false;
            notifyListeners();
            debugPrint('✅ Weight returned to zero, ready for next auto save');
          }
          // Only reset tracking if we were previously tracking a weight
          if (_currentWeight != null) {
            _resetStableTracking();
          }
        } else if (!_waitingForZeroWeight && currentWeight > 0) {
          // Has weight and not waiting - check stability
          if (_isWeightStable(currentWeight)) {
            _stableCount++;
            notifyListeners();

            if (_stableCount >= _stableCountThreshold) {
              _triggerAutoSave(currentWeight);
            }
          } else {
            _currentWeight = currentWeight;
            _stableCount = 1;
            notifyListeners();
          }
        } else if (_waitingForZeroWeight) {
          // Waiting for zero weight
          debugPrint(
            '⏳ Waiting for weight to return to zero... Current: ${currentWeight.toStringAsFixed(1)} kg',
          );
        }
      } else {
        _resetStableTracking();
      }
    } catch (e) {
      debugPrint('❌ Error monitoring weight: $e');
      _setError('Weight monitoring error: $e');
    }

    // Continue monitoring
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_isAutoSaveActive) {
        _monitorWeightChanges();
      }
    });
  }

  bool _isWeightStable(double newWeight) {
    if (_currentWeight == null) {
      _currentWeight = newWeight;
      return true;
    }

    final difference = (newWeight - _currentWeight!).abs();
    return difference <= _weightTolerance;
  }

  void _resetStableTracking() {
    _currentWeight = null;
    _stableCount = 0;
    notifyListeners();
  }

  // ========== SAVE OPERATIONS ==========

  /// Auto save when weight is stable
  Future<bool> _triggerAutoSave(double stableWeight) async {
    try {
      _setProcessing(true);
      _clearError();

      // Verify database and table
      if (!await _verifyDatabaseAndTable()) {
        return false;
      }

      debugPrint(
        '💾 Starting auto save for weight: ${stableWeight.toStringAsFixed(1)} kg',
      );

      final success = await _performSave(
        stableWeight,
        'auto',
        'Auto saved after $_stableCountThreshold stable readings',
      );

      if (success) {
        _totalAutoSaves++;
        _waitingForZeroWeight = true;
        _lastSaveTime = DateTime.now();

        // Auto reset tare after save
        await _displayProvider.sendCustomCommand('CLEAR_TARE');

        _resetStableTracking();

        debugPrint(
          '✅ Auto saved: ${stableWeight.toStringAsFixed(1)} kg - Waiting for zero weight',
        );
      }

      return success;
    } catch (e) {
      _setError('Auto save failed: $e');
      debugPrint('❌ Auto save error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// Manual save operation
  Future<bool> manualSave({String? customNotes}) async {
    try {
      _setProcessing(true);
      _clearError();

      // Verify database and table
      if (!await _verifyDatabaseAndTable()) {
        return false;
      }

      final currentWeight = _displayProvider.netWeight;
      if (currentWeight == null || currentWeight <= 0) {
        _setError('No valid weight to save');
        return false;
      }

      debugPrint(
        '📝 Starting manual save for weight: ${currentWeight.toStringAsFixed(1)} kg',
      );

      final notes = customNotes ?? 'Manual save';
      final success = await _performSave(currentWeight, 'manual', notes);

      if (success) {
        _totalManualSaves++;
        _lastSaveTime = DateTime.now();

        debugPrint('✅ Manual save: ${currentWeight.toStringAsFixed(1)} kg');
      }

      return success;
    } catch (e) {
      _setError('Manual save failed: $e');
      debugPrint('❌ Manual save error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// Core save operation
  Future<bool> _performSave(
    double weight,
    String saveType,
    String notes,
  ) async {
    final saveData = {
      'weight': weight,
      'raw_weight': _displayProvider.rawWeightWithoutTare ?? 0.0,
      'tare_offset': _displayProvider.tareOffset,
      'device_name': _displayProvider.deviceName,
      'timestamp': DateTime.now().toIso8601String(),
      'auto_save_session': DateTime.now().millisecondsSinceEpoch,
      'notes': notes,
      'save_type': saveType,
    };

    debugPrint('📝 Save data prepared: $saveData');

    return await _crudServices.insertRecord(_tableName, saveData);
  }

  /// Verify database and table are ready
  Future<bool> _verifyDatabaseAndTable() async {
    if (!_crudServices.isDatabaseReady) {
      _setError('Database not ready');
      return false;
    }

    final tableExists = await _crudServices.doesTableExist(_tableName);
    if (!tableExists) {
      debugPrint('❌ Table $_tableName does not exist, attempting to create...');
      await _initializeTable();

      final tableExistsAfterInit = await _crudServices.doesTableExist(
        _tableName,
      );
      if (!tableExistsAfterInit) {
        _setError('Cannot create required table for save operation');
        return false;
      }
    }

    return true;
  }

  // ========== DATA OPERATIONS ==========

  /// Get all saved records
  Future<List<Map<String, dynamic>>> getAllRecords({String? orderBy}) async {
    try {
      _clearError();
      return await _crudServices.getAllRecords(
        _tableName,
        orderBy: orderBy ?? 'timestamp DESC',
      );
    } catch (e) {
      _setError('Failed to load records: $e');
      return [];
    }
  }

  /// Get records with conditions
  Future<List<Map<String, dynamic>>> getRecordsWhere({
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    try {
      _clearError();
      return await _crudServices.getRecordsWhere(
        _tableName,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy ?? 'timestamp DESC',
        limit: limit,
      );
    } catch (e) {
      _setError('Failed to load filtered records: $e');
      return [];
    }
  }

  /// Get today's records
  Future<List<Map<String, dynamic>>> getTodayRecords() async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    return await getRecordsWhere(
      where: 'timestamp BETWEEN ? AND ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );
  }

  /// Get records by save type
  Future<List<Map<String, dynamic>>> getRecordsByType(String saveType) async {
    return await getRecordsWhere(where: 'save_type = ?', whereArgs: [saveType]);
  }

  /// Delete record by ID
  Future<bool> deleteRecord(int id) async {
    try {
      _clearError();
      return await _crudServices.deleteRecordById(_tableName, id);
    } catch (e) {
      _setError('Failed to delete record: $e');
      return false;
    }
  }

  /// Delete all records
  Future<bool> deleteAllRecords() async {
    try {
      _clearError();
      return await _crudServices.deleteAllRecords(_tableName);
    } catch (e) {
      _setError('Failed to delete all records: $e');
      return false;
    }
  }

  /// Count records
  Future<int> countRecords({String? where, List<dynamic>? whereArgs}) async {
    try {
      _clearError();
      return await _crudServices.countRecords(
        _tableName,
        where: where,
        whereArgs: whereArgs,
      );
    } catch (e) {
      _setError('Failed to count records: $e');
      return 0;
    }
  }

  // ========== UTILITY METHODS ==========

  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ AutoSave Service Error: $error');
    }
    notifyListeners();
  }

  void _clearError() {
    _lastError = null;
  }

  /// Reset all statistics
  void resetStatistics() {
    _totalAutoSaves = 0;
    _totalManualSaves = 0;
    _lastSaveTime = null;
    _clearError();
    notifyListeners();
  }

  /// Get service statistics
  Map<String, dynamic> getStatistics() {
    return {
      'isInitialized': _isInitialized,
      'isAutoSaveActive': _isAutoSaveActive,
      'waitingForZeroWeight': _waitingForZeroWeight,
      'stableCount': _stableCount,
      'stableCountThreshold': _stableCountThreshold,
      'weightTolerance': _weightTolerance,
      'zeroWeightThreshold': _zeroWeightThreshold,
      'totalAutoSaves': _totalAutoSaves,
      'totalManualSaves': _totalManualSaves,
      'lastSaveTime': _lastSaveTime?.toIso8601String(),
      'lastError': _lastError,
      'isProcessing': _isProcessing,
    };
  }

  /// Reinitialize the service
  Future<void> reinitialize() async {
    stopAutoSave();
    _isInitialized = false;
    await _initialize();
  }

  @override
  void dispose() {
    stopAutoSave();
    super.dispose();
  }
}
