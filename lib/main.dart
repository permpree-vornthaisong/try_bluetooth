// ========== main.dart ==========
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/DisplayAutoSaveWeightPage.dart';
import 'package:try_bluetooth/pages/SettingsPage.dart';
import 'package:try_bluetooth/pages/TestCreate.dart';
import 'package:try_bluetooth/providers/CRUD_Services_Providers.dart';
import 'package:try_bluetooth/providers/DisplayMainProvider.dart';
import 'package:try_bluetooth/providers/AutoSaveProviderServices.dart';
import 'package:try_bluetooth/providers/GenericSaveService.dart';
import 'package:try_bluetooth/providers/NavigationBar1Provider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
import 'package:try_bluetooth/providers/DisplayProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => NavigationBar1Provider()),

        ChangeNotifierProvider(create: (context) => SettingProvider()),

        ChangeNotifierProvider(create: (context) => DisplayProvider()),

        ChangeNotifierProvider(create: (_) => DisplayMainProvider()),
        ChangeNotifierProxyProvider2<
          CRUD_Services_Provider,
          DisplayMainProvider,
          GenericSaveService
        >(
          create: (context) {
            final crudServices = Provider.of<CRUD_Services_Provider>(
              context,
              listen: false,
            );
            final displayProvider = Provider.of<DisplayMainProvider>(
              context,
              listen: false,
            );
            return GenericSaveService(crudServices, displayProvider);
          },
          update: (context, crudServices, displayProvider, previous) {
            return previous ??
                GenericSaveService(crudServices, displayProvider);
          },
        ),
        ChangeNotifierProxyProvider2<
          CRUD_Services_Provider,
          DisplayMainProvider,
          AutoSaveProviderServices
        >(
          create: (context) {
            debugPrint('🔧 Creating AutoSaveProviderServices...');
            final crudServices = Provider.of<CRUD_Services_Provider>(
              context,
              listen: false,
            );
            final displayProvider = Provider.of<DisplayMainProvider>(
              context,
              listen: false,
            );

            debugPrint(
              '📍 CRUD Services ready: ${crudServices.isDatabaseReady}',
            );
            debugPrint(
              '📍 Display Provider ready: ${displayProvider.isConnected}',
            );

            return AutoSaveProviderServices(crudServices, displayProvider);
          },
          update: (context, crudServices, displayProvider, previous) {
            if (previous != null) {
              return previous;
            }
            debugPrint('🔄 Updating AutoSaveProviderServices...');
            return AutoSaveProviderServices(crudServices, displayProvider);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
    });
  }

  void _initializeProviders() {
    try {
      debugPrint('🚀 Starting provider initialization...');

      final settingProvider = Provider.of<SettingProvider>(
        context,
        listen: false,
      );
      final displayProvider = Provider.of<DisplayProvider>(
        context,
        listen: false,
      );
      final displayMainProvider = Provider.of<DisplayMainProvider>(
        context,
        listen: false,
      );
      final crudServices = Provider.of<CRUD_Services_Provider>(
        context,
        listen: false,
      );
      final autoSaveService = Provider.of<AutoSaveProviderServices>(
        context,
        listen: false,
      );

      debugPrint('📋 Provider status check:');
      debugPrint('  - SettingProvider: Ready');
      debugPrint('  - DisplayProvider: Ready');
      debugPrint('  - CalibrationEasy: Ready');
      debugPrint('  - DisplayMainProvider: Ready');
      debugPrint(
        '  - CRUDServices: ${crudServices.isDatabaseReady ? "Ready" : "Not Ready"}',
      );
      debugPrint(
        '  - AutoSaveService: ${autoSaveService.isInitialized ? "Ready" : "Not Ready"}',
      );

      // Initialize DisplayMainProvider
      displayMainProvider.initializeWithProviders(
        settingProvider,
        displayProvider,
      );
      debugPrint('✅ DisplayMainProvider initialized');

      // Initialize CalibrationEasy

      debugPrint('✅ CalibrationEasy initialized');

      debugPrint('✅ All providers initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing providers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                selectedIcon: Icon(Icons.auto_mode),
                icon: Icon(Icons.auto_mode_outlined),
                label: 'Auto Save',
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                label: 'Calibration',
              ),
              NavigationDestination(icon: Icon(Icons.info), label: 'Status'),
              NavigationDestination(
                icon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          );
        },
      ),
      body: Consumer<NavigationBar1Provider>(
        builder: (context, navigationProvider, child) {
          return _buildCurrentPage(navigationProvider.currentPageIndex);
        },
      ),
    );
  }

  Widget _buildCurrentPage(int currentPageIndex) {
    switch (currentPageIndex) {
      case 0:
        return TestCreateWidget(
          saveService: Provider.of<GenericSaveService>(context),
        );
      case 1:
        return DisplayAutoSaveWeightPage();
      case 2:
        return _buildStatusPage();
      case 3:
        return SettingsPage();
      default:
        return DisplayAutoSaveWeightPage();
    }
  }

  Widget _buildStatusPage() {
    return Consumer3<
      DisplayMainProvider,
      CRUD_Services_Provider,
      AutoSaveProviderServices
    >(
      builder: (
        context,
        displayMainProvider,
        crudServices,
        autoSaveService,
        child,
      ) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page Header
                const Text(
                  'System Status',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Connection Status Card
                Card(
                  color: Colors.green.shade50,
                  child: ListTile(
                    leading: Icon(
                      displayMainProvider.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth_disabled,
                      color:
                          displayMainProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                    title: const Text('Connection Status'),
                    subtitle: Text(
                      'Device: ${displayMainProvider.deviceName ?? "Not connected"}\n'
                      'Weight: ${displayMainProvider.formattedWeight} kg\n'
                      'Status: ${displayMainProvider.connectionStatus}',
                    ),
                    trailing: Icon(
                      displayMainProvider.isConnected
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          displayMainProvider.isConnected
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Auto Save Status Card
                Card(
                  color: Colors.purple.shade50,
                  child: ListTile(
                    leading: Icon(
                      autoSaveService.isAutoSaveActive
                          ? Icons.auto_mode
                          : Icons.auto_mode_outlined,
                      color:
                          autoSaveService.isAutoSaveActive
                              ? Colors.purple
                              : Colors.grey,
                    ),
                    title: const Text('Auto Save Status'),
                    subtitle: Text(
                      'Initialized: ${autoSaveService.isInitialized ? 'Yes' : 'No'}\n'
                      'Active: ${autoSaveService.isAutoSaveActive ? 'Yes' : 'No'}\n'
                      'Auto Saves: ${autoSaveService.totalAutoSaves}\n'
                      'Manual Saves: ${autoSaveService.totalManualSaves}\n'
                      'Waiting for Zero: ${autoSaveService.waitingForZeroWeight ? 'Yes' : 'No'}',
                    ),
                    trailing: Icon(
                      autoSaveService.isInitialized
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          autoSaveService.isInitialized
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Database Status Card
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: Icon(
                      crudServices.isDatabaseReady
                          ? Icons.storage
                          : Icons.storage_outlined,
                      color:
                          crudServices.isDatabaseReady
                              ? Colors.blue
                              : Colors.grey,
                    ),
                    title: const Text('Database Status'),
                    subtitle: Text(
                      'Ready: ${crudServices.isDatabaseReady ? 'Yes' : 'No'}\n'
                      'Total Operations: ${crudServices.totalOperations}\n'
                      'Last Operation: ${crudServices.lastOperation ?? 'None'}',
                    ),
                    trailing: Icon(
                      crudServices.isDatabaseReady
                          ? Icons.check_circle
                          : Icons.error,
                      color:
                          crudServices.isDatabaseReady
                              ? Colors.green
                              : Colors.red,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // System Status
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(
                      Icons.system_security_update_good,
                      color: Colors.orange,
                    ),
                    title: const Text('System Status'),
                    subtitle: Text(
                      'Processing: ${crudServices.isProcessing ? 'Yes' : 'No'}\n'
                      'AutoSave Processing: ${autoSaveService.isProcessing ? 'Yes' : 'No'}\n'
                      'Last Error: ${crudServices.lastError ?? autoSaveService.lastError ?? 'None'}',
                    ),
                    trailing:
                        (crudServices.isProcessing ||
                                autoSaveService.isProcessing)
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

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Reinitialize AutoSave Service
                          autoSaveService.reinitialize();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('AutoSave Service reinitialized'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reinit AutoSave'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Clear statistics
                          autoSaveService.resetStatistics();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Statistics cleared'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Stats'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
