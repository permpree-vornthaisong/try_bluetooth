import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'SettingProvider.dart';
import 'DisplayProvider.dart';

class PopupProvider extends ChangeNotifier {
  // Dependencies
  SettingProvider? _settingProvider;
  DisplayProvider? _displayProvider;
  
  // State
  bool _isProcessing = false;
  String? _lastOperation;
  String? _lastError;
  
  // Statistics
  int _tareOperations = 0;
  int _zeroOperations = 0;
  
  // SQLite Database
  Database? _database;
  
  // Custom Tare Storage (SQLite-based)
  double _customTareOffset = 0.0;
  bool _useCustomTare = false;
  
  // Getters
  bool get isProcessing => _isProcessing;
  String? get lastOperation => _lastOperation;
  String? get lastError => _lastError;
  int get tareOperations => _tareOperations;
  int get zeroOperations => _zeroOperations;
  
  // Connection status
  bool get isConnected => _settingProvider?.connectedDevice != null;
  String get connectionStatus => _settingProvider?.connectionStatus ?? 'Disconnected';
  String get deviceName => _settingProvider?.connectedDevice != null 
      ? _settingProvider!.getBLEDeviceDisplayName(_settingProvider!.connectedDevice!)
      : 'No Device';
  
  // Weight data
  double? get currentRawValue => _settingProvider?.currentRawValue;
  
  // Combined Tare Offset (DisplayProvider + Custom SQLite)
  double get tareOffset {
    double displayTare = _displayProvider?.tareOffset ?? 0.0;
    return _useCustomTare ? _customTareOffset : displayTare;
  }
  
  bool get hasTareOffset => tareOffset != 0.0;
  
  // Formatted weight display
  String get formattedWeight {
    final rawValue = currentRawValue;
    if (rawValue == null) return "-.--";
    
    final finalWeight = rawValue - tareOffset;
    if (finalWeight <= 0.0) {
      return "0.0";
    }
    return finalWeight.abs().toStringAsFixed(1);
  }
  
  // ========== ADDITIONAL WEIGHT GETTERS ==========
  
  /// Get weight without tare (raw weight)
  double? get rawWeightWithoutTare {
    return _settingProvider?.currentRawValue;
  }

  /// Get net weight (weight after tare)
  double? get netWeight {
    final raw = rawWeightWithoutTare;
    if (raw == null) return null;
    return raw - tareOffset;
  }

  /// Get tare percentage of current weight
  double? get tarePercentage {
    final raw = rawWeightWithoutTare;
    if (raw == null || raw == 0) return null;
    return (tareOffset / raw) * 100;
  }

  /// Check if tare is valid
  bool get isTareValid {
    return tareOffset >= 0 && isTareReasonable(tareOffset);
  }

  /// Check if using custom tare from SQLite
  bool get isUsingCustomTare => _useCustomTare;
  
  // ========== DATABASE OPERATIONS ==========
  
  /// Initialize SQLite database for tare storage
  Future<void> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'popup_provider.db');
      
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE tare_settings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              device_name TEXT,
              tare_value REAL,
              created_at TEXT,
              is_active INTEGER DEFAULT 0
            )
          ''');
          
          await db.execute('''
            CREATE TABLE tare_presets (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              preset_name TEXT UNIQUE,
              tare_value REAL,
              description TEXT,
              created_at TEXT
            )
          ''');
        },
      );
      
      // Load active tare setting
      await _loadActiveTareSetting();
      
      if (kDebugMode) {
        print('✅ PopupProvider database initialized');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error initializing database: $e');
      }
    }
  }
  
  /// Load active tare setting from database
  Future<void> _loadActiveTareSetting() async {
    if (_database == null) return;
    
    try {
      final List<Map<String, dynamic>> results = await _database!.query(
        'tare_settings',
        where: 'is_active = ?',
        whereArgs: [1],
        orderBy: 'created_at DESC',
        limit: 1,
      );
      
      if (results.isNotEmpty) {
        _customTareOffset = results.first['tare_value'] ?? 0.0;
        _useCustomTare = _customTareOffset != 0.0;
        
        if (kDebugMode) {
          print('📂 Loaded tare setting: ${_customTareOffset} kg');
        }
        
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading tare setting: $e');
      }
    }
  }
  
  /// Save tare setting to database
  Future<bool> _saveTareSetting(double tareValue) async {
    if (_database == null) return false;
    
    try {
      // Deactivate all previous settings
      await _database!.update(
        'tare_settings',
        {'is_active': 0},
      );
      
      // Insert new active setting
      await _database!.insert('tare_settings', {
        'device_name': deviceName,
        'tare_value': tareValue,
        'created_at': DateTime.now().toIso8601String(),
        'is_active': 1,
      });
      
      if (kDebugMode) {
        print('💾 Saved tare setting: $tareValue kg');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving tare setting: $e');
      }
      return false;
    }
  }
  
  /// Clear active tare setting from database
  Future<bool> _clearTareSetting() async {
    if (_database == null) return false;
    
    try {
      await _database!.update(
        'tare_settings',
        {'is_active': 0},
      );
      
      if (kDebugMode) {
        print('🗑️ Cleared active tare setting');
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error clearing tare setting: $e');
      }
      return false;
    }
  }
  
  // Initialize with providers - แก้ไขให้ return PopupProvider
  PopupProvider initializeWithProviders(
    SettingProvider settingProvider,
    DisplayProvider displayProvider,
  ) {
    // ลบ listener เก่า (ถ้ามี)
    _settingProvider?.removeListener(_onProviderChanged);
    _displayProvider?.removeListener(_onProviderChanged);
    
    _settingProvider = settingProvider;
    _displayProvider = displayProvider;
    
    // Listen to provider changes
    _settingProvider!.addListener(_onProviderChanged);
    _displayProvider!.addListener(_onProviderChanged);
    
    // Initialize database
    _initDatabase();
    
    if (kDebugMode) {
      print('✅ PopupProvider initialized with providers');
      print('✅ Current weight: ${_settingProvider?.currentRawValue}');
      print('✅ Display tare offset: ${_displayProvider?.tareOffset}');
      print('✅ Custom tare offset: $_customTareOffset');
    }
    
    // Notify listeners ให้ UI อัพเดท
    notifyListeners();
    return this; // 🔥 return this เพื่อให้ ProxyProvider ทำงานได้
  }
  
  void _onProviderChanged() {
    if (kDebugMode) {
      print('🔄 Provider changed - Weight: ${currentRawValue}, Tare: ${tareOffset}');
    }
    notifyListeners();
  }
  
  // Set processing state
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
  
  // Set operation info
  void _setOperation(String operation, {String? error}) {
    _lastOperation = operation;
    _lastError = error;
    notifyListeners();
  }
  
  // Clear error
  void clearError() {
    _lastError = null;
    notifyListeners();
  }
  
  // ========== TARE OPERATIONS ==========
  
  /// Perform Tare operation (using current weight)
  Future<TareResult> performTare() async {
    if (kDebugMode) {
      print('🎯 Starting performTare()');
      print('   - SettingProvider: ${_settingProvider != null ? "✅" : "❌"}');
      print('   - Current weight: ${_settingProvider?.currentRawValue}');
    }

    if (_settingProvider == null) {
      if (kDebugMode) {
        print('❌ SettingProvider not initialized');
      }
      return TareResult(
        success: false,
        message: 'SettingProvider ยังไม่ได้เชื่อมต่อ กรุณาลองใหม่',
        error: 'Missing SettingProvider',
      );
    }
    
    _setProcessing(true);
    _setOperation('TARE');
    
    try {
      final currentWeight = _settingProvider!.currentRawValue;
      
      if (kDebugMode) {
        print('   - Retrieved weight: $currentWeight');
      }
      
      if (currentWeight == null) {
        if (kDebugMode) {
          print('❌ No weight data available');
        }
        return TareResult(
          success: false,
          message: 'ไม่มีข้อมูลน้ำหนักสำหรับ Tare กรุณาเชื่อมต่ออุปกรณ์',
          error: 'No weight data',
        );
      }
      
      // Save tare value to SQLite
      bool saved = await _saveTareSetting(currentWeight);
      
      if (saved) {
        _customTareOffset = currentWeight;
        _useCustomTare = true;
        _tareOperations++;
        
        if (kDebugMode) {
          print('   - Tare saved to SQLite: $currentWeight kg');
        }
        
        return TareResult(
          success: true,
          message: 'Tare ตั้งค่าที่ ${currentWeight.toStringAsFixed(1)} kg (SQLite)',
          tareValue: currentWeight,
        );
      } else {
        return TareResult(
          success: false,
          message: 'ไม่สามารถบันทึกค่า Tare ได้',
          error: 'Database save failed',
        );
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in performTare: $e');
      }
      _setOperation('TARE', error: e.toString());
      return TareResult(
        success: false,
        message: 'เกิดข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }
  
  /// Clear Tare operation
  Future<TareResult> clearTare() async {
    if (kDebugMode) {
      print('🎯 Starting clearTare()');
    }

    _setProcessing(true);
    _setOperation('CLEAR_TARE');
    
    try {
      if (kDebugMode) {
        print('   - Current custom tare offset: $_customTareOffset');
      }
      
      // Clear SQLite tare setting
      bool cleared = await _clearTareSetting();
      
      if (cleared) {
        _customTareOffset = 0.0;
        _useCustomTare = false;
        
        // Also clear DisplayProvider tare if available
        try {
          _displayProvider?.clearTare();
        } catch (e) {
          if (kDebugMode) {
            print('   - DisplayProvider clearTare not available: $e');
          }
        }
        
        if (kDebugMode) {
          print('   - Tare cleared from SQLite');
        }
        
        return TareResult(
          success: true,
          message: 'Tare ล้างค่าแล้ว (SQLite)',
        );
      } else {
        return TareResult(
          success: false,
          message: 'ไม่สามารถล้างค่า Tare ได้',
          error: 'Database clear failed',
        );
      }
      
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error in clearTare: $e');
      }
      _setOperation('CLEAR_TARE', error: e.toString());
      return TareResult(
        success: false,
        message: 'เกิดข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }
  
  /// Toggle Tare (perform or clear based on current state)
  Future<TareResult> toggleTare() async {
    if (kDebugMode) {
      print('🎯 Starting toggleTare()');
      print('   - hasTareOffset: $hasTareOffset');
      print('   - tareOffset: $tareOffset');
    }

    if (hasTareOffset) {
      return await clearTare();
    } else {
      return await performTare();
    }
  }

  // ========== ADVANCED TARE OPERATIONS (Now Working with SQLite) ==========

  /// Set specific tare value (manual input)
  Future<TareResult> setTareValue(double tareValue) async {
    if (tareValue < 0) {
      return TareResult(
        success: false,
        message: 'ค่า Tare ต้องไม่เป็นค่าลบ',
        error: 'Negative tare value',
      );
    }

    _setProcessing(true);
    _setOperation('SET_TARE_VALUE');

    try {
      bool saved = await _saveTareSetting(tareValue);
      
      if (saved) {
        _customTareOffset = tareValue;
        _useCustomTare = true;
        _tareOperations++;

        if (kDebugMode) {
          print('✅ Set tare value to: $tareValue kg (SQLite)');
        }

        return TareResult(
          success: true,
          message: 'ตั้งค่า Tare เป็น ${tareValue.toStringAsFixed(1)} kg (SQLite)',
          tareValue: tareValue,
        );
      } else {
        return TareResult(
          success: false,
          message: 'ไม่สามารถบันทึกค่า Tare ได้',
          error: 'Database save failed',
        );
      }

    } catch (e) {
      _setOperation('SET_TARE_VALUE', error: e.toString());
      return TareResult(
        success: false,
        message: 'เกิดข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }

  /// Adjust tare value by adding/subtracting amount
  Future<TareResult> adjustTareValue(double adjustment) async {
    _setProcessing(true);
    _setOperation('ADJUST_TARE');

    try {
      final currentTare = tareOffset;
      final newTare = currentTare + adjustment;

      if (newTare < 0) {
        return TareResult(
          success: false,
          message: 'ค่า Tare ใหม่จะเป็นค่าลบ (${newTare.toStringAsFixed(1)} kg)',
          error: 'Resulting negative tare',
        );
      }

      return await setTareValue(newTare);

    } catch (e) {
      _setOperation('ADJUST_TARE', error: e.toString());
      return TareResult(
        success: false,
        message: 'เกิดข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }

  /// Perform tare with specific weight value
  Future<TareResult> performTareWithValue(double weightValue) async {
    if (weightValue < 0) {
      return TareResult(
        success: false,
        message: 'ค่าน้ำหนักต้องไม่เป็นค่าลบ',
        error: 'Negative weight value',
      );
    }

    return await setTareValue(weightValue);
  }

  /// Quick tare adjustments (common values)
  Future<TareResult> quickTareAdjust(QuickTareOption option) async {
    double adjustment;
    
    switch (option) {
      case QuickTareOption.plus100g:
        adjustment = 0.1;
        break;
      case QuickTareOption.minus100g:
        adjustment = -0.1;
        break;
      case QuickTareOption.plus500g:
        adjustment = 0.5;
        break;
      case QuickTareOption.minus500g:
        adjustment = -0.5;
        break;
      case QuickTareOption.plus1kg:
        adjustment = 1.0;
        break;
      case QuickTareOption.minus1kg:
        adjustment = -1.0;
        break;
    }

    return await adjustTareValue(adjustment);
  }

  /// Reset tare to zero (alias for clearTare)
  Future<TareResult> resetTare() async {
    return await clearTare();
  }

  /// Check if tare is within reasonable range
  bool isTareReasonable(double tareValue) {
    const maxReasonableTare = 1000.0; // 1000 kg
    return tareValue >= 0 && tareValue <= maxReasonableTare;
  }

  /// Save current weight as tare preset
  Future<TareResult> saveTarePreset(String presetName) async {
    final currentWeight = rawWeightWithoutTare;
    
    if (currentWeight == null) {
      return TareResult(
        success: false,
        message: 'ไม่มีข้อมูลน้ำหนักสำหรับบันทึก preset',
        error: 'No weight data',
      );
    }

    if (_database == null) {
      return TareResult(
        success: false,
        message: 'Database ยังไม่พร้อม',
        error: 'Database not initialized',
      );
    }

    try {
      await _database!.insert('tare_presets', {
        'preset_name': presetName,
        'tare_value': currentWeight,
        'description': 'Preset created from current weight',
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      
      if (kDebugMode) {
        print('💾 Saved tare preset "$presetName": $currentWeight kg');
      }

      return TareResult(
        success: true,
        message: 'บันทึก Tare preset "$presetName" = ${currentWeight.toStringAsFixed(1)} kg',
        tareValue: currentWeight,
      );
    } catch (e) {
      return TareResult(
        success: false,
        message: 'ไม่สามารถบันทึก preset ได้: $e',
        error: e.toString(),
      );
    }
  }

  /// Load tare preset
  Future<TareResult> loadTarePreset(String presetName) async {
    if (_database == null) {
      return TareResult(
        success: false,
        message: 'Database ยังไม่พร้อม',
        error: 'Database not initialized',
      );
    }

    try {
      final List<Map<String, dynamic>> results = await _database!.query(
        'tare_presets',
        where: 'preset_name = ?',
        whereArgs: [presetName],
        limit: 1,
      );

      if (results.isEmpty) {
        return TareResult(
          success: false,
          message: 'ไม่พบ preset "$presetName"',
          error: 'Preset not found',
        );
      }

      final double presetValue = results.first['tare_value'];
      return await setTareValue(presetValue);
      
    } catch (e) {
      return TareResult(
        success: false,
        message: 'ไม่สามารถโหลด preset ได้: $e',
        error: e.toString(),
      );
    }
  }

  /// Get list of saved presets
  Future<List<Map<String, dynamic>>> getTarePresets() async {
    if (_database == null) return [];

    try {
      return await _database!.query(
        'tare_presets',
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error getting presets: $e');
      }
      return [];
    }
  }

  /// Get tare status information
  Map<String, dynamic> getTareStatus() {
    return {
      'hasTare': hasTareOffset,
      'tareValue': tareOffset,
      'rawWeight': rawWeightWithoutTare,
      'netWeight': netWeight,
      'formattedWeight': formattedWeight,
      'tarePercentage': tarePercentage,
      'isValid': isTareValid,
      'operations': _tareOperations,
      'isUsingCustomTare': _useCustomTare,
      'customTareValue': _customTareOffset,
      'displayTareValue': _displayProvider?.tareOffset ?? 0.0,
    };
  }
  
  // ========== ZERO OPERATIONS ==========
  
  /// Send Zero command to ESP32
  Future<ZeroResult> sendZeroCommand() async {
    if (_settingProvider == null) {
      return ZeroResult(
        success: false,
        message: 'SettingProvider not initialized',
        error: 'Missing SettingProvider',
      );
    }
    
    _setProcessing(true);
    _setOperation('ZERO');
    
    try {
      // Check connection
      if (!isConnected || _settingProvider!.characteristics.isEmpty) {
        return ZeroResult(
          success: false,
          message: 'ไม่ได้เชื่อมต่ออุปกรณ์ หรือไม่มี characteristic',
          error: 'No connection or characteristics',
        );
      }
      
      // Find writable characteristic
      BluetoothCharacteristic? writeChar = _findWritableCharacteristic();
      
      if (writeChar == null) {
        return ZeroResult(
          success: false,
          message: 'ไม่พบ characteristic สำหรับส่งคำสั่ง',
          error: 'No writable characteristic found',
        );
      }
      
      // Send zero command
      await _settingProvider!.writeCharacteristic(
        writeChar,
        'zero'.codeUnits,
      );
      
      _zeroOperations++;
      
      return ZeroResult(
        success: true,
        message: 'ส่งคำสั่ง Zero ไป ESP32 แล้ว',
        characteristicUuid: writeChar.uuid.toString(),
      );
      
    } catch (e) {
      _setOperation('ZERO', error: e.toString());
      return ZeroResult(
        success: false,
        message: 'ข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }
  
  // ========== HELPER METHODS ==========
  
  /// Find writable characteristic for sending commands
  BluetoothCharacteristic? _findWritableCharacteristic() {
    if (_settingProvider == null) return null;
    
    for (var charList in _settingProvider!.characteristics.values) {
      for (var char in charList) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          return char;
        }
      }
    }
    return null;
  }
  
  /// Send custom command to ESP32
  Future<CommandResult> sendCustomCommand(String command) async {
    if (_settingProvider == null) {
      return CommandResult(
        success: false,
        message: 'SettingProvider not initialized',
        error: 'Missing SettingProvider',
      );
    }
    
    _setProcessing(true);
    _setOperation('CUSTOM_COMMAND');
    
    try {
      if (!isConnected) {
        return CommandResult(
          success: false,
          message: 'ไม่ได้เชื่อมต่ออุปกรณ์',
          error: 'No connection',
        );
      }
      
      BluetoothCharacteristic? writeChar = _findWritableCharacteristic();
      
      if (writeChar == null) {
        return CommandResult(
          success: false,
          message: 'ไม่พบ characteristic สำหรับส่งคำสั่ง',
          error: 'No writable characteristic',
        );
      }
      
      await _settingProvider!.writeCharacteristic(
        writeChar,
        command.codeUnits,
      );
      
      return CommandResult(
        success: true,
        message: 'ส่งคำสั่ง "$command" แล้ว',
        command: command,
      );
      
    } catch (e) {
      _setOperation('CUSTOM_COMMAND', error: e.toString());
      return CommandResult(
        success: false,
        message: 'ข้อผิดพลาด: $e',
        error: e.toString(),
      );
    } finally {
      _setProcessing(false);
    }
  }
  
  // ========== STATISTICS & INFO ==========
  
  /// Get operation statistics
  Map<String, dynamic> getStatistics() {
    return {
      'tareOperations': _tareOperations,
      'zeroOperations': _zeroOperations,
      'totalOperations': _tareOperations + _zeroOperations,
      'lastOperation': _lastOperation,
      'lastError': _lastError,
      'isProcessing': _isProcessing,
      'isConnected': isConnected,
      'hasTareOffset': hasTareOffset,
      'tareOffset': tareOffset,
      'currentWeight': formattedWeight,
    };
  }
  
  /// Reset statistics
  void resetStatistics() {
    _tareOperations = 0;
    _zeroOperations = 0;
    _lastOperation = null;
    _lastError = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    if (kDebugMode) {
      print('🗑️ PopupProvider disposing');
    }
    _settingProvider?.removeListener(_onProviderChanged);
    _displayProvider?.removeListener(_onProviderChanged);
    _database?.close();
    super.dispose();
  }
}

// ========== ENUMS ==========

enum QuickTareOption {
  plus100g,   // +0.1 kg
  minus100g,  // -0.1 kg
  plus500g,   // +0.5 kg
  minus500g,  // -0.5 kg
  plus1kg,    // +1.0 kg
  minus1kg,   // -1.0 kg
}

// ========== RESULT CLASSES ==========

class TareResult {
  final bool success;
  final String message;
  final String? error;
  final double? tareValue;
  
  const TareResult({
    required this.success,
    required this.message,
    this.error,
    this.tareValue,
  });
}

class ZeroResult {
  final bool success;
  final String message;
  final String? error;
  final String? characteristicUuid;
  
  const ZeroResult({
    required this.success,
    required this.message,
    this.error,
    this.characteristicUuid,
  });
}

class CommandResult {
  final bool success;
  final String message;
  final String? error;
  final String? command;
  
  const CommandResult({
    required this.success,
    required this.message,
    this.error,
    this.command,
  });
}