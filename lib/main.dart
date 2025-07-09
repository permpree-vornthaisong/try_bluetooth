import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/FormulaWidget.dart';
import 'package:try_bluetooth/pages/TestEntityCar.dart';
import 'package:try_bluetooth/pages/TestPageWidget.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/GenericCRUDProvider.dart';
import 'package:try_bluetooth/providers/GenericTestPageProvider.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // เพิ่ม GenericCRUDProvider เท่านั้น
        ChangeNotifierProvider<GenericCRUDProvider>(
          create: (context) => GenericCRUDProvider(),
        ),
        ChangeNotifierProvider<GenericTestPageProvider>(
          create: (context) => GenericTestPageProvider(),
        ),
        ChangeNotifierProvider<FormulaProvider>(
          create: (context) => FormulaProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'Test CRUD App',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: FormulaWidget(), // ใช้ TestPage เป็นหน้าหลัก
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
