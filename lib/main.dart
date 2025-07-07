// ========== main.dart ==========
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/CalibrationZeroPage.dart';
import 'package:try_bluetooth/pages/SettingsPage.dart';
import 'package:try_bluetooth/pages/DisplayPage.dart';
import 'package:try_bluetooth/pages/UserListPage.dart';
import 'package:try_bluetooth/pages/WeightHumanPage.dart';
import 'package:try_bluetooth/pages/popup_widget.dart';
import 'package:try_bluetooth/providers/CRUDSQLiteProvider.dart'
    show CRUDSQLiteProvider;
import 'package:try_bluetooth/providers/CRUD_Services_Providers.dart';
import 'package:try_bluetooth/providers/PopupProvider.dart';
import 'package:try_bluetooth/providers/SaveAnimalProvider.dart';
import 'package:try_bluetooth/providers/SaveHumanProvider.dart';
import 'package:try_bluetooth/providers/SaveObjectProvider.dart';
import 'package:try_bluetooth/providers/WeightHumanProvider.dart';
import 'package:try_bluetooth/widgets/CalibrationWidget.dart';
import 'package:try_bluetooth/providers/NavigationBar1Provider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/DisplayProvider.dart';
import 'package:try_bluetooth/providers/CalibrationProvider.dart';
import 'package:try_bluetooth/providers/FactoryCalibrationProvider.dart';
import 'package:try_bluetooth/providers/calibration_easy_provider.dart';

void main() async {
  // ✅ เพิ่มการเตรียมใช้งาน async
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ✅ 1. Navigation Provider
        ChangeNotifierProvider(create: (context) => NavigationBar1Provider()),

        // ✅ 2. BLE & Connection Providers
        ChangeNotifierProvider(create: (context) => SettingProvider()),

        // ✅ 3. Display Provider
        ChangeNotifierProvider(create: (context) => DisplayProvider()),

        // ✅ 4. Calibration Providers
        ChangeNotifierProvider(create: (context) => CalibrationProvider()),
        ChangeNotifierProvider(
          create: (context) => FactoryCalibrationProvider(),
        ),
        ChangeNotifierProvider(create: (context) => CalibrationEasy()),

        // ✅ 5. Database Providers - เรียก initDatabase() เฉพาะที่นี่
        ChangeNotifierProvider(
          create: (_) {
            final provider = SaveHumanProvider();
            provider.initDatabase(); // Initialize ครั้งเดียวที่นี่
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = SaveObjectProvider();
            provider.initDatabase();
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final provider = SaveAnimalProvider();
            provider.initDatabase();
            return provider;
          },
        ),

        // ✅ 6. Weight Providers
        ChangeNotifierProvider(
          create: (_) {
            final provider = WeightHumanProvider();
            provider.initialize();
            return provider;
          },
        ),

        // ✅ 7. CRUD Provider - เพิ่ม initialization
        ChangeNotifierProvider(
          create: (_) {
            final provider = CRUDSQLiteProvider();
            provider.initDatabase('app_database'); // Initialize database
            return provider;
          },
        ),
        ChangeNotifierProvider(
          create:
              (context) => CRUDServicesProvider(
                Provider.of<CRUDSQLiteProvider>(context, listen: false),
              ),
        ),

        // ✅ 8. PopupProvider - ใช้ ProxyProvider เพื่อรับ dependencies
        ChangeNotifierProxyProvider2<
          SettingProvider,
          DisplayProvider,
          PopupProvider
        >(
          create: (_) => PopupProvider(),
          update: (context, settingProvider, displayProvider, previous) {
            // วิธีที่ถูกต้อง - แยกขั้นตอนออกมา
            if (previous != null) {
              previous.initializeWithProviders(
                settingProvider,
                displayProvider,
              );
              return previous;
            } else {
              final newProvider = PopupProvider();
              newProvider.initializeWithProviders(
                settingProvider,
                displayProvider,
              );
              return newProvider;
            }
          },
        ),
      ],
      child: MaterialApp(
        title: 'BLE Navigation App',
        theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
        home: const NavigationExample(),
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
    try {
      final settingProvider = Provider.of<SettingProvider>(
        context,
        listen: false,
      );
      final calibrationEasy = Provider.of<CalibrationEasy>(
        context,
        listen: false,
      );
      final saveHumanProvider = Provider.of<SaveHumanProvider>(
        context,
        listen: false,
      );
      final popupProvider = Provider.of<PopupProvider>(context, listen: false);

      // เชื่อมต่อ CalibrationEasy กับ SettingProvider
      calibrationEasy.connectToSettingProvider(settingProvider);

      // Initialize CalibrationEasy (ไม่ใช่ database)
      calibrationEasy.initialize();

      // ✅ PopupProvider จะถูก initialize อัตโนมัติผ่าน ProxyProvider แล้ว
      print('✅ PopupProvider initialized: ${popupProvider.isConnected}');
      print('✅ All providers initialized and connected successfully');
      print(
        '✅ SaveHumanProvider records: ${saveHumanProvider.savedWeights.length}',
      );
    } catch (e) {
      print('❌ Error initializing providers: $e');
    }
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
        return PopupWidget(); // BLE Data Display page
      case 1:
        return const CalibrationWidget(); // Weight Calibration page
      case 2:
        return CalibrationWidget(); // Weight Calibration page
      case 3:
        return _buildNotificationsPage();
      case 4:
        return const SettingsPage(); // BLE Settings page
      default:
        return const DisplayPage();
    }
  }

  Widget _buildNotificationsPage() {
    return Consumer5<
      SettingProvider,
      CalibrationEasy,
      CalibrationProvider,
      SaveHumanProvider,
      PopupProvider
    >(
      builder: (
        context,
        settingProvider,
        calibrationEasy,
        calibrationProvider,
        saveHumanProvider,
        popupProvider,
        child,
      ) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                // ✅ PopupProvider Status Card - เพิ่มใหม่
                Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: Icon(
                      popupProvider.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          popupProvider.isConnected ? Colors.green : Colors.red,
                    ),
                    title: const Text('PopupProvider Status'),
                    subtitle: Text(
                      'Connection: ${popupProvider.connectionStatus}\n'
                      'Device: ${popupProvider.deviceName}\n'
                      'Current Weight: ${popupProvider.formattedWeight} kg\n'
                      'Tare Operations: ${popupProvider.tareOperations}\n'
                      'Zero Operations: ${popupProvider.zeroOperations}',
                    ),
                    trailing:
                        popupProvider.isProcessing
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : Icon(
                              popupProvider.isConnected
                                  ? Icons.check_circle
                                  : Icons.error,
                              color:
                                  popupProvider.isConnected
                                      ? Colors.green
                                      : Colors.red,
                            ),
                  ),
                ),

                // ✅ Test PopupProvider Functions
                Card(
                  color: Colors.blue.shade50,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.scale, color: Colors.blue),
                        title: const Text('Test PopupProvider'),
                        subtitle: const Text('Test Tare and Zero functions'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    popupProvider.isProcessing
                                        ? null
                                        : () async {
                                          final result =
                                              await popupProvider.toggleTare();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(result.message),
                                                backgroundColor:
                                                    result.success
                                                        ? Colors.blue
                                                        : Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                child: Text(
                                  popupProvider.hasTareOffset
                                      ? 'Clear Tare'
                                      : 'Set Tare',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed:
                                    popupProvider.isProcessing
                                        ? null
                                        : () async {
                                          final result =
                                              await popupProvider
                                                  .sendZeroCommand();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(result.message),
                                                backgroundColor:
                                                    result.success
                                                        ? Colors.orange
                                                        : Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                child: const Text('Send Zero'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ✅ Database Status Card
                Card(
                  child: ListTile(
                    leading: Icon(
                      saveHumanProvider.savedWeights.isNotEmpty
                          ? Icons.storage
                          : Icons.storage_outlined,
                      color: Colors.purple,
                    ),
                    title: const Text('Database Status'),
                    subtitle: Text(
                      'Saved Records: ${saveHumanProvider.savedWeights.length}\n'
                      'Loading: ${saveHumanProvider.isLoading ? 'Yes' : 'No'}',
                    ),
                    trailing:
                        saveHumanProvider.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                            ),
                  ),
                ),

                // ✅ Quick Actions
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.person, color: Colors.blue),
                        title: const Text('Weight Human Page'),
                        subtitle: const Text('Test the WeightHumanPage'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WeightHumanPage(),
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(
                          Icons.control_camera,
                          color: Colors.green,
                        ),
                        title: const Text('Popup Widget'),
                        subtitle: const Text(
                          'Test the PopupWidget with PopupProvider',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PopupWidget(),
                            ),
                          );
                        },
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.indigo[600], size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[800],
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
