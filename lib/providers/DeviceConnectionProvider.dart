import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceConnectionProvider extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  List<Uint8List> _receivedData = [];
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  List<StreamSubscription<List<int>>> _dataSubscriptions = []; // ⭐ เปลี่ยนเป็น List
  List<BluetoothCharacteristic> _writeCharacteristics = []; // ⭐ เก็บทุก write characteristics
  List<BluetoothCharacteristic> _notifyCharacteristics = []; // ⭐ เก็บทุก notify characteristics
  String _statusMessage = '';
  bool _isConnecting = false;

  // Getters
  BluetoothDevice? get connectedDevice => _connectedDevice;
  BluetoothConnectionState get connectionState => _connectionState;
  List<BluetoothService> get services => _services;
  List<Uint8List> get receivedData => _receivedData;
  String get statusMessage => _statusMessage;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _connectionState == BluetoothConnectionState.connected;

  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) return;

    try {
      _isConnecting = true;
      _statusMessage = 'กำลังเชื่อมต่อ...';
      notifyListeners();

      if (kDebugMode) {
        print('🔗 [DeviceConnection] Connecting to ${device.platformName}...');
      }

      // ยกเลิกการเชื่อมต่อเก่า (ถ้ามี)
      await disconnect();

      _connectedDevice = device;

      // ฟังสถานะการเชื่อมต่อ
      _connectionStateSubscription = device.connectionState.listen((state) {
        _connectionState = state;
        if (state == BluetoothConnectionState.disconnected) {
          _statusMessage = 'ตัดการเชื่อมต่อแล้ว';
          _clearConnection();
        } else if (state == BluetoothConnectionState.connected) {
          _statusMessage = 'เชื่อมต่อสำเร็จ';
        }
        notifyListeners();
      });

      // เชื่อมต่อ
      await device.connect(autoConnect: false);

      // ค้นหา services และ characteristics
      await discoverServices();
      await startAllNotifications(); // ⭐ เปลี่ยนเป็น auto-detect ทุก characteristics

      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _statusMessage = 'เชื่อมต่อล้มเหลว: $e';
      
      if (kDebugMode) {
        print('❌ [DeviceConnection] Connection failed: $e');
      }
      
      notifyListeners();
    }
  }

  Future<void> discoverServices() async {
    if (_connectedDevice == null) return;

    try {
      _statusMessage = 'กำลังค้นหา services...';
      notifyListeners();

      if (kDebugMode) {
        print('🔍 [DeviceConnection] Discovering services...');
      }

      _services = await _connectedDevice!.discoverServices();
      _writeCharacteristics.clear();
      _notifyCharacteristics.clear();

      // ⭐ Auto-detect ทุก characteristics
      for (BluetoothService service in _services) {
        if (kDebugMode) {
          print('📁 [DeviceConnection] Service: ${service.uuid}');
        }
        
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          if (kDebugMode) {
            print('  📋 [DeviceConnection] Characteristic: ${characteristic.uuid}');
            print('     - Properties: Read=${characteristic.properties.read}, Write=${characteristic.properties.write}, WriteNoResp=${characteristic.properties.writeWithoutResponse}, Notify=${characteristic.properties.notify}, Indicate=${characteristic.properties.indicate}');
          }
          
          // เก็บ write characteristics
          if (characteristic.properties.write || characteristic.properties.writeWithoutResponse) {
            _writeCharacteristics.add(characteristic);
            if (kDebugMode) {
              print('     ✍️ [DeviceConnection] Added as write characteristic');
            }
          }
          
          // เก็บ notify characteristics
          if (characteristic.properties.notify || characteristic.properties.indicate) {
            _notifyCharacteristics.add(characteristic);
            if (kDebugMode) {
              print('     🔔 [DeviceConnection] Added as notify characteristic');
            }
          }
        }
      }

      if (kDebugMode) {
        print('✅ [DeviceConnection] Discovery completed');
        print('📊 [DeviceConnection] Found ${_writeCharacteristics.length} write characteristics');
        print('📊 [DeviceConnection] Found ${_notifyCharacteristics.length} notify characteristics');
      }

      _statusMessage = 'พร้อมรับส่งข้อมูล';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ค้นหา services ล้มเหลว: $e';
      
      if (kDebugMode) {
        print('❌ [DeviceConnection] Service discovery failed: $e');
      }
      
      notifyListeners();
    }
  }

  // ⭐ เปลี่ยนเป็น subscribe ทุก notify characteristics
  Future<void> startAllNotifications() async {
    if (_notifyCharacteristics.isEmpty) {
      _statusMessage = 'ไม่พบ characteristic สำหรับรับข้อมูล';
      
      if (kDebugMode) {
        print('⚠️ [DeviceConnection] No notify characteristics found');
      }
      
      notifyListeners();
      return;
    }

    try {
      // Cancel existing subscriptions
      for (var subscription in _dataSubscriptions) {
        subscription.cancel();
      }
      _dataSubscriptions.clear();

      // Subscribe to all notify characteristics
      for (var characteristic in _notifyCharacteristics) {
        if (kDebugMode) {
          print('🔔 [DeviceConnection] Subscribing to ${characteristic.uuid}');
        }
        
        await characteristic.setNotifyValue(true);
        
        final subscription = characteristic.onValueReceived.listen((data) {
          if (data.isNotEmpty) {
            // แปลงข้อมูลที่ได้รับเป็นข้อความ
            String receivedData = String.fromCharCodes(data);
            
            if (kDebugMode) {
              print('📨 [DeviceConnection] Data from ${characteristic.uuid}: "$receivedData"');
            }

            // เก็บข้อมูลใน _receivedData
            _receivedData.add(Uint8List.fromList(data));

            // เก็บแค่ 100 รายการล่าสุด
            if (_receivedData.length > 100) {
              _receivedData.removeAt(0);
            }
            notifyListeners();
          }
        });
        
        _dataSubscriptions.add(subscription);
        
        if (kDebugMode) {
          print('✅ [DeviceConnection] Successfully subscribed to ${characteristic.uuid}');
        }
      }
      
      _statusMessage = 'เริ่มรับข้อมูลจาก ${_notifyCharacteristics.length} characteristics';
      
      if (kDebugMode) {
        print('✅ [DeviceConnection] All notifications started successfully');
      }
      
      notifyListeners();
    } catch (e) {
      _statusMessage = 'เริ่มรับข้อมูลล้มเหลว: $e';
      
      if (kDebugMode) {
        print('❌ [DeviceConnection] Failed to start notifications: $e');
      }
      
      notifyListeners();
    }
  }

  // ⭐ ปรับปรุงให้ส่งไปทุก write characteristics
  Future<void> sendData(String data) async {
    if (_writeCharacteristics.isEmpty) {
      _statusMessage = 'ไม่พบ characteristic สำหรับส่งข้อมูล';
      
      if (kDebugMode) {
        print('⚠️ [DeviceConnection] No write characteristics found');
      }
      
      notifyListeners();
      return;
    }

    try {
      // แปลง string เป็น bytes
      List<int> bytes = data.codeUnits;
      
      // ส่งไปทุก write characteristics
      for (var characteristic in _writeCharacteristics) {
        if (kDebugMode) {
          print('✍️ [DeviceConnection] Sending "$data" to ${characteristic.uuid}');
        }
        
        // ตรวจสอบว่าต้องใช้ write หรือ writeWithoutResponse
        if (characteristic.properties.writeWithoutResponse) {
          await characteristic.write(bytes, withoutResponse: true);
        } else {
          await characteristic.write(bytes);
        }
        
        if (kDebugMode) {
          print('✅ [DeviceConnection] Data sent to ${characteristic.uuid}');
        }
      }

      _statusMessage = 'ส่งข้อมูลสำเร็จ: $data';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ส่งข้อมูลล้มเหลว: $e';
      
      if (kDebugMode) {
        print('❌ [DeviceConnection] Failed to send data: $e');
      }
      
      notifyListeners();
    }
  }

  // ⭐ ปรับปรุงให้ส่งไปทุก write characteristics
  Future<void> sendBytes(List<int> bytes) async {
    if (_writeCharacteristics.isEmpty) {
      _statusMessage = 'ไม่พบ characteristic สำหรับส่งข้อมูล';
      notifyListeners();
      return;
    }

    try {
      // ส่งไปทุก write characteristics
      for (var characteristic in _writeCharacteristics) {
        if (kDebugMode) {
          print('✍️ [DeviceConnection] Sending ${bytes.length} bytes to ${characteristic.uuid}');
        }
        
        if (characteristic.properties.writeWithoutResponse) {
          await characteristic.write(bytes, withoutResponse: true);
        } else {
          await characteristic.write(bytes);
        }
      }

      _statusMessage = 'ส่ง bytes สำเร็จ: ${bytes.length} bytes';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ส่ง bytes ล้มเหลว: $e';
      
      if (kDebugMode) {
        print('❌ [DeviceConnection] Failed to send bytes: $e');
      }
      
      notifyListeners();
    }
  }

  void clearReceivedData() {
    _receivedData.clear();
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      // Cancel all subscriptions
      for (var subscription in _dataSubscriptions) {
        await subscription.cancel();
      }
      _dataSubscriptions.clear();
      
      await _connectionStateSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _clearConnection();
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ [DeviceConnection] Disconnect error: $e');
      }
    }
  }

  void _clearConnection() {
    _connectedDevice = null;
    _services.clear();
    _receivedData.clear();
    _writeCharacteristics.clear();
    _notifyCharacteristics.clear();
    _connectionState = BluetoothConnectionState.disconnected;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

String convertToAscii(Uint8List data) {
  try {
    return String.fromCharCodes(data);
  } catch (e) {
    return 'Error converting to ASCII: $e';
  }
}