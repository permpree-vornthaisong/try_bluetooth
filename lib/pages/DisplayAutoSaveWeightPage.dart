import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/DisplayMainProvider.dart';
import '../providers/AutoSaveProviderServices.dart';

class DisplayAutoSaveWeightPage extends StatelessWidget {
  const DisplayAutoSaveWeightPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การชั่งอัตโนมัติ'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          // Auto Save Toggle Button
          Consumer<AutoSaveProviderServices>(
            builder: (context, autoSaveService, child) {
              return IconButton(
                icon: Icon(autoSaveService.isAutoSaveActive ? Icons.pause : Icons.play_arrow),
                onPressed: autoSaveService.isInitialized 
                  ? () => autoSaveService.toggleAutoSave()
                  : null,
                tooltip: autoSaveService.isAutoSaveActive ? 'Pause Auto Save' : 'Start Auto Save',
              );
            },
          ),
          Consumer<AutoSaveProviderServices>(
            builder: (context, autoSaveService, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => autoSaveService.getAllRecords(),
                tooltip: 'Refresh',
              );
            },
          ),
          Consumer<AutoSaveProviderServices>(
            builder: (context, autoSaveService, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'clear_all':
                      _showClearAllDialog(context, autoSaveService);
                      break;
                    case 'settings':
                      _showSettingsDialog(context, autoSaveService);
                      break;
                    case 'statistics':
                      _showStatisticsDialog(context, autoSaveService);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'statistics',
                    child: Row(
                      children: [
                        Icon(Icons.analytics),
                        SizedBox(width: 8),
                        Text('Statistics'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'settings',
                    child: Row(
                      children: [
                        Icon(Icons.settings),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Clear All'),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Weight Display & Controls
            _buildWeightDisplaySection(),
            
            // Filters
            _buildFiltersSection(),
            
            // Records List - ใช้ SizedBox เพื่อกำหนดความสูง
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.6, // 60% ของหน้าจอ
              child: _buildRecordsList(),
            ),
          ],
        ),
      ),
      floatingActionButton: Consumer<AutoSaveProviderServices>(
        builder: (context, autoSaveService, child) {
          return FloatingActionButton(
            onPressed: autoSaveService.isInitialized 
              ? () => _onManualSave(context, autoSaveService)
              : null,
            backgroundColor: autoSaveService.isInitialized ? Colors.blue : Colors.grey,
            child: const Icon(Icons.save),
            tooltip: 'Manual Save',
          );
        },
      ),
    );
  }
  
  Widget _buildWeightDisplaySection() {
    return Consumer2<DisplayMainProvider, AutoSaveProviderServices>(
      builder: (context, displayProvider, autoSaveService, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Column(
            children: [
              // Current Weight Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWeightCard(
                    'น้ำหนักปัจจุบัน',
                    displayProvider.formattedWeight,
                    Colors.blue,
                    Icons.scale,
                  ),
                  _buildWeightCard(
                    'Raw Weight',
                    displayProvider.rawWeightWithoutTare?.toStringAsFixed(1) ?? '-.--',
                    Colors.green,
                    Icons.straighten,
                  ),
                  _buildWeightCard(
                    'Tare Offset',
                    displayProvider.tareOffset.toStringAsFixed(1),
                    Colors.orange,
                    Icons.remove_circle_outline,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Auto Save Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: autoSaveService.isInitialized
                    ? (autoSaveService.isAutoSaveActive ? Colors.green.shade100 : Colors.grey.shade100)
                    : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: autoSaveService.isInitialized
                      ? (autoSaveService.isAutoSaveActive ? Colors.green.shade300 : Colors.grey.shade300)
                      : Colors.orange.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      !autoSaveService.isInitialized 
                        ? Icons.hourglass_empty
                        : (autoSaveService.isAutoSaveActive ? Icons.auto_mode : Icons.pause_circle),
                      color: !autoSaveService.isInitialized 
                        ? Colors.orange 
                        : (autoSaveService.isAutoSaveActive ? Colors.green : Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            !autoSaveService.isInitialized 
                              ? 'Auto Save: Initializing...'
                              : (autoSaveService.isAutoSaveActive ? 'Auto Save: Active' : 'Auto Save: Paused'),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: !autoSaveService.isInitialized 
                                ? Colors.orange.shade800
                                : (autoSaveService.isAutoSaveActive ? Colors.green.shade800 : Colors.grey.shade800),
                            ),
                          ),
                          if (autoSaveService.isInitialized && autoSaveService.isAutoSaveActive) ...[
                            Text(
                              autoSaveService.waitingForZeroWeight 
                                ? 'รอให้น้ำหนักเป็น 0 ก่อนบันทึกครั้งต่อไป'
                                : 'Stable: ${autoSaveService.stableCount}/${autoSaveService.stableCountThreshold} readings',
                              style: TextStyle(
                                fontSize: 12,
                                color: autoSaveService.waitingForZeroWeight 
                                  ? Colors.orange.shade600 
                                  : Colors.green.shade600,
                              ),
                            ),
                          ],
                          if (autoSaveService.lastError != null) ...[
                            Text(
                              'Error: ${autoSaveService.lastError}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (autoSaveService.isInitialized) ...[
                          Text(
                            'Auto: ${autoSaveService.totalAutoSaves} | Manual: ${autoSaveService.totalManualSaves}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildWeightCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '$value kg',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltersSection() {
    return Consumer<AutoSaveProviderServices>(
      builder: (context, autoSaveService, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
          ),
          child: Row(
            children: [
              // Filter by
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'all', // Always default to 'all' since we don't store state
                  decoration: const InputDecoration(
                    labelText: 'Filter',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All Records')),
                    DropdownMenuItem(value: 'today', child: Text('Today')),
                    DropdownMenuItem(value: 'auto', child: Text('Auto Saved')),
                    DropdownMenuItem(value: 'manual', child: Text('Manual Saved')),
                  ],
                  onChanged: (value) {
                    switch (value) {
                      case 'today':
                        autoSaveService.getTodayRecords();
                        break;
                      case 'auto':
                        autoSaveService.getRecordsByType('auto');
                        break;
                      case 'manual':
                        autoSaveService.getRecordsByType('manual');
                        break;
                      default:
                        autoSaveService.getAllRecords();
                    }
                  },
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Sort order
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: 'DESC', // Always default to DESC since we don't store state
                  decoration: const InputDecoration(
                    labelText: 'Sort',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'DESC', child: Text('Newest First')),
                    DropdownMenuItem(value: 'ASC', child: Text('Oldest First')),
                  ],
                  onChanged: (value) {
                    autoSaveService.getAllRecords(orderBy: 'timestamp $value');
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildRecordsList() {
    return Consumer<AutoSaveProviderServices>(
      builder: (context, autoSaveService, child) {
        // แสดง loading หาก service ยังไม่พร้อม
        if (!autoSaveService.isInitialized) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('กำลังเตรียม Auto Save Service...'),
              ],
            ),
          );
        }

        // แสดง error หากมี
        if (autoSaveService.lastError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text(
                  autoSaveService.lastError!,
                  style: TextStyle(color: Colors.red.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    // Clear error และ reload data
                    autoSaveService.getAllRecords();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        // ใช้ FutureBuilder แบบมี key เพื่อป้องกัน rebuild loop
        return FutureBuilder<List<Map<String, dynamic>>>(
          key: ValueKey('records_${autoSaveService.hashCode}'),
          future: _loadRecordsOnce(autoSaveService),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: Colors.red.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: Colors.red.shade600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Force rebuild by calling setState equivalent
                        autoSaveService.getAllRecords();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            
            final records = snapshot.data ?? [];
            
            if (records.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No saved records',
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'บันทึกข้อมูลแรกโดยกด Manual Save\nหรือเปิด Auto Save',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: records.length,
              itemBuilder: (context, index) {
                final record = records[index];
                return _buildRecordCard(context, record, index, autoSaveService);
              },
            );
          },
        );
      },
    );
  }

  // Helper method เพื่อป้องกัน rebuild loop
  Future<List<Map<String, dynamic>>> _loadRecordsOnce(AutoSaveProviderServices autoSaveService) async {
    try {
      return await autoSaveService.getAllRecords();
    } catch (e) {
      debugPrint('❌ Error loading records: $e');
      rethrow;
    }
  }
  
  Widget _buildRecordCard(BuildContext context, Map<String, dynamic> record, int index, AutoSaveProviderServices autoSaveService) {
    final timestamp = DateTime.parse(record['timestamp']);
    final weight = record['weight']?.toDouble() ?? 0.0;
    final rawWeight = record['raw_weight']?.toDouble() ?? 0.0;
    final tareOffset = record['tare_offset']?.toDouble() ?? 0.0;
    final notes = record['notes'] ?? '';
    final saveType = record['save_type'] ?? 'unknown';
    
    // Determine card color based on save type
    Color cardColor = Colors.white;
    Color accentColor = Colors.blue;
    IconData typeIcon = Icons.save;
    
    switch (saveType) {
      case 'auto':
        cardColor = Colors.green.shade50;
        accentColor = Colors.green;
        typeIcon = Icons.auto_mode;
        break;
      case 'manual':
        cardColor = Colors.blue.shade50;
        accentColor = Colors.blue;
        typeIcon = Icons.touch_app;
        break;
      default:
        cardColor = Colors.grey.shade50;
        accentColor = Colors.grey;
        typeIcon = Icons.help;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(typeIcon, size: 16, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      '#${index + 1} (${saveType.toUpperCase()})',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _onDeleteRecord(context, record['id'], autoSaveService),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Weight information
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('น้ำหนัก', '${weight.toStringAsFixed(1)} kg', accentColor),
                ),
                Expanded(
                  child: _buildInfoItem('Raw', '${rawWeight.toStringAsFixed(1)} kg', Colors.green),
                ),
                Expanded(
                  child: _buildInfoItem('Tare', '${tareOffset.toStringAsFixed(1)} kg', Colors.orange),
                ),
              ],
            ),
            
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ========== UTILITY METHODS ==========
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // ========== ACTION METHODS ==========
  
  void _onManualSave(BuildContext context, AutoSaveProviderServices autoSaveService) async {
    final success = await autoSaveService.manualSave(customNotes: 'Manual save from UI');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Weight saved manually' : 'Save failed: ${autoSaveService.lastError ?? 'Unknown error'}'),
          backgroundColor: success ? Colors.blue : Colors.red,
        ),
      );
    }
  }
  
  void _onDeleteRecord(BuildContext context, int id, AutoSaveProviderServices autoSaveService) async {
    final success = await autoSaveService.deleteRecord(id);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Record deleted' : 'Delete failed'),
          backgroundColor: success ? Colors.orange : Colors.red,
        ),
      );
    }
  }
  
  void _showClearAllDialog(BuildContext context, AutoSaveProviderServices autoSaveService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete all saved records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await autoSaveService.deleteAllRecords();
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success ? 'All records deleted' : 'Clear failed'),
                    backgroundColor: success ? Colors.orange : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }
  
  void _showSettingsDialog(BuildContext context, AutoSaveProviderServices autoSaveService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Save Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: autoSaveService.stableCountThreshold.toString(),
              decoration: const InputDecoration(
                labelText: 'Stable Count Threshold',
                helperText: 'Number of stable readings before auto save',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final threshold = int.tryParse(value);
                if (threshold != null && threshold > 0) {
                  autoSaveService.setStableCountThreshold(threshold);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: autoSaveService.weightTolerance.toString(),
              decoration: const InputDecoration(
                labelText: 'Weight Tolerance (kg)',
                helperText: 'Maximum weight variation to consider stable',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final tolerance = double.tryParse(value);
                if (tolerance != null && tolerance >= 0) {
                  autoSaveService.setWeightTolerance(tolerance);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: autoSaveService.zeroWeightThreshold.toString(),
              decoration: const InputDecoration(
                labelText: 'Zero Weight Threshold (kg)',
                helperText: 'Weight below this is considered zero',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final threshold = double.tryParse(value);
                if (threshold != null && threshold >= 0) {
                  autoSaveService.setZeroWeightThreshold(threshold);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings updated'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
  
  void _showStatisticsDialog(BuildContext context, AutoSaveProviderServices autoSaveService) {
    final stats = autoSaveService.getStatistics();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Save Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatItem('Initialized', stats['isInitialized'].toString()),
            _buildStatItem('Auto Save Active', stats['isAutoSaveActive'].toString()),
            _buildStatItem('Total Auto Saves', stats['totalAutoSaves'].toString()),
            _buildStatItem('Total Manual Saves', stats['totalManualSaves'].toString()),
            _buildStatItem('Stable Count Threshold', stats['stableCountThreshold'].toString()),
            _buildStatItem('Weight Tolerance', '${stats['weightTolerance']} kg'),
            _buildStatItem('Zero Weight Threshold', '${stats['zeroWeightThreshold']} kg'),
            if (stats['lastSaveTime'] != null)
              _buildStatItem('Last Save', DateTime.parse(stats['lastSaveTime']).toString()),
            if (stats['lastError'] != null)
              _buildStatItem('Last Error', stats['lastError'], isError: true),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              autoSaveService.resetStatistics();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Statistics reset'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Reset Stats'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red : Colors.grey.shade700,
                fontSize: 12,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}