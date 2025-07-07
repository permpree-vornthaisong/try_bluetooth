import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/CalibrationZeroPage.dart';
import 'package:try_bluetooth/pages/SettingsPage.dart';
import 'package:try_bluetooth/pages/DisplayPage.dart';
import 'package:try_bluetooth/pages/UserListPage.dart';
import 'package:try_bluetooth/pages/WeightHumanPage.dart';
import 'package:try_bluetooth/pages/popup_widget.dart';
import 'package:try_bluetooth/providers/CRUDSQLiteProvider.dart' show CRUDSQLiteProvider;
import 'package:try_bluetooth/providers/CRUD_Services_Providers.dart';
import 'package:try_bluetooth/providers/SaveAnimalProvider.dart';
import 'package:try_bluetooth/providers/SaveHumanProvider.dart';
import 'package:try_bluetooth/providers/SaveObjectProvider.dart';
import 'package:try_bluetooth/providers/WeightHumanProvider.dart';
import 'package:try_bluetooth/widgets/CalibrationWidget.dart';
import 'package:try_bluetooth/widgets/FactoryCalibrationWidget.dart';
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
        ChangeNotifierProvider(create: (context) => FactoryCalibrationProvider()),
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
          create: (context) => CRUDServicesProvider(
            Provider.of<CRUDSQLiteProvider>(context, listen: false),
          ),
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

  // ✅ เชื่อมต่อ providers กันหลังจาก build แล้ว (ไม่เรียก initDatabase ซ้ำ)
  void _initializeProviders() {
    try {
      final settingProvider = Provider.of<SettingProvider>(context, listen: false);
      final calibrationEasy = Provider.of<CalibrationEasy>(context, listen: false);
      final saveHumanProvider = Provider.of<SaveHumanProvider>(context, listen: false);

      // เชื่อมต่อ CalibrationEasy กับ SettingProvider
      calibrationEasy.connectToSettingProvider(settingProvider);

      // Initialize CalibrationEasy (ไม่ใช่ database)
      calibrationEasy.initialize();

      // ✅ ไม่ต้องเรียก initDatabase() ซ้ำที่นี่ เพราะเรียกไปแล้วใน MultiProvider

      print('✅ All providers initialized and connected successfully');
      print('✅ SaveHumanProvider records: ${saveHumanProvider.savedWeights.length}');
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

  Widget _buildCurrentPage(BuildContext context, ThemeData theme, int currentPageIndex) {
    switch (currentPageIndex) {
      case 0:
        return ExampleUsage(); // BLE Data Display page
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
    return Consumer4<SettingProvider, CalibrationEasy, CalibrationProvider, SaveHumanProvider>(
      builder: (context, settingProvider, calibrationEasy, calibrationProvider, saveHumanProvider, child) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: <Widget>[
                // ✅ Database Status Card
                Card(
                  child: ListTile(
                    leading: Icon(
                      saveHumanProvider.savedWeights.isNotEmpty ? Icons.storage : Icons.storage_outlined,
                      color: Colors.purple,
                    ),
                    title: const Text('Database Status'),
                    subtitle: Text(
                      'Saved Records: ${saveHumanProvider.savedWeights.length}\n'
                      'Loading: ${saveHumanProvider.isLoading ? 'Yes' : 'No'}',
                    ),
                    trailing: saveHumanProvider.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle, color: Colors.green),
                  ),
                ),

                // ✅ Test Save Button
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.add_circle, color: Colors.blue),
                    title: const Text('Test Database'),
                    subtitle: const Text('Add a test record to verify database is working'),
                    trailing: ElevatedButton(
                      onPressed: () async {
                        try {
                          final success = await saveHumanProvider.saveWeight(
                            personName: 'Test User ${DateTime.now().millisecondsSinceEpoch}',
                            weight: 70.0,
                            notes: 'Test record created at ${DateTime.now()}',
                          );

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Test record saved!' : 'Failed to save test record'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      child: const Text('Test Save'),
                    ),
                  ),
                ),

                // ✅ Database Statistics
                if (saveHumanProvider.savedWeights.isNotEmpty)
                  Card(
                    color: Colors.indigo.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.analytics, color: Colors.indigo),
                              SizedBox(width: 8),
                              Text(
                                'Database Statistics',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo[800],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final stats = saveHumanProvider.getStatistics();
                              return Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          'Total Records',
                                          '${stats['totalRecords']}',
                                          Icons.receipt_long,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Unique People',
                                          '${stats['uniquePeople']}',
                                          Icons.people,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          'Average Weight',
                                          '${(stats['averageWeight'] as double).toStringAsFixed(1)} kg',
                                          Icons.balance,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Weight Range',
                                          '${(stats['minWeight'] as double).toStringAsFixed(1)}-${(stats['maxWeight'] as double).toStringAsFixed(1)} kg',
                                          Icons.straighten,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
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
                            MaterialPageRoute(builder: (context) => const WeightHumanPage()),
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