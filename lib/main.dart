import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/CalibrationZeroPage.dart';
import 'package:try_bluetooth/pages/SettingsPage.dart';
import 'package:try_bluetooth/pages/DisplayPage.dart';
import 'package:try_bluetooth/providers/SaveHumanProvider.dart';
import 'package:try_bluetooth/widgets/CalibrationWidget.dart';
import 'package:try_bluetooth/widgets/FactoryCalibrationWidget.dart';
import 'package:try_bluetooth/providers/NavigationBar1Provider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/DisplayProvider.dart';
import 'package:try_bluetooth/providers/CalibrationProvider.dart';
import 'package:try_bluetooth/providers/FactoryCalibrationProvider.dart';
import 'package:try_bluetooth/providers/calibration_easy_provider.dart'; // ✅ เพิ่มนี้
// import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart'; // ✅ ถ้ามี

/// Flutter code sample for [NavigationBar] using Provider pattern.

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Navigation App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: MultiProvider(
        providers: [
          // ✅ 1. Navigation Provider
          ChangeNotifierProvider(create: (context) => NavigationBar1Provider()),

          // ✅ 2. BLE & Connection Providers
          ChangeNotifierProvider(create: (context) => SettingProvider()),
          // ChangeNotifierProvider(create: (context) => DeviceConnectionProvider()), // ถ้ามี

          // ✅ 3. Display Provider
          ChangeNotifierProvider(create: (context) => DisplayProvider()),

          // ✅ 4. Calibration Providers
          ChangeNotifierProvider(create: (context) => CalibrationProvider()),
          ChangeNotifierProvider(
            create: (context) => FactoryCalibrationProvider(),
          ),
          ChangeNotifierProvider(
            create: (context) => CalibrationEasy(),
          ), // ✅ เพิ่มนี้
          // ✅ 5. เพิ่ม Providers อื่นๆ ที่อาจมี
          // ChangeNotifierProvider(create: (context) => ThemeProvider()),
          // ChangeNotifierProvider(create: (context) => UserPreferencesProvider()),
           ChangeNotifierProvider(create: (_) => SaveHumanProvider()..initDatabase()),
        ],
        child: const NavigationExample(),
      ),
    );
  }
}

class NavigationExample extends StatefulWidget {
  const NavigationExample({super.key});

  @override
  State<NavigationExample> createState() => _NavigationExampleState();
}

class _NavigationExampleState extends State<NavigationExample> {
  @override
  void initState() {
    super.initState();

    // ✅ Initialize providers after widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  // ✅ เชื่อมต่อ providers กันหลังจาก build แล้ว
  void _initializeProviders() {
    final settingProvider = Provider.of<SettingProvider>(
      context,
      listen: false,
    );
    final calibrationEasy = Provider.of<CalibrationEasy>(
      context,
      listen: false,
    );

    // เชื่อมต่อ CalibrationEasy กับ SettingProvider
    calibrationEasy.connectToSettingProvider(settingProvider);

    // Initialize CalibrationEasy database
    calibrationEasy.initialize();

    print('All providers initialized and connected');
  }

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
                icon: Badge(label: Text('BLE'), child: Icon(Icons.settings)),
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
        return CalibrationZeroPage(); // Factory Calibration page
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
              Icon(Icons.bluetooth, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('BLE Navigation App', style: theme.textTheme.headlineMedium),
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
    return Consumer3<SettingProvider, CalibrationEasy, CalibrationProvider>(
      builder: (
        context,
        settingProvider,
        calibrationEasy,
        calibrationProvider,
        child,
      ) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                // ✅ 1. Bluetooth Status Card
                Card(
                  child: ListTile(
                    leading: Icon(
                      Icons.bluetooth,
                      color:
                          settingProvider.isBluetoothOn
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    title: const Text('Bluetooth Status'),
                    subtitle: Text(
                      settingProvider.isBluetoothOn
                          ? 'Bluetooth is ON'
                          : 'Bluetooth is OFF',
                    ),
                  ),
                ),

                // ✅ 2. BLE Connection Card
                Card(
                  child: ListTile(
                    leading: Icon(
                      settingProvider.connectedDevice != null
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          settingProvider.connectedDevice != null
                              ? Colors.green
                              : Colors.grey,
                    ),
                    title: const Text('BLE Connection'),
                    subtitle: Text(settingProvider.connectionStatus),
                  ),
                ),

                // ✅ 3. Raw Value Card (แสดง raw value ปัจจุบัน)
                if (settingProvider.connectedDevice != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.sensors, color: Colors.purple),
                      title: const Text('Raw Value'),
                      subtitle: Text(
                        settingProvider.currentRawValue != null
                            ? 'Current: ${settingProvider.currentRawValue!.toStringAsFixed(6)}'
                            : 'No data received',
                      ),
                      trailing:
                          settingProvider.currentRawValue != null
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              )
                              : const Icon(Icons.error, color: Colors.red),
                    ),
                  ),

                // ✅ 4. Calibration Status Card
                Card(
                  child: ListTile(
                    leading: Icon(
                      calibrationEasy.isCalibrated
                          ? Icons.done_all
                          : Icons.warning,
                      color:
                          calibrationEasy.isCalibrated
                              ? Colors.green
                              : Colors.orange,
                    ),
                    title: const Text('Calibration Status'),
                    subtitle: Text(calibrationEasy.statusMessage),
                    trailing:
                        calibrationEasy.isCollecting
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : null,
                  ),
                ),

                // ✅ 5. Connected Device Info
                if (settingProvider.connectedDevice != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.info, color: Colors.blue),
                      title: Text(
                        'Connected to: ${settingProvider.getBLEDeviceDisplayName(settingProvider.connectedDevice!)}',
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'RSSI: ${settingProvider.rssi ?? 'Unknown'} dBm',
                          ),
                          Text('Services: ${settingProvider.services.length}'),
                          Text('Raw Text: "${settingProvider.lastRawText}"'),
                        ],
                      ),
                    ),
                  ),

                // ✅ 6. Available Devices
                if (settingProvider.bleDevices.isNotEmpty)
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.devices_other,
                        color: Colors.orange,
                      ),
                      title: const Text('Available BLE Devices'),
                      subtitle: Text(
                        '${settingProvider.bleDevices.length} devices found',
                      ),
                    ),
                  ),

                // ✅ 7. Quick Actions
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(
                          Icons.display_settings,
                          color: Colors.purple,
                        ),
                        title: const Text('ASCII Data Display'),
                        subtitle: const Text(
                          'View real-time data from BLE device',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Provider.of<NavigationBar1Provider>(
                            context,
                            listen: false,
                          ).setCurrentPageIndex(0);
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.tune, color: Colors.green),
                        title: const Text('Calibration'),
                        subtitle: const Text('Set zero and reference weight'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Provider.of<NavigationBar1Provider>(
                            context,
                            listen: false,
                          ).setCurrentPageIndex(1);
                        },
                      ),
                    ],
                  ),
                ),

                // ✅ 8. Provider Connection Status (Debug Info)
                if (settingProvider.connectedDevice != null)
                  Card(
                    color: Colors.grey.shade50,
                    child: ExpansionTile(
                      leading: const Icon(
                        Icons.developer_mode,
                        color: Colors.grey,
                      ),
                      title: const Text('Debug Information'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CalibrationEasy Connected: ${calibrationEasy.toString().contains('CalibrationEasy') ? 'Yes' : 'No'}',
                              ),
                              Text(
                                'Target Readings: ${calibrationEasy.targetReadings}',
                              ),
                              Text(
                                'Is Collecting: ${calibrationEasy.isCollecting}',
                              ),
                              Text(
                                'Collection Progress: ${(calibrationEasy.collectionProgress * 100).toStringAsFixed(1)}%',
                              ),
                              if (calibrationEasy.zeroPoint != null)
                                Text(
                                  'Zero Point: ${calibrationEasy.zeroPoint!.toStringAsFixed(6)}',
                                ),
                              if (calibrationEasy.referencePoint != null)
                                Text(
                                  'Reference Point: ${calibrationEasy.referencePoint!.toStringAsFixed(6)} (${calibrationEasy.referenceWeight} kg)',
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
