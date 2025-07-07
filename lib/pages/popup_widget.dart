import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SettingProvider.dart';
import '../providers/CalibrationProvider.dart';
import '../providers/DisplayProvider.dart';

class PopupWidget extends StatelessWidget {
  final VoidCallback? onTarePressed;
  final VoidCallback? onZeroPressed;
  final VoidCallback? onCalibrationPressed;
  final String currentWeight;
  
  const PopupWidget({
    super.key,
    this.onTarePressed,
    this.onZeroPressed,
    this.onCalibrationPressed,
    this.currentWeight = '0.0',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การควบคุมเครื่องชั่ง'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header Tabs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
              ),
              child: Row(
                children: [
                  // ปุ่มกำหนด
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'ปุ่มกำหนด',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // ปรับโรงงาน
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'ปรับโรงงาน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // สถานะการเชื่อมต่อ
                  Expanded(
                    child: Consumer<SettingProvider>(
                      builder: (context, settingProvider, child) {
                        bool isConnected = settingProvider.connectedDevice != null;
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isConnected ? Colors.green.shade300 : Colors.red.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                isConnected 
                                    ? Icons.bluetooth_connected 
                                    : Icons.bluetooth_disabled,
                                color: isConnected ? Colors.green : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isConnected ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isConnected ? Colors.green.shade800 : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left Side - Control Buttons
                    SizedBox(
                      width: 120,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Tare Button
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<DisplayProvider>(
                              builder: (context, displayProvider, child) {
                                return ElevatedButton(
                                  onPressed: onTarePressed ?? () {
                                    // ใช้ Provider ถ้าไม่มี callback
                                    displayProvider.clearTare();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Tare ล้างค่าแล้ว'),
                                        backgroundColor: Colors.blue,
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: displayProvider.tareOffset != 0.0 
                                        ? Colors.orange.shade100 
                                        : Colors.blue.shade100,
                                    foregroundColor: displayProvider.tareOffset != 0.0 
                                        ? Colors.orange.shade800 
                                        : Colors.blue.shade800,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    displayProvider.tareOffset != 0.0 ? 'Clear Tare' : 'Tare',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Zero Button
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<SettingProvider>(
                              builder: (context, settingProvider, child) {
                                return ElevatedButton(
                                  onPressed: onZeroPressed ?? () {
                                    // ส่งคำสั่ง Zero ไป ESP32
                                    if (settingProvider.connectedDevice != null) {
                                      // ส่งคำสั่ง zero ผ่าน BLE
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('ส่งคำสั่ง Zero แล้ว'),
                                          backgroundColor: Colors.orange,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('ไม่ได้เชื่อมต่ออุปกรณ์'),
                                          backgroundColor: Colors.red,
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: settingProvider.connectedDevice != null 
                                        ? Colors.orange.shade100 
                                        : Colors.grey.shade200,
                                    foregroundColor: settingProvider.connectedDevice != null 
                                        ? Colors.orange.shade800 
                                        : Colors.grey.shade600,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Zero',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Calibration Button
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<CalibrationProvider>(
                              builder: (context, calibrationProvider, child) {
                                return ElevatedButton(
                                  onPressed: onCalibrationPressed ?? () {
                                    // ไปหน้าปรับเทียบ
                                    Navigator.pushNamed(context, '/calibration');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: calibrationProvider.isCalibrated 
                                        ? Colors.green.shade100 
                                        : Colors.yellow.shade100,
                                    foregroundColor: calibrationProvider.isCalibrated 
                                        ? Colors.green.shade800 
                                        : Colors.yellow.shade800,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    calibrationProvider.isCalibrated 
                                        ? 'ปรับเทียบแล้ว\n(${calibrationProvider.calibrationPoints.length})' 
                                        : 'ปรับเทียบ\nเซนเซอร์',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Right Side - Weight Display
                    Expanded(
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Weight Icon
                            Icon(
                              Icons.scale,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Weight Value - ใช้ Consumer แสดงน้ำหนักแบบ real-time
                            Consumer2<DisplayProvider, SettingProvider>(
                              builder: (context, displayProvider, settingProvider, child) {
                                // ใช้ข้อมูลจาก SettingProvider เหมือน CalibrationZeroPage
                                double? rawValue = settingProvider.currentRawValue;
                                String displayWeight = currentWeight;
                                
                                // ถ้ามีข้อมูลจาก Provider ใช้แทน
                                if (displayProvider.hasValidWeight) {
                                  // ดึงน้ำหนักจาก DisplayProvider และปรับเป็นค่าบวก
                                  double weight = displayProvider.netWeight ?? 0.0;
                                  // ถ้าน้อยกว่า 0 หรือ -0 ให้แสดง 0
                                  if (weight <= 0.0) {
                                    displayWeight = "0.0";
                                  } else {
                                    displayWeight = weight.abs().toStringAsFixed(1);
                                  }
                                } else if (rawValue != null) {
                                  // ถ้าน้อยกว่า 0 หรือ -0 ให้แสดง 0
                                  if (rawValue <= 0.0) {
                                    displayWeight = "0.0";
                                  } else {
                                    displayWeight = rawValue.abs().toStringAsFixed(1);
                                  }
                                }
                                
                                return Text(
                                  displayWeight,
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color: rawValue != null 
                                        ? Colors.blue.shade800 
                                        : Colors.grey.shade800,
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: 8),
                            
                            // kg Unit
                            Text(
                              'kg',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Status Text
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'น้ำหนักปัจจุบัน',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

// Helper function สำหรับแสดงสถานะการเชื่อมต่อ (ตาม CalibrationZeroPage)
Widget buildConnectionStatus(BuildContext context, {
  SettingProvider? settingProvider,
  String connectionStatus = 'Disconnected',
  String deviceName = 'No Device',
  bool isConnected = false,
  bool isCalibrated = false,
  int calibrationPointsCount = 0,
}) {
  // ถ้าส่ง settingProvider มาใช้ข้อมูลจริง
  if (settingProvider != null) {
    isConnected = settingProvider.connectedDevice != null;
    connectionStatus = settingProvider.connectionStatus;
    if (isConnected) {
      deviceName = settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!);
    }
  }

  return Card(
    margin: const EdgeInsets.all(8),
    color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Connection Status
          Icon(
            isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
            color: isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected 
                      ? 'เชื่อมต่อ: $deviceName'
                      : 'ยังไม่ได้เชื่อมต่อ Bluetooth',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isConnected ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
                if (isConnected)
                  Text(
                    'Status: $connectionStatus',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          // Calibration Status
          if (isCalibrated) ...[
            const SizedBox(width: 16),
            Icon(
              Icons.check_circle,
              color: Colors.green,
            ),
            const SizedBox(width: 4),
            Text(
              'Calibrated ($calibrationPointsCount)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

// ตัวอย่างการใช้งาน
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PopupWidget(
                  // currentWeight: '75.5',
                  onTarePressed: () {
                    print('Tare pressed');
                    // Provider logic จะใส่ที่นี่
                  },
                  onZeroPressed: () {
                    print('Zero pressed');
                    // Provider logic จะใส่ที่นี่
                  },
                  onCalibrationPressed: () {
                    print('Calibration pressed');
                    // Provider logic จะใส่ที่นี่
                  },
                ),
              ),
            );
          },
          child: const Text('Go to Control Page'),
        ),
      ),
    );
  }
}