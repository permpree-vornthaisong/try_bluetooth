import 'dart:async';

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
  Map<String, bool> _characteristicSubscriptionsStatus = {}; // ✅ Fixed syntax

  // Raw value storage for calibration และ raw text
  double? _currentRawValue;
  String? _primaryCharacteristicUuid; // UUID of main weight characteristic
  String _lastRawText = ''; // Store last received text for debugging
  String _rawReceivedText =
      ''; // เพิ่มตัวแปรนี้สำหรับเก็บข้อมูล raw text ล่าสุด

  // Getters
  BluetoothAdapterState get adapterState => _adapterState;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get bleDevices => _bleDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnecting => _isConnecting;
  String get connectionStatus => _connectionStatus;
  bool get isBluetoothOn => _adapterState == BluetoothAdapterState.on;
  List<BluetoothService> get services => _services;
  Map<String, List<BluetoothCharacteristic>> get characteristics =>
      _characteristics;
  Map<String, dynamic> get characteristicValues => _characteristicValues;

  // เพิ่ม getters ใหม่
  double? get currentRawValue =>
      _currentRawValue; // Clean raw value for calibration
  String get lastRawText => _lastRawText; // For debugging
  String? get rawReceivedText =>
      _rawReceivedText.isNotEmpty ? _rawReceivedText : null; // ✅ Fixed syntax

  bool get autoSubscribeEnabled => _autoSubscribeEnabled;
  int? get rssi => _rssi;
  int? get mtu => _mtu;

  void toggleAutoSubscribe() {
    _autoSubscribeEnabled = !_autoSubscribeEnabled; // ✅ Fixed syntax
    notifyListeners();
  }

  // ทำความสะอาดข้อมูลตัวเลข
  String _cleanNumericString(String input) {
    // ลบทุกอย่างยกเว้น ตัวเลข, จุดทศนิยม, และเครื่องหมายลบ
    return input.replaceAll(RegExp(r'[^0-9.-]'), '');
  }

  // แยกค่าตัวเลขจากข้อมูลที่รับมาและเก็บ raw text
  double? _extractRawValue(List<int> data) {
    try {
      // Convert bytes to string
      String text = String.fromCharCodes(data).trim();
      _lastRawText = text; // Store for debugging
      _rawReceivedText = text; // เก็บข้อมูล raw text ล่าสุด

      if (kDebugMode) {
        print('📨 [SettingProvider] Raw received text: "$text"');
      }

      // ตรวจสอบรูปแบบข้อมูลแบบใหม่ เช่น "U002.00T000.00DN" หรือ "S002.00T000.00DN"
      if (text.length >= 14 && text.endsWith('DN')) {
        // รูปแบบ: U/S + 002.00 + T + 000.00 + DN
        // ดึงเฉพาะส่วนน้ำหนัก (ตำแหน่ง 1-6)
        try {
          String weightPart = text.substring(1, 7); // "002.00"
          double? weightValue = double.tryParse(weightPart);

          if (weightValue != null &&
              weightValue.isFinite &&
              !weightValue.isNaN) {
            if (kDebugMode) {
              print(
                '⚖️ [SettingProvider] Extracted structured weight: $weightValue',
              );
            }
            return weightValue;
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ [SettingProvider] Error parsing structured format: $e');
          }
        }
      }

      // ถ้าไม่ใช่รูปแบบใหม่ ใช้วิธีเดิม
      // Remove all non-numeric characters except decimal point and minus sign
      String cleanText = _cleanNumericString(text);

      if (kDebugMode) {
        print('🧹 [SettingProvider] Cleaned text: "$cleanText"');
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
          print('⚖️ [SettingProvider] Extracted cleaned weight: $value');
        }
        return value;
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SettingProvider] Error extracting raw value: $e');
      }
      return null;
    }
  }

  // เพิ่ม method นี้ใน SettingProvider
  Future<void> requestWeightData() async {
    if (_connectedDevice == null) return;

    // หา characteristic ที่มี write property
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {
          try {
            // ส่งคำสั่งขอข้อมูลน้ำหนัก (command อาจแตกต่างกันแต่ละรุ่น)
            List<int> command = [0x01]; // ตัวอย่าง command
            await characteristic.write(command);

            // ถ้ามี read property ให้อ่านข้อมูลกลับมา
            if (characteristic.properties.read) {
              await readCharacteristic(characteristic);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Error requesting weight data: $e');
            }
          }
        }
      }
    }
  }

  // เพิ่ม method ตรวจสอบว่าเครื่องรองรับแบบไหน
  bool get supportsAutoNotify {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.notify ||
            characteristic.properties.indicate) {
          return true;
        }
      }
    }
    return false;
  }

  bool get supportsCommandResponse {
    for (BluetoothService service in _services) {
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        if (characteristic.properties.write ||
            characteristic.properties.writeWithoutResponse) {
          return true;
        }
      }
    }
    return false;
  }

  // แยกข้อมูลแบบละเอียดจาก raw text
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
        print('❌ [SettingProvider] Error parsing weight data: $e');
      }
      return {};
    }
  }

  // สำหรับ CalibrationEasy ใช้
  double? getRawValueForCalibration() {
    return _currentRawValue;
  }

  // กำหนด characteristic หลักสำหรับน้ำหนัก
  void setPrimaryWeightCharacteristic(String uuid) {
    _primaryCharacteristicUuid = uuid;
    if (kDebugMode) {
      print('🎯 [SettingProvider] Set primary weight characteristic: $uuid');
    }
  }

  // ⭐ เพิ่ม method สำหรับหา write characteristic อัตโนมัติ
  BluetoothCharacteristic? getWriteCharacteristic() {
    for (var serviceEntry in _characteristics.entries) {
      for (var char in serviceEntry.value) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          if (kDebugMode) {
            print(
              '✍️ [SettingProvider] Found write characteristic: ${char.uuid}',
            );
          }
          return char;
        }
      }
    }
    if (kDebugMode) {
      print('❌ [SettingProvider] No write characteristic found');
    }
    return null;
  }

  // ⭐ เพิ่ม method สำหรับส่งคำสั่งโดยอัตโนมัติ
  Future<void> sendCommand(String command) async {
    final writeChar = getWriteCharacteristic();
    if (writeChar != null) {
      await writeCharacteristic(writeChar, command.codeUnits);
    } else {
      if (kDebugMode) {
        print(
          '❌ [SettingProvider] Cannot send command "$command" - no write characteristic',
        );
      }
    }
  }

  // ⭐ Debug method - แสดงสถานะการเชื่อมต่อแบบละเอียด
  Future<void> debugConnectionStatus() async {
    if (kDebugMode) {
      print('\n=== 🔍 BLE DEBUG INFO ===');
      print('Connected Device: $_connectedDevice');
      print('Services Count: ${_services.length}');
      print(
        'Characteristics Count: ${_characteristics.values.fold(0, (sum, list) => sum + list.length)}',
      );
      print('Auto Subscribe Enabled: $_autoSubscribeEnabled');
      print('Active Subscriptions: ${_characteristicSubscriptions.length}');
      print('Subscription Status: $_characteristicSubscriptionsStatus');
      print('Current Raw Value: $_currentRawValue');
      print('Raw Received Text: "$_rawReceivedText"');
      print('Last Raw Text: "$_lastRawText"');
      print('Primary Characteristic UUID: $_primaryCharacteristicUuid');

      // ตรวจสอบแต่ละ characteristic
      for (var serviceEntry in _characteristics.entries) {
        print('\n--- Service: ${serviceEntry.key} ---');
        for (var char in serviceEntry.value) {
          bool hasNotify = char.properties.notify || char.properties.indicate;
          bool isSubscribed =
              _characteristicSubscriptionsStatus[char.uuid.toString()] ??
              false; // ✅ Fixed syntax
          print('Characteristic: ${char.uuid}');
          print('  - Properties: ${getCharacteristicProperties(char)}');
          print('  - Has Notify/Indicate: $hasNotify');
          print('  - Is Subscribed: $isSubscribed');

          if (_characteristicValues.containsKey(char.uuid.toString())) {
            var value = _characteristicValues[char.uuid.toString()];
            print('  - Last Value: ${formatCharacteristicValue(value)}');
          } else {
            print('  - Last Value: None');
          }
        }
      }
      print('======================\n');
    }
  }

  // ⭐ Force subscribe เฉพาะ notify characteristics
  Future<void> forceSubscribeAllNotifyCharacteristics() async {
    if (kDebugMode) {
      print(
        '🔄 [SettingProvider] Force subscribing to all notify characteristics...',
      );
    }

    // Cancel existing subscriptions first
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
    _characteristicSubscriptionsStatus.clear(); // ✅ Fixed syntax

    for (var serviceEntry in _characteristics.entries) {
      for (var char in serviceEntry.value) {
        if (char.properties.notify || char.properties.indicate) {
          if (kDebugMode) {
            print('🔔 [SettingProvider] Force subscribing to: ${char.uuid}');
          }

          await _subscribeToCharacteristic(char);

          // รอสักครู่เพื่อให้ระบบประมวลผล
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    if (kDebugMode) {
      print('✅ [SettingProvider] Force subscribe completed');
      await debugConnectionStatus();
    }
  }

  // ⭐ Force subscribe ทุก characteristics (รวมที่ไม่มี notify)
  Future<void> forceSubscribeAllCharacteristics() async {
    if (kDebugMode) {
      print('🔄 [SettingProvider] Force subscribing to ALL characteristics...');
    }

    // Cancel existing subscriptions first
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
    _characteristicSubscriptionsStatus.clear(); // ✅ Fixed syntax

    for (var serviceEntry in _characteristics.entries) {
      for (var char in serviceEntry.value) {
        if (kDebugMode) {
          print(
            '🔧 [SettingProvider] Force subscribing to: ${char.uuid} (${getCharacteristicProperties(char)})',
          );
        }

        try {
          await char.setNotifyValue(true);

          final subscription = char.onValueReceived.listen((value) {
            if (kDebugMode) {
              print(
                '📨 [FORCE] Data received from ${char.uuid}: ${value.length} bytes',
              );
              String text = String.fromCharCodes(value).trim();
              print('📨 [FORCE] Raw text: "$text"');
            }

            _characteristicValues[char.uuid.toString()] = value;

            double? rawValue = _extractRawValue(value);
            if (rawValue != null) {
              _currentRawValue = rawValue;
              _primaryCharacteristicUuid = char.uuid.toString();

              if (kDebugMode) {
                print('⚖️ [FORCE] Updated current raw value: $rawValue');
              }
            }

            notifyListeners();
          });

          _characteristicSubscriptions.add(subscription);
          _characteristicSubscriptionsStatus[char.uuid.toString()] =
              true; // ✅ Fixed syntax

          if (kDebugMode) {
            print('✅ [FORCE] Successfully subscribed to ${char.uuid}');
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              '❌ [FORCE] Error subscribing to characteristic ${char.uuid}: $e',
            );
          }
        }

        // รอสักครู่เพื่อให้ระบบประมวลผล
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    if (kDebugMode) {
      print(
        '✅ [SettingProvider] Force subscribe to all characteristics completed',
      );
      await debugConnectionStatus();
    }
  }

  // ⭐ Manual subscribe to specific characteristic
  Future<void> manualSubscribeToCharacteristic(
    String characteristicUuid,
  ) async {
    if (kDebugMode) {
      print(
        '🔧 [SettingProvider] Manual subscribe to characteristic: $characteristicUuid',
      );
    }

    BluetoothCharacteristic? targetChar;

    // หา characteristic ที่ต้องการ
    for (var serviceEntry in _characteristics.entries) {
      for (var char in serviceEntry.value) {
        if (char.uuid.toString().toLowerCase().contains(
              characteristicUuid.toLowerCase(),
            ) ||
            characteristicUuid.toLowerCase().contains(
              char.uuid.toString().toLowerCase(),
            )) {
          targetChar = char;
          break;
        }
      }
      if (targetChar != null) break;
    }

    if (targetChar == null) {
      if (kDebugMode) {
        print(
          '❌ [SettingProvider] Characteristic $characteristicUuid not found',
        );
      }
      return;
    }

    if (kDebugMode) {
      print('🎯 [SettingProvider] Found characteristic: ${targetChar.uuid}');
      print('   - Properties: ${getCharacteristicProperties(targetChar)}');
    }

    // ลอง subscribe แม้ว่าจะไม่มี notify/indicate properties
    try {
      await targetChar.setNotifyValue(true);

      final subscription = targetChar.onValueReceived.listen((value) {
        if (kDebugMode) {
          print(
            '📨 [MANUAL] Data received from ${targetChar!.uuid}: ${value.length} bytes',
          );
          String text = String.fromCharCodes(value).trim();
          print('📨 [MANUAL] Raw text: "$text"');
        }

        _characteristicValues[targetChar!.uuid.toString()] = value;

        double? rawValue = _extractRawValue(value);
        if (rawValue != null) {
          _currentRawValue = rawValue;
          _primaryCharacteristicUuid = targetChar.uuid.toString();

          if (kDebugMode) {
            print('⚖️ [MANUAL] Updated current raw value: $rawValue');
          }
        }

        notifyListeners();
      });

      _characteristicSubscriptions.add(subscription);
      _characteristicSubscriptionsStatus[targetChar.uuid.toString()] =
          true; // ✅ Fixed syntax

      if (kDebugMode) {
        print('✅ [MANUAL] Successfully subscribed to ${targetChar.uuid}');
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ [MANUAL] Error subscribing to characteristic ${targetChar.uuid}: $e',
        );
      }
    }
  }

  Future<void> unsubscribeFromCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      await characteristic.setNotifyValue(false);

      // Remove specific subscription
      _characteristicSubscriptions.removeWhere((sub) {
        // This is a simplified check - in practice you'd need better tracking
        return sub.toString().contains(characteristic.uuid.toString());
      });

      _characteristicSubscriptionsStatus[characteristic.uuid.toString()] =
          false; // ✅ Fixed syntax

      if (kDebugMode) {
        print('❌ [SettingProvider] Unsubscribed from ${characteristic.uuid}');
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ [SettingProvider] Error unsubscribing from characteristic: $e',
        );
      }
    }
  }

  bool isSubscribedTo(BluetoothCharacteristic characteristic) {
    return _characteristicSubscriptionsStatus[characteristic.uuid.toString()] ??
        false; // ✅ Fixed syntax
  }

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
        print('❌ [SettingProvider] Error turning on Bluetooth: $e');
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
        print('❌ [SettingProvider] Error starting BLE scan: $e');
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
        print('❌ [SettingProvider] Error stopping BLE scan: $e');
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
        print(
          '⚠️ [SettingProvider] Already connecting to a device, ignoring request',
        );
      }
      return;
    }

    // Check if already connected to this device
    if (_connectedDevice?.remoteId == device.remoteId) {
      if (kDebugMode) {
        print('⚠️ [SettingProvider] Already connected to this device');
      }
      return;
    }

    try {
      _isConnecting = true;
      _connectionStatus = 'Connecting to BLE device...';
      notifyListeners();

      if (kDebugMode) {
        print(
          '🔗 [SettingProvider] Connecting to ${device.platformName} (${device.remoteId})...',
        );
      }

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
      _connectionStateSubscription = device.connectionState.listen((
        state,
      ) async {
        if (state == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          _connectionStatus = 'Connected to ${device.platformName}';

          if (kDebugMode) {
            print('✅ [SettingProvider] Connected to ${device.platformName}');
          }

          // Discover BLE services and characteristics
          await _discoverBLEServices();
          await _readRSSI();
          await _requestMTU();
        } else if (state == BluetoothConnectionState.disconnected) {
          _connectedDevice = null;
          _connectionStatus = 'Disconnected';
          _clearBLEData();

          if (kDebugMode) {
            print('❌ [SettingProvider] Disconnected from device');
          }
        }
        notifyListeners();
      });
    } catch (e) {
      _connectionStatus = 'Failed to connect to BLE device';
      if (kDebugMode) {
        print('❌ [SettingProvider] Error connecting to BLE device: $e');
      }
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

  // ⭐ Auto-detect discovery services
  Future<void> _discoverBLEServices() async {
    if (_connectedDevice == null) return;

    try {
      bool hasNotify = false;
      bool hasWrite = false;

      for (BluetoothService service in _services) {
        _characteristics[service.uuid.toString()] = service.characteristics;

        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            hasNotify = true;
            await _subscribeToCharacteristic(characteristic);
          }
          if (characteristic.properties.write ||
              characteristic.properties.writeWithoutResponse) {
            hasWrite = true;
          }
        }
      }
      if (!hasNotify && hasWrite) {
        // เริ่ม timer สำหรับขอข้อมูลเป็นระยะ
        _startPeriodicDataRequest();
      }
      if (kDebugMode) {
        print('🔍 [SettingProvider] Discovering BLE services...');
      }

      // Clear existing subscriptions first
      for (var subscription in _characteristicSubscriptions) {
        subscription.cancel();
      }
      _characteristicSubscriptions.clear();
      _characteristicSubscriptionsStatus.clear(); // ✅ Fixed syntax

      _services = await _connectedDevice!.discoverServices(); // ✅ Fixed syntax
      _characteristics.clear();

      if (kDebugMode) {
        print('📋 [SettingProvider] Found ${_services.length} services');
      }

      // ⭐ Auto-detect และ subscribe ทุก notify characteristics
      for (BluetoothService service in _services) {
        _characteristics[service.uuid.toString()] = service.characteristics;

        if (kDebugMode) {
          print(
            '📁 [SettingProvider] Service: ${service.uuid} with ${service.characteristics.length} characteristics',
          );
        }

        for (BluetoothCharacteristic characteristic
            in service.characteristics) {
          if (kDebugMode) {
            print(
              '  📋 [SettingProvider] Characteristic: ${characteristic.uuid}',
            );
            print('     - Read: ${characteristic.properties.read}');
            print('     - Write: ${characteristic.properties.write}');
            print(
              '     - WriteWithoutResponse: ${characteristic.properties.writeWithoutResponse}',
            );
            print('     - Notify: ${characteristic.properties.notify}');
            print('     - Indicate: ${characteristic.properties.indicate}');
          }

          // ⭐ Subscribe ทุก characteristic ที่มี notify หรือ indicate
          if (characteristic.properties.notify ||
              characteristic.properties.indicate) {
            if (kDebugMode) {
              print(
                '🔔 [SettingProvider] Auto-subscribing to: ${characteristic.uuid}',
              );
            }
            await _subscribeToCharacteristic(characteristic);

            // Add delay between subscriptions เพื่อป้องกัน conflicts
            await Future.delayed(const Duration(milliseconds: 200));
          }
        }
      }

      if (kDebugMode) {
        print('✅ [SettingProvider] Service discovery completed');
        print(
          '📊 [SettingProvider] Total characteristics: ${_characteristics.values.expand((list) => list).length}',
        );
        print(
          '📊 [SettingProvider] Subscribed: ${_characteristicSubscriptionsStatus.values.where((subscribed) => subscribed).length}',
        );
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SettingProvider] Error discovering BLE services: $e');
      }
    }
  }

  Timer? _dataRequestTimer;

  void _startPeriodicDataRequest() {
    _dataRequestTimer?.cancel();
    _dataRequestTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      requestWeightData();
    });
  }

  // ⭐ ปรับปรุง _subscribeToCharacteristic ให้ robust ขึ้น
  Future<void> _subscribeToCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
    try {
      if (kDebugMode) {
        print(
          '🔔 [SettingProvider] Attempting to subscribe to: ${characteristic.uuid}',
        );
      }

      // Check if already subscribed
      bool isAlreadySubscribed =
          _characteristicSubscriptionsStatus[characteristic.uuid.toString()] ??
          false; // ✅ Fixed syntax

      if (isAlreadySubscribed) {
        if (kDebugMode) {
          print(
            '⚠️ [SettingProvider] Already subscribed to ${characteristic.uuid}',
          );
        }
        return;
      }

      await characteristic.setNotifyValue(true);

      final subscription = characteristic.onValueReceived.listen((value) {
        if (kDebugMode) {
          String text = String.fromCharCodes(value).trim();
          print(
            '📨 [SettingProvider] Data from ${characteristic.uuid}: "$text" (${value.length} bytes)',
          );
        }

        _characteristicValues[characteristic.uuid.toString()] = value;

        // ⭐ แยกค่า raw value และเก็บ raw text
        double? rawValue = _extractRawValue(value);
        if (rawValue != null) {
          _currentRawValue = rawValue;

          // ⭐ Auto-set เป็น primary characteristic ถ้าได้รับข้อมูลน้ำหนัก
          if (_primaryCharacteristicUuid == null ||
              _primaryCharacteristicUuid != characteristic.uuid.toString()) {
            _primaryCharacteristicUuid = characteristic.uuid.toString();
            if (kDebugMode) {
              print(
                '🎯 [SettingProvider] Set ${characteristic.uuid} as primary weight characteristic',
              );
            }
          }

          if (kDebugMode) {
            print('⚖️ [SettingProvider] Updated raw value: $rawValue');
          }
        }

        notifyListeners();
      });

      _characteristicSubscriptions.add(subscription);
      _characteristicSubscriptionsStatus[characteristic.uuid.toString()] =
          true; // ✅ Fixed syntax

      if (kDebugMode) {
        print(
          '✅ [SettingProvider] Successfully subscribed to ${characteristic.uuid}',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print(
          '❌ [SettingProvider] Error subscribing to ${characteristic.uuid}: $e',
        );
      }
    }
  }

  Future<void> readCharacteristic(
    BluetoothCharacteristic characteristic,
  ) async {
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

  // ⭐ ปรับปรุง writeCharacteristic ให้หา characteristic อัตโนมัติ
  Future<void> writeCharacteristic(
    BluetoothCharacteristic? characteristic,
    List<int> value,
  ) async {
    try {
      BluetoothCharacteristic? targetChar =
          characteristic ?? getWriteCharacteristic();

      if (targetChar == null) {
        if (kDebugMode) {
          print('❌ [SettingProvider] No writable characteristic found');
        }
        return;
      }

      if (kDebugMode) {
        String message = String.fromCharCodes(value);
        print('✍️ [SettingProvider] Writing "$message" to ${targetChar.uuid}');
      }

      await targetChar.write(value);

      if (kDebugMode) {
        print('✅ [SettingProvider] Write successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ [SettingProvider] Error writing characteristic: $e');
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
    _characteristicSubscriptionsStatus.clear();
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
      RegExp weightPattern = RegExp(
        r'Weight:\s*([+-]?\d+\.?\d*)',
        caseSensitive: false,
      );
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
    if (characteristic.properties.writeWithoutResponse)
      props.add('Write w/o Response');
    if (characteristic.properties.notify) props.add('Notify');
    if (characteristic.properties.indicate) props.add('Indicate');
    return props.join(', ');
  }

  @override
  void dispose() {
    _adapterStateSubscription?.cancel();
    _scanResultsSubscription?.cancel();
    _dataRequestTimer?.cancel();
    _connectionStateSubscription?.cancel();

    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }

    _stopBLEScan();
    disconnectBLEDevice();
    super.dispose();
  }
}
