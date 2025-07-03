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
  // Add subscription control
  bool _autoSubscribeEnabled = true;
  Map<String, bool> _characteristicSubscriptions_status = {};

  bool get autoSubscribeEnabled => _autoSubscribeEnabled;
  
  void toggleAutoSubscribe() {
    _autoSubscribeEnabled = !_autoSubscribeEnabled;
    notifyListeners();
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
        
        // Optional: Limit console output for frequent updates
        if (kDebugMode) {
          print('BLE Data from ${characteristic.uuid}: ${value.length} bytes');
        }
        
        notifyListeners();
      });
      
      _characteristicSubscriptions.add(subscription);
      
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
    
    // Cancel all characteristic subscriptions
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
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