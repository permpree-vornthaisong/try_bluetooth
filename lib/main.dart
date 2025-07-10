import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';

import 'providers/GenericCRUDProvider.dart';
import 'providers/GenericTestPageProvider.dart';
import 'providers/FormulaProvider.dart';
import 'providers/SettingProvider.dart';
import 'providers/DisplayProvider.dart';
import 'providers/DisplayHomeProvider.dart';
import 'providers/BottomNavigationBarProvider.dart';

import 'pages/DisplayHomePage.dart';
import 'pages/FormulaWidget.dart';
import 'pages/SettingsPage.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GenericCRUDProvider()),
        ChangeNotifierProvider(create: (_) => GenericTestPageProvider()),
        ChangeNotifierProvider(create: (_) => FormulaProvider()),
        ChangeNotifierProvider(create: (_) => SettingProvider()),
        ChangeNotifierProvider(create: (_) => DisplayProvider()),
        ChangeNotifierProvider(create: (_) => DisplayHomeProvider()),
        ChangeNotifierProvider(create: (_) => DeviceConnectionProvider()),
        ChangeNotifierProvider(create: (_) => BottomNavigationBarProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MainScaffold(), // ใช้ scaffold หลักของคุณ
    );
  }
}

class MainScaffold extends StatelessWidget {
  MainScaffold({super.key});

  static final List<Widget> _pages = [
    DisplayHomePage(), // จะ initialize เอง
    FormulaWidget(), // จะ initialize เอง
    SettingsPage(), // จะ initialize เอง
  ];

  @override
  Widget build(BuildContext context) {
    final bottomNavProvider = Provider.of<BottomNavigationBarProvider>(context);

    return Scaffold(
      body: _pages[bottomNavProvider.selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: bottomNavProvider.selectedIndex,
        onTap: (index) {
          bottomNavProvider.changeIndex(index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight),
            label: 'Display',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.functions),
            label: 'Formula',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
