// StatusPage.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/AutoSaveProviderServices.dart'
    show AutoSaveProviderServices;
import 'package:try_bluetooth/providers/CRUD_Services_Providers.dart'
    show CRUD_Services_Provider;
import 'package:try_bluetooth/providers/DisplayMainProvider.dart';

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
                          : const Icon(Icons.check_circle, color: Colors.green),
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