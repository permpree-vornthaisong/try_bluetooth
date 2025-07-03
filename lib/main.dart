import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/SettingsPage.dart';
import 'package:try_bluetooth/pages/DisplayPage.dart';
import 'package:try_bluetooth/widgets/CalibrationWidget.dart';
import 'package:try_bluetooth/widgets/FactoryCalibrationWidget.dart';
import 'package:try_bluetooth/providers/NavigationBar1Provider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/DisplayProvider.dart';
import 'package:try_bluetooth/providers/CalibrationProvider.dart';
import 'package:try_bluetooth/providers/FactoryCalibrationProvider.dart';

/// Flutter code sample for [NavigationBar] using Provider pattern.

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Navigation App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => NavigationBar1Provider()),
          ChangeNotifierProvider(create: (context) => SettingProvider()),
          ChangeNotifierProvider(create: (context) => DisplayProvider()),
          ChangeNotifierProvider(create: (context) => CalibrationProvider()),
          ChangeNotifierProvider(create: (context) => FactoryCalibrationProvider()),
        ],
        child: const NavigationExample(),
      ),
    );
  }
}

class NavigationExample extends StatelessWidget {
  const NavigationExample({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      bottomNavigationBar: Consumer<NavigationBar1Provider>(
        builder: (context, navigationProvider, child) {
          return NavigationBar(
            onDestinationSelected: (int index) {
              navigationProvider.setCurrentPageIndex(index);
            },
            indicatorColor: Colors.amber,
            selectedIndex: navigationProvider.currentPageIndex,
            destinations: const <Widget>[
              NavigationDestination(
                selectedIcon: Icon(Icons.display_settings),
                icon: Icon(Icons.display_settings_outlined),
                label: 'Display',
              ),
              NavigationDestination(
                icon: Badge(child: Icon(Icons.tune)),
                label: 'Calibration',
              ),
              NavigationDestination(
                icon: Badge(child: Icon(Icons.factory)),
                label: 'Factory',
              ),
              NavigationDestination(
                icon: Badge(child: Icon(Icons.notifications_sharp)),
                label: 'Notifications',
              ),
              NavigationDestination(
                icon: Badge(
                  label: Text('BLE'),
                  child: Icon(Icons.settings),
                ),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
      body: Consumer<NavigationBar1Provider>(
        builder: (context, navigationProvider, child) {
          return _buildCurrentPage(
            context,
            theme,
            navigationProvider.currentPageIndex,
          );
        },
      ),
    );
  }

  Widget _buildCurrentPage(
    BuildContext context,
    ThemeData theme,
    int currentPageIndex,
  ) {
    switch (currentPageIndex) {
      case 0:
        return const DisplayPage(); // BLE Data Display page
      case 1:
        return const CalibrationWidget(); // Weight Calibration page
      case 2:
        return const FactoryCalibrationWidget(); // Factory Calibration page
      case 3:
        return _buildNotificationsPage();
      case 4:
        return const SettingsPage(); // BLE Settings page
      default:
        return const DisplayPage();
    }
  }

  Widget _buildHomePage(ThemeData theme) {
    return Card(
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.all(8.0),
      child: SizedBox.expand(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.bluetooth,
                size: 64,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'BLE Navigation App',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Navigate to Settings to manage BLE connections',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsPage() {
    return Consumer<SettingProvider>(
      builder: (context, settingProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: <Widget>[
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.bluetooth,
                    color: settingProvider.isBluetoothOn ? Colors.blue : Colors.grey,
                  ),
                  title: const Text('Bluetooth Status'),
                  subtitle: Text(
                    settingProvider.isBluetoothOn ? 'Bluetooth is ON' : 'Bluetooth is OFF',
                  ),
                ),
              ),
              Card(
                child: ListTile(
                  leading: Icon(
                    settingProvider.connectedDevice != null 
                        ? Icons.bluetooth_connected 
                        : Icons.bluetooth_disabled,
                    color: settingProvider.connectedDevice != null ? Colors.green : Colors.grey,
                  ),
                  title: const Text('BLE Connection'),
                  subtitle: Text(settingProvider.connectionStatus),
                ),
              ),
              if (settingProvider.connectedDevice != null)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info, color: Colors.blue),
                    title: Text('Connected to: ${settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!)}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RSSI: ${settingProvider.rssi ?? 'Unknown'} dBm'),
                        Text('Services: ${settingProvider.services.length}'),
                      ],
                    ),
                  ),
                ),
              if (settingProvider.bleDevices.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.devices_other, color: Colors.orange),
                    title: const Text('Available BLE Devices'),
                    subtitle: Text('${settingProvider.bleDevices.length} devices found'),
                  ),
                ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.display_settings, color: Colors.purple),
                  title: const Text('ASCII Data Display'),
                  subtitle: const Text('View real-time data from BLE device'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to Display tab
                    Provider.of<NavigationBar1Provider>(context, listen: false).setCurrentPageIndex(0);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}