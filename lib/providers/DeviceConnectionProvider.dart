import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class DeviceConnectionProvider extends ChangeNotifier {
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState = BluetoothConnectionState.disconnected;
  List<BluetoothService> _services = [];
  List<Uint8List> _receivedData = [];
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  StreamSubscription<List<int>>? _dataSubscription;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
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

      // ค้นหา services
      await discoverServices();

      _isConnecting = false;
      notifyListeners();
    } catch (e) {
      _isConnecting = false;
      _statusMessage = 'เชื่อมต่อล้มเหลว: $e';
      notifyListeners();
    }
  }

  Future<void> discoverServices() async {
    if (_connectedDevice == null) return;

    try {
      _statusMessage = 'กำลังค้นหา services...';
      notifyListeners();

      _services = await _connectedDevice!.discoverServices();

      // ค้นหา characteristics สำหรับอ่านและเขียน
      for (BluetoothService service in _services) {
        for (BluetoothCharacteristic characteristic in service.characteristics) {
          // ตรวจสอบ properties
          if (characteristic.properties.write || 
              characteristic.properties.writeWithoutResponse) {
            _writeCharacteristic = characteristic;
          }
          
          if (characteristic.properties.notify || 
              characteristic.properties.indicate) {
            _notifyCharacteristic = characteristic;
            // เริ่มรับข้อมูล
            await startNotifications();
          }
        }
      }

      _statusMessage = 'พร้อมรับส่งข้อมูล';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ค้นหา services ล้มเหลว: $e';
      notifyListeners();
    }
  }

  Future<void> startNotifications() async {
    if (_notifyCharacteristic == null) return;

    try {
      await _notifyCharacteristic!.setNotifyValue(true);
      
      _dataSubscription = _notifyCharacteristic!.value.listen((data) {
        if (data.isNotEmpty) {
          _receivedData.add(Uint8List.fromList(data));
          // เก็บแค่ 100 รายการล่าสุด
          if (_receivedData.length > 100) {
            _receivedData.removeAt(0);
          }
          notifyListeners();
        }
      });
    } catch (e) {
      _statusMessage = 'เริ่มรับข้อมูลล้มเหลว: $e';
      notifyListeners();
    }
  }

  Future<void> sendData(String data) async {
    if (_writeCharacteristic == null) {
      _statusMessage = 'ไม่พบ characteristic สำหรับส่งข้อมูล';
      notifyListeners();
      return;
    }

    try {
      // แปลง string เป็น bytes
      List<int> bytes = data.codeUnits;
      
      // ตรวจสอบว่าต้องใช้ write หรือ writeWithoutResponse
      if (_writeCharacteristic!.properties.writeWithoutResponse) {
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
      } else {
        await _writeCharacteristic!.write(bytes);
      }

      _statusMessage = 'ส่งข้อมูลสำเร็จ: $data';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ส่งข้อมูลล้มเหลว: $e';
      notifyListeners();
    }
  }

  Future<void> sendBytes(List<int> bytes) async {
    if (_writeCharacteristic == null) {
      _statusMessage = 'ไม่พบ characteristic สำหรับส่งข้อมูล';
      notifyListeners();
      return;
    }

    try {
      if (_writeCharacteristic!.properties.writeWithoutResponse) {
        await _writeCharacteristic!.write(bytes, withoutResponse: true);
      } else {
        await _writeCharacteristic!.write(bytes);
      }

      _statusMessage = 'ส่ง bytes สำเร็จ: ${bytes.length} bytes';
      notifyListeners();
    } catch (e) {
      _statusMessage = 'ส่ง bytes ล้มเหลว: $e';
      notifyListeners();
    }
  }

  void clearReceivedData() {
    _receivedData.clear();
    notifyListeners();
  }

  Future<void> disconnect() async {
    try {
      await _dataSubscription?.cancel();
      await _connectionStateSubscription?.cancel();
      
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      
      _clearConnection();
      notifyListeners();
    } catch (e) {
      debugPrint('Disconnect error: $e');
    }
  }

  void _clearConnection() {
    _connectedDevice = null;
    _services.clear();
    _receivedData.clear();
    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _connectionState = BluetoothConnectionState.disconnected;
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}