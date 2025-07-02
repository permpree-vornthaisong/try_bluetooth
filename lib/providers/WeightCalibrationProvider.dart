import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';

class WeightCalibrationProvider extends ChangeNotifier {
  bool _isConnected = false;
  List<double> _weights = [];
  int _weightsLast10 = 10; // Maximum number of weights to store
  String _weightsLast10Text = '';
  String _lastRawData = ''; // เก็บข้อมูลดิบล่าสุด
  DeviceConnectionProvider? _deviceProvider; // Add reference to device provider

  // Getters
  bool get isConnected => _isConnected;
  List<double> get weights => List.unmodifiable(_weights);
  String get weightsLast10Text => _weightsLast10Text;
  int get weightsLast10 => _weightsLast10;
  String get lastRawData => _lastRawData;

  // Add setter for device provider
  set deviceProvider(DeviceConnectionProvider provider) {
    _deviceProvider = provider;
  }

  void connect() {
    _isConnected = true;
    notifyListeners();
  }

  void disconnect() {
    _isConnected = false;
    _weights.clear();
    _weightsLast10Text = '';
    _lastRawData = '';
    notifyListeners();
  }

  // Get max weights based on device data or fallback to default
  int get maxWeights {
    if (_deviceProvider != null && _deviceProvider!.receivedData.isNotEmpty) {
      return _deviceProvider!.receivedData.length;
    }
    return _weightsLast10;
  }

  // Method to parse weight from Bluetooth data string
  double? parseWeightFromString(String data) {
    try {
      // ตัวอย่าง: "Weight: 130679.00 kg"
      _lastRawData = data;
      
      // ใช้ RegExp เพื่อหาตัวเลขในข้อความ
      RegExp weightRegex = RegExp(r'Weight:\s*([0-9]+\.?[0-9]*)\s*kg');
      Match? match = weightRegex.firstMatch(data);
      
      if (match != null && match.group(1) != null) {
        double weight = double.parse(match.group(1)!);
        return weight;
      }
      
      // วิธีอื่น: ถ้า format เปลี่ยน ใช้วิธีนี้
      // แยกคำและหาตัวเลข
      List<String> parts = data.split(' ');
      for (String part in parts) {
        // ลองแปลงแต่ละส่วนเป็นตัวเลข
        try {
          double weight = double.parse(part);
          if (weight > 0) { // ตรวจสอบว่าเป็นค่าที่มีเหตุผล
            return weight;
          }
        } catch (e) {
          continue;
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error parsing weight: $e');
      return null;
    }
  }

  // Method to process received Bluetooth data
  void processBluetoothData(Uint8List data) {
    try {
      String receivedString = String.fromCharCodes(data);
      debugPrint('Received Bluetooth data: $receivedString');
      
      double? weight = parseWeightFromString(receivedString);
      if (weight != null) {
        addWeight(weight);
      } else {
        debugPrint('Could not parse weight from: $receivedString');
      }
    } catch (e) {
      debugPrint('Error processing Bluetooth data: $e');
    }
  }

  // Method to process received data from device provider
  void processLatestDeviceData() {
    if (_deviceProvider != null && _deviceProvider!.receivedData.isNotEmpty) {
      Uint8List latestData = _deviceProvider!.receivedData.last;
      processBluetoothData(latestData);
    }
  }

  void addWeight(double weight) {
    // Use the weightsLast10 value for consistency
    if (_weights.length >= _weightsLast10) {
      _weights.removeAt(0);
    }
    _weights.add(weight);
    _updateWeightsText();
    notifyListeners();
    
    debugPrint('Added weight: $weight kg');
  }

  // Method to update max weights if needed
  void setMaxWeights(int max) {
    if (max > 0) {
      _weightsLast10 = max;
      // Trim existing weights if new max is smaller
      while (_weights.length > _weightsLast10) {
        _weights.removeAt(0);
      }
      _updateWeightsText();
      notifyListeners();
    }
  }

  // Helper method to update the weights text representation
  void _updateWeightsText() {
    if (_weights.isEmpty) {
      _weightsLast10Text = 'ยังไม่มีข้อมูลน้ำหนัก';
    } else {
      _weightsLast10Text = 'น้ำหนักล่าสุด ${_weights.length} ครั้ง: ${_weights.map((w) => w.toStringAsFixed(2)).join(', ')} kg';
    }
  }

  // Method to get average of current weights
  double get averageWeight {
    if (_weights.isEmpty) return 0.0;
    return _weights.reduce((a, b) => a + b) / _weights.length;
  }

  // Method to get the latest weight
  double? get latestWeight {
    return _weights.isEmpty ? null : _weights.last;
  }

  // Method to clear all weights
  void clearWeights() {
    _weights.clear();
    _weightsLast10Text = '';
    _lastRawData = '';
    notifyListeners();
  }

  // Method to remove a specific weight by index
  void removeWeightAt(int index) {
    if (index >= 0 && index < _weights.length) {
      _weights.removeAt(index);
      _updateWeightsText();
      notifyListeners();
    }
  }

  // Method to get weights formatted as string
  String getWeightsAsString() {
    if (_weights.isEmpty) return 'ไม่มีข้อมูลน้ำหนัก';
    return _weights.map((w) => '${w.toStringAsFixed(2)} kg').join(', ');
  }

  // คำนวณส่วนเบี่ยงเบนมาตรฐาน
  double get standardDeviation {
    if (_weights.length < 2) return 0.0;
    
    double mean = averageWeight;
    double variance = _weights.map((w) => (w - mean) * (w - mean)).reduce((a, b) => a + b) / _weights.length;
    return variance.isFinite ? variance : 0.0;
  }

  // ค่าสูงสุดและต่ำสุด
  double? get maxWeight => _weights.isEmpty ? null : _weights.reduce((a, b) => a > b ? a : b);
  double? get minWeight => _weights.isEmpty ? null : _weights.reduce((a, b) => a < b ? a : b);
}