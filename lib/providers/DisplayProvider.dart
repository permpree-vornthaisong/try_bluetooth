import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'SettingProvider.dart';
import 'CalibrationProvider.dart';

class DisplayProvider extends ChangeNotifier {
  // Weight display state
  double _tareOffset = 0.0;
  double? _currentWeight;
  double? _currentRawValue;
  String _rawDataText = 'No Data';
  bool _isDataAvailable = false;
  
  // Provider references
  SettingProvider? _settingProvider;
  CalibrationProvider? _calibrationProvider;
  
  // Track last processed values to avoid unnecessary updates
  Map<String, List<int>> _lastProcessedValues = {};
  
  // Timer for periodic updates
  Timer? _updateTimer;

  // Getters
  double get tareOffset => _tareOffset;
  double? get currentWeight => _currentWeight;
  double? get currentRawValue => _currentRawValue;
  String get rawDataText => _rawDataText;
  bool get isDataAvailable => _isDataAvailable;
  bool get hasValidWeight => _currentWeight != null && _isDataAvailable;
  
  // Net weight (after tare)
  double? get netWeight {
    if (_currentWeight == null) return null;
    double net = _currentWeight! - _tareOffset;
    return net < 0 ? 0.0 : net;
  }

  // Initialize with providers
  void initializeWithProviders(
    SettingProvider settingProvider,
    CalibrationProvider calibrationProvider,
  ) {
    _settingProvider = settingProvider;
    _calibrationProvider = calibrationProvider;
    
    // Listen to provider changes
    _settingProvider!.addListener(_onDataChanged);
    _calibrationProvider!.addListener(_onDataChanged);
    
    // Start periodic update timer
    _startUpdateTimer();
    
    // Initial data processing
    _processCurrentData();
  }

  void _startUpdateTimer() {
    _updateTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      _processCurrentData();
    });
  }

  void _onDataChanged() {
    _processCurrentData();
  }

  void _processCurrentData() {
    if (_settingProvider == null || _calibrationProvider == null) return;
    
    bool hasNewData = false;
    
    // Process BLE data
    if (_settingProvider!.characteristicValues.isNotEmpty) {
      final firstValue = _settingProvider!.characteristicValues.values.first;
      
      if (firstValue is List<int> && firstValue.isNotEmpty) {
        // Check if this is new data
        String uuid = _settingProvider!.characteristicValues.keys.first;
        
        if (!_lastProcessedValues.containsKey(uuid) || 
            !listEquals(_lastProcessedValues[uuid], firstValue)) {
          
          _lastProcessedValues[uuid] = List<int>.from(firstValue);
          hasNewData = true;
          
          try {
            String receivedText = String.fromCharCodes(firstValue).trim();
            _rawDataText = receivedText;
            _currentRawValue = _parseWeightFromText(receivedText);
            
            // Calculate calibrated weight if possible
            if (_currentRawValue != null && _calibrationProvider!.isCalibrated) {
              _currentWeight = _calibrationProvider!.convertRawToWeight(_currentRawValue!);
              _isDataAvailable = true;
            } else {
              _currentWeight = null;
              _isDataAvailable = false;
            }
          } catch (e) {
            _rawDataText = 'Parse Error';
            _currentRawValue = null;
            _currentWeight = null;
            _isDataAvailable = false;
          }
        }
      }
    } else {
      // No data available
      if (_isDataAvailable) {
        _rawDataText = 'No Data';
        _currentRawValue = null;
        _currentWeight = null;
        _isDataAvailable = false;
        hasNewData = true;
      }
    }
    
    if (hasNewData) {
      notifyListeners();
    }
  }

  // Helper method to parse weight from text
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

  // Tare functionality
  bool performTare() {
    if (_currentWeight != null && _isDataAvailable) {
      _tareOffset = _currentWeight!;
      notifyListeners();
      return true;
    }
    return false;
  }

  void clearTare() {
    _tareOffset = 0.0;
    notifyListeners();
  }

  // Weight display methods
  String getFormattedWeight({int precision = 1}) {
    if (netWeight != null) {
      return '${netWeight!.toStringAsFixed(precision)} kg';
    }
    return '--.- kg';
  }

  String getFormattedRawValue({int precision = 2}) {
    if (_currentRawValue != null) {
      return _currentRawValue!.toStringAsFixed(precision);
    }
    return '--.-';
  }

  String getFormattedCalibratedWeight({int precision = 1}) {
    if (_currentWeight != null) {
      return '${(_currentWeight! + _tareOffset).toStringAsFixed(precision)} kg';
    }
    return '--.- kg';
  }

  String getFormattedTareOffset({int precision = 1}) {
    return '${_tareOffset.toStringAsFixed(precision)} kg';
  }

  // Status checks
  bool get isConnected => _settingProvider?.connectedDevice != null;
  bool get isCalibrated => _calibrationProvider?.isCalibrated ?? false;
  
  String get connectionStatus => _settingProvider?.connectionStatus ?? 'Disconnected';
  
  String getDeviceName() {
    if (_settingProvider?.connectedDevice != null) {
      return _settingProvider!.getBLEDeviceDisplayName(_settingProvider!.connectedDevice!);
    }
    return 'No Device';
  }

  int get calibrationPointsCount => _calibrationProvider?.calibrationPoints.length ?? 0;

  // Validation methods
  bool isWeightInRange(double minWeight, double maxWeight) {
    if (netWeight == null) return false;
    return netWeight! >= minWeight && netWeight! <= maxWeight;
  }

  bool isWeightStable(double threshold, List<double> recentReadings) {
    if (recentReadings.length < 2) return false;
    
    double minWeight = recentReadings.reduce((a, b) => a < b ? a : b);
    double maxWeight = recentReadings.reduce((a, b) => a > b ? a : b);
    
    return (maxWeight - minWeight) <= threshold;
  }

  // Debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'isConnected': isConnected,
      'isCalibrated': isCalibrated,
      'isDataAvailable': _isDataAvailable,
      'currentWeight': _currentWeight,
      'netWeight': netWeight,
      'tareOffset': _tareOffset,
      'rawValue': _currentRawValue,
      'rawText': _rawDataText,
      'deviceName': getDeviceName(),
      'calibrationPoints': calibrationPointsCount,
    };
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _settingProvider?.removeListener(_onDataChanged);
    _calibrationProvider?.removeListener(_onDataChanged);
    super.dispose();
  }
}