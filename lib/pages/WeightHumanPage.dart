import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SettingProvider.dart';
import '../providers/CalibrationProvider.dart';
import '../providers/SaveHumanProvider.dart';
import '../providers/WeightHumanProvider.dart';

class WeightHumanPage extends StatefulWidget {
  const WeightHumanPage({super.key});

  @override
  State<WeightHumanPage> createState() => _WeightHumanPageState();
}

class _WeightHumanPageState extends State<WeightHumanPage> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize weight provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WeightHumanProvider>(context, listen: false).initialize();
    });

    // Setup pulse animation for stabilizing state
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            const SizedBox(width: 8),
            Text('ชั่งน้ำหนักคน'),
          ],
        ),
        backgroundColor: Colors.blue.withOpacity(0.1),
        actions: [
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.tune),
            tooltip: 'ตั้งค่าการชั่ง',
          ),
          IconButton(
            onPressed: _showHistoryDialog,
            icon: const Icon(Icons.history),
            tooltip: 'ประวัติการชั่ง',
          ),
        ],
      ),
      body: Consumer4<SettingProvider, CalibrationProvider, SaveHumanProvider, WeightHumanProvider>(
        builder: (context, settingProvider, calibrationProvider, saveHumanProvider, weightProvider, child) {
          // Process weight readings
          WidgetsBinding.instance.addPostFrameCallback((_) {
            weightProvider.processFromProviders(settingProvider, calibrationProvider);
          });

          // Control pulse animation
          if (weightProvider.isStabilizing) {
            if (!_pulseController.isAnimating) {
              _pulseController.repeat(reverse: true);
            }
          } else {
            _pulseController.stop();
            _pulseController.reset();
          }

          return Column(
            children: [
              _buildConnectionStatus(settingProvider, calibrationProvider),
              Expanded(
                child: _buildWeightDisplay(
                  settingProvider,
                  calibrationProvider,
                  weightProvider,
                ),
              ),
              _buildControlPanel(weightProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(SettingProvider settingProvider, CalibrationProvider calibrationProvider) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Connection Status
            Icon(
              settingProvider.connectedDevice != null ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: settingProvider.connectedDevice != null ? Colors.green : Colors.red,
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
              calibrationProvider.isCalibrated ? Icons.check_circle : Icons.warning,
              color: calibrationProvider.isCalibrated ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              calibrationProvider.isCalibrated
                  ? 'Calibrated (${calibrationProvider.calibrationPoints.length})'
                  : 'Not Calibrated',
              style: TextStyle(
                fontSize: 12,
                color: calibrationProvider.isCalibrated ? Colors.green : Colors.orange,
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
    WeightHumanProvider weightProvider,
  ) {
    // Get current raw data for display
    String rawText = 'No Data';
    double? currentRawValue;
    double? calibratedWeight;

    if (settingProvider.characteristicValues.isNotEmpty) {
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          rawText = receivedText;
          currentRawValue = weightProvider.parseWeightFromText(receivedText);

          if (currentRawValue != null && calibrationProvider.isCalibrated) {
            calibratedWeight = calibrationProvider.convertRawToWeight(currentRawValue);
          }
        } catch (e) {
          rawText = 'Parse Error';
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Weight Display
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: weightProvider.isStabilizing ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: weightProvider.weightStatusColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.person, size: 48, color: Colors.blue),
                      const SizedBox(height: 16),
                      Text(
                        'ชั่งน้ำหนักคน',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Weight Display
                      if (weightProvider.isReadyToSave && weightProvider.netWeight != null) ...[
                        Text(
                          '${weightProvider.getFormattedWeight(weightProvider.netWeight!)} kg',
                          style: TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              weightProvider.weightStatusIcon,
                              color: weightProvider.weightStatusColor,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              weightProvider.weightStatusText,
                              style: TextStyle(
                                color: weightProvider.weightStatusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ] else if (calibratedWeight != null) ...[
                        () {
                          final netWeight = calibratedWeight! - weightProvider.tareOffset;
                          final displayWeight = netWeight < 0 ? 0.0 : netWeight;
                          
                          return Column(
                            children: [
                              Text(
                                '${weightProvider.getFormattedWeight(displayWeight)} kg',
                                style: TextStyle(
                                  fontSize: 48,
                                  fontWeight: FontWeight.bold,
                                  color: weightProvider.isStabilizing ? Colors.orange : Colors.blue[700],
                                ),
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (weightProvider.isStabilizing) ...[
                                    SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.orange,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ] else ...[
                                    Icon(weightProvider.weightStatusIcon, color: Colors.grey, size: 16),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    weightProvider.weightStatusText,
                                    style: TextStyle(
                                      color: weightProvider.weightStatusColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }(),
                      ] else ...[
                        Icon(Icons.scale, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          calibrationProvider.isCalibrated ? 'รอข้อมูลน้ำหนัก' : 'ยังไม่ได้ปรับเทียบ',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
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
                            Text('Raw Value: ${currentRawValue.toStringAsFixed(2)}'),
                            Text('Calibrated: ${weightProvider.getFormattedWeight(calibratedWeight)} kg'),
                          ],
                        ),
                        if (weightProvider.tareOffset != 0.0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tare Offset: ${weightProvider.getFormattedWeight(weightProvider.tareOffset)} kg',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text(
                                'Net: ${weightProvider.getFormattedWeight(calibratedWeight - weightProvider.tareOffset < 0 ? 0.0 : calibratedWeight - weightProvider.tareOffset)} kg',
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

          // Human-specific Information
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'การตั้งค่าสำหรับคน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
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
                          '${weightProvider.humanSettings['minWeight']}-${weightProvider.humanSettings['maxWeight']} kg',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'ความแม่นยำ',
                          '±${weightProvider.humanSettings['stabilityThreshold']} kg',
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
                          '${(weightProvider.humanSettings['stabilityDuration'] as double).toInt()} วินาที',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoItem(
                          'ทศนิยม',
                          '${weightProvider.precision} ตำแหน่ง',
                        ),
                      ),
                      if (weightProvider.tareOffset != 0.0)
                        Expanded(
                          child: _buildInfoItem(
                            'Tare Offset',
                            '${weightProvider.getFormattedWeight(weightProvider.tareOffset)} kg',
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

  Widget _buildControlPanel(WeightHumanProvider weightProvider) {
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
                  onPressed: weightProvider.isReadyToSave ? _saveWeight : null,
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

  void _tareWeight() {
    final settingProvider = Provider.of<SettingProvider>(context, listen: false);
    final calibrationProvider = Provider.of<CalibrationProvider>(context, listen: false);
    final weightProvider = Provider.of<WeightHumanProvider>(context, listen: false);

    // Get current weight to use as tare offset
    if (settingProvider.characteristicValues.isNotEmpty && calibrationProvider.isCalibrated) {
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          double? currentRawValue = weightProvider.parseWeightFromText(receivedText);

          if (currentRawValue != null) {
            double currentCalibratedWeight = calibrationProvider.convertRawToWeight(currentRawValue);
            weightProvider.setTareOffset(currentCalibratedWeight);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tare ตั้งค่าที่ ${weightProvider.getFormattedWeight(currentCalibratedWeight)} kg',
                ),
                backgroundColor: Colors.blue,
                action: SnackBarAction(
                  label: 'Clear Tare',
                  textColor: Colors.white,
                  onPressed: () => weightProvider.clearTare(),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ไม่สามารถตั้งค่า Tare ได้ - ไม่มีข้อมูลน้ำหนัก'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _saveWeight() async {
    final weightProvider = Provider.of<WeightHumanProvider>(context, listen: false);
    
    if (!weightProvider.isReadyToSave || weightProvider.netWeight == null) return;

    final TextEditingController nameController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    // Show dialog to input person data
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: Colors.blue),
            const SizedBox(width: 8),
            Text('บันทึกน้ำหนักคน'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'น้ำหนักที่วัดได้: ${weightProvider.getFormattedWeight(weightProvider.netWeight!)} kg',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'โหมด: ชั่งน้ำหนักคน',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (weightProvider.tareOffset != 0.0) ...[
                const SizedBox(height: 8),
                Text(
                  'Tare Offset: ${weightProvider.getFormattedWeight(weightProvider.tareOffset)} kg',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              
              // ช่องกรอกชื่อคน
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'ชื่อคน',
                  hintText: 'กรุณากรอกชื่อคนที่ชั่งน้ำหนัก',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
              
              // ช่องกรอกหมายเหตุ
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                decoration: InputDecoration(
                  labelText: 'หมายเหตุ (ไม่บังคับ)',
                  hintText: 'เพิ่มหมายเหตุเพิ่มเติม...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('กรุณากรอกชื่อคน'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      try {
        final success = await weightProvider.saveWeight(
          context,
          nameController.text.trim(),
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'บันทึกน้ำหนักคนสำเร็จ!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('ชื่อ: ${nameController.text.trim()}'),
                  Text('น้ำหนัก: ${weightProvider.getFormattedWeight(weightProvider.netWeight!)} kg'),
                  if (notesController.text.trim().isNotEmpty)
                    Text('หมายเหตุ: ${notesController.text.trim()}'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
              action: SnackBarAction(
                label: 'ดูประวัติ',
                textColor: Colors.white,
                onPressed: _showHistoryDialog,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่พบ SaveHumanProvider - กรุณาตรวจสอบการตั้งค่า'),
            backgroundColor: Colors.red,
          ),
        );
        print('SaveHumanProvider error: $e');
      }
    }

    nameController.dispose();
    notesController.dispose();
  }

  void _showSettingsDialog() {
    final weightProvider = Provider.of<WeightHumanProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('การตั้งค่าการชั่งน้ำหนักคน'),
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
                weightProvider,
              ),
              _buildSettingSlider(
                'เวลาเสถียร (วินาที)',
                'stabilityDuration',
                1.0,
                10.0,
                0,
                weightProvider,
                isInt: true,
              ),
              _buildSettingSlider(
                'น้ำหนักต่ำสุด (kg)',
                'minWeight',
                1.0,
                50.0,
                1,
                weightProvider,
              ),
              _buildSettingSlider(
                'น้ำหนักสูงสุด (kg)',
                'maxWeight',
                100.0,
                500.0,
                0,
                weightProvider,
              ),
              _buildSettingSlider(
                'ทศนิยม (ตำแหน่ง)',
                'precision',
                0.0,
                3.0,
                0,
                weightProvider,
                isInt: true,
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
    int decimals,
    WeightHumanProvider weightProvider, {
    bool isInt = false,
  }) {
    final currentValue = weightProvider.humanSettings[key] as double;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: currentValue,
          min: min,
          max: max,
          divisions: isInt ? (max - min).toInt() : null,
          label: isInt ? currentValue.toInt().toString() : currentValue.toStringAsFixed(decimals),
          onChanged: (value) {
            weightProvider.updateSetting(key, isInt ? value.round().toDouble() : value);
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  void _showHistoryDialog() {
    try {
      final saveHumanProvider = Provider.of<SaveHumanProvider>(context, listen: false);
      
      showDialog(
        context: context,
        builder: (context) => Consumer<SaveHumanProvider>(
          builder: (context, saveHumanProvider, child) {
            final savedWeights = saveHumanProvider.savedWeights;
            final stats = saveHumanProvider.getStatistics();

            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.history, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text('ประวัติการชั่งน้ำหนักคน'),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // Statistics Card
                    if (savedWeights.isNotEmpty) ...[
                      Card(
                        color: Colors.blue.withOpacity(0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              Text(
                                'สถิติการชั่งน้ำหนักคน',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem(
                                      'จำนวนครั้ง',
                                      '${stats['totalRecords']}',
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatItem(
                                      'จำนวนคน',
                                      '${stats['uniquePeople']}',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatItem(
                                      'น้ำหนักเฉลี่ย',
                                      '${(stats['averageWeight'] as double).toStringAsFixed(1)} kg',
                                    ),
                                  ),
                                  Expanded(
                                    child: _buildStatItem(
                                      'ช่วงน้ำหนัก',
                                      '${(stats['minWeight'] as double).toStringAsFixed(1)}-${(stats['maxWeight'] as double).toStringAsFixed(1)} kg',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],

                    // History List
                    Expanded(
                      child: savedWeights.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.person, size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'ยังไม่มีประวัติการชั่งน้ำหนักคน',
                                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: savedWeights.length,
                              itemBuilder: (context, index) {
                                final weight = savedWeights[index];
                                final date = weight.timestamp.toLocal();
                                
                                return Card(
                                  margin: const EdgeInsets.symmetric(vertical: 2),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blue.withOpacity(0.2),
                                      child: Icon(Icons.person, color: Colors.blue[700]),
                                    ),
                                    title: Text(
                                      weight.personName,
                                      style: TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${date.day}/${date.month}/${date.year} '
                                          '${date.hour.toString().padLeft(2, '0')}:'
                                          '${date.minute.toString().padLeft(2, '0')}:'
                                          '${date.second.toString().padLeft(2, '0')}',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        if (weight.notes != null && weight.notes!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'หมายเหตุ: ${weight.notes}',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontStyle: FontStyle.italic,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${weight.weight.toStringAsFixed(1)} kg',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                        PopupMenuButton<String>(
                                          onSelected: (value) async {
                                            if (value == 'delete') {
                                              final confirmed = await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: Text('ยืนยันการลบ'),
                                                  content: Text('ต้องการลบข้อมูลของ ${weight.personName} หรือไม่?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(context, false),
                                                      child: Text('ยกเลิก'),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () => Navigator.pop(context, true),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor: Colors.red,
                                                        foregroundColor: Colors.white,
                                                      ),
                                                      child: Text('ลบ'),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true) {
                                                final success = await saveHumanProvider.deleteWeight(weight.id);
                                                if (success) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('ลบข้อมูลสำเร็จ'),
                                                      backgroundColor: Colors.green,
                                                    ),
                                                  );
                                                }
                                              }
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'delete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.delete, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('ลบ'),
                                                ],
                                              ),
                                            ),
                                          ],
                                          child: Icon(Icons.more_vert, size: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (savedWeights.isNotEmpty) ...[
                  TextButton(
                    onPressed: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('ยืนยันการล้างข้อมูล'),
                          content: Text('ต้องการลบประวัติการชั่งทั้งหมด ${savedWeights.length} รายการหรือไม่?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('ยกเลิก'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: Text('ล้างทั้งหมด'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        final success = await saveHumanProvider.clearAllData();
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('ล้างข้อมูลทั้งหมดสำเร็จ'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    },
                    child: Text('ล้างทั้งหมด', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton(
                    onPressed: () {
                      final csvData = saveHumanProvider.exportToCSV();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('ส่งออกข้อมูล CSV (${savedWeights.length} รายการ)'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: Text('ส่งออก CSV'),
                  ),
                ],
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ไม่พบ SaveHumanProvider - กรุณาตรวจสอบการตั้งค่าใน main.dart'),
          backgroundColor: Colors.red,
        ),
      );
      print('SaveHumanProvider error in history: $e');
    }
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.blue[700],
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}