import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/DisplayProvider.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';
class DisplayPage extends StatefulWidget {
  const DisplayPage({super.key});

  @override
  State<DisplayPage> createState() => _DisplayPageState();
}

class _DisplayPageState extends State<DisplayPage> {
  final ScrollController _scrollController = ScrollController();
  late DisplayProvider _displayProvider;

  @override
  void initState() {
    super.initState();
    // Initialize DisplayProvider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _displayProvider = Provider.of<DisplayProvider>(context, listen: false);
      _displayProvider.setScrollController(_scrollController);
      
      // Connect to SettingProvider
      final settingProvider = Provider.of<SettingProvider>(context, listen: false);
      _displayProvider.initializeWithSettingProvider(settingProvider);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Data Display'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          Consumer<DisplayProvider>(
            builder: (context, displayProvider, child) {
              return IconButton(
                onPressed: displayProvider.clearAllMessages,
                icon: const Icon(Icons.clear_all),
                tooltip: 'Clear All',
              );
            },
          ),
          Consumer<DisplayProvider>(
            builder: (context, displayProvider, child) {
              return IconButton(
                onPressed: displayProvider.toggleAutoScroll,
                icon: Icon(displayProvider.autoScroll ? Icons.lock : Icons.lock_open),
                tooltip: displayProvider.autoScroll ? 'Disable Auto Scroll' : 'Enable Auto Scroll',
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final displayProvider = Provider.of<DisplayProvider>(context, listen: false);
              switch (value) {
                case 'export':
                  _showExportDialog(context, displayProvider);
                  break;
                case 'stats':
                  _showStatsDialog(context, displayProvider);
                  break;
                case 'settings':
                  _showDisplaySettings(context, displayProvider);
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download),
                    SizedBox(width: 8),
                    Text('Export Messages'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'stats',
                child: Row(
                  children: [
                    Icon(Icons.bar_chart),
                    SizedBox(width: 8),
                    Text('Statistics'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.tune),
                    SizedBox(width: 8),
                    Text('Display Settings'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer2<SettingProvider, DisplayProvider>(
        builder: (context, settingProvider, displayProvider, child) {
          return Column(
            children: [
              _buildConnectionStatus(settingProvider),
              _buildDataStats(displayProvider),
              Expanded(
                child: _buildDataDisplay(displayProvider),
              ),
              _buildControlPanel(settingProvider, displayProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConnectionStatus(SettingProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: provider.connectedDevice != null ? Colors.green.shade50 : Colors.red.shade50,
        border: Border(
          bottom: BorderSide(
            color: provider.connectedDevice != null ? Colors.green : Colors.red,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            provider.connectedDevice != null 
                ? Icons.bluetooth_connected 
                : Icons.bluetooth_disabled,
            color: provider.connectedDevice != null ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.connectionStatus,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (provider.connectedDevice != null) ...[
                  Text(
                    'Device: ${provider.getBLEDeviceDisplayName(provider.connectedDevice!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Text(
                    'RSSI: ${provider.rssi ?? 'Unknown'} dBm | Services: ${provider.services.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataStats(DisplayProvider displayProvider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Icon(Icons.data_usage, size: 16, color: Colors.blue),
          const SizedBox(width: 4),
          Text(
            'Messages: ${displayProvider.messageCount}/${displayProvider.maxMessages}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          Icon(
            displayProvider.autoScroll ? Icons.arrow_downward : Icons.pause,
            size: 16,
            color: displayProvider.autoScroll ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            displayProvider.autoScroll ? 'Auto Scroll' : 'Paused',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildDataDisplay(DisplayProvider displayProvider) {
    if (displayProvider.receivedMessages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.message,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No data received yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a BLE device to see ASCII data',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8.0),
        itemCount: displayProvider.receivedMessages.length,
        itemBuilder: (context, index) {
          final message = displayProvider.receivedMessages[index];
          final isHex = message.contains('HEX:');
          final isManual = message.contains('MANUAL:');
          
          Color backgroundColor;
          Color borderColor;
          Color textColor;
          
          if (isManual) {
            backgroundColor = Colors.purple.shade50;
            borderColor = Colors.purple.shade200;
            textColor = Colors.purple.shade800;
          } else if (isHex) {
            backgroundColor = Colors.orange.shade50;
            borderColor = Colors.orange.shade200;
            textColor = Colors.orange.shade800;
          } else {
            backgroundColor = Colors.blue.shade50;
            borderColor = Colors.blue.shade200;
            textColor = Colors.blue.shade800;
          }
          
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 2.0),
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${index + 1}.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildControlPanel(SettingProvider settingProvider, DisplayProvider displayProvider) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        border: Border(
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: displayProvider.clearAllMessages,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: displayProvider.toggleAutoScroll,
              icon: Icon(displayProvider.autoScroll ? Icons.pause : Icons.play_arrow),
              label: Text(displayProvider.autoScroll ? 'Pause' : 'Resume'),
              style: ElevatedButton.styleFrom(
                backgroundColor: displayProvider.autoScroll ? Colors.orange.shade100 : Colors.green.shade100,
                foregroundColor: displayProvider.autoScroll ? Colors.orange.shade800 : Colors.green.shade800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _showTestInputDialog(context, displayProvider),
              icon: const Icon(Icons.edit),
              label: const Text('Test'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple.shade100,
                foregroundColor: Colors.purple.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestInputDialog(BuildContext context, DisplayProvider displayProvider) {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Test Input'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Test message',
            hintText: 'Enter test message',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                displayProvider.addManualMessage(controller.text);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, DisplayProvider displayProvider) {
    final exportData = displayProvider.exportMessages();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Messages'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: SingleChildScrollView(
            child: SelectableText(
              exportData,
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

  void _showStatsDialog(BuildContext context, DisplayProvider displayProvider) {
    final stats = displayProvider.getMessageStats();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('Total Messages', stats['total']!),
            _buildStatRow('ASCII Messages', stats['ascii']!),
            _buildStatRow('HEX Messages', stats['hex']!),
            _buildStatRow('Manual Messages', stats['manual']!),
          ],
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

  Widget _buildStatRow(String label, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showDisplaySettings(BuildContext context, DisplayProvider displayProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Display Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Max Messages:'),
                DropdownButton<int>(
                  value: displayProvider.maxMessages,
                  items: [50, 100, 200, 500].map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text('$value'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      displayProvider.setMaxMessages(value);
                    }
                  },
                ),
              ],
            ),
          ],
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