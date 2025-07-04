import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/calibration_easy_provider.dart';

// UI สำหรับ Set Zero Calibration
class CalibrationZeroPage extends StatefulWidget {
  @override
  _CalibrationZeroPageState createState() => _CalibrationZeroPageState();
}

class _CalibrationZeroPageState extends State<CalibrationZeroPage> {
  // ✅ ลบ initState ออก เพราะ Provider เชื่อมต่อกันแล้วที่ main.dart
  // @override
  // void initState() {
  //   super.initState();
  //   // ไม่ต้องเชื่อมต่อ Provider แล้ว
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set Zero Calibration'),
       
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          physics: BouncingScrollPhysics(),
          child: Consumer2<SettingProvider, CalibrationEasy>(
            builder: (context, settingProvider, calibrationProvider, child) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ✅ 1. แสดงสถานะการเชื่อมต่อ Bluetooth
                  _buildConnectionStatus(settingProvider),
                  SizedBox(height: 20),
      
                  // ✅ 2. แสดง Raw Value ปัจจุบัน
                  _buildCurrentRawValue(settingProvider),
                  SizedBox(height: 20),
      
                  // ✅ 3. แสดงสถานะ Calibration
                  _buildCalibrationStatus(calibrationProvider),
                  SizedBox(height: 20),
      
                  // ✅ 4. ปุ่ม Set Zero
                  _buildSetZeroButton(settingProvider, calibrationProvider),
                  SizedBox(height: 20),
      
                  // ✅ 5. Progress Bar (แสดงเมื่อกำลัง collect)
                  if (calibrationProvider.isCollecting)
                    _buildProgressIndicator(calibrationProvider),
      
                  SizedBox(height: 20),
      
                  // ✅ 6. แสดงข้อมูล Debug
                  _buildDebugInfo(settingProvider, calibrationProvider),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // 1. สถานะการเชื่อมต่อ Bluetooth
  Widget _buildConnectionStatus(SettingProvider settingProvider) {
    bool isConnected = settingProvider.connectedDevice != null;

    return Card(
      color: isConnected ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: isConnected ? Colors.green : Colors.red,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                isConnected
                    ? 'เชื่อมต่อ: ${settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!)}'
                    : 'ยังไม่ได้เชื่อมต่อ Bluetooth',
                style: TextStyle(
                  color:
                      isConnected ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. แสดง Raw Value ปัจจุบัน
  Widget _buildCurrentRawValue(SettingProvider settingProvider) {
    double? rawValue = settingProvider.currentRawValue;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Raw Value ปัจจุบัน:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    rawValue != null
                        ? Colors.blue.shade50
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: rawValue != null ? Colors.blue : Colors.grey,
                ),
              ),
              child: Text(
                rawValue != null ? rawValue.toStringAsFixed(6) : 'ไม่มีข้อมูล',
                style: TextStyle(
                  fontSize: 20,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  color:
                      rawValue != null
                          ? Colors.blue.shade700
                          : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'ข้อมูลดิบ: "${settingProvider.lastRawText}"',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 3. สถานะ Calibration
  Widget _buildCalibrationStatus(CalibrationEasy calibrationProvider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'สถานะ Calibration:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              calibrationProvider.statusMessage,
              style: TextStyle(
                fontSize: 14,
                color:
                    calibrationProvider.isCalibrated
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
              ),
            ),
            if (calibrationProvider.zeroPoint != null) ...[
              SizedBox(height: 8),
              Text(
                'Zero Point: ${calibrationProvider.zeroPoint!.toStringAsFixed(6)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 4. ปุ่ม Set Zero
  Widget _buildSetZeroButton(
    SettingProvider settingProvider,
    CalibrationEasy calibrationProvider,
  ) {
    bool canSetZero =
        settingProvider.connectedDevice != null &&
        settingProvider.currentRawValue != null &&
        !calibrationProvider.isCollecting;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed:
              canSetZero
                  ? () async {
                    // ✅ เรียกใช้ calibrationFirst_0kg
                    await calibrationProvider.calibrationFirst_0kg();

                    // แสดง SnackBar
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('เริ่มการ Set Zero แล้ว'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  }
                  : null,
          icon: Icon(
            calibrationProvider.isCollectingZero
                ? Icons.stop
                : Icons.exposure_zero,
          ),
          label: Text(
            calibrationProvider.isCollectingZero
                ? 'กำลัง Collect ข้อมูล 0 kg...'
                : 'Set Zero (0 kg)',
            style: TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.symmetric(vertical: 16),
            backgroundColor:
                calibrationProvider.isCollectingZero
                    ? Colors.orange
                    : Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        SizedBox(height: 8),

        // ปุ่มยกเลิก (แสดงเมื่อกำลัง collect)
        if (calibrationProvider.isCollecting)
          OutlinedButton.icon(
            onPressed: () {
              calibrationProvider.cancelCollection();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ยกเลิกการ Collect ข้อมูลแล้ว'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            icon: Icon(Icons.cancel),
            label: Text('ยกเลิก'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),

        // ✅ เพิ่มปุ่ม Reset Calibration
        SizedBox(height: 8),
        if (calibrationProvider.zeroPoint != null &&
            !calibrationProvider.isCollecting)
          OutlinedButton.icon(
            onPressed: () async {
              // แสดง Confirmation Dialog
              bool confirm = await _showResetConfirmDialog(context);
              if (confirm) {
                await calibrationProvider.resetCalibration();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('รีเซ็ต Calibration แล้ว'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            icon: Icon(Icons.refresh, color: Colors.red),
            label: Text(
              'Reset Calibration',
              style: TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: Colors.red),
            ),
          ),
      ],
    );
  }

  // ✅ เพิ่ม Confirmation Dialog สำหรับ Reset
  Future<bool> _showResetConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('ยืนยันการรีเซ็ต'),
              content: Text(
                'คุณต้องการรีเซ็ต Calibration ใช่หรือไม่?\nข้อมูล Zero Point และ Reference Point จะถูกลบทั้งหมด',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: Text('รีเซ็ต', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // 5. Progress Bar
  Widget _buildProgressIndicator(CalibrationEasy calibrationProvider) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'กำลัง Collect ข้อมูล: ${calibrationProvider.currentReadingsCount}/${calibrationProvider.targetReadings}',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            LinearProgressIndicator(
              value: calibrationProvider.collectionProgress,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 8),
            Text(
              '${(calibrationProvider.collectionProgress * 100).toStringAsFixed(1)}%',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // 6. ข้อมูล Debug
  Widget _buildDebugInfo(
    SettingProvider settingProvider,
    CalibrationEasy calibrationProvider,
  ) {
    return ExpansionTile(
      title: Text('Debug Information'),
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connection Status: ${settingProvider.connectionStatus}'),
              Text('Is Collecting: ${calibrationProvider.isCollecting}'),
              Text('Target Readings: ${calibrationProvider.targetReadings}'),
              Text(
                'Current Readings: ${calibrationProvider.currentReadingsCount}',
              ),
              if (settingProvider.currentRawValue != null)
                Text('Raw Value: ${settingProvider.currentRawValue}'),
              Text('Last Raw Text: "${settingProvider.lastRawText}"'),
              SizedBox(height: 10),
              Text(
                'Calibration Info:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(calibrationProvider.calibrationSummary),
              SizedBox(height: 10),

              // ✅ เพิ่มข้อมูล Provider Connection Status
              Text(
                'Provider Status:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('CalibrationEasy Instance: ${calibrationProvider.hashCode}'),
              Text('SettingProvider Instance: ${settingProvider.hashCode}'),
              Text(
                'Raw Value Function Connected: ${calibrationProvider.toString().contains('CalibrationEasy') ? 'Yes' : 'No'}',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
