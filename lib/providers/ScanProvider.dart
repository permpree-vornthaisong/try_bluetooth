import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class BluetoothDeviceInfo {
  final String name;
  final String address;
  final DeviceType type;
  final int? rssi;
  final BluetoothDevice? bleDevice;

  BluetoothDeviceInfo({
    required this.name,
    required this.address,
    required this.type,
    this.rssi,
    this.bleDevice,
  });
}

enum DeviceType { ble, classic }

class ScanProvider extends ChangeNotifier {
  List<BluetoothDeviceInfo> _devices = [];
  bool _isScanning = false;
  String _statusMessage = '';

  List<BluetoothDeviceInfo> get devices => _devices;
  bool get isScanning => _isScanning;
  String get statusMessage => _statusMessage;

  // สำหรับ BLE scanning
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> startScan() async {
    if (_isScanning) return;

    _devices.clear();
    _isScanning = true;
    _statusMessage = 'กำลังขอสิทธิ์...';
    notifyListeners();

    // ขอสิทธิ์ที่จำเป็น
    bool hasPermissions = await _requestPermissions();
    if (!hasPermissions) {
      _statusMessage = 'ไม่ได้รับอนุญาตให้ใช้ Bluetooth';
      _isScanning = false;
      notifyListeners();
      return;
    }

    // ตรวจสอบว่า Bluetooth เปิดอยู่หรือไม่
    bool isBluetoothOn = await FlutterBluePlus.isOn;
    if (!isBluetoothOn) {
      _statusMessage = 'กรุณาเปิด Bluetooth';
      _isScanning = false;
      notifyListeners();
      return;
    }

    _statusMessage = 'กำลังค้นหาอุปกรณ์...';
    notifyListeners();

    // เริ่มสแกน BLE
    await _startBLEScan();

    // สำหรับ Classic Bluetooth บน Android
    if (Platform.isAndroid) {
      await _startClassicScan();
    }
  }

  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [
          Permission.bluetooth,
          Permission.bluetoothScan,
          Permission.bluetoothConnect,
          Permission.location,
        ].request();

    return statuses.values.every(
      (status) => status == PermissionStatus.granted,
    );
  }

  Future<void> _startBLEScan() async {
    try {
      // หยุดการสแกนเก่า (ถ้ามี)
      await FlutterBluePlus.stopScan();

      // ดึงอุปกรณ์ที่เชื่อมต่ออยู่
      List<BluetoothDevice> connectedDevices =
          await FlutterBluePlus.connectedDevices;
      for (var device in connectedDevices) {
        _addDevice(
          BluetoothDeviceInfo(
            name: device.name.isNotEmpty ? device.name : 'Unknown Device',
            address: device.id.toString(),
            type: DeviceType.ble,
            bleDevice: device,
          ),
        );
      }

      // เริ่มสแกนหาอุปกรณ์ใหม่
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          // ตรวจสอบว่าอุปกรณ์นี้ยังไม่อยู่ในรายการ
          bool exists = _devices.any(
            (d) => d.address == result.device.id.toString(),
          );
          if (!exists) {
            _addDevice(
              BluetoothDeviceInfo(
                name:
                    result.device.name.isNotEmpty
                        ? result.device.name
                        : 'Unknown Device',
                address: result.device.id.toString(),
                type: DeviceType.ble,
                rssi: result.rssi,
                bleDevice: result.device,
              ),
            );
          }
        }
      });

      // เริ่มสแกน (10 วินาที)
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      // รอจนสแกนเสร็จ
      Future.delayed(const Duration(seconds: 10), () {
        stopScan();
      });
    } catch (e) {
      _statusMessage = 'เกิดข้อผิดพลาด: $e';
      notifyListeners();
    }
  }

  Future<void> _startClassicScan() async {
    // สำหรับ Classic Bluetooth จำเป็นต้องใช้ platform-specific code
    // หรือใช้ package เพิ่มเติม เช่น flutter_bluetooth_serial
    // ตัวอย่างนี้จะแสดงเฉพาะอุปกรณ์ที่จับคู่แล้ว

    try {
      // ถ้าใช้ flutter_bluetooth_serial
      // List<BluetoothDevice> bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      // for (var device in bondedDevices) {
      //   _addDevice(BluetoothDeviceInfo(
      //     name: device.name ?? 'Unknown Device',
      //     address: device.address,
      //     type: DeviceType.classic,
      //   ));
      // }
    } catch (e) {
      debugPrint('Classic Bluetooth scan error: $e');
    }
  }

  void _addDevice(BluetoothDeviceInfo device) {
    _devices.add(device);
    notifyListeners();
  }

  Future<void> stopScan() async {
    _scanSubscription?.cancel();
    await FlutterBluePlus.stopScan();
    _isScanning = false;
    _statusMessage = 'สแกนเสร็จสิ้น';
    notifyListeners();
  }

  Future<void> connectToDevice(BluetoothDeviceInfo deviceInfo) async {
    if (deviceInfo.type == DeviceType.ble && deviceInfo.bleDevice != null) {
      try {
        _statusMessage = 'กำลังเชื่อมต่อกับ ${deviceInfo.name}...';
        notifyListeners();

        await deviceInfo.bleDevice!.connect();

        _statusMessage = 'เชื่อมต่อสำเร็จ!';
        notifyListeners();
      } catch (e) {
        _statusMessage = 'เชื่อมต่อล้มเหลว: $e';
        notifyListeners();
      }
    } else if (deviceInfo.type == DeviceType.classic) {
      // สำหรับ Classic Bluetooth
      _statusMessage = 'Classic Bluetooth ต้องใช้ implementation เพิ่มเติม';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    super.dispose();
  }
}
