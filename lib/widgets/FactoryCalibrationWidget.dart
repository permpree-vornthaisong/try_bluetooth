import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/FactoryCalibrationProvider.dart';
import '../providers/CalibrationProvider.dart';

class FactoryCalibrationWidget extends StatelessWidget {
  const FactoryCalibrationWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory Calibration'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          Consumer<FactoryCalibrationProvider>(
            builder: (context, factoryProvider, child) {
              return PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'history':
                      _showCalibrationHistory(context, factoryProvider);
                      break;
                    case 'clear_history':
                      _showClearHistoryDialog(context, factoryProvider);
                      break;
                    case 'custom':
                      _showCustomCalibrationDialog(context, factoryProvider);
                      break;
                  }
                },
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'history',
                        child: Row(
                          children: [
                            Icon(Icons.history),
                            SizedBox(width: 8),
                            Text('History'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'custom',
                        child: Row(
                          children: [
                            Icon(Icons.add_box),
                            SizedBox(width: 8),
                            Text('Add Custom'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'clear_history',
                        child: Row(
                          children: [
                            Icon(Icons.delete_sweep, color: Colors.red),
                            SizedBox(width: 8),
                            Text(
                              'Clear History',
                              style: TextStyle(color: Colors.red),
                            ),
                          ],
                        ),
                      ),
                    ],
              );
            },
          ),
        ],
      ),
      body: Consumer2<FactoryCalibrationProvider, CalibrationProvider>(
        builder: (context, factoryProvider, calibrationProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusCard(factoryProvider, calibrationProvider),
                const SizedBox(height: 16),
                _buildWarningCard(),
                const SizedBox(height: 16),
                _buildFactoryCalibrationsList(
                  context,
                  factoryProvider,
                  calibrationProvider,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    FactoryCalibrationProvider factoryProvider,
    CalibrationProvider calibrationProvider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.factory, color: Colors.blue.shade600, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Factory Calibration Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Calibration:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        calibrationProvider.isCalibrated
                            ? 'Active (${calibrationProvider.calibrationPoints.length} points)'
                            : 'Not Calibrated',
                        style: TextStyle(
                          color:
                              calibrationProvider.isCalibrated
                                  ? Colors.green
                                  : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Last Applied:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        factoryProvider.lastAppliedCalibration.isNotEmpty
                            ? factoryProvider.lastAppliedCalibration
                            : 'None',
                        style: TextStyle(
                          color:
                              factoryProvider.lastAppliedCalibration.isNotEmpty
                                  ? Colors.blue
                                  : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (calibrationProvider.isCalibrated) ...[
              const SizedBox(height: 12),
              Text(
                'Accuracy: ${calibrationProvider.getCalibrationAccuracy().toStringAsFixed(2)}%',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'คำเตือน',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'การใช้ Factory Calibration จะลบข้อมูลการปรับเทียบเดิมทั้งหมด\nและแทนที่ด้วยค่าที่กำหนดไว้จากโรงงาน',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFactoryCalibrationsList(
    BuildContext context,
    FactoryCalibrationProvider factoryProvider,
    CalibrationProvider calibrationProvider,
  ) {
    if (factoryProvider.factoryCalibrations.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.settings_backup_restore,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Factory Calibrations Available',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.precision_manufacturing,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Available Factory Calibrations (${factoryProvider.factoryCalibrations.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: factoryProvider.factoryCalibrations.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final calibration = factoryProvider.factoryCalibrations[index];
              final isSelected =
                  factoryProvider.lastAppliedCalibration == calibration.name;

              return Container(
                color: isSelected ? Colors.blue.shade50 : null,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isSelected
                            ? Colors.blue.shade100
                            : Colors.grey.shade100,
                    child: Icon(
                      isSelected ? Icons.check_circle : Icons.factory,
                      color:
                          isSelected
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          calibration.name,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.blue.shade800 : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'v${calibration.version}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(calibration.description),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.scatter_plot,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${calibration.points.length} points',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.schedule,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            calibration.createdAt.toString().substring(0, 10),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed:
                            () => _showCalibrationDetails(
                              context,
                              calibration,
                              factoryProvider,
                            ),
                        icon: const Icon(Icons.info_outline),
                        tooltip: 'View Details',
                      ),
                      const SizedBox(width: 8),
                      factoryProvider.isApplying
                          ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : ElevatedButton.icon(
                            onPressed:
                                () => _applyFactoryCalibration(
                                  context,
                                  calibration,
                                  factoryProvider,
                                  calibrationProvider,
                                ),
                            icon: const Icon(Icons.download, size: 16),
                            label: const Text('Apply'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isSelected
                                      ? Colors.green.shade100
                                      : Colors.blue.shade100,
                              foregroundColor:
                                  isSelected
                                      ? Colors.green.shade800
                                      : Colors.blue.shade800,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _applyFactoryCalibration(
    BuildContext context,
    FactoryCalibrationData calibration,
    FactoryCalibrationProvider factoryProvider,
    CalibrationProvider calibrationProvider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade600),
                const SizedBox(width: 8),
                const Text('Confirm Factory Calibration'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('คุณต้องการใช้ Factory Calibration: ${calibration.name}?'),
                const SizedBox(height: 8),
                const Text(
                  'การดำเนินการนี้จะ:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const Text('• ลบข้อมูลการปรับเทียบเดิมทั้งหมด'),
                const Text('• ใช้ข้อมูลจากโรงงานแทน'),
                Text('• เพิ่ม ${calibration.points.length} จุดปรับเทียบใหม่'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    calibration.description,
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();

                  final success = await factoryProvider.applyFactoryCalibration(
                    calibration,
                    (CalibrationPoint point, String notes) async {
                      await calibrationProvider.addCalibrationPoint(
                        point.rawValue,
                        point.actualWeight,
                        notes: notes,
                      );
                    },
                    () async {
                      await calibrationProvider.clearAllCalibrationData();
                    },
                  );

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Factory Calibration "${calibration.name}" applied successfully!'
                              : 'Failed to apply Factory Calibration',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade100,
                  foregroundColor: Colors.orange.shade800,
                ),
                child: const Text('Apply'),
              ),
            ],
          ),
    );
  }

  void _showCalibrationDetails(
    BuildContext context,
    FactoryCalibrationData calibration,
    FactoryCalibrationProvider factoryProvider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(calibration.name),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      factoryProvider.getCalibrationInfo(calibration),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  final jsonData = factoryProvider.exportFactoryCalibration(
                    calibration,
                  );
                  _showJsonDialog(context, 'Export JSON', jsonData);
                },
                child: const Text('Export JSON'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _showCalibrationHistory(
    BuildContext context,
    FactoryCalibrationProvider factoryProvider,
  ) async {
    final history = await factoryProvider.getCalibrationHistory();

    if (context.mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Calibration History'),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child:
                    history.isEmpty
                        ? const Center(child: Text('No calibration history'))
                        : ListView.builder(
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final appliedAt =
                                DateTime.fromMillisecondsSinceEpoch(
                                  item['applied_at'],
                                );

                            return ListTile(
                              leading: Icon(
                                Icons.history,
                                color: Colors.blue.shade600,
                              ),
                              title: Text(item['name']),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['description']),
                                  Text(
                                    'Applied: ${appliedAt.toString().substring(0, 19)}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                              trailing: Text(
                                'v${item['version']}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          },
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    }
  }

  void _showClearHistoryDialog(
    BuildContext context,
    FactoryCalibrationProvider factoryProvider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear History'),
            content: const Text(
              'Are you sure you want to clear all calibration history?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await factoryProvider.clearCalibrationHistory();
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calibration history cleared'),
                    ),
                  );
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Clear'),
              ),
            ],
          ),
    );
  }

  void _showCustomCalibrationDialog(
    BuildContext context,
    FactoryCalibrationProvider factoryProvider,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Add Custom Calibration'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Paste JSON calibration data:'),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'JSON Data',
                    hintText: 'Paste factory calibration JSON here',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 8,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (controller.text.isNotEmpty) {
                    final success = await factoryProvider
                        .addCustomFactoryCalibration(controller.text);
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Custom calibration added successfully'
                              : 'Invalid JSON format',
                        ),
                        backgroundColor: success ? Colors.green : Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showJsonDialog(BuildContext context, String title, String jsonData) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: SingleChildScrollView(
                child: SelectableText(
                  jsonData,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}
