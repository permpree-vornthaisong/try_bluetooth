import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';

class WeightCalibrationPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weight Calibration')),
      body: Consumer<DeviceConnectionProvider>(
        builder: (context, deviceProvider, child) {
          return Column(
            children: [
              // แสดงสถานะการเชื่อมต่อ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color:
                    deviceProvider.isConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      deviceProvider.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          deviceProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      deviceProvider.isConnected
                          ? 'Connected to Device'
                          : 'Not Connected',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // แสดงข้อมูลน้ำหนักที่ได้รับ
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last 10 Weights:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child:
                            deviceProvider.receivedData.isEmpty
                                ? const Center(
                                  child: Text(
                                    'No weight data received yet.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                                : ListView.builder(
                                  itemCount: deviceProvider.receivedData.length,
                                  itemBuilder: (context, index) {
                                    final rawData =
                                        deviceProvider.receivedData[index];
                                    final weight = _parseWeight(
                                      rawData,
                                    ); // แปลงข้อมูลเป็นน้ำหนัก
                                    return ListTile(
                                      title: Text('Weight: $weight kg'),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ฟังก์ชันแปลงข้อมูลเป็นน้ำหนัก
  double _parseWeight(Uint8List rawData) {
    try {
      final asciiData = String.fromCharCodes(rawData);
      return double.tryParse(asciiData) ?? 0.0; // แปลงเป็น double
    } catch (e) {
      return 0.0; // กรณีแปลงไม่ได้
    }
  }
}
