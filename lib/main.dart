import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/ScanPage.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';
import 'package:try_bluetooth/providers/ScanProvider.dart';
import 'package:try_bluetooth/providers/WeightCalibrationProvider.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => DeviceConnectionProvider()),
        ChangeNotifierProvider(create: (_) => WeightCalibrationProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluetooth Scanner',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ScanPage(),
    );
  }
}
