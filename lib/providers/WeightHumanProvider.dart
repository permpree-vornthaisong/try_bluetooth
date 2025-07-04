import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/SettingProvider.dart';
import '../providers/CalibrationProvider.dart';
import '../providers/SaveHumanProvider.dart';

class WeightHumanProvider extends ChangeNotifier {
  // Weight measurement state
  bool _isStabilizing = false;
  List<double> _stabilityReadings = [];
  double? _stableWeight;
  DateTime? _lastReadingTime;

  // Tare functionality
  double _tareOffset = 0.0;
  DateTime? _tareTimestamp;

  // Human-specific settings
  final Map<String, dynamic> _humanSettings = {
    'stabilityThreshold': 0.1, // ± 0.1 kg
    'stabilityDuration': 3.0, // 3 seconds
    'minWeight': 10.0, // minimum 10 kg
    'maxWeight': 300.0, // maximum 300 kg
    'precision': 1.0, // 1 decimal place
    'autoTare': true,
  };

  // Getters
  bool get isStabilizing => _isStabilizing;
  List<double> get stabilityReadings => _stabilityReadings;
  double? get stableWeight => _stableWeight;
  DateTime? get lastReadingTime => _lastReadingTime;
  double get tareOffset => _tareOffset;
  DateTime? get tareTimestamp => _tareTimestamp;
  Map<String, dynamic> get humanSettings => _humanSettings;

  // Initialize provider
  void initialize() {
    _resetMeasurement();
  }

  // Process new weight reading
  void processWeightReading(double weight) {
    final threshold = _humanSettings['stabilityThreshold'] as double;
    final duration = (_humanSettings['stabilityDuration'] as double).toInt();

    final now = DateTime.now();

    // Check if weight is within valid range for humans
    if (!_isWeightValid(weight)) {
      _resetMeasurement();
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
        double avgWeight = _stabilityReadings.reduce((a, b) => a + b) / _stabilityReadings.length;
        _stableWeight = avgWeight;
        _isStabilizing = false;
      } else {
        // Weight is still fluctuating
        _isStabilizing = true;
        _stableWeight = null;
      }
    } else {
      // Not enough readings yet
      _isStabilizing = true;
      _stableWeight = null;
    }

    _lastReadingTime = now;
    notifyListeners();
  }

  // Check if weight is valid for humans
  bool _isWeightValid(double weight) {
    final minWeight = _humanSettings['minWeight'] as double;
    final maxWeight = _humanSettings['maxWeight'] as double;
    return weight >= minWeight && weight <= maxWeight;
  }

  // Reset measurement state
  void _resetMeasurement() {
    _isStabilizing = false;
    _stabilityReadings.clear();
    _stableWeight = null;
    notifyListeners();
  }

  // Set tare offset
  void setTareOffset(double offset) {
    _tareOffset = offset;
    _tareTimestamp = DateTime.now();
    _resetMeasurement();
    notifyListeners();
  }

  // Clear tare
  void clearTare() {
    _tareOffset = 0.0;
    _tareTimestamp = null;
    _resetMeasurement();
    notifyListeners();
  }

  // Update human-specific settings
  void updateSetting(String key, dynamic value) {
    if (_humanSettings.containsKey(key)) {
      _humanSettings[key] = value;
      _resetMeasurement(); // Reset when settings change
      notifyListeners();
    }
  }

  // Get precision for display
  int get precision => (_humanSettings['precision'] as double).toInt();

  // Get formatted weight string
  String getFormattedWeight(double weight) {
    return weight.toStringAsFixed(precision);
  }

  // Check if current weight is stable and ready to save
  bool get isReadyToSave => _stableWeight != null && _isWeightValid(_stableWeight!);

  // Get current net weight (with tare applied)
  double? get netWeight {
    if (_stableWeight == null) return null;
    final net = _stableWeight! - _tareOffset;
    return net < 0 ? 0.0 : net;
  }

  // Get weight status text
  String get weightStatusText {
    if (_stableWeight != null && _isWeightValid(_stableWeight!)) {
      return 'น้ำหนักเสถียร';
    } else if (_isStabilizing) {
      return 'กำลังวัด... (${_stabilityReadings.length}/${(_humanSettings['stabilityDuration'] as double).toInt()}s)';
    } else {
      return 'กำลังรอข้อมูล';
    }
  }

  // Get weight status color
  Color get weightStatusColor {
    if (_stableWeight != null && _isWeightValid(_stableWeight!)) {
      return Colors.green;
    } else if (_isStabilizing) {
      return Colors.orange;
    } else {
      return Colors.grey;
    }
  }

  // Get weight status icon
  IconData get weightStatusIcon {
    if (_stableWeight != null && _isWeightValid(_stableWeight!)) {
      return Icons.check_circle;
    } else if (_isStabilizing) {
      return Icons.sync;
    } else {
      return Icons.sync;
    }
  }

  // Save weight with context
  Future<bool> saveWeight(BuildContext context, String personName, {String? notes}) async {
    if (!isReadyToSave || netWeight == null) return false;

    try {
      final saveHumanProvider = Provider.of<SaveHumanProvider>(context, listen: false);
      
      final success = await saveHumanProvider.saveWeight(
        personName: personName.trim(),
        weight: netWeight!,
        notes: notes?.trim(),
      );

      if (success) {
        _resetMeasurement(); // Reset after successful save
      }

      return success;
    } catch (e) {
      debugPrint('Error saving human weight: $e');
      return false;
    }
  }

  // Parse weight from raw text (helper method)
  double? parseWeightFromText(String text) {
    try {
      RegExp weightPattern = RegExp(r'Weight:\s*([+-]?\d+\.?\d*)', caseSensitive: false);
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

  // Process weight from providers
  void processFromProviders(SettingProvider settingProvider, CalibrationProvider calibrationProvider) {
    if (settingProvider.characteristicValues.isNotEmpty && calibrationProvider.isCalibrated) {
      final firstValue = settingProvider.characteristicValues.values.first;
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        try {
          String receivedText = String.fromCharCodes(firstValue).trim();
          double? currentRawValue = parseWeightFromText(receivedText);

          if (currentRawValue != null) {
            double calibratedWeight = calibrationProvider.convertRawToWeight(currentRawValue);
            // Apply tare offset
            double netWeight = calibratedWeight - _tareOffset;
            if (netWeight < 0) netWeight = 0.0;
            
            processWeightReading(netWeight);
          }
        } catch (e) {
          debugPrint('Error processing weight from providers: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}