import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DisplayHomeProvider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({Key? key}) : super(key: key);

  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage>
    with WidgetsBindingObserver {
  Timer? _autoSaveTimer;

  // ⚡ Auto Save - ใช้สถานะจากเครื่อง
  static const Duration _autoSaveInterval = Duration(
    milliseconds: 100,
  ); // เช็คบ่อยๆ เพื่อจับ S status

  // ตัวแปรสำหรับ Auto Save Logic
  bool _hasAutoSavedInThisCycle = false;
  String _lastRawData = '';
  double? _lastSavedWeight;
  bool _isCurrentlyStable = false;
  bool _wasStableInPreviousCheck = false;
  bool _hasStartedFromZero = false;
  double? _s0; // สำหรับเก็บค่าเมื่อ input == S00.00
  double? _s1; // สำหรับเก็บค่าเมื่อ stable และ weight >= 0.0

  // 💾 Cache สำหรับ Database Operations
  Map<String, List<String>> _tableColumnsCache = {};
  Map<String, bool> _hasWeightColumnCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      provider.initialize(context).then((_) {
        print("✅ FormulaProvider initialized");
        final formulaTableNames = provider.getFormulaTableNames();
        print("📝 Formula table names: $formulaTableNames");
      });
      Provider.of<DisplayHomeProvider>(
        context,
        listen: false,
      ).initialize(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSaveTimer?.cancel();
    _clearCache();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        print('🔄 [LIFECYCLE] App resumed - checking auto save status');
        _checkAndRestartAutoSave();
        break;
      case AppLifecycleState.paused:
        print('⏸️ [LIFECYCLE] App paused');
        break;
      case AppLifecycleState.inactive:
        print('😴 [LIFECYCLE] App inactive');
        break;
      case AppLifecycleState.detached:
        print('🚪 [LIFECYCLE] App detached');
        break;
      default:
        break;
    }
  }

  void _checkAndRestartAutoSave() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final displayProvider = Provider.of<DisplayHomeProvider>(
          context,
          listen: false,
        );

        print('🔍 [AUTO SAVE] Checking status...');
        print('   Auto Save Mode: ${displayProvider.isAutoSaveMode}');
        print('   Timer Active: ${_autoSaveTimer?.isActive ?? false}');

        if (displayProvider.isAutoSaveMode &&
            (_autoSaveTimer == null || !_autoSaveTimer!.isActive)) {
          print(
            '🔧 [AUTO SAVE] Mode is ON but timer is inactive - restarting...',
          );
          _startAutoSaveWithStableDetection();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 Smart Auto Save restarted'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else if (!displayProvider.isAutoSaveMode &&
            (_autoSaveTimer?.isActive ?? false)) {
          print('🛑 [AUTO SAVE] Mode is OFF but timer is active - stopping...');
          _stopAutoSave();
        } else {
          print('✅ [AUTO SAVE] Status is consistent');
        }
      } catch (e) {
        print('❌ [AUTO SAVE] Error checking status: $e');
      }
    });
  }

  // 📊 แยกข้อมูลจาก raw string
  Map<String, dynamic> _parseWeightData(String rawData) {
    try {
      // ตัวอย่าง: "U002.00T000.00DN" หรือ "S002.00T000.00DN"
      if (rawData.length < 13) return {};

      // ดึงสถานะ (U = Unstable, S = Stable)
      String status = rawData.substring(0, 1);
      bool isStable = status == 'S';

      // ดึงน้ำหนัก (ตำแหน่ง 1-6: "002.00")
      String weightStr = rawData.substring(1, 7);
      double weight = double.tryParse(weightStr) ?? 0.0;

      // ดึงค่า Tare (ตำแหน่ง 8-13: "000.00")
      String tareStr = rawData.substring(8, 14);
      double tare = double.tryParse(tareStr) ?? 0.0;

      return {
        'status': status,
        'isStable': isStable,
        'weight': weight,
        'tare': tare,
        'rawData': rawData,
      };
    } catch (e) {
      print('❌ [PARSE] Error parsing weight data: $e');
      return {};
    }
  }

  // ⚡ Auto Save - ปรับตามเงื่อนไขใหม่
  void _startAutoSaveWithStableDetection() {
    _autoSaveTimer?.cancel();

    // รีเซ็ต state
    _hasAutoSavedInThisCycle = false;
    _lastRawData = '';
    _lastSavedWeight = null;
    _isCurrentlyStable = false;
    _wasStableInPreviousCheck = false;
    _hasStartedFromZero = false;
    _s0 = null;
    _s1 = null;

    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) async {
      final displayProvider = Provider.of<DisplayHomeProvider>(
        context,
        listen: false,
      );
      final formulaProvider = Provider.of<FormulaProvider>(
        context,
        listen: false,
      );
      final settingProvider = Provider.of<SettingProvider>(
        context,
        listen: false,
      );

      // ตรวจสอบเงื่อนไขพื้นฐาน
      if (!displayProvider.isAutoSaveMode) {
        print('🛑 [AUTO SAVE] Mode disabled, stopping timer');
        timer.cancel();
        return;
      }

      if (!displayProvider.hasValidFormulaSelected) {
        return;
      }

      // ดึงข้อมูล raw จาก SettingProvider
      String? currentRawData = settingProvider.rawReceivedText;

      if (currentRawData == null || currentRawData.isEmpty) {
        return;
      }

      // ถ้าข้อมูลไม่เปลี่ยน ไม่ต้องประมวลผล
      if (currentRawData == _lastRawData) {
        return;
      }

      _lastRawData = currentRawData;

      // แยกข้อมูล
      Map<String, dynamic> parsed = _parseWeightData(currentRawData);

      if (parsed.isEmpty) {
        return;
      }

      bool isStable = parsed['isStable'] as bool;
      double weight = parsed['weight'] as double;
      double tare = parsed['tare'] as double;
      String status = parsed['status'] as String;

      print('📊 [AUTO SAVE] Raw: $currentRawData');
      print('   Status: $status (${isStable ? "STABLE" : "UNSTABLE"})');
      print('   Weight: ${weight.toStringAsFixed(2)} kg');
      print('   Tare: ${tare.toStringAsFixed(2)} kg');

      // อัพเดทสถานะ
      _wasStableInPreviousCheck = _isCurrentlyStable;
      _isCurrentlyStable = isStable;

      // รีเซ็ต cycle เมื่อน้ำหนักกลับไปที่ S00.00
      if (isStable && weight == 0.0) {
        if (_hasAutoSavedInThisCycle) {
          _resetAutoSaveCycle();
        }
        _s0 = 0.0; // ตั้งค่า _s0 เมื่อ input == S00.00
        print('📌 [AUTO SAVE] S[0] set to 0.00 (input is S00.00)');
      }

      // ตั้งค่า _s1 เมื่อ stable และน้ำหนัก >= 0.0
      if (isStable && weight >= 0.0) {
        _s1 = weight;
        print('📌 [AUTO SAVE] S[1] set to ${weight.toStringAsFixed(2)}');
      }

      // บันทึกเมื่อ _s0 == 0.0 และ _s1 ไม่เป็น null และ _s1 != 0.0
      if (_s0 == 0.0 && _s1 != null && _s1 != 0.0 && !_hasAutoSavedInThisCycle) {
        print('✅ [AUTO SAVE] Condition met: S[0] == 0.00 && S[1] non-zero');
        print('   S[0]: $_s0');
        print('   S[1]: ${_s1?.toStringAsFixed(2)}');

        try {
          // บันทึกน้ำหนัก _s1
          await _insertWeightWithMachineStable(
            context,
            displayProvider,
            formulaProvider,
            settingProvider,
            weightToSave: _s1!,
            tareValue: tare,
            rawData: currentRawData,
          );

          _hasAutoSavedInThisCycle = true;
          _lastSavedWeight = _s1;

          print('💾 [AUTO SAVE] Save SUCCESS!');
          print('   Saved Weight: ${_s1!.toStringAsFixed(2)} kg');
          print('   Tare: ${tare.toStringAsFixed(2)} kg');
          print('   Raw Data: $currentRawData');

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🎯 Saved: ${_s1!.toStringAsFixed(2)} kg!',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print('❌ [AUTO SAVE] Save FAILED: $e');
        }
      } else {
        print('⏳ [AUTO SAVE] Waiting for condition: S[0] == 0.00 && S[1] non-zero');
        print('   Current S[0]: $_s0');
        print('   Current S[1]: ${_s1?.toStringAsFixed(2)}');
        print('   Has saved: $_hasAutoSavedInThisCycle');
      }
    });

    print('🟢 [AUTO SAVE] Started');
    print('📋 [AUTO SAVE] Configuration:');
    print('   - Check interval: ${_autoSaveInterval.inMilliseconds} ms');
    print('   - Save condition: S[0] == 0.00 && S[1] non-zero');
  }

  // 🔄 รีเซ็ต cycle
  void _resetAutoSaveCycle() {
    print('🔄 [AUTO SAVE] CYCLE RESET');
    print('   Previous saved: $_hasAutoSavedInThisCycle');
    print(
      '   Last saved weight: ${_lastSavedWeight?.toStringAsFixed(2) ?? "None"}',
    );

    _hasAutoSavedInThisCycle = false;
    _lastSavedWeight = null;
    _isCurrentlyStable = false;
    _wasStableInPreviousCheck = false;
    _lastRawData = '';
    _hasStartedFromZero = true;
    _s0 = null;
    _s1 = null;

    print('✅ [AUTO SAVE] Reset complete - ready for next cycle');
  }

  // ฟังก์ชันหยุด auto save
  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;

    // รีเซ็ต state
    _hasAutoSavedInThisCycle = false;
    _lastRawData = '';
    _lastSavedWeight = null;
    _isCurrentlyStable = false;
    _wasStableInPreviousCheck = false;
    _hasStartedFromZero = false;
    _s0 = null;
    _s1 = null;

    print('🔴 [AUTO SAVE] Stopped and reset all states');
  }

  // 💾 บันทึกน้ำหนักด้วย Machine Stable
  Future<void> _insertWeightWithMachineStable(
    BuildContext context,
    DisplayHomeProvider displayProvider,
    FormulaProvider formulaProvider,
    SettingProvider settingProvider, {
    required double weightToSave,
    required double tareValue,
    required String rawData,
  }) async {
    try {
      print('🔄 [SAVE] Starting optimized weight insertion...');

      final selectedFormulaName = displayProvider.selectedFormula!;
      final deviceName =
          settingProvider.connectedDevice?.platformName ?? 'ESP32_LoadCell';
      final timestamp = DateTime.now().toIso8601String();

      final tableName =
          'formula_${selectedFormulaName.toLowerCase().replaceAll(' ', '_')}';

      print(
        '⚖️ [SAVE] Weight: ${weightToSave.toStringAsFixed(2)} kg',
      );
      print(
        '🔧 [SAVE] Tare: ${tareValue.toStringAsFixed(2)} kg',
      );
      print('📱 [SAVE] Device: $deviceName');
      print('🕐 [SAVE] Timestamp: $timestamp');
      print('📊 [SAVE] Raw Data: $rawData');

      // ตรวจสอบ formula
      final formulaDetails = formulaProvider.getFormulaByName(
        selectedFormulaName,
      );
      if (formulaDetails == null) {
        throw Exception('Formula not found: $selectedFormulaName');
      }

      print('✅ [FormulaProvider] Found formula: $selectedFormulaName');
      print('📋 [SAVE] Table: $tableName');

      // 💾 ใช้ cache สำหรับ table columns
      List<String> existingColumns;
      if (_tableColumnsCache.containsKey(tableName)) {
        existingColumns = _tableColumnsCache[tableName]!;
        print('💾 [SAVE] Using cached columns');
      } else {
        existingColumns = await formulaProvider.getTableColumns(tableName);
        _tableColumnsCache[tableName] = existingColumns;
        print('📖 [FormulaProvider] Getting columns for table: $tableName');
        print(
          '📊 [FormulaProvider] Retrieved ${existingColumns.length} columns from $tableName',
        );
        print(
          '🔍 [SAVE] Cached columns for future use: $existingColumns',
        );
      }

      print(
        '🏷️ [SAVE] Existing columns in database: $existingColumns',
      );

      // 💾 ใช้ cache สำหรับ weight column check
      bool hasWeightColumn;
      if (_hasWeightColumnCache.containsKey(tableName)) {
        hasWeightColumn = _hasWeightColumnCache[tableName]!;
      } else {
        hasWeightColumn = existingColumns.any(
          (col) => col.toLowerCase().contains('weight'),
        );
        _hasWeightColumnCache[tableName] = hasWeightColumn;
      }

      print('🔍 [SAVE] Has weight column: $hasWeightColumn');

      // 📝 เตรียมข้อมูลพร้อมข้อมูลเพิ่มเติม
      final Map<String, dynamic> dataToInsert = {};

      for (final columnName in existingColumns) {
        final lowerColumnName = columnName.toLowerCase();

        if (lowerColumnName.contains('weight')) {
          dataToInsert[columnName] = weightToSave;
          print(
            '⚖️ [SAVE] Inserted weight: $weightToSave -> $columnName',
          );
        } else if (lowerColumnName.contains('tare')) {
          dataToInsert[columnName] = tareValue;
          print(
            '🔧 [SAVE] Inserted tare: $tareValue -> $columnName',
          );
        } else if (lowerColumnName.contains('time') ||
            lowerColumnName.contains('date') ||
            lowerColumnName == 'updated_at') {
          dataToInsert[columnName] = timestamp;
          print('🕐 [SAVE] Inserted timestamp -> $columnName');
        } else if (lowerColumnName.contains('device')) {
          dataToInsert[columnName] = deviceName;
          print('📱 [SAVE] Inserted device -> $columnName');
        } else if (lowerColumnName.contains('raw') ||
            lowerColumnName.contains('data')) {
          dataToInsert[columnName] = rawData;
          print('📊 [SAVE] Inserted raw data -> $columnName');
        } else if (lowerColumnName.contains('status')) {
          dataToInsert[columnName] = 'STABLE';
          print('✅ [SAVE] Inserted status -> $columnName');
        } else if (lowerColumnName != 'id' &&
            lowerColumnName != 'created_at' &&
            lowerColumnName != 'updated_at') {
          dataToInsert[columnName] =
              'Auto-${DateTime.now().millisecondsSinceEpoch}';
          print('📝 [SAVE] Inserted default -> $columnName');
        }
      }

      print('💾 [SAVE] Final data to insert: $dataToInsert');

      // 💾 บันทึกลง database
      final success = await formulaProvider.createRecord(
        tableName: tableName,
        data: dataToInsert,
      );

      if (success) {
        print('✅ [SAVE] Weight data saved successfully!');
        print(
          '📊 [SAVE] Weight: ${weightToSave.toStringAsFixed(2)} kg',
        );
        print(
          '🔧 [SAVE] Tare: ${tareValue.toStringAsFixed(2)} kg',
        );
        print('📋 [SAVE] Formula: $selectedFormulaName');
        print('📊 [SAVE] Raw: $rawData');
      } else {
        print('❌ [SAVE] Failed to save weight data');
        throw Exception('Database save failed');
      }
    } catch (e) {
      print('❌ [SAVE] Error: $e');
      throw e;
    }
  }

  // 🧹 ล้าง cache เมื่อจำเป็น
  void _clearCache() {
    _tableColumnsCache.clear();
    _hasWeightColumnCache.clear();
    print('🧹 [CACHE] Cleared all caches');
  }

  // ฟังก์ชันสำหรับ manual save
  Future<void> _insertWeightManual(
    BuildContext context,
    DisplayHomeProvider displayProvider,
    FormulaProvider formulaProvider,
    SettingProvider settingProvider,
  ) async {
    try {
      print('🔄 [MANUAL SAVE] Starting weight insertion process...');

      if (displayProvider.isReadonlyMode ||
          !displayProvider.hasValidFormulaSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a formula first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      if (settingProvider.currentRawValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No weight data available. Please connect device first.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final weightValue = settingProvider.currentRawValue!;

      // ลองดึงข้อมูล raw ถ้ามี
      String? rawData = settingProvider.rawReceivedText;
      Map<String, dynamic> parsed = {};
      double tareValue = 0.0;

      if (rawData != null && rawData.isNotEmpty) {
        parsed = _parseWeightData(rawData);
        tareValue = parsed['tare'] ?? 0.0;
      }

      print(
        '⚖️ [MANUAL SAVE] Weight value: ${weightValue.toStringAsFixed(2)} kg',
      );
      if (parsed.isNotEmpty) {
        print(
          '🔧 [MANUAL SAVE] Tare value: ${tareValue.toStringAsFixed(2)} kg',
        );
        print('📊 [MANUAL SAVE] Raw data: $rawData');
      }

      await _insertWeightWithMachineStable(
        context,
        displayProvider,
        formulaProvider,
        settingProvider,
        weightToSave: weightValue,
        tareValue: tareValue,
        rawData: rawData ?? 'MANUAL-${DateTime.now().millisecondsSinceEpoch}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Weight ${weightValue.toStringAsFixed(2)} kg saved manually!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      print('✅ [MANUAL SAVE] Weight data saved successfully!');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving weight: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('❌ [MANUAL SAVE] Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestartAutoSave();
    });

    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              width: double.infinity,
              height: 60,
              color: const Color(0xFF5A9B9E),
              child: Row(
                children: [
                  // Connect Button
                  Expanded(
                    child: Consumer<SettingProvider>(
                      builder: (context, settingProvider, _) {
                        final isConnected =
                            settingProvider.connectedDevice != null;
                        return Container(
                          margin: const EdgeInsets.all(8),
                          child: ElevatedButton(
                            onPressed: () {
                              // TODO: Add connect/disconnect logic
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isConnected ? Colors.green : Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isConnected
                                      ? Icons.check_circle
                                      : Icons.circle,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isConnected ? 'Connected' : 'Connect',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Formula Dropdown
                  Expanded(
                    child: Consumer<DisplayHomeProvider>(
                      builder: (context, provider, child) {
                        final currentValue = provider.selectedFormula;
                        final availableItems = provider.availableFormulas;

                        String? validValue = currentValue;
                        if (currentValue != null &&
                            !availableItems.any(
                              (item) => item['value'] == currentValue,
                            )) {
                          validValue = DisplayHomeProvider.readonlyValue;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            provider.setSelectedFormula(
                              DisplayHomeProvider.readonlyValue,
                            );
                          });
                        }

                        return Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: validValue,
                            isExpanded: true,
                            underline: Container(),
                            icon: const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                            items:
                                availableItems.map((formula) {
                                  final isReadonly =
                                      formula['isReadonly'] == true;
                                  return DropdownMenuItem<String>(
                                    value: formula['value'] as String,
                                    child: Row(
                                      children: [
                                        Icon(
                                          isReadonly
                                              ? Icons.visibility_off
                                              : Icons.calculate,
                                          size: 16,
                                          color:
                                              isReadonly
                                                  ? Colors.grey
                                                  : Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isReadonly
                                                ? 'Read only'
                                                : formula['name'] as String,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color:
                                                  isReadonly
                                                      ? Colors.grey
                                                      : Colors.black,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                provider.setSelectedFormula(newValue);
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Content Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Top Row - TARE and ZERO
                    Consumer<SettingProvider>(
                      builder: (context, settingProvider, child) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildButton(
                                'TARE',
                                onPressed: () async {
                                  if (settingProvider.connectedDevice != null) {
                                    BluetoothCharacteristic?
                                    writeCharacteristic;

                                    for (var serviceEntry
                                        in settingProvider
                                            .characteristics
                                            .entries) {
                                      for (var char in serviceEntry.value) {
                                        if (char.properties.write ||
                                            char
                                                .properties
                                                .writeWithoutResponse) {
                                          writeCharacteristic = char;
                                          break;
                                        }
                                      }
                                      if (writeCharacteristic != null) break;
                                    }

                                    if (writeCharacteristic != null) {
                                      String message = "TARE";
                                      List<int> data = message.codeUnits;
                                      await settingProvider.writeCharacteristic(
                                        writeCharacteristic,
                                        data,
                                      );
                                      print('Data sent: $message');
                                    } else {
                                      print('No writable characteristic found');
                                    }
                                  } else {
                                    print('No device connected');
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildButton(
                                'ZERO',
                                onPressed: () async {
                                  if (settingProvider.connectedDevice != null) {
                                    BluetoothCharacteristic?
                                    writeCharacteristic;

                                    for (var serviceEntry
                                        in settingProvider
                                            .characteristics
                                            .entries) {
                                      for (var char in serviceEntry.value) {
                                        if (char.properties.write ||
                                            char
                                                .properties
                                                .writeWithoutResponse) {
                                          writeCharacteristic = char;
                                          break;
                                        }
                                      }
                                      if (writeCharacteristic != null) break;
                                    }

                                    if (writeCharacteristic != null) {
                                      String message = "ZERO";
                                      List<int> data = message.codeUnits;
                                      await settingProvider.writeCharacteristic(
                                        writeCharacteristic,
                                        data,
                                      );
                                      print('Data sent: $message');
                                    } else {
                                      print('No writable characteristic found');
                                    }
                                  } else {
                                    print('No device connected');
                                  }
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Center Weight Display with Raw Data
                    Expanded(
                      flex: 2,
                      child: Consumer<SettingProvider>(
                        builder: (context, settingProvider, _) {
                          // Parse ข้อมูล raw เพื่อแสดงสถานะ
                          Map<String, dynamic> parsed = {};
                          if (settingProvider.rawReceivedText != null &&
                              settingProvider.rawReceivedText!.isNotEmpty) {
                            parsed = _parseWeightData(
                              settingProvider.rawReceivedText!,
                            );
                          }

                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3E50),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // kg unit
                                Text(
                                  'kg',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 32,
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                // Weight value
                                Text(
                                  settingProvider.currentRawValue != null
                                      ? settingProvider.currentRawValue!
                                          .toStringAsFixed(1)
                                      : '0.0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // แสดงสถานะ Stable/Unstable จากเครื่อง
                                if (parsed.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          parsed['isStable'] == true
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            parsed['isStable'] == true
                                                ? Colors.green.withOpacity(0.5)
                                                : Colors.orange.withOpacity(
                                                  0.5,
                                                ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          parsed['isStable'] == true
                                              ? Icons.check_circle
                                              : Icons.pending,
                                          size: 16,
                                          color:
                                              parsed['isStable'] == true
                                                  ? Colors.green[300]
                                                  : Colors.orange[300],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          parsed['isStable'] == true
                                              ? 'STABLE'
                                              : 'UNSTABLE',
                                          style: TextStyle(
                                            color:
                                                parsed['isStable'] == true
                                                    ? Colors.green[300]
                                                    : Colors.orange[300],
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // แสดงค่า Tare ถ้ามี
                                  if (parsed['tare'] != null &&
                                      parsed['tare'] > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tare: ${(parsed['tare'] as double).toStringAsFixed(2)} kg',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],

                                  // แสดง Raw Data
                                  const SizedBox(height: 4),
                                  Text(
                                    'Raw: ${parsed['rawData']}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],

                                // แสดงสถานะ Auto Save
                                _buildAutoSaveStatus(),
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // BTN5 (Full width)
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: _buildButton(
                        'BTN5',
                        backgroundColor: const Color(0xFF7FB8C4),
                        onPressed: () {
                          print('BTN5 pressed');
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bottom Row - AUTO SAVE และ CLICK SAVE WEIGHT
                    Consumer<DisplayHomeProvider>(
                      builder: (context, displayProvider, child) {
                        return Row(
                          children: [
                            // AUTO SAVE Button
                            Expanded(
                              child: _buildAutoSaveButton(displayProvider),
                            ),
                            const SizedBox(width: 16),

                            // CLICK SAVE WEIGHT Button
                            Expanded(
                              child: Consumer3<
                                DisplayHomeProvider,
                                FormulaProvider,
                                SettingProvider
                              >(
                                builder: (
                                  context,
                                  displayProvider,
                                  formulaProvider,
                                  settingProvider,
                                  child,
                                ) {
                                  final isDisabled =
                                      displayProvider.isAutoSaveMode;

                                  return _buildButton(
                                    'CLICK SAVE WEIGHT',
                                    backgroundColor:
                                        isDisabled ? Colors.grey : Colors.teal,
                                    onPressed:
                                        isDisabled
                                            ? null
                                            : () async {
                                              await _insertWeightManual(
                                                context,
                                                displayProvider,
                                                formulaProvider,
                                                settingProvider,
                                              );
                                            },
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⚡ อัพเดท UI ส่วน Auto Save Button
  Widget _buildAutoSaveButton(DisplayHomeProvider displayProvider) {
    return GestureDetector(
      onLongPress: () {
        if (displayProvider.isAutoSaveMode &&
            (_autoSaveTimer == null || !_autoSaveTimer!.isActive)) {
          print('🔄 [MANUAL] Force restarting auto save...');
          _startAutoSaveWithStableDetection();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔄 Smart Auto Save restarted'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 1),
            ),
          );
        }
      },
      child: _buildButton(
        displayProvider.isAutoSaveMode
            ? 'STOP AUTO SAVE'
            : 'START SMART AUTO SAVE',
        backgroundColor:
            displayProvider.isAutoSaveMode ? Colors.orange : Colors.blue,
        onPressed: () {
          if (displayProvider.isAutoSaveMode) {
            // หยุด auto save
            displayProvider.setAutoSaveMode(false);
            _stopAutoSave();
            _clearCache();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Smart Auto Save stopped'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 1),
              ),
            );
          } else {
            // ตรวจสอบเงื่อนไข
            if (displayProvider.isReadonlyMode ||
                !displayProvider.hasValidFormulaSelected) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select a formula first'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }

            // เริ่ม auto save
            displayProvider.setAutoSaveMode(true);
            _startAutoSaveWithStableDetection();

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🎯 Smart Auto Save started - Waiting for conditions',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 4),
              ),
            );
          }
        },
      ),
    );
  }

  // 📊 แสดงสถานะ Auto Save
  Widget _buildAutoSaveStatus() {
    return Consumer<DisplayHomeProvider>(
      builder: (context, displayProvider, _) {
        if (!displayProvider.isAutoSaveMode) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _autoSaveTimer?.isActive == true
                        ? Icons.smart_toy
                        : Icons.warning,
                    size: 16,
                    color:
                        _autoSaveTimer?.isActive == true
                            ? Colors.blue[300]
                            : Colors.orange[300],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _autoSaveTimer?.isActive == true
                        ? 'SMART AUTO SAVE'
                        : 'AUTO SAVE PAUSED',
                    style: TextStyle(
                      color:
                          _autoSaveTimer?.isActive == true
                              ? Colors.blue[300]
                              : Colors.orange[300],
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton(
    String text, {
    Color? backgroundColor,
    VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? const Color(0xFF2D3E50),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}