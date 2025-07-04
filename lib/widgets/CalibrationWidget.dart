import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/CalibrationProvider.dart';
import '../providers/SettingProvider.dart';

class CalibrationWidget extends StatefulWidget {
  const CalibrationWidget({super.key});

  @override
  State<CalibrationWidget> createState() => _CalibrationWidgetState();
}

class _CalibrationWidgetState extends State<CalibrationWidget> {
  final TextEditingController _actualWeightController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _rawValueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Listen to BLE data and add to readings
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This will be called after the first frame
    });
  }

  @override
  void dispose() {
    _actualWeightController.dispose();
    _notesController.dispose();
    _rawValueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Calibration'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          Consumer<CalibrationProvider>(
            builder: (context, calibrationProvider, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'export':
                      _showExportDialog(context, calibrationProvider);
                      break;
                    case 'clear_all':
                      _showClearAllDialog(context, calibrationProvider);
                      break;
                    case 'stats':
                      _showStatsDialog(context, calibrationProvider);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'stats',
                    child: Row(
                      children: [
                        Icon(Icons.analytics),
                        SizedBox(width: 8),
                        Text('Statistics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download),
                        SizedBox(width: 8),
                        Text('Export Data'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<CalibrationProvider, SettingProvider>(
        builder: (context, calibrationProvider, settingProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildConnectionStatus(settingProvider),
                const SizedBox(height: 16),
                _buildCalibrationStatus(calibrationProvider),
                const SizedBox(height: 16),
                _buildCurrentWeightDisplay(settingProvider, calibrationProvider),
                // const SizedBox(height: 16),
                // _buildCalibrationForm(calibrationProvider, settingProvider),
                const SizedBox(height: 16),
                _buildCalibrationPointsList(calibrationProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(SettingProvider settingProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              settingProvider.connectedDevice != null
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: settingProvider.connectedDevice != null ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settingProvider.connectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (settingProvider.connectedDevice != null)
                    Text(
                      'Device: ${settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationStatus(CalibrationProvider calibrationProvider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  calibrationProvider.isCalibrated ? Icons.check_circle : Icons.warning,
                  color: calibrationProvider.isCalibrated ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  calibrationProvider.isCalibrated ? 'Calibrated' : 'Not Calibrated',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (calibrationProvider.isCalibrated) ...[
              Text('Calibration Points: ${calibrationProvider.calibrationPoints.length}'),
              Text('Accuracy: ${calibrationProvider.getCalibrationAccuracy().toStringAsFixed(2)}%'),
              if (calibrationProvider.averageError != null)
                Text('Average Error: ±${calibrationProvider.averageError!.toStringAsFixed(3)} kg'),
            ] else ...[
              const Text('Add at least 2 calibration points to enable calibration'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentWeightDisplay(SettingProvider settingProvider, CalibrationProvider calibrationProvider) {
    // Get current raw value from BLE data
    double? currentRawValue;
    String rawText = 'No Data';

    if (settingProvider.characteristicValues.isNotEmpty) {
      // Get the latest characteristic value
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          rawText = receivedText;

          // Parse weight from format "Weight: 7393.00 kg"
          currentRawValue = _parseWeightFromText(receivedText);
          
          // Add to calibration provider for average calculation
          if (currentRawValue != null) {
            calibrationProvider.addReading(currentRawValue);
          }
        } catch (e) {
          rawText = 'Parse Error';
        }
      }
    }

    // Get statistics
    Map<String, double> stats = calibrationProvider.getReadingStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Quick Calibration',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                // Toggle for using average
                Row(
                  children: [
                    Text(
                      'ใช้ค่าเฉลี่ย',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    Switch(
                      value: calibrationProvider.useAverageForCalibration,
                      onChanged: (value) {
                        calibrationProvider.setUseAverageForCalibration(value);
                      },
                      activeColor: Colors.blue,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Show current reading info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current Reading:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const Spacer(),
                      Text(
                        'Readings: ${stats['count']!.toInt()}/${calibrationProvider.maxReadingsForAverage}',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  Text(
                    rawText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                    ),
                  ),
                  if (stats['count']! > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'เฉลี่ย: ${stats['average']!.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'ต่ำสุด: ${stats['min']!.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'สูงสุด: ${stats['max']!.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(calibrationProvider.useAverageForCalibration ? 'ค่าเฉลี่ย' : 'ค่าปัจจุบัน'),
                      Text(
                        calibrationProvider.useAverageForCalibration 
                            ? (calibrationProvider.currentAverageReading?.toStringAsFixed(2) ?? 'No Data')
                            : (currentRawValue?.toStringAsFixed(2) ?? 'No Data'),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: calibrationProvider.useAverageForCalibration ? Colors.blue : Colors.black,
                        ),
                      ),
                      Text(
                        calibrationProvider.useAverageForCalibration 
                            ? '(${stats['count']!.toInt()} ค่า)'
                            : '(ปัจจุบัน)',
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward),
                Expanded(
                  child: Column(
                    children: [
                      const Text('น้ำหนักที่ปรับเทียบแล้ว'),
                      Text(
                        currentRawValue != null
                            ? '${calibrationProvider.convertRawToWeight(
                                calibrationProvider.useAverageForCalibration 
                                    ? (calibrationProvider.currentAverageReading ?? currentRawValue)
                                    : currentRawValue
                              ).toStringAsFixed(2)} kg'
                            : 'No Data',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: calibrationProvider.isCalibrated ? Colors.green : Colors.orange,
                        ),
                      ),
                      Text(
                        calibrationProvider.isCalibrated
                            ? '(ปรับเทียบแล้ว)'
                            : '(ยังไม่ปรับเทียบ)',
                        style: TextStyle(
                          fontSize: 10,
                          color: calibrationProvider.isCalibrated ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildQuickCalibrationButtons(calibrationProvider, currentRawValue),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCalibrationButtons(CalibrationProvider calibrationProvider, double? currentRawValue) {
    if (!calibrationProvider.isQuickCalibrating) {
      // ปุ่มเริ่ม Quick Calibration
      return Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.speed, size: 32, color: Colors.blue.shade600),
                const SizedBox(height: 8),
                Text(
                  'Quick Calibration',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const Text(
                  'วางน้ำหนักที่ทราบแน่นอน แล้วกดปุ่ม 2 ครั้ง',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: currentRawValue != null
                  ? () => calibrationProvider.startQuickCalibration()
                  : null,
              icon: const Icon(Icons.play_arrow),
              label: const Text('เริ่ม Quick Calibration'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      );
    }

    // Quick Calibration ขั้นตอนที่ 1: รอค่า Zero
    if (calibrationProvider.quickCalibrationStep == 'waiting_zero') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.looks_one, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ขั้นตอนที่ 1: ไม่ใส่น้ำหนัก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'ให้แน่ใจว่าไม่มีของอยู่บนเครื่องชั่ง\nแล้วกด "บันทึกค่า Zero"',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => calibrationProvider.cancelQuickCalibration(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('ยกเลิก'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentRawValue != null
                        ? () {
                            double valueToUse = calibrationProvider.useAverageForCalibration && 
                                               calibrationProvider.currentAverageReading != null
                                ? calibrationProvider.currentAverageReading!
                                : currentRawValue!;
                            calibrationProvider.captureZeroReading(valueToUse);
                          }
                        : null,
                    icon: const Icon(Icons.check),
                    label: Text(calibrationProvider.useAverageForCalibration 
                        ? 'บันทึกค่าเฉลี่ย Zero' 
                        : 'บันทึกค่า Zero'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade100,
                      foregroundColor: Colors.orange.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Quick Calibration ขั้นตอนที่ 2: รอค่าน้ำหนัก
    if (calibrationProvider.quickCalibrationStep == 'waiting_weight') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.looks_two, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ขั้นตอนที่ 2: วางน้ำหนัก',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (calibrationProvider.zeroValue != null) ...[
              Text(
                'ค่า Zero: ${calibrationProvider.zeroValue!.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              Text(
                calibrationProvider.useAverageForCalibration 
                    ? 'ใช้ค่าเฉลี่ยจาก ${calibrationProvider.recentReadings.length} ค่า'
                    : 'ใช้ค่าปัจจุบัน',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: _actualWeightController,
              decoration: const InputDecoration(
                labelText: 'น้ำหนักที่ทราบ (kg)',
                hintText: 'เช่น 1.0, 5.0, 10.0',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            const Text(
              'วางน้ำหนักที่ทราบแน่นอนลงบนเครื่องชั่ง\nใส่น้ำหนักด้านบน แล้วกด "เสร็จสิ้น"',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => calibrationProvider.cancelQuickCalibration(),
                    icon: const Icon(Icons.cancel),
                    label: const Text('ยกเลิก'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: currentRawValue != null && _actualWeightController.text.isNotEmpty
                        ? () => _completeQuickCalibration(calibrationProvider, currentRawValue!)
                        : null,
                    icon: const Icon(Icons.check),
                    label: const Text('เสร็จสิ้น'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container();
  }

  void _completeQuickCalibration(CalibrationProvider calibrationProvider, double currentRawValue) {
    final actualWeight = double.tryParse(_actualWeightController.text);

    if (actualWeight == null || actualWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาใส่น้ำหนักที่ถูกต้อง')),
      );
      return;
    }

    // Use appropriate value (average or current)
    double valueToUse = calibrationProvider.useAverageForCalibration && 
                       calibrationProvider.currentAverageReading != null
        ? calibrationProvider.currentAverageReading!
        : currentRawValue;

    calibrationProvider.captureWeightReading(valueToUse, actualWeight);
    _actualWeightController.clear();

    String method = calibrationProvider.useAverageForCalibration ? 'ค่าเฉลี่ย' : 'ค่าปัจจุบัน';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quick Calibration เสร็จสิ้น! ใช้$method เพิ่ม 2 จุดปรับเทียบแล้ว'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Helper method to parse weight from text like "Weight: 7393.00 kg"
  double? _parseWeightFromText(String text) {
    try {
      // Try to find number after "Weight:" if present
      RegExp weightPattern = RegExp(r'Weight:\s*([+-]?\d+\.?\d*)', caseSensitive: false);
      Match? match = weightPattern.firstMatch(text);
      
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
      
      // If no "Weight:" pattern, try to extract any number from the text
      RegExp numberPattern = RegExp(r'([+-]?\d+\.?\d*)');
      match = numberPattern.firstMatch(text);
      
      if (match != null) {
        return double.tryParse(match.group(1)!);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  Widget _buildCalibrationForm(CalibrationProvider calibrationProvider, SettingProvider settingProvider) {
    if (!calibrationProvider.isCalibrating) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Manual Calibration Entry',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _rawValueController,
                decoration: const InputDecoration(
                  labelText: 'Raw Value',
                  hintText: 'Enter raw sensor value',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _actualWeightController,
                decoration: const InputDecoration(
                  labelText: 'Actual Weight (kg)',
                  hintText: 'Enter known weight',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  hintText: 'Add notes about this calibration point',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _addManualCalibrationPoint(calibrationProvider),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Calibration Point'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade100,
                    foregroundColor: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Calibration in progress
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Calibration in Progress',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Raw Value: ${calibrationProvider.currentRawValue?.toStringAsFixed(3)}'),
            const SizedBox(height: 12),
            TextField(
              controller: _actualWeightController,
              decoration: const InputDecoration(
                labelText: 'Actual Weight (kg)',
                hintText: 'Enter the known weight',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Add notes about this calibration',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      calibrationProvider.cancelCalibration();
                      _actualWeightController.clear();
                      _notesController.clear();
                    },
                    icon: const Icon(Icons.cancel),
                    label: const Text('Cancel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _completeCalibration(calibrationProvider),
                    icon: const Icon(Icons.check),
                    label: const Text('Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalibrationPointsList(CalibrationProvider calibrationProvider) {
    if (calibrationProvider.calibrationPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.scale, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No Calibration Points',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add calibration points to improve accuracy',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Calibration Points (${calibrationProvider.calibrationPoints.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: calibrationProvider.calibrationPoints.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final point = calibrationProvider.calibrationPoints[index];
              final predictedWeight = calibrationProvider.convertRawToWeight(point.rawValue);
              final error = (predictedWeight - point.actualWeight).abs();

              return ListTile(
                title: Text('${point.actualWeight} kg'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Raw: ${point.rawValue.toStringAsFixed(3)}'),
                    if (calibrationProvider.isCalibrated)
                      Text(
                        'Error: ±${error.toStringAsFixed(3)} kg',
                        style: TextStyle(
                          color: error > 0.1 ? Colors.red : Colors.green,
                          fontSize: 12,
                        ),
                      ),
                    Text(
                      point.timestamp.toString().substring(0, 19),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (point.notes != null && point.notes!.isNotEmpty)
                      Text(
                        point.notes!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () => _confirmDeletePoint(context, calibrationProvider, point),
                  icon: const Icon(Icons.delete, color: Colors.red),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _addManualCalibrationPoint(CalibrationProvider calibrationProvider) {
    final rawValue = double.tryParse(_rawValueController.text);
    final actualWeight = double.tryParse(_actualWeightController.text);

    if (rawValue == null || actualWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid numbers')),
      );
      return;
    }

    calibrationProvider.addCalibrationPoint(
      rawValue,
      actualWeight,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    _rawValueController.clear();
    _actualWeightController.clear();
    _notesController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibration point added successfully')),
    );
  }

  void _completeCalibration(CalibrationProvider calibrationProvider) {
    final actualWeight = double.tryParse(_actualWeightController.text);

    if (actualWeight == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid weight')),
      );
      return;
    }

    calibrationProvider.completeCalibration(
      actualWeight,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
    );

    _actualWeightController.clear();
    _notesController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calibration completed successfully')),
    );
  }

  void _confirmDeletePoint(BuildContext context, CalibrationProvider calibrationProvider, CalibrationData point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Calibration Point'),
        content: Text('Are you sure you want to delete the calibration point for ${point.actualWeight} kg?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              calibrationProvider.removeCalibrationPoint(point.id!);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calibration point deleted')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, CalibrationProvider calibrationProvider) {
    final exportData = calibrationProvider.exportCalibrationData();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Calibration Data'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: SelectableText(
              exportData,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showClearAllDialog(BuildContext context, CalibrationProvider calibrationProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Calibration Data'),
        content: const Text(
          'Are you sure you want to delete all calibration points? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              calibrationProvider.clearAllCalibrationData();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All calibration data cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  void _showStatsDialog(BuildContext context, CalibrationProvider calibrationProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Calibration Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total Points', '${calibrationProvider.totalCalibrations}'),
            if (calibrationProvider.isCalibrated) ...[
              _buildStatRow(
                'Accuracy', 
                '${calibrationProvider.getCalibrationAccuracy().toStringAsFixed(2)}%'
              ),
              if (calibrationProvider.averageError != null)
                _buildStatRow(
                  'Average Error', 
                  '±${calibrationProvider.averageError!.toStringAsFixed(3)} kg'
                ),
              if (calibrationProvider.maxError != null)
                _buildStatRow(
                  'Max Error', 
                  '±${calibrationProvider.maxError!.toStringAsFixed(3)} kg'
                ),
              if (calibrationProvider.slope != null)
                _buildStatRow(
                  'Slope', 
                  calibrationProvider.slope!.toStringAsFixed(6)
                ),
              if (calibrationProvider.intercept != null)
                _buildStatRow(
                  'Intercept', 
                  calibrationProvider.intercept!.toStringAsFixed(6)
                ),
            ] else ...[
              const Text(
                'Add at least 2 calibration points to see statistics',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}