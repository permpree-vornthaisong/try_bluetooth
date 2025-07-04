import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SettingProvider.dart';
import '../providers/CalibrationProvider.dart';

enum WeightMode {
  person('ชั่งน้ำหนักคน', Icons.person, Colors.blue),
  object('ชั่งสิ่งของ', Icons.inventory_2, Colors.green),
  animal('ชั่งสิ่งมีชีวิต', Icons.pets, Colors.orange);

  const WeightMode(this.displayName, this.icon, this.color);
  final String displayName;
  final IconData icon;
  final MaterialColor color;
}

class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  WeightMode _selectedMode = WeightMode.person;
  bool _isStabilizing = false;
  List<double> _stabilityReadings = [];
  double? _stableWeight;
  DateTime? _lastReadingTime;

  // Tare functionality
  double _tareOffset = 0.0;
  DateTime? _tareTimestamp;

  // Settings for different modes
  Map<WeightMode, Map<String, dynamic>> _modeSettings = {
    WeightMode.person: {
      'stabilityThreshold': 0.1, // ± 0.1 kg
      'stabilityDuration': 3, // 3 seconds
      'minWeight': 10.0, // minimum 10 kg
      'maxWeight': 300.0, // maximum 300 kg
      'precision': 1, // 1 decimal place
      'autoTare': true,
    },
    WeightMode.object: {
      'stabilityThreshold': 0.05, // ± 0.05 kg
      'stabilityDuration': 2, // 2 seconds
      'minWeight': 0.01, // minimum 0.01 kg
      'maxWeight': 1000.0, // maximum 1000 kg
      'precision': 2, // 2 decimal places
      'autoTare': false,
    },
    WeightMode.animal: {
      'stabilityThreshold': 0.2, // ± 0.2 kg (animals move)
      'stabilityDuration': 5, // 5 seconds
      'minWeight': 0.1, // minimum 0.1 kg
      'maxWeight': 500.0, // maximum 500 kg
      'precision': 1, // 1 decimal place
      'autoTare': true,
    },
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Display'),
        backgroundColor: _selectedMode.color.withOpacity(0.1),
        actions: [
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.tune),
            tooltip: 'Mode Settings',
          ),
          IconButton(
            onPressed: _showHistoryDialog,
            icon: const Icon(Icons.history),
            tooltip: 'Weight History',
          ),
        ],
      ),
      body: Consumer2<SettingProvider, CalibrationProvider>(
        builder: (context, settingProvider, calibrationProvider, child) {
          return Column(
            children: [
              _buildModeSelector(),
              _buildConnectionStatus(settingProvider, calibrationProvider),
              Expanded(
                child: _buildWeightDisplay(
                  settingProvider,
                  calibrationProvider,
                ),
              ),
              _buildControlPanel(settingProvider, calibrationProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: _selectedMode.color.withOpacity(0.1),
        border: Border(
          bottom: BorderSide(color: _selectedMode.color.withOpacity(0.3)),
        ),
      ),
      child: Column(
        children: [
          Text(
            'เลือกโหมดการชั่ง',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _selectedMode.color[800],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children:
                WeightMode.values.map((mode) {
                  final isSelected = _selectedMode == mode;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => _changeMode(mode),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? mode.color : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: mode.color,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              mode.icon,
                              color: isSelected ? Colors.white : mode.color,
                              size: 24,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mode.displayName,
                              style: TextStyle(
                                color: isSelected ? Colors.white : mode.color,
                                fontSize: 11,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(
    SettingProvider settingProvider,
    CalibrationProvider calibrationProvider,
  ) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Connection Status
            Icon(
              settingProvider.connectedDevice != null
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color:
                  settingProvider.connectedDevice != null
                      ? Colors.green
                      : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settingProvider.connectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (settingProvider.connectedDevice != null)
                    Text(
                      'Device: ${settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            // Calibration Status
            const SizedBox(width: 16),
            Icon(
              calibrationProvider.isCalibrated
                  ? Icons.check_circle
                  : Icons.warning,
              color:
                  calibrationProvider.isCalibrated
                      ? Colors.green
                      : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              calibrationProvider.isCalibrated
                  ? 'Calibrated (${calibrationProvider.calibrationPoints.length})'
                  : 'Not Calibrated',
              style: TextStyle(
                fontSize: 12,
                color:
                    calibrationProvider.isCalibrated
                        ? Colors.green
                        : Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDisplay(
    SettingProvider settingProvider,
    CalibrationProvider calibrationProvider,
  ) {
    // Get current raw value from BLE data
    double? currentRawValue;
    String rawText = 'No Data';
    double? calibratedWeight;

    if (settingProvider.characteristicValues.isNotEmpty) {
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          rawText = receivedText;
          currentRawValue = _parseWeightFromText(receivedText);

          if (currentRawValue != null && calibrationProvider.isCalibrated) {
            calibratedWeight = calibrationProvider.convertRawToWeight(
              currentRawValue,
            );
            // ลบค่า Tare offset ออกจากน้ำหนักที่ปรับเทียบแล้ว
            calibratedWeight = calibratedWeight - _tareOffset;
            // ให้น้ำหนักเป็น 0 ถ้าน้อยกว่า 0
            if (calibratedWeight < 0) {
              calibratedWeight = 0.0;
            }
            _processWeightReading(calibratedWeight);
          }
        } catch (e) {
          rawText = 'Parse Error';
        }
      }
    }

    final modeConfig = _modeSettings[_selectedMode]!;
    final precision = modeConfig['precision'] as int;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Weight Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _selectedMode.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _selectedMode.color.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(_selectedMode.icon, size: 48, color: _selectedMode.color),
                const SizedBox(height: 16),
                Text(
                  _selectedMode.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _selectedMode.color[800],
                  ),
                ),
                const SizedBox(height: 24),

                // Weight Display
                if (_stableWeight != null &&
                    _isWeightValid(_stableWeight!)) ...[
                  Text(
                    '${_stableWeight!.toStringAsFixed(precision)} kg',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: _selectedMode.color.shade700,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'น้ำหนักเสถียร',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ] else if (calibratedWeight != null) ...[
                  Text(
                    '${calibratedWeight.toStringAsFixed(precision)} kg',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color:
                          _isStabilizing
                              ? Colors.orange
                              : _selectedMode.color[700],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      if (calibratedWeight != null) {
                        await sendBLECommand(
                          settingProvider,
                          'CURRENT:${calibratedWeight!.toStringAsFixed(precision)}',
                        );
                      }
                    },
                    child: Text('ส่งน้ำหนักปัจจุบัน'),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isStabilizing) ...[
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'กำลังวัด... (${_stabilityReadings.length}/${modeConfig['stabilityDuration']}s)',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ] else ...[
                        Icon(Icons.sync, color: Colors.grey, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'กำลังรอข้อมูล',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Icon(Icons.scale, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    calibrationProvider.isCalibrated
                        ? 'รอข้อมูลน้ำหนัก'
                        : 'ยังไม่ได้ปรับเทียบ',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Raw Data Display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raw Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      rawText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (currentRawValue != null && calibratedWeight != null) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Raw Value: ${currentRawValue.toStringAsFixed(2)}',
                            ),
                            Text(
                              'Calibrated: ${(calibratedWeight + _tareOffset).toStringAsFixed(precision)} kg',
                            ),
                          ],
                        ),
                        if (_tareOffset != 0.0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tare Offset: ${_tareOffset.toStringAsFixed(precision)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text(
                                'Net: ${calibratedWeight.toStringAsFixed(precision)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Mode Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _selectedMode.icon,
                        color: _selectedMode.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'การตั้งค่า ${_selectedMode.displayName}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedMode.color[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'ช่วงน้ำหนัก',
                          '${modeConfig['minWeight']}-${modeConfig['maxWeight']} kg',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'ความแม่นยำ',
                          '±${modeConfig['stabilityThreshold']} kg',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          'เวลาเสถียร',
                          '${modeConfig['stabilityDuration']} วินาที',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'ทศนิยม',
                          '${modeConfig['precision']} ตำแหน่ง',
                        ),
                      ),
                      if (_tareOffset != 0.0)
                        Expanded(
                          child: _buildInfoItem(
                            'Tare Offset',
                            '${_tareOffset.toStringAsFixed(2)} kg',
                            color: Colors.orange[700],
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
    );
  }

  Widget _buildInfoItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600]),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildControlPanel(
    SettingProvider settingProvider,
    CalibrationProvider calibrationProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _tareWeight,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Tare (ศูนย์)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[100],
                    foregroundColor: Colors.blue[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _stableWeight != null ? _saveWeight : null,
                  icon: const Icon(Icons.save),
                  label: const Text('บันทึก'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[100],
                    foregroundColor: Colors.green[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/calibration'),
                  icon: const Icon(Icons.tune),
                  label: const Text('ปรับเทียบ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[100],
                    foregroundColor: Colors.orange[800],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  icon: const Icon(Icons.settings),
                  label: const Text('การตั้งค่า'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[800],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  double? _parseWeightFromText(String text) {
    try {
      RegExp weightPattern = RegExp(
        r'Weight:\s*([+-]?\d+\.?\d*)',
        caseSensitive: false,
      );
      Match? match = weightPattern.firstMatch(text);

      if (match != null) {
        return double.tryParse(match.group(1)!);
      }

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

  void _changeMode(WeightMode mode) {
    setState(() {
      _selectedMode = mode;
      _isStabilizing = false;
      _stabilityReadings.clear();
      _stableWeight = null;
      // อาจจะเคลียร์ tare เมื่อเปลี่ยนโหมด (ตามการตั้งค่า)
      if (_modeSettings[mode]!['autoTare'] == true) {
        _tareOffset = 0.0;
        _tareTimestamp = null;
      }
    });
  }

  void _processWeightReading(double weight) {
    final modeConfig = _modeSettings[_selectedMode]!;
    final threshold = modeConfig['stabilityThreshold'] as double;
    final duration = modeConfig['stabilityDuration'] as int;

    final now = DateTime.now();

    // Check if weight is within valid range
    if (!_isWeightValid(weight)) {
      setState(() {
        _isStabilizing = false;
        _stabilityReadings.clear();
        _stableWeight = null;
      });
      return;
    }

    // Add reading to stability buffer
    _stabilityReadings.add(weight);

    // Keep only recent readings (within duration)
    if (_stabilityReadings.length > duration) {
      _stabilityReadings.removeAt(0);
    }

    // Check if we have enough stable readings
    if (_stabilityReadings.length >= duration) {
      double minWeight = _stabilityReadings.reduce((a, b) => a < b ? a : b);
      double maxWeight = _stabilityReadings.reduce((a, b) => a > b ? a : b);

      if ((maxWeight - minWeight) <= threshold) {
        // Weight is stable
        double avgWeight =
            _stabilityReadings.reduce((a, b) => a + b) /
            _stabilityReadings.length;
        setState(() {
          _stableWeight = avgWeight;
          _isStabilizing = false;
        });
      } else {
        // Weight is still fluctuating
        setState(() {
          _isStabilizing = true;
          _stableWeight = null;
        });
      }
    } else {
      // Not enough readings yet
      setState(() {
        _isStabilizing = true;
        _stableWeight = null;
      });
    }

    _lastReadingTime = now;
  }

  bool _isWeightValid(double weight) {
    final modeConfig = _modeSettings[_selectedMode]!;
    final minWeight = modeConfig['minWeight'] as double;
    final maxWeight = modeConfig['maxWeight'] as double;

    return weight >= minWeight && weight <= maxWeight;
  }

  void _tareWeight() {
    final settingProvider = Provider.of<SettingProvider>(
      context,
      listen: false,
    );
    final calibrationProvider = Provider.of<CalibrationProvider>(
      context,
      listen: false,
    );

    // Get current weight to use as tare offset
    if (settingProvider.characteristicValues.isNotEmpty &&
        calibrationProvider.isCalibrated) {
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          double? currentRawValue = _parseWeightFromText(receivedText);

          if (currentRawValue != null) {
            double currentCalibratedWeight = calibrationProvider
                .convertRawToWeight(currentRawValue);

            // Set the current calibrated weight as the new tare offset
            setState(() {
              _tareOffset = currentCalibratedWeight;
              _tareTimestamp = DateTime.now();
              _isStabilizing = false;
              _stabilityReadings.clear();
              _stableWeight = null;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tare ตั้งค่าที่ ${_tareOffset.toStringAsFixed(2)} kg (${_selectedMode.displayName})',
                ),
                backgroundColor: _selectedMode.color,
                action: SnackBarAction(
                  label: 'Clear Tare',
                  textColor: Colors.white,
                  onPressed: _clearTare,
                ),
              ),
            );
            return;
          }
        } catch (e) {
          // Handle parse error
        }
      }
    }

    // If no valid weight data, just reset display
    setState(() {
      _isStabilizing = false;
      _stabilityReadings.clear();
      _stableWeight = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ไม่สามารถตั้งค่า Tare ได้ - ไม่มีข้อมูลน้ำหนัก'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _clearTare() {
    setState(() {
      _tareOffset = 0.0;
      _tareTimestamp = null;
      _isStabilizing = false;
      _stabilityReadings.clear();
      _stableWeight = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ล้างค่า Tare แล้ว'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _saveWeight() {
    if (_stableWeight != null) {
      final precision = _modeSettings[_selectedMode]!['precision'] as int;

      // Here you could save to database or export
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'บันทึกน้ำหนัก: ${_stableWeight!.toStringAsFixed(precision)} kg (${_selectedMode.displayName})',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('การตั้งค่า ${_selectedMode.displayName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSettingSlider(
                    'ความแม่นยำ (±kg)',
                    'stabilityThreshold',
                    0.01,
                    1.0,
                    2,
                  ),
                  _buildSettingSlider(
                    'เวลาเสถียร (วินาที)',
                    'stabilityDuration',
                    1.0,
                    10.0,
                    0,
                    isInt: true,
                  ),
                  _buildSettingSlider(
                    'น้ำหนักต่ำสุด (kg)',
                    'minWeight',
                    0.01,
                    100.0,
                    2,
                  ),
                  _buildSettingSlider(
                    'น้ำหนักสูงสุด (kg)',
                    'maxWeight',
                    10.0,
                    2000.0,
                    0,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ปิด'),
              ),
            ],
          ),
    );
  }

  Widget _buildSettingSlider(
    String label,
    String key,
    double min,
    double max,
    int decimals, {
    bool isInt = false,
  }) {
    final currentValue = _modeSettings[_selectedMode]![key] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: isInt ? (max - min).toInt() : null,
          label:
              isInt
                  ? currentValue.toInt().toString()
                  : currentValue.toStringAsFixed(decimals),
          onChanged: (value) {
            setState(() {
              _modeSettings[_selectedMode]![key] =
                  isInt ? value.round().toDouble() : value;
            });
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('ประวัติการชั่ง'),
            content: Container(
              width: double.maxFinite,
              height: 300,
              child: const Center(child: Text('ยังไม่มีประวัติการชั่ง')),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('ปิด'),
              ),
            ],
          ),
    );
  }
}

// ฟังก์ชันส่งคำสั่งไป ESP32
Future<void> sendBLECommand(
  SettingProvider settingProvider,
  String command,
) async {
  if (settingProvider.connectedDevice != null &&
      settingProvider.characteristics.isNotEmpty) {
    for (var characteristicList in settingProvider.characteristics.values) {
      for (var char in characteristicList) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          if (char.uuid.toString().toLowerCase().contains('abcdef01')) {
            await settingProvider.writeCharacteristic(char, command.codeUnits);
            return;
          }
        }
      }
    }
  }
}
