// ตัวอย่างการใช้งานใน Widget
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';
import 'package:try_bluetooth/providers/WeightCalibrationProvider.dart';

class WeightDisplayWidget extends StatefulWidget {
  @override
  _WeightDisplayWidgetState createState() => _WeightDisplayWidgetState();
}

class _WeightDisplayWidgetState extends State<WeightDisplayWidget> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WeightCalibrationProvider>(
      builder: (context, weightProvider, child) {
        return Column(
          children: [
            // แสดงสถานะการเชื่อมต่อ
            Text(
              'สถานะ: ${weightProvider.isConnected ? "เชื่อมต่อแล้ว" : "ยังไม่เชื่อมต่อ"}',
              style: TextStyle(
                color: weightProvider.isConnected ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 10),

            // แสดงข้อมูลดิบล่าสุด
            Text('ข้อมูลดิบ: ${weightProvider.lastRawData}'),

            SizedBox(height: 10),

            // แสดงน้ำหนักล่าสุด
            Text(
              'น้ำหนักล่าสุด: ${weightProvider.latestWeight?.toStringAsFixed(2) ?? 'N/A'} kg',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            // แสดงค่าเฉลี่ย
            Text(
              'ค่าเฉลี่ย: ${weightProvider.averageWeight.toStringAsFixed(2)} kg',
            ),

            // แสดงค่าสูงสุด-ต่ำสุด
            Text(
              'สูงสุด: ${weightProvider.maxWeight?.toStringAsFixed(2) ?? 'N/A'} kg',
            ),
            Text(
              'ต่ำสุด: ${weightProvider.minWeight?.toStringAsFixed(2) ?? 'N/A'} kg',
            ),

            SizedBox(height: 10),

            // แสดงรายการน้ำหนักทั้งหมด
            Text(weightProvider.weightsLast10Text),

            SizedBox(height: 20),

            // ปุ่มต่างๆ
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // จำลองการรับข้อมูลจาก Bluetooth
                    weightProvider.processBluetoothData(
                      Uint8List.fromList('Weight: 130679.00 kg'.codeUnits),
                    );
                  },
                  child: Text('ทดสอบข้อมูล'),
                ),

                ElevatedButton(
                  onPressed: () {
                    weightProvider.clearWeights();
                  },
                  child: Text('ล้างข้อมูล'),
                ),

                ElevatedButton(
                  onPressed: () {
                    // ประมวลผลข้อมูลล่าสุดจากอุปกรณ์
                    weightProvider.processLatestDeviceData();
                  },
                  child: Text('อ่านข้อมูลล่าสุด'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

// ตัวอย่างการเชื่อมต่อกับ DeviceConnectionProvider
class BluetoothWeightApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceConnectionProvider()),
        ChangeNotifierProxyProvider<
          DeviceConnectionProvider,
          WeightCalibrationProvider
        >(
          create: (_) => WeightCalibrationProvider(),
          update: (_, deviceProvider, weightProvider) {
            weightProvider!.deviceProvider = deviceProvider;
            return weightProvider;
          },
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: Text('Weight Calibration')),
          body: Padding(
            padding: EdgeInsets.all(16.0),
            child: WeightDisplayWidget(),
          ),
        ),
      ),
    );
  }
}
