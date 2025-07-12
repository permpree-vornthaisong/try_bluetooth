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
    super.dispose();
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

  // 💾 ฟังก์ชันบันทึกน้ำหนักไปที่ weight column
  Future<void> _saveWeightData(
    DisplayHomeProvider displayProvider,
    FormulaProvider formulaProvider,
    SettingProvider settingProvider,
  ) async {
    try {
      print('🔄 [SAVE] Starting weight save...');

      // ตรวจสอบว่าเลือก formula แล้วหรือยัง
      if (displayProvider.selectedFormula == null ||
          displayProvider.selectedFormula ==
              DisplayHomeProvider.readonlyValue) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Please select a formula first'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      // ตรวจสอบว่ามีข้อมูลน้ำหนักหรือไม่
      if (settingProvider.currentRawValue == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ No weight data available'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final selectedFormulaName = displayProvider.selectedFormula!;
      final tableName =
          'formula_${selectedFormulaName.toLowerCase().replaceAll(' ', '_')}';
      final currentWeight = settingProvider.currentRawValue!;

      print('📋 [SAVE] Selected formula: $selectedFormulaName');
      print('📋 [SAVE] Table name: $tableName');
      print('⚖️ [SAVE] Current weight: ${currentWeight.toStringAsFixed(2)} kg');

      // ดึงข้อมูล columns ที่มีอยู่ในตาราง
      final existingColumns = await formulaProvider.getTableColumns(tableName);
      print('🏷️ [SAVE] Existing columns: $existingColumns');

      // ตรวจสอบว่ามี weight column หรือไม่
      bool hasWeightColumn = existingColumns.any(
        (col) => col.toLowerCase().contains('weight'),
      );

      String weightColumnName = 'weight';

      if (!hasWeightColumn) {
        print('➕ [SAVE] No weight column found, adding new column...');

        // เพิ่ม weight column ใหม่
        final addColumnSuccess = await formulaProvider.addColumnToTable(
          tableName,
          'weight',
          'REAL',
        );

        if (!addColumnSuccess) {
          throw Exception('Failed to add weight column');
        }

        print('✅ [SAVE] Weight column added successfully');
        weightColumnName = 'weight';
      } else {
        // หา weight column ที่มีอยู่
        weightColumnName = existingColumns.firstWhere(
          (col) => col.toLowerCase().contains('weight'),
        );
        print('✅ [SAVE] Found existing weight column: $weightColumnName');
      }

      // สร้างข้อมูลสำหรับบันทึก
      final Map<String, dynamic> dataToInsert = {
        weightColumnName: currentWeight,
      };

      print('💾 [SAVE] Data to insert: $dataToInsert');

      // บันทึกลง database
      final success = await formulaProvider.createRecord(
        tableName: tableName,
        data: dataToInsert,
      );

      if (success) {
        print('✅ [SAVE] Weight saved successfully!');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Weight ${currentWeight.toStringAsFixed(2)} kg saved to $selectedFormulaName!',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Database save failed');
      }
    } catch (e) {
      print('❌ [SAVE] Error: $e');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving weight: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
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
                              ],
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SAVE WEIGHT BUTTON (Full width)
                    Consumer3<
                      DisplayHomeProvider,
                      FormulaProvider,
                      SettingProvider
                    >(
                      builder: (
                        context,
                        displayProvider,
                        formulaProvider,
                        settingProvider,
                        _,
                      ) {
                        return SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: _buildButton(
                            'SAVE WEIGHT',
                            backgroundColor: const Color(0xFF4CAF50),
                            onPressed: () async {
                              await _saveWeightData(
                                displayProvider,
                                formulaProvider,
                                settingProvider,
                              );
                            },
                          ),
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
