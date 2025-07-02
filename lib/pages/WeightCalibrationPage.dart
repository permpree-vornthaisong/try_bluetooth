import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';

class WeightCalibrationPage extends StatelessWidget {
  const WeightCalibrationPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeviceConnectionProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calibration & Weight'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Zero Factor Section
            Text(
              'Zero Factor',
              style: Theme.of(context).textTheme.headline6,
            ),
            ElevatedButton(
              onPressed: () {
                provider.sendData('Z'); // ส่งคำสั่ง Zero Factor
              },
              child: const Text('Set Zero Factor'),
            ),
            const SizedBox(height: 16),

            // Calibration Factor Section
            Text(
              'Calibration Factor',
              style: Theme.of(context).textTheme.headline6,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter known weight (kg)',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      provider.calibrationWeight = value; // เก็บน้ำหนักที่ป้อน
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (provider.calibrationWeight != null) {
                      provider.sendData('F${provider.calibrationWeight}');
                    }
                  },
                  child: const Text('Calibrate'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Read Weight Section
            Text(
              'Read Weight',
              style: Theme.of(context).textTheme.headline6,
            ),
            ElevatedButton(
              onPressed: () {
                provider.sendData('O'); // ส่งคำสั่งเปิดการอ่านน้ำหนัก
              },
              child: const Text('Start Reading Weight'),
            ),
            const SizedBox(height: 16),

            // Display Weight
            Text(
              'Current Weight:',
              style: Theme.of(context).textTheme.headline6,
            ),
            Consumer<DeviceConnectionProvider>(
              builder: (context, provider, child) {
                return Text(
                  provider.currentWeight ?? 'No data',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}