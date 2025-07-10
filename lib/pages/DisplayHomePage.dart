import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DisplayHomeProvider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/GenericCRUDProvider.dart';

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({Key? key}) : super(key: key);

  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> {
  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Container(
              width: double.infinity,
              height: 60,
              color: const Color(0xFF5A9B9E), // Teal color
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

                  // Read Only Dropdown
                  Expanded(
                    child: Consumer<DisplayHomeProvider>(
                      builder: (context, provider, child) {
                        // ตรวจสอบว่า selectedFormula ยังมีอยู่ใน availableFormulas หรือไม่
                        final currentValue = provider.selectedFormula;
                        final availableItems = provider.availableFormulas;
                        
                        // ถ้า currentValue ไม่มีใน availableItems ให้ reset เป็น readonly
                        String? validValue = currentValue;
                        if (currentValue != null && 
                            !availableItems.any((item) => item['value'] == currentValue)) {
                          validValue = DisplayHomeProvider.readonlyValue;
                          // Reset ค่าใน provider
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            provider.setSelectedFormula(DisplayHomeProvider.readonlyValue);
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
                            items: availableItems.map((formula) {
                              final isReadonly = formula['isReadonly'] == true;
                              return DropdownMenuItem<String>(
                                value: formula['value'] as String,
                                child: Row(
                                  children: [
                                    Icon(
                                      isReadonly
                                          ? Icons.visibility_off
                                          : Icons.calculate,
                                      size: 16,
                                      color: isReadonly
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
                                          color: isReadonly
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
                    // Top Row - BTN1 and BTN2
                    Consumer<SettingProvider>(
                      builder: (context, settingProvider, child) {
                        return Row(
                          children: [
                            Expanded(
                              child: _buildButton(
                                'SEND DATA',
                                onPressed: () async {
                                  // หา characteristic ที่ต้องการส่งข้อมูลไป
                                  if (settingProvider.connectedDevice != null) {
                                    // ดึง characteristic ที่สามารถ write ได้
                                    BluetoothCharacteristic? writeCharacteristic;
                                    
                                    for (var serviceEntry in settingProvider.characteristics.entries) {
                                      for (var char in serviceEntry.value) {
                                        if (char.properties.write || char.properties.writeWithoutResponse) {
                                          writeCharacteristic = char;
                                          break;
                                        }
                                      }
                                      if (writeCharacteristic != null) break;
                                    }
                                    
                                    if (writeCharacteristic != null) {
                                      // เตรียมข้อมูลที่จะส่ง (ตัวอย่าง: ส่งคำว่า "HELLO")
                                      String message = "HELLO";
                                      List<int> data = message.codeUnits;
                                      
                                      // ส่งข้อมูล
                                      await settingProvider.writeCharacteristic(writeCharacteristic, data);
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
                                'BTN2',
                                onPressed: () {
                                  print('BTN2 pressed');
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 16),

                    // Center Weight Display
                    Expanded(
                      flex: 2,
                      child: Consumer<SettingProvider>(
                        builder: (context, settingProvider, _) {
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2D3E50), // Dark background
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
                        backgroundColor: const Color(0xFF7FB8C4), // Light blue
                        onPressed: () {
                          print('BTN5 pressed');
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Bottom Row - BTN3 and BTN4
                    Row(
                      children: [
                        Expanded(
                          child: _buildButton(
                            'BTN3',
                            onPressed: () {
                              print('BTN3 pressed');
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Consumer3<DisplayHomeProvider, FormulaProvider, SettingProvider>(
                            builder: (context, displayProvider, formulaProvider, settingProvider, child) {
                              return _buildButton(
                                'SAVE WEIGHT',
                                backgroundColor: Colors.teal,
                                onPressed: () async {
                                  await _insertWeightToBTN4(
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

  // Helper function สำหรับเพิ่ม weight column ลงใน table
  Future<void> _addWeightColumnToTable(
    FormulaProvider formulaProvider,
    String tableName,
  ) async {
    try {
      print('🔧 [BTN4] Attempting to add weight column to table: $tableName');
      
      // วิธีง่ายๆ: ใช้ Provider.of เพื่อเข้าถึง GenericCRUDProvider โดยตรง
      final crudProvider = Provider.of<GenericCRUDProvider>(context, listen: false);
      
      if (crudProvider.database != null) {
        try {
          // ลอง ALTER TABLE เพื่อเพิ่ม weight column
          await crudProvider.database!.execute(
            'ALTER TABLE $tableName ADD COLUMN weight TEXT'
          );
          print('✅ [BTN4] Successfully added weight column');
          
          // เพิ่ม columns เสริม
          try {
            await crudProvider.database!.execute(
              'ALTER TABLE $tableName ADD COLUMN weight_timestamp TEXT'
            );
            await crudProvider.database!.execute(
              'ALTER TABLE $tableName ADD COLUMN weight_device TEXT'
            );
            print('✅ [BTN4] Added additional weight-related columns');
          } catch (e) {
            print('⚠️ [BTN4] Additional columns may already exist: $e');
          }
          
        } catch (e) {
          print('❌ [BTN4] Could not add weight column (may already exist): $e');
          // ไม่ throw error เพราะอาจจะมี column อยู่แล้ว
        }
      } else {
        print('❌ [BTN4] Database not available');
      }
      
    } catch (e) {
      print('❌ [BTN4] Error in _addWeightColumnToTable: $e');
      // ไม่ throw error เพื่อให้ function หลักทำงานต่อได้
    }
  }

  // ฟังก์ชันสำหรับ BTN4 - Insert น้ำหนักโดยอัตโนมัติ (ปรับปรุงใหม่)
  Future<void> _insertWeightToBTN4(
    BuildContext context,
    DisplayHomeProvider displayProvider,
    FormulaProvider formulaProvider,
    SettingProvider settingProvider,
  ) async {
    try {
      print('🔄 [BTN4] Starting weight insertion process...');

      // 1. ตรวจสอบว่าเลือก formula แล้วหรือยัง
      if (displayProvider.isReadonlyMode || !displayProvider.hasValidFormulaSelected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a formula first'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // 2. ตรวจสอบว่ามีข้อมูลน้ำหนักหรือไม่
      if (settingProvider.currentRawValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No weight data available. Please connect device first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final selectedFormulaName = displayProvider.selectedFormula!;
      final weightValue = settingProvider.currentRawValue!;
      final deviceName = settingProvider.connectedDevice?.platformName ?? 'Unknown Device';
      final timestamp = DateTime.now().toIso8601String();

      print('⚖️ [BTN4] Weight value: ${weightValue.toStringAsFixed(2)} kg');
      print('📱 [BTN4] Device: $deviceName');
      print('🕐 [BTN4] Timestamp: $timestamp');

      // 3. ดึงข้อมูล formula
      final formulaDetails = formulaProvider.getFormulaByName(selectedFormulaName);
      
      if (formulaDetails == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Formula not found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final tableName = 'formula_${selectedFormulaName.toLowerCase().replaceAll(' ', '_')}';
      
      print('📋 [BTN4] Table: $tableName');

      // 4. ตรวจสอบ columns ที่มีอยู่ใน table จริง
      final existingColumns = await formulaProvider.getTableColumns(tableName);
      print('🏷️ [BTN4] Existing columns in database: $existingColumns');

      // 5. ตรวจสอบว่ามี weight column หรือไม่
      final hasWeightColumn = existingColumns.any((col) => 
          col.toLowerCase() == 'weight' || 
          col.toLowerCase() == 'weight_kg' || 
          col.toLowerCase() == 'weight_value' ||
          col.toLowerCase().contains('weight')
      );

      print('🔍 [BTN4] Has weight column: $hasWeightColumn');

      // 6. เตรียมข้อมูลสำหรับ insert
      final Map<String, dynamic> dataToInsert = {};

      if (hasWeightColumn) {
        // กรณีมี weight column อยู่แล้ว
        print('✅ [BTN4] Using existing weight column');
        
        // ใส่ข้อมูลตาม column ที่มีอยู่จริง
        for (final columnName in existingColumns) {
          final lowerColumnName = columnName.toLowerCase();
          
          if (lowerColumnName == 'weight' || 
              lowerColumnName == 'weight_kg' || 
              lowerColumnName == 'weight_value' ||
              lowerColumnName.contains('weight')) {
            // ใส่ค่าน้ำหนัก
            dataToInsert[columnName] = weightValue.toString();
            print('⚖️ [BTN4] Inserted weight: $weightValue -> $columnName');
          } else if (lowerColumnName.contains('time') || 
                     lowerColumnName.contains('date') ||
                     lowerColumnName == 'timestamp') {
            // ใส่ timestamp
            dataToInsert[columnName] = timestamp;
            print('🕐 [BTN4] Inserted timestamp -> $columnName');
          } else if (lowerColumnName.contains('device') || 
                     lowerColumnName.contains('source')) {
            // ใส่ชื่อ device
            dataToInsert[columnName] = deviceName;
            print('📱 [BTN4] Inserted device -> $columnName');
          } else if (lowerColumnName != 'id' && 
                     lowerColumnName != 'created_at' && 
                     lowerColumnName != 'updated_at') {
            // ใส่ข้อมูล default สำหรับ column อื่นๆ (ยกเว้น system columns)
            dataToInsert[columnName] = 'Auto-${DateTime.now().millisecondsSinceEpoch}';
            print('📝 [BTN4] Inserted default -> $columnName');
          }
        }
      } else {
        // กรณีไม่มี weight column - ลองเพิ่ม weight column
        print('⚠️ [BTN4] No weight column found. Attempting to add weight column...');
        
        try {
          // ลองเพิ่ม weight column
          await _addWeightColumnToTable(formulaProvider, tableName);
          
          // หลังเพิ่ม column แล้ว ดึง columns ใหม่
          final updatedColumns = await formulaProvider.getTableColumns(tableName);
          print('🔄 [BTN4] Updated columns: $updatedColumns');
          
          // ใส่ข้อมูลตาม column ที่มีอยู่
          for (final columnName in updatedColumns) {
            final lowerColumnName = columnName.toLowerCase();
            
            if (lowerColumnName == 'weight') {
              dataToInsert[columnName] = weightValue.toString();
            } else if (lowerColumnName == 'weight_timestamp') {
              dataToInsert[columnName] = timestamp;
            } else if (lowerColumnName == 'weight_device') {
              dataToInsert[columnName] = deviceName;
            } else if (lowerColumnName != 'id' && 
                       lowerColumnName != 'created_at' && 
                       lowerColumnName != 'updated_at') {
              dataToInsert[columnName] = 'Auto-${DateTime.now().millisecondsSinceEpoch}';
            }
          }
          
          print('✅ [BTN4] Successfully added weight column and prepared data');
          
        } catch (e) {
          // ถ้าเพิ่ม column ไม่ได้ ให้ใส่ข้อมูลตาม column เดิมเท่านั้น
          print('⚠️ [BTN4] Could not add weight column. Using existing columns only: $e');
          
          for (final columnName in existingColumns) {
            final lowerColumnName = columnName.toLowerCase();
            
            if (lowerColumnName.contains('time') || 
                lowerColumnName.contains('date') ||
                lowerColumnName == 'timestamp') {
              dataToInsert[columnName] = timestamp;
            } else if (lowerColumnName.contains('device') || 
                       lowerColumnName.contains('source')) {
              dataToInsert[columnName] = deviceName;
            } else if (lowerColumnName != 'id' && 
                       lowerColumnName != 'created_at' && 
                       lowerColumnName != 'updated_at') {
              // ใส่ค่าน้ำหนักใน column แรกที่ไม่ใช่ system column
              if (dataToInsert.isEmpty || 
                  (existingColumns.indexOf(columnName) == existingColumns.indexWhere((col) => 
                    !['id', 'created_at', 'updated_at'].contains(col.toLowerCase())))) {
                dataToInsert[columnName] = 'Weight: ${weightValue.toString()} kg';
              } else {
                dataToInsert[columnName] = 'Auto-${DateTime.now().millisecondsSinceEpoch}';
              }
            }
          }
        }
      }

      print('💾 [BTN4] Final data to insert: $dataToInsert');

      // 7. Insert ข้อมูลลง database
      final success = await formulaProvider.createRecord(
        tableName: tableName,
        data: dataToInsert,
      );

      // 8. แสดงผลลัพธ์
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Weight ${weightValue.toStringAsFixed(2)} kg saved to $selectedFormulaName!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        print('✅ [BTN4] Weight data saved successfully!');
        print('📊 [BTN4] Weight: ${weightValue.toStringAsFixed(2)} kg');
        print('📋 [BTN4] Formula: $selectedFormulaName');
        
        // Optional: Print table data to verify
        await formulaProvider.printSpecificTable(tableName);
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save weight data'),
            backgroundColor: Colors.red,
          ),
        );
        
        print('❌ [BTN4] Failed to save weight data');
      }

    } catch (e) {
      print('❌ [BTN4] Error in weight insertion: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving weight: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          backgroundColor:
              backgroundColor ?? const Color(0xFF2D3E50), // Default dark color
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 2,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}