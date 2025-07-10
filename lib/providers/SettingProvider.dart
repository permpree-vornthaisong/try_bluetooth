import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SettingProvider extends ChangeNotifier {
  // BLE state
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  bool _isScanning = false;
  List<BluetoothDevice> _bleDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;
  String _connectionStatus = 'Disconnected';
  
  // BLE Services and Characteristics
  List<BluetoothService> _services = [];
  Map<String, List<BluetoothCharacteristic>> _characteristics = {};
  Map<String, dynamic> _characteristicValues = {};
  
  // RSSI and connection info
  int? _rssi;
  int? _mtu;

  // Subscriptions
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  List<StreamSubscription> _characteristicSubscriptions = [];

  // Add subscription control
  bool _autoSubscribeEnabled = true;
  Map<String, bool> _characteristicSubscriptions_status = {};

  // ✅ เพิ่มส่วนนี้ - Raw value storage for calibration และ raw text
  double? _currentRawValue;
  String? _primaryCharacteristicUuid; // UUID of main weight characteristic
  String _lastRawText = ''; // Store last received text for debugging
  String _rawReceivedText = ''; // ⚡ เพิ่มตัวแปรนี้สำหรับเก็บข้อมูล raw text ล่าสุด

  // Getters
  BluetoothAdapterState get adapterState => _adapterState;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get bleDevices => _bleDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnecting => _isConnecting;
  String get connectionStatus => _connectionStatus;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;
  List<BluetoothService> get services => _services;
  Map<String, List<BluetoothCharacteristic>> get characteristics => _characteristics;
  Map<String, dynamic> get characteristicValues => _characteristicValues;
  
  // ✅ เพิ่ม getters ใหม่
  double? get currentRawValue => _currentRawValue; // Clean raw value for calibration
  String get lastRawText => _lastRawText; // For debugging
  String? get rawReceivedText => _rawReceivedText.isNotEmpty ? _rawReceivedText : null; // ⚡ เพิ่ม getter นี้

  bool get autoSubscribeEnabled => _autoSubscribeEnabled;
  
  void toggleAutoSubscribe() {
    _autoSubscribeEnabled = !_autoSubscribeEnabled;
    notifyListeners();
  }

  // ✅ เพิ่ม method ใหม่ - ทำความสะอาดข้อมูลตัวเลข
  String _cleanNumericString(String input) {
    // ลบทุกอย่างยกเว้น ตัวเลข, จุดทศนิยม, และเครื่องหมายลบ
    return input.replaceAll(RegExp(r'[^0-9.-]'), '');
  }

  // ✅ แก้ไข method นี้ - แยกค่าตัวเลขจากข้อมูลที่รับมาและเก็บ raw text
  double? _extractRawValue(List<int> data) {
    try {
      // Convert bytes to string
      String text = String.fromCharCodes(data).trim();
      _lastRawText = text; // Store for debugging
      _rawReceivedText = text; // ⚡ เก็บข้อมูล raw text ล่าสุด
      
      if (kDebugMode) {
        print('Raw received text: "$text"');
      }
      
      // ⚡ ตรวจสอบรูปแบบข้อมูลแบบใหม่ เช่น "U002.00T000.00DN" หรือ "S002.00T000.00DN"
      if (text.length >= 14 && text.endsWith('DN')) {
        // รูปแบบ: U/S + 002.00 + T + 000.00 + DN
        // ดึงเฉพาะส่วนน้ำหนัก (ตำแหน่ง 1-6)
        try {
          String weightPart = text.substring(1, 7); // "002.00"
          double? weightValue = double.tryParse(weightPart);
          
          if (weightValue != null && weightValue.isFinite && !weightValue.isNaN) {
            if (kDebugMode) {
              print('Extracted raw value: $weightValue');
            }
            return weightValue;
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error parsing weight from structured format: $e');
          }
        }
      }
      
      // ถ้าไม่ใช่รูปแบบใหม่ ใช้วิธีเดิม
      // Remove all non-numeric characters except decimal point and minus sign
      String cleanText = _cleanNumericString(text);
      
      if (kDebugMode) {
        print('Cleaned text: "$cleanText"');
      }
      
      if (cleanText.isEmpty) {
        return null;
      }
      
      // Handle multiple decimal points - keep only the first one
      List<String> parts = cleanText.split('.');
      if (parts.length > 2) {
        cleanText = '${parts[0]}.${parts.sublist(1).join('')}';
      }
      
      // Try to parse as double
      double? value = double.tryParse(cleanText);
      
      if (value != null && value.isFinite && !value.isNaN) {
        if (kDebugMode) {
          print('Extracted raw value: $value');
        }
        return value;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error extracting raw value: $e');
      }
      return null;
    }
  }

  // ✅ เพิ่ม method ใหม่ - แยกข้อมูลแบบละเอียดจาก raw text
  Map<String, dynamic> parseWeightData(String rawData) {
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
      if (kDebugMode) {
        print('Error parsing weight data: $e');
      }
      return {};
    }
  }

  // ✅ เพิ่ม method ใหม่ - สำหรับ CalibrationEasy ใช้
  double? getRawValueForCalibration() {
    return _currentRawValue;
  }

  // ✅ เพิ่ม method ใหม่ - กำหนด characteristic หลักสำหรับน้ำหนัก
  void setPrimaryWeightCharacteristic(String uuid) {
    _primaryCharacteristicUuid = uuid;
    if (kDebugMode) {
      print('Set primary weight characteristic: $uuid');
    }
  }

  Future<void> unsubscribeFromCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      await characteristic.setNotifyValue(false);
      
      // Remove specific subscription
      _characteristicSubscriptions.removeWhere((sub) {
        // This is a simplified check - in practice you'd need better tracking
        return sub.toString().contains(characteristic.uuid.toString());
      });
      
      _characteristicSubscriptions_status[characteristic.uuid.toString()] = false;
      
      if (kDebugMode) {
        print('Unsubscribed from ${characteristic.uuid}');
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error unsubscribing from characteristic: $e');
      }
    }
  }

  bool isSubscribedTo(BluetoothCharacteristic characteristic) {
    return _characteristicSubscriptions_status[characteristic.uuid.toString()] ?? false;
  }
  int? get rssi => _rssi;
  int? get mtu => _mtu;

  SettingProvider() {
    _initializeBLE();
  }

  void _initializeBLE() {
    // Listen to adapter state changes
    _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      notifyListeners();
      
      if (state == BluetoothAdapterState.on) {
        _startBLEScan();
      } else {
        _stopBLEScan();
        _bleDevices.clear();
      }
    });

    // Get initial adapter state
    FlutterBluePlus.adapterState.first.then((state) {
      _adapterState = state;
      notifyListeners();
    });

    // Listen to scan results for BLE devices
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _bleDevices.clear();
      for (ScanResult r in results) {
        // Filter for BLE devices (devices with advertisement data)
        if (r.advertisementData.localName.isNotEmpty || 
            r.advertisementData.serviceUuids.isNotEmpty ||
            r.device.platformName.isNotEmpty) {
          _bleDevices.add(r.device);
        }
      }
      notifyListeners();
    });
  }

  Future<void> turnOnBluetooth() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await FlutterBluePlus.turnOn();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error turning on Bluetooth: $e');
      }
    }
  }

  Future<void> _startBLEScan() async {
    if (_isScanning) return;
    
    try {
      _isScanning = true;
      notifyListeners();
      
      // Scan specifically for BLE devices with timeout
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error starting BLE scan: $e');
      }
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _stopBLEScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping BLE scan: $e');
      }
    }
    _isScanning = false;
    notifyListeners();
  }

  Future<void> refreshBLEDevices() async {
    if (!isBluetoothOn) {
      await turnOnBluetooth();
      return;
    }
    
    await _stopBLEScan();
    await _startBLEScan();
  }

  Future<void> connectToBLEDevice(BluetoothDevice device) async {
    if (_isConnecting) {
      if (kDebugMode) {
        print('Already connecting to a device, ignoring request');
      }
      return;
    }

    // Check if already connected to this device
    if (_connectedDevice?.remoteId == device.remoteId) {
      if (kDebugMode) {
        print('Already connected to this device');
      }
      return;
    }

    try {
      _isConnecting = true;
      _connectionStatus = 'Connecting to BLE device...';
      notifyListeners();

      // Disconnect from current device if connected
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      // Connect to BLE device
      await device.connect(
        timeout: const Duration(seconds: 20),
        autoConnect: false,
      );
      
      // Listen to connection state
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _connectionStatus = 'Connected to ${device.platformName}';
          
          // Discover BLE services and characteristics
          await _discoverBLEServices();
          await _readRSSI();
          await _requestMTU();
          
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStatus = 'Disconnected';
          _clearBLEData();
        }
        notifyListeners();
      });

    } catch (e) {
      _connectionStatus = 'Failed to connect to BLE device';
      if (kDebugMode) {
        print('Error connecting to BLE device: $e');
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  Future<void> _discoverBLEServices() async {
    if (_connectedDevice == null) return;

    try {
      // Clear existing subscriptions first
      for (var subscription in _characteristicSubscriptions) {
        subscription.cancel();
      }
      _characteristicSubscriptions.clear();

      _services = await _connectedDevice!.discoverServices();
      _characteristics.clear();

      for (BluetoothService service in _services) {
        _characteristics[service.uuid.toString()] = service.characteristics;
        
        // Auto-subscribe to notify/indicate characteristics
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            await _subscribeToCharacteristic(characteristic);
          }
        }
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error discovering BLE services: $e');
      }
    }
  }

  Future<void> _subscribeToCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      // Check if already subscribed
      bool isAlreadySubscribed = _characteristicSubscriptions.any(
        (sub) => sub.toString().contains(characteristic.uuid.toString())
      );
      
      if (isAlreadySubscribed) {
        if (kDebugMode) {
          print('Already subscribed to ${characteristic.uuid}');
        }
        return;
      }

      await characteristic.setNotifyValue(true);
      
      final subscription = characteristic.onValueReceived.listen((value) {
        _characteristicValues[characteristic.uuid.toString()] = value;
        
        // ✅ แก้ไขส่วนนี้ - แยกค่า raw value สำหรับ calibration และเก็บ raw text
        double? rawValue = _extractRawValue(value);
        if (rawValue != null) {
          _currentRawValue = rawValue;
          
          // If this is the primary weight characteristic, update it
          if (_primaryCharacteristicUuid == null || 
              _primaryCharacteristicUuid == characteristic.uuid.toString()) {
            _primaryCharacteristicUuid = characteristic.uuid.toString();
          }
        }
        
        // Optional: Limit console output for frequent updates
        if (kDebugMode) {
          print('BLE Data from ${characteristic.uuid}: ${value.length} bytes, Raw: $rawValue');
        }
        
        notifyListeners();
      });
      
      _characteristicSubscriptions.add(subscription);
      _characteristicSubscriptions_status[characteristic.uuid.toString()] = true;
      
      if (kDebugMode) {
        print('Subscribed to ${characteristic.uuid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error subscribing to characteristic ${characteristic.uuid}: $e');
      }
    }
  }

  Future<void> readCharacteristic(BluetoothCharacteristic characteristic) async {
    try {
      final value = await characteristic.read();
      _characteristicValues[characteristic.uuid.toString()] = value;
      
      // ✅ เพิ่มส่วนนี้ - แยกค่า raw value เมื่ออ่านข้อมูล
      double? rawValue = _extractRawValue(value);
      if (rawValue != null) {
        _currentRawValue = rawValue;
      }
      
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error reading characteristic: $e');
      }
    }
  }

  Future<void> writeCharacteristic(BluetoothCharacteristic characteristic, List<int> value) async {
    try {
      await characteristic.write(value);
    } catch (e) {
      if (kDebugMode) {
        print('Error writing characteristic: $e');
      }
    }
  }

  Future<void> _readRSSI() async {
    if (_connectedDevice == null) return;
    
    try {
      _rssi = await _connectedDevice!.readRssi();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error reading RSSI: $e');
      }
    }
  }

  Future<void> _requestMTU() async {
    if (_connectedDevice == null) return;
    
    try {
      _mtu = await _connectedDevice!.requestMtu(512);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error requesting MTU: $e');
      }
    }
  }

  Future<void> disconnectBLEDevice() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
        _connectedDevice = null;
        _connectionStatus = 'Disconnected';
        _clearBLEData();
        notifyListeners();
      } catch (e) {
        if (kDebugMode) {
          print('Error disconnecting BLE device: $e');
        }
      }
    }
  }

  void _clearBLEData() {
    _services.clear();
    _characteristics.clear();
    _characteristicValues.clear();
    _rssi = null;
    _mtu = null;
    
    // ✅ เพิ่มส่วนนี้ - เคลียร์ raw value data และ raw text
    _currentRawValue = null;
    _primaryCharacteristicUuid = null;
    _lastRawText = '';
    _rawReceivedText = ''; // ⚡ เคลียร์ raw text ด้วย
    
    // Cancel all characteristic subscriptions
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
    _characteristicSubscriptions_status.clear();
  }

  String getBLEDeviceDisplayName(BluetoothDevice device) {
    String name = device.platformName;
    if (name.isEmpty) {
      name = device.remoteId.toString();
    }
    return name;
  }

  String formatCharacteristicValue(List<int> value) {
    if (value.isEmpty) return 'No data';
    
    // Try to decode as UTF-8 string first
    try {
      String text = String.fromCharCodes(value).trim();
      
      // Check if it's a weight reading format
      if (text.toLowerCase().contains('weight')) {
        // Parse and format weight reading
        double? weight = _parseWeightFromText(text);
        if (weight != null) {
          return 'Weight: ${weight.toStringAsFixed(2)} kg';
        }
      }
      
      return text;
    } catch (e) {
      // If not valid UTF-8, show as hex
      return value.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    }
  }

  // Helper method to parse weight from text like "Weight: 7393.00 kg"
  double? _parseWeightFromText(String text) {
    try {
      // Look for pattern like "Weight: 7393.00 kg" or similar
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

  String getCharacteristicProperties(BluetoothCharacteristic characteristic) {
    List<String> props = [];
    if (characteristic.properties.read) props.add('Read');
    if (characteristic.properties.write) props.add('Write');
    if (characteristic.properties.writeWithoutResponse) props.add('Write w/o Response');
    if (characteristic.properties.notify) props.add('Notify');
    if (characteristic.properties.indicate) props.add('Indicate');
    return props.join(', ');
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    
    _stopBLEScan();
    disconnectBLEDevice();
    super.dispose();
  }
}