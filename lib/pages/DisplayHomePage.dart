
// 2. อัพเดท DisplayHomePage.dart - เพิ่ม auto save functionality และ timer

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DisplayHomeProvider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/GenericCRUDProvider.dart';
import 'dart:async'; // เพิ่ม import สำหรับ Timer

class DisplayHomePage extends StatefulWidget {
  const DisplayHomePage({Key? key}) : super(key: key);

  @override
  State<DisplayHomePage> createState() => _DisplayHomePageState();
}

class _DisplayHomePageState extends State<DisplayHomePage> with WidgetsBindingObserver {
  Timer? _autoSaveTimer; // Timer สำหรับ auto save
  static const Duration _autoSaveInterval = Duration(seconds: 1); // เช็คทุก 1 วินาที
  
  // ตัวแปรสำหรับ Auto Save Logic
  List<double> _weightHistory = []; // เก็บประวัติน้ำหนัก 10 ค่าล่าสุด
  static const int _maxHistoryCount = 10; // จำนวนค่าที่เก็บใน history
  bool _hasAutoSavedInThisCycle = false; // เช็คว่าบันทึกไปแล้วหรือยังในรอบนี้
  double? _lastSavedWeight; // น้ำหนักที่บันทึกครั้งสุดท้าย
  int _debugCounter = 0; // ตัวนับสำหรับ debug
  bool _isWeightIncreasing = true; // ตรวจสอบว่าน้ำหนักเพิ่มขึ้นหรือลดลง
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // เพิ่ม observer สำหรับ lifecycle
    
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
    WidgetsBinding.instance.removeObserver(this); // ลบ observer
    _autoSaveTimer?.cancel(); // ยกเลิก timer เมื่อ dispose
    _weightHistory.clear(); // ล้าง history
    super.dispose();
  }

  // ฟังก์ชันที่จะทำงานเมื่อ app state เปลี่ยน (เช่น สลับหน้า)
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

  // ฟังก์ชันตรวจสอบและรีสตาร์ท auto save หากจำเป็น
  void _checkAndRestartAutoSave() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final displayProvider = Provider.of<DisplayHomeProvider>(context, listen: false);
        
        print('🔍 [AUTO SAVE] Checking status...');
        print('   Auto Save Mode: ${displayProvider.isAutoSaveMode}');
        print('   Timer Active: ${_autoSaveTimer?.isActive ?? false}');
        
        if (displayProvider.isAutoSaveMode && (_autoSaveTimer == null || !_autoSaveTimer!.isActive)) {
          print('🔧 [AUTO SAVE] Mode is ON but timer is inactive - restarting...');
          
          // รีสตาร์ท auto save
          _startAutoSave();
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🔄 Auto Save restarted'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 1),
              ),
            );
          }
        } else if (!displayProvider.isAutoSaveMode && (_autoSaveTimer?.isActive ?? false)) {
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

  // ฟังก์ชันตรวจสอบว่าน้ำหนักพร้อมสำหรับ save หรือไม่
  bool _isReadyToSave() {
    if (_weightHistory.length < _maxHistoryCount) {
      print('📊 [AUTO SAVE] Not enough data: ${_weightHistory.length}/$_maxHistoryCount');
      return false; // ต้องมีข้อมูลครบ 10 ค่าก่อน
    }

    // หาค่าที่ปรากฏบ่อยที่สุด (mode) หรือค่าที่นิ่งที่สุด
    Map<double, int> weightCount = {};
    for (double weight in _weightHistory) {
      // ปัดเศษให้เป็นทศนิยม 1 ตำแหน่งเพื่อหาค่าที่ใกล้เคียงกัน
      double roundedWeight = double.parse(weight.toStringAsFixed(1));
      weightCount[roundedWeight] = (weightCount[roundedWeight] ?? 0) + 1;
    }

    // หาค่าที่ปรากฏบ่อยที่สุด
    double mostStableWeight = 0.0;
    int maxCount = 0;
    
    weightCount.forEach((weight, count) {
      if (count > maxCount) {
        maxCount = count;
        mostStableWeight = weight;
      }
    });

    print('🔍 [AUTO SAVE] Stability Analysis (#${_debugCounter}):');
    print('   History: ${_weightHistory.map((w) => w.toStringAsFixed(2)).join(', ')}');
    print('   Weight frequencies: $weightCount');
    print('   Most stable weight: ${mostStableWeight.toStringAsFixed(1)} kg (appeared $maxCount times)');
    print('   Cycle Status: ${_hasAutoSavedInThisCycle ? "SAVED" : "READY"}');

    // ถ้ามีค่าที่ปรากฏ 3 ครั้งขึ้นไปใน 10 ค่าล่าสุด ถือว่านิ่ง
    if (maxCount >= 3 && !_hasAutoSavedInThisCycle && mostStableWeight > 0.1) {
      print('✅ [AUTO SAVE] Found stable weight: ${mostStableWeight.toStringAsFixed(1)} kg (${maxCount}/$_maxHistoryCount times)');
      _lastSavedWeight = mostStableWeight; // เก็บค่าที่จะ save
      return true;
    }

    return false;
  }

  // ฟังก์ชันเพิ่มน้ำหนักลงใน history
  void _addWeightToHistory(double weight) {
    _weightHistory.add(weight);
    
    // เก็บแค่ 10 ค่าล่าสุด
    if (_weightHistory.length > _maxHistoryCount) {
      _weightHistory.removeAt(0);
    }

    print('📊 [AUTO SAVE] Added weight: ${weight.toStringAsFixed(2)} kg (${_weightHistory.length}/$_maxHistoryCount)');
  }

  // ฟังก์ชันรีเซ็ต cycle เมื่อน้ำหนักกลับไปที่ 0
  void _resetAutoSaveCycle() {
    print('🔄 [AUTO SAVE] CYCLE RESET TRIGGERED');
    print('   Previous history: ${_weightHistory.map((w) => w.toStringAsFixed(2)).join(', ')}');
    print('   Previous saved: $_hasAutoSavedInThisCycle');
    print('   Last saved weight: ${_lastSavedWeight?.toStringAsFixed(2) ?? "None"}');
    
    _weightHistory.clear();
    _hasAutoSavedInThisCycle = false;
    _lastSavedWeight = null;
    _debugCounter = 0;
    _isWeightIncreasing = true;
    
    print('✅ [AUTO SAVE] Cycle reset complete - ready for new measurements');
  }

  // ฟังก์ชันเริ่มต้น auto save
  void _startAutoSave() {
    _autoSaveTimer?.cancel(); // ยกเลิก timer เดิมก่อน (ถ้ามี)
    
    // รีเซ็ต state และ debug counter
    _weightHistory.clear();
    _hasAutoSavedInThisCycle = false;
    _lastSavedWeight = null;
    _debugCounter = 0;
    _isWeightIncreasing = true;
    
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) async {
      _debugCounter++;
      
      final displayProvider = Provider.of<DisplayHomeProvider>(context, listen: false);
      final formulaProvider = Provider.of<FormulaProvider>(context, listen: false);
      final settingProvider = Provider.of<SettingProvider>(context, listen: false);
      
      // ตรวจสอบว่ายังอยู่ใน auto save mode หรือไม่
      if (!displayProvider.isAutoSaveMode) {
        print('🛑 [AUTO SAVE] Mode disabled, stopping timer');
        timer.cancel();
        return;
      }

      // ตรวจสอบเงื่อนไขพื้นฐาน
      if (!displayProvider.hasValidFormulaSelected) {
        print('❌ [AUTO SAVE] No valid formula selected (#${_debugCounter})');
        return;
      }
      
      if (settingProvider.currentRawValue == null) {
        print('❌ [AUTO SAVE] No weight data available (#${_debugCounter})');
        return;
      }

      final currentWeight = settingProvider.currentRawValue!;
      print('\n🔄 [AUTO SAVE] Check #${_debugCounter} - Current weight: ${currentWeight.toStringAsFixed(3)} kg');
      
      // ตรวจสอบว่าน้ำหนักกลับไปที่ 0 หรือใกล้ 0 (รีเซ็ต cycle)
      if (currentWeight <= 0.1) {
        if (_weightHistory.isNotEmpty || _hasAutoSavedInThisCycle) {
          _resetAutoSaveCycle();
        } else {
          print('⚪ [AUTO SAVE] Weight at zero, no reset needed');
        }
        return;
      }

      // เพิ่มน้ำหนักปัจจุบันลงใน history
      _addWeightToHistory(currentWeight);

      // ตรวจสอบว่าบันทึกไปแล้วหรือยังในรอบนี้
      if (_hasAutoSavedInThisCycle) {
        print('⏸️ [AUTO SAVE] Already saved in this cycle (last: ${_lastSavedWeight?.toStringAsFixed(2)}), waiting for reset...');
        return;
      }

      // ตรวจสอบว่าพร้อม save หรือไม่ (ค่าที่นิ่งที่สุดจาก 10 ค่า)
      if (_isReadyToSave()) {
        print('✅ [AUTO SAVE] Found stable weight! Attempting to save...');
        
        try {
          // บันทึกน้ำหนัก (ใช้ค่าที่นิ่งที่สุดที่หาได้)
          await _insertWeightToBTN4(
            context,
            displayProvider,
            formulaProvider,
            settingProvider,
            isAutoSave: true,
            weightToSave: _lastSavedWeight, // ส่งค่าที่นิ่งที่สุด
          );
          
          // ทำเครื่องหมายว่าบันทึกแล้วในรอบนี้
          _hasAutoSavedInThisCycle = true;
          
          print('💾 [AUTO SAVE] SAVE SUCCESSFUL!');
          print('   Saved weight: ${_lastSavedWeight?.toStringAsFixed(2)} kg (most stable value)');
          print('   Cycle locked until weight returns to zero');
          
          // แสดง notification แบบไม่ aggressive
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '🔄 Auto saved: ${_lastSavedWeight?.toStringAsFixed(2)} kg (stable)',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 1),
              ),
            );
          }
          
        } catch (e) {
          print('❌ [AUTO SAVE] SAVE FAILED: $e');
          // ไม่ทำเครื่องหมายว่าบันทึกแล้ว ให้ลองใหม่ในครั้งต่อไป
        }
      } else {
        print('⏳ [AUTO SAVE] Not ready to save yet (need stable weight from 10 readings)...');
      }
    });
    
    print('🟢 [AUTO SAVE] Started with stable weight detection');
    print('📋 [AUTO SAVE] Configuration:');
    print('   - Check interval: ${_autoSaveInterval.inSeconds} second(s)');
    print('   - History size: ${_maxHistoryCount} readings');
    print('   - Save when: Most stable weight found (3+ occurrences in 10 readings)');
    print('   - Reset when: Weight returns to near zero');
  }

  // ฟังก์ชันหยุด auto save
  void _stopAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = null;
    
    // รีเซ็ต state และ debug counter
    _weightHistory.clear();
    _hasAutoSavedInThisCycle = false;
    _lastSavedWeight = null;
    _debugCounter = 0;
    _isWeightIncreasing = true;
    
    print('🔴 [AUTO SAVE] Stopped and reset all states');
  }

  @override
  Widget build(BuildContext context) {
    // เรียกฟังก์ชันเช็ค auto save status เมื่อ build widget
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
                            !availableItems.any(
                              (item) => item['value'] == currentValue,
                            )) {
                          validValue = DisplayHomeProvider.readonlyValue;
                          // Reset ค่าใน provider
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
                                'TARE',
                                onPressed: () async {
                                  // หา characteristic ที่ต้องการส่งข้อมูลไป
                                  if (settingProvider.connectedDevice != null) {
                                    // ดึง characteristic ที่สามารถ write ได้
                                    BluetoothCharacteristic? writeCharacteristic;

                                    for (var serviceEntry
                                        in settingProvider.characteristics.entries) {
                                      for (var char in serviceEntry.value) {
                                        if (char.properties.write ||
                                            char.properties.writeWithoutResponse) {
                                          writeCharacteristic = char;
                                          break;
                                        }
                                      }
                                      if (writeCharacteristic != null) break;
                                    }

                                    if (writeCharacteristic != null) {
                                      // เตรียมข้อมูลที่จะส่ง (ตัวอย่าง: ส่งคำว่า "HELLO")
                                      String message = "TARE";
                                      List<int> data = message.codeUnits;

                                      // ส่งข้อมูล
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
                                  // หา characteristic ที่ต้องการส่งข้อมูลไป
                                  if (settingProvider.connectedDevice != null) {
                                    // ดึง characteristic ที่สามารถ write ได้
                                    BluetoothCharacteristic? writeCharacteristic;

                                    for (var serviceEntry
                                        in settingProvider.characteristics.entries) {
                                      for (var char in serviceEntry.value) {
                                        if (char.properties.write ||
                                            char.properties.writeWithoutResponse) {
                                          writeCharacteristic = char;
                                          break;
                                        }
                                      }
                                      if (writeCharacteristic != null) break;
                                    }

                                    if (writeCharacteristic != null) {
                                      // เตรียมข้อมูลที่จะส่ง (ตัวอย่าง: ส่งคำว่า "HELLO")
                                      String message = "ZERO";
                                      List<int> data = message.codeUnits;

                                      // ส่งข้อมูล
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
                                      ? settingProvider.currentRawValue!.toStringAsFixed(1)
                                      : '0.0',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 64,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                // แสดงสถานะ Auto Save (ถ้าเปิดอยู่)
                                Consumer<DisplayHomeProvider>(
                                  builder: (context, displayProvider, _) {
                                    if (displayProvider.isAutoSaveMode) {
                                      return Container(
                                        margin: const EdgeInsets.only(top: 16),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(0.5),
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _autoSaveTimer?.isActive == true 
                                                    ? Icons.autorenew 
                                                    : Icons.warning,
                                                  size: 16,
                                                  color: _autoSaveTimer?.isActive == true 
                                                    ? Colors.green[300]
                                                    : Colors.orange[300],
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _autoSaveTimer?.isActive == true 
                                                    ? 'AUTO SAVE ON' 
                                                    : 'AUTO SAVE PAUSED',
                                                  style: TextStyle(
                                                    color: _autoSaveTimer?.isActive == true 
                                                      ? Colors.green[300]
                                                      : Colors.orange[300],
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            // แสดงสถานะเพิ่มเติม
                                            if (_weightHistory.isNotEmpty || _hasAutoSavedInThisCycle)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 2),
                                                child: Text(
                                                  _hasAutoSavedInThisCycle 
                                                    ? 'Saved! Waiting for reset...'
                                                    : _autoSaveTimer?.isActive == true
                                                      ? 'Monitoring (${_weightHistory.length}/$_maxHistoryCount)'
                                                      : 'Timer inactive - tap to restart',
                                                  style: TextStyle(
                                                    color: _autoSaveTimer?.isActive == true 
                                                      ? Colors.green[200]
                                                      : Colors.orange[200],
                                                    fontSize: 10,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
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

                    // Bottom Row - AUTO SAVE และ CLICK SAVE WEIGHT
                    Consumer<DisplayHomeProvider>(
                      builder: (context, displayProvider, child) {
                        return Row(
                          children: [
                                // AUTO SAVE Button
                            Expanded(
                              child: GestureDetector(
                                // เพิ่ม gesture detector เพื่อให้สามารถแตะ restart ได้
                                onLongPress: () {
                                  final displayProvider = Provider.of<DisplayHomeProvider>(context, listen: false);
                                  if (displayProvider.isAutoSaveMode && (_autoSaveTimer == null || !_autoSaveTimer!.isActive)) {
                                    print('🔄 [MANUAL] Force restarting auto save...');
                                    _startAutoSave();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('🔄 Auto Save force restarted'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                                child: _buildButton(
                                  displayProvider.isAutoSaveMode 
                                      ? 'STOP AUTO SAVE' 
                                      : 'START AUTO SAVE',
                                  backgroundColor: displayProvider.isAutoSaveMode 
                                      ? Colors.orange 
                                      : Colors.blue,
                                  onPressed: () {
                                    if (displayProvider.isAutoSaveMode) {
                                      // หยุด auto save
                                      displayProvider.setAutoSaveMode(false);
                                      _stopAutoSave();
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Auto Save stopped'),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    } else {
                                      // ตรวจสอบเงื่อนไขก่อนเริ่ม auto save
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
                                      _startAutoSave();
                                      
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Auto Save started - will save the most stable weight from 10 readings',
                                          ),
                                          backgroundColor: Colors.green,
                                          duration: const Duration(seconds: 3),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
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
                                  final isDisabled = displayProvider.isAutoSaveMode;
                                  
                                  return _buildButton(
                                    'CLICK SAVE WEIGHT',
                                    backgroundColor: isDisabled 
                                        ? Colors.grey 
                                        : Colors.teal,
                                    onPressed: isDisabled 
                                        ? null 
                                        : () async {
                                            await _insertWeightToBTN4(
                                              context,
                                              displayProvider,
                                              formulaProvider,
                                              settingProvider,
                                              isAutoSave: false,
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

  // Helper function สำหรับเพิ่ม weight column ลงใน table
  Future<void> _addWeightColumnToTable(
    FormulaProvider formulaProvider,
    String tableName,
  ) async {
    try {
      print('🔧 [BTN4] Attempting to add weight column to table: $tableName');

      // วิธีง่ายๆ: ใช้ Provider.of เพื่อเข้าถึง GenericCRUDProvider โดยตรง
      final crudProvider = Provider.of<GenericCRUDProvider>(
        context,
        listen: false,
      );

      if (crudProvider.database != null) {
        try {
          // ลอง ALTER TABLE เพื่อเพิ่ม weight column
          await crudProvider.database!.execute(
            'ALTER TABLE $tableName ADD COLUMN weight TEXT',
          );
          print('✅ [BTN4] Successfully added weight column');

          // เพิ่ม columns เสริม
          try {
            // await crudProvider.database!.execute(
            //   'ALTER TABLE $tableName ADD COLUMN weight_timestamp TEXT'
            // );
            // await crudProvider.database!.execute(
            //   'ALTER TABLE $tableName ADD COLUMN weight_device TEXT'
            // );
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
    SettingProvider settingProvider, {
    bool isAutoSave = false, // เพิ่ม parameter เพื่อระบุว่าเป็น auto save หรือไม่
    double? weightToSave, // เพิ่ม parameter สำหรับน้ำหนักที่จะ save (สำหรับ auto save)
  }) async {
    try {
      final saveType = isAutoSave ? 'AUTO SAVE' : 'MANUAL SAVE';
      print('🔄 [$saveType] Starting weight insertion process...');

      // 1. ตรวจสอบว่าเลือก formula แล้วหรือยัง
      if (displayProvider.isReadonlyMode ||
          !displayProvider.hasValidFormulaSelected) {
        if (!isAutoSave) { // แสดง snackbar เฉพาะ manual save
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a formula first'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // 2. ตรวจสอบว่ามีข้อมูลน้ำหนักหรือไม่
      if (settingProvider.currentRawValue == null) {
        if (!isAutoSave) { // แสดง snackbar เฉพาะ manual save
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No weight data available. Please connect device first.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final selectedFormulaName = displayProvider.selectedFormula!;
      // ใช้น้ำหนักที่ส่งมา (สำหรับ auto save) หรือน้ำหนักปัจจุบัน (สำหรับ manual save)
      final weightValue = weightToSave ?? settingProvider.currentRawValue!;
      final deviceName =
          settingProvider.connectedDevice?.platformName ?? 'Unknown Device';
      final timestamp = DateTime.now().toIso8601String();

      print('⚖️ [$saveType] Weight value: ${weightValue.toStringAsFixed(2)} kg');
      print('📱 [$saveType] Device: $deviceName');
      print('🕐 [$saveType] Timestamp: $timestamp');
      if (isAutoSave && weightToSave != null) {
        print('📌 [$saveType] Using stable weight: ${weightValue.toStringAsFixed(2)} kg (not current)');
      }

      // 3. ดึงข้อมูล formula
      final formulaDetails = formulaProvider.getFormulaByName(
        selectedFormulaName,
      );

      if (formulaDetails == null) {
        if (!isAutoSave) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Formula not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final tableName =
          'formula_${selectedFormulaName.toLowerCase().replaceAll(' ', '_')}';

      print('📋 [$saveType] Table: $tableName');

      // 4. ตรวจสอบ columns ที่มีอยู่ใน table จริง
      final existingColumns = await formulaProvider.getTableColumns(tableName);
      print('🏷️ [$saveType] Existing columns in database: $existingColumns');

      // 5. ตรวจสอบว่ามี weight column หรือไม่
      final hasWeightColumn = existingColumns.any(
        (col) =>
            col.toLowerCase() == 'weight' ||
            col.toLowerCase() == 'weight_kg' ||
            col.toLowerCase() == 'weight_value' ||
            col.toLowerCase().contains('weight'),
      );

      print('🔍 [$saveType] Has weight column: $hasWeightColumn');

      // 6. เตรียมข้อมูลสำหรับ insert
      final Map<String, dynamic> dataToInsert = {};

      if (hasWeightColumn) {
        // กรณีมี weight column อยู่แล้ว
        print('✅ [$saveType] Using existing weight column');

        // ใส่ข้อมูลตาม column ที่มีอยู่จริง
        for (final columnName in existingColumns) {
          final lowerColumnName = columnName.toLowerCase();

          if (lowerColumnName == 'weight' ||
              lowerColumnName == 'weight_kg' ||
              lowerColumnName == 'weight_value' ||
              lowerColumnName.contains('weight')) {
            // ใส่ค่าน้ำหนัก
            dataToInsert[columnName] = weightValue.toString();
            print('⚖️ [$saveType] Inserted weight: $weightValue -> $columnName');
          } else if (lowerColumnName.contains('time') ||
              lowerColumnName.contains('date') ||
              lowerColumnName == 'timestamp') {
            // ใส่ timestamp
            dataToInsert[columnName] = timestamp;
            print('🕐 [$saveType] Inserted timestamp -> $columnName');
          } else if (lowerColumnName.contains('device') ||
              lowerColumnName.contains('source')) {
            // ใส่ชื่อ device
            dataToInsert[columnName] = deviceName;
            print('📱 [$saveType] Inserted device -> $columnName');
          } else if (lowerColumnName != 'id' &&
              lowerColumnName != 'created_at' &&
              lowerColumnName != 'updated_at') {
            // ใส่ข้อมูล default สำหรับ column อื่นๆ (ยกเว้น system columns)
            dataToInsert[columnName] =
                'Auto-${DateTime.now().millisecondsSinceEpoch}';
            print('📝 [$saveType] Inserted default -> $columnName');
          }
        }
      } else {
        // กรณีไม่มี weight column - ลองเพิ่ม weight column
        print(
          '⚠️ [$saveType] No weight column found. Attempting to add weight column...',
        );

        try {
          // ลองเพิ่ม weight column
          await _addWeightColumnToTable(formulaProvider, tableName);

          // หลังเพิ่ม column แล้ว ดึง columns ใหม่
          final updatedColumns = await formulaProvider.getTableColumns(
            tableName,
          );
          print('🔄 [$saveType] Updated columns: $updatedColumns');

          // ใส่ข้อมูลตาม column ที่มีอยู่
          for (final columnName in updatedColumns) {
            final lowerColumnName = columnName.toLowerCase();

            if (lowerColumnName == 'weight') {
              dataToInsert[columnName] = weightValue.toString();
            } else if (lowerColumnName == 'weight_timestamp') {
              // dataToInsert[columnName] = timestamp;
            } else if (lowerColumnName == 'weight_device') {
              // dataToInsert[columnName] = deviceName;
            } else if (lowerColumnName != 'id' &&
                lowerColumnName != 'created_at' &&
                lowerColumnName != 'updated_at') {
              dataToInsert[columnName] =
                  'Auto-${DateTime.now().millisecondsSinceEpoch}';
            }
          }

          print('✅ [$saveType] Successfully added weight column and prepared data');
        } catch (e) {
          // ถ้าเพิ่ม column ไม่ได้ ให้ใส่ข้อมูลตาม column เดิมเท่านั้น
          print(
            '⚠️ [$saveType] Could not add weight column. Using existing columns only: $e',
          );

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
                  (existingColumns.indexOf(columnName) ==
                      existingColumns.indexWhere(
                        (col) =>
                            ![
                              'id',
                              'created_at',
                              'updated_at',
                            ].contains(col.toLowerCase()),
                      ))) {
                dataToInsert[columnName] =
                    'Weight: ${weightValue.toString()} kg';
              } else {
                dataToInsert[columnName] =
                    'Auto-${DateTime.now().millisecondsSinceEpoch}';
              }
            }
          }
        }
      }

      print('💾 [$saveType] Final data to insert: $dataToInsert');

      // 7. Insert ข้อมูลลง database
      final success = await formulaProvider.createRecord(
        tableName: tableName,
        data: dataToInsert,
      );

      // 8. แสดงผลลัพธ์
      if (success) {
        if (!isAutoSave) { // แสดง snackbar เฉพาะ manual save
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Weight ${weightValue.toStringAsFixed(2)} kg saved to $selectedFormulaName!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        print('✅ [$saveType] Weight data saved successfully!');
        print('📊 [$saveType] Weight: ${weightValue.toStringAsFixed(2)} kg');
        print('📋 [$saveType] Formula: $selectedFormulaName');

        // Optional: Print table data to verify (เฉพาะ manual save)
        if (!isAutoSave) {
          await formulaProvider.printSpecificTable(tableName);
        }
      } else {
        if (!isAutoSave) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save weight data'),
              backgroundColor: Colors.red,
            ),
          );
        }

        print('❌ [$saveType] Failed to save weight data');
      }
    } catch (e) {
    

      if (!isAutoSave) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving weight: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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