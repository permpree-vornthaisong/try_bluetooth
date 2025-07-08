import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/CRUD_Services_Providers.dart';
import '../providers/SettingProvider.dart';
import '../providers/DisplayProvider.dart';

class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  @override
  void initState() {
    super.initState();

    // Initialize DisplayProvider with other providers after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final displayProvider = Provider.of<DisplayProvider>(
        context,
        listen: false,
      );
      final settingProvider = Provider.of<SettingProvider>(
        context,
        listen: false,
      );

      displayProvider.initializeWithProviders(settingProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weight Display'),
        backgroundColor: Colors.blue.withOpacity(0.1),
      ),
      body: Consumer<DisplayProvider>(
        builder: (context, displayProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                _buildConnectionStatus(displayProvider),
                Expanded(child: _buildWeightDisplay(displayProvider)),
                _buildTareButton(displayProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(DisplayProvider displayProvider) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Connection Status
            Icon(
              displayProvider.isConnected
                  ? Icons.bluetooth_connected
                  : Icons.bluetooth_disabled,
              color: displayProvider.isConnected ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayProvider.connectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (displayProvider.isConnected)
                    Text(
                      'Device: ${displayProvider.getDeviceName()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightDisplay(DisplayProvider displayProvider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Main Weight Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
            child: Column(
              children: [
                Icon(Icons.scale, size: 48, color: Colors.blue),
                const SizedBox(height: 16),
                Text(
                  'เครื่องชั่งน้ำหนัก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
                const SizedBox(height: 24),

                // Weight Display
                if (displayProvider.hasValidWeight) ...[
                  Text(
                    displayProvider.getFormattedWeight(),
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ] else ...[
                  Icon(Icons.scale, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              // รับ CRUD Service จาก Provider
              final crudService = Provider.of<CRUD_Services_Provider>(
                context,
                listen: false,
              );

              try {
                // 1. สร้าง Table
                print('Creating table...');
                await crudService.createTable('users', '''
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT UNIQUE,
        age INTEGER,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
        ''');

                // 2. Insert ข้อมูลทดสอบ
                print('Inserting test data...');
                await crudService.insertMultipleRecords('users', [
                  {'name': 'John Doe', 'email': 'john@example.com', 'age': 25},
                  {
                    'name': 'Jane Smith',
                    'email': 'jane@example.com',
                    'age': 30,
                  },
                  {
                    'name': 'Bob Johnson',
                    'email': 'bob@example.com',
                    'age': 35,
                  },
                ]);

                // 3. แสดงผลลัพธ์
                final count = await crudService.countRecords('users');
                print('✅ Success! Created table and inserted $count records');

                // แสดง SnackBar แจ้งผลสำเร็จ
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '✅ Created table "users" and inserted $count records',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('❌ Error: $e');

                // แสดง SnackBar แจ้งข้อผิดพลาด
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('❌ Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Create Table + Insert Data'),
          ),
          // Raw Data Display
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Raw Data',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      displayProvider.rawDataText,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if (displayProvider.hasValidWeight) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Raw Value: ${displayProvider.getFormattedRawValue()}',
                            ),
                            Text(
                              'Calibrated: ${displayProvider.getFormattedCalibratedWeight()}',
                            ),
                          ],
                        ),
                        if (displayProvider.tareOffset != 0.0) ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Tare Offset: ${displayProvider.getFormattedTareOffset()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              Text(
                                'Net: ${displayProvider.getFormattedWeight()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Debug Info (สำหรับการพัฒนา - สามารถลบออกได้)
          if (kDebugMode) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Debug Info',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayProvider.getDebugInfo().toString(),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTareButton(DisplayProvider displayProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _performTare(displayProvider),
              icon: const Icon(Icons.restart_alt),
              label: const Text('Tare (ศูนย์)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[100],
                foregroundColor: Colors.blue[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          if (displayProvider.tareOffset != 0.0) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _clearTare(displayProvider),
              icon: const Icon(Icons.clear),
              label: const Text('Clear Tare'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[100],
                foregroundColor: Colors.orange[800],
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _performTare(DisplayProvider displayProvider) {
    if (displayProvider.performTare()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Tare ตั้งค่าที่ ${displayProvider.getFormattedTareOffset()}',
          ),
          backgroundColor: Colors.blue,
          action: SnackBarAction(
            label: 'Clear Tare',
            textColor: Colors.white,
            onPressed: () => _clearTare(displayProvider),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่สามารถตั้งค่า Tare ได้ - ไม่มีข้อมูลน้ำหนัก'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _clearTare(DisplayProvider displayProvider) {
    displayProvider.clearTare();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ล้างค่า Tare แล้ว'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
