import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('BLE Settings'),
        backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
        actions: [
          // เพิ่มปุ่ม Debug เพื่อดูสถานะ
          IconButton(
            onPressed: () => _showDebugInfo(context),
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Info',
          ),
        ],
      ),
      body: Consumer<SettingProvider>(
        builder: (context, settingProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBluetoothSection(context, settingProvider),
                const SizedBox(height: 16),
                _buildConnectionStatus(settingProvider),
                const SizedBox(height: 16),
                if (settingProvider.connectedDevice != null) ...[
                  _buildConnectionInfo(settingProvider),
                  const SizedBox(height: 16),
                  // เพิ่มปุ่มเข้า Device Details โดยตรง
                  ElevatedButton.icon(
                    onPressed: () => _showBLEDeviceDetails(context, settingProvider),
                    icon: const Icon(Icons.info),
                    label: const Text('Show Device Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                _buildBLEDevicesList(context, settingProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  // เพิ่มฟังก์ชัน Debug
  void _showDebugInfo(BuildContext context) {
    final provider = Provider.of<SettingProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Bluetooth On: ${provider.isBluetoothOn}'),
              Text('Connected Device: ${provider.connectedDevice?.remoteId ?? 'None'}'),
              Text('Services Count: ${provider.services.length}'),
              Text('Total Characteristics: ${provider.characteristics.values.fold(0, (sum, list) => sum + list.length)}'),
              const SizedBox(height: 16),
              const Text('Characteristics with Write:'),
              ...provider.characteristics.values.expand((list) => list).where((char) => 
                char.properties.write || char.properties.writeWithoutResponse
              ).map((char) => Text('- ${char.uuid}')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothSection(
    BuildContext context,
    SettingProvider provider,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: provider.isBluetoothOn ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bluetooth Low Energy (BLE)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Switch(
                  value: provider.isBluetoothOn,
                  onChanged: (value) {
                    if (value) {
                      provider.turnOnBluetooth();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Status: ${_getBluetoothStatusText(provider.adapterState)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus(SettingProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  provider.connectedDevice != null
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color:
                      provider.connectedDevice != null
                          ? Colors.green
                          : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    provider.connectionStatus,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                if (provider.connectedDevice != null)
                  IconButton(
                    onPressed: provider.disconnectBLEDevice,
                    icon: const Icon(Icons.close),
                    tooltip: 'Disconnect',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionInfo(SettingProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Info',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.signal_cellular_alt, size: 16),
                const SizedBox(width: 4),
                Text('RSSI: ${provider.rssi ?? 'Unknown'} dBm'),
                const SizedBox(width: 16),
                const Icon(Icons.swap_horiz, size: 16),
                const SizedBox(width: 4),
                Text('MTU: ${provider.mtu ?? 'Unknown'} bytes'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Services: ${provider.services.length}'),
            Text(
              'Device ID: ${provider.connectedDevice?.remoteId.toString() ?? 'Unknown'}',
            ),
            // แสดงจำนวน Characteristics ที่มี Write properties
            Text(
              'Writable Characteristics: ${provider.characteristics.values.expand((list) => list).where((char) => char.properties.write || char.properties.writeWithoutResponse).length}',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBLEDevicesList(BuildContext context, SettingProvider provider) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.devices_other,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'BLE Devices',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (provider.isScanning)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: provider.refreshBLEDevices,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Scan for BLE devices',
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 300),
            child: _buildBLEDevicesContent(context, provider),
          ),
        ],
      ),
    );
  }

  Widget _buildBLEDevicesContent(
    BuildContext context,
    SettingProvider provider,
  ) {
    if (!provider.isBluetoothOn) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bluetooth_disabled, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('Turn on Bluetooth to scan for BLE devices'),
          ],
        ),
      );
    }

    if (provider.bleDevices.isEmpty && !provider.isScanning) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No BLE devices found'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: provider.refreshBLEDevices,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan for BLE devices'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: provider.bleDevices.length,
      itemBuilder: (context, index) {
        final device = provider.bleDevices[index];
        final isConnected =
            provider.connectedDevice?.remoteId == device.remoteId;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Icon(
              Icons.bluetooth,
              color: isConnected ? Colors.green : Colors.blue,
            ),
            title: Text(
              provider.getBLEDeviceDisplayName(device),
              style: TextStyle(
                fontWeight: isConnected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ID: ${device.remoteId.toString()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Type: BLE Device',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            trailing: isConnected
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      Text(
                        'Connected',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  )
                : provider.isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        onPressed: () => provider.connectToBLEDevice(device),
                        icon: const Icon(Icons.connect_without_contact),
                        tooltip: 'Connect to BLE device',
                      ),
            onTap: isConnected
                ? () => _showBLEDeviceDetails(context, provider)
                : provider.isConnecting
                    ? null
                    : () => provider.connectToBLEDevice(device),
          ),
        );
      },
    );
  }

  void _showBLEDeviceDetails(BuildContext context, SettingProvider provider) {
    if (provider.connectedDevice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No device connected'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    print('DEBUG: Showing device details');
    print('DEBUG: Services count: ${provider.services.length}');
    print('DEBUG: Characteristics: ${provider.characteristics}');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'BLE Device: ${provider.getBLEDeviceDisplayName(provider.connectedDevice!)}',
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device ID: ${provider.connectedDevice!.remoteId}'),
              Text('RSSI: ${provider.rssi ?? 'Unknown'} dBm'),
              Text('MTU: ${provider.mtu ?? 'Unknown'} bytes'),
              const SizedBox(height: 16),
              Text('Services (${provider.services.length}):'),
              const SizedBox(height: 8),
              Expanded(
                child: provider.services.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Loading services...'),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: provider.services.length,
                        itemBuilder: (context, index) {
                          final service = provider.services[index];
                          final characteristics =
                              provider.characteristics[service.uuid.toString()] ?? [];

                          print('DEBUG: Service ${service.uuid} has ${characteristics.length} characteristics');

                          return Card(
                            child: ExpansionTile(
                              title: Text(
                                'Service: ${_formatUUID(service.uuid.toString())}',
                              ),
                              subtitle: Text(
                                '${characteristics.length} characteristics',
                              ),
                              children: characteristics.map((char) {
                                final value = provider.characteristicValues[char.uuid.toString()];
                                final hasWrite = char.properties.write || char.properties.writeWithoutResponse;
                                
                                print('DEBUG: Characteristic ${char.uuid} - Write: $hasWrite');

                                return ListTile(
                                  dense: true,
                                  title: Text(
                                    'Characteristic: ${_formatUUID(char.uuid.toString())}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Properties: ${provider.getCharacteristicProperties(char)}',
                                      ),
                                      if (value != null)
                                        Text(
                                          'Value: ${provider.formatCharacteristicValue(value)}',
                                        ),
                                      // Debug info
                                      Text(
                                        'Debug: Write=${char.properties.write}, WriteNoResp=${char.properties.writeWithoutResponse}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Read button
                                      if (char.properties.read)
                                        IconButton(
                                          onPressed: () => provider.readCharacteristic(char),
                                          icon: const Icon(Icons.download, size: 16),
                                          tooltip: 'Read',
                                        ),
                                      
                                      // Write button - เพิ่ม debug
                                      if (hasWrite) ...[
                                        IconButton(
                                          onPressed: () => _showWriteDialog(context, provider, char),
                                          icon: const Icon(Icons.edit, size: 16),
                                          tooltip: 'Write',
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.blue[100],
                                          ),
                                        ),
                                        
                                        // Send 'o' button
                                        IconButton(
                                          onPressed: () => _sendOCommand(context, provider, char),
                                          icon: const Icon(Icons.radio_button_unchecked, size: 16),
                                          tooltip: 'Send O',
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.orange.shade100,
                                            foregroundColor: Colors.orange.shade700,
                                          ),
                                        ),
                                        
                                        // Quick commands
                                        PopupMenuButton<String>(
                                          onSelected: (command) => _sendQuickCommand(context, provider, char, command),
                                          icon: const Icon(Icons.flash_on, size: 16),
                                          tooltip: 'Quick Commands',
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(
                                              value: 'start',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.play_arrow, size: 16, color: Colors.green),
                                                  SizedBox(width: 8),
                                                  Text('Start'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'stop',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.stop, size: 16, color: Colors.red),
                                                  SizedBox(width: 8),
                                                  Text('Stop'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'zero',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.exposure_zero, size: 16, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Text('Zero'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'tare',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.restart_alt, size: 16, color: Colors.orange),
                                                  SizedBox(width: 8),
                                                  Text('Tare'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'status',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.info, size: 16, color: Colors.purple),
                                                  SizedBox(width: 8),
                                                  Text('Status'),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else ...[
                                        // แสดงข้อความว่าทำไมไม่มีปุ่ม Write
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: Colors.red[100],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'No Write',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.red[700],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );
                        },
                      ),
              ),
            ],
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

  void _sendOCommand(
    BuildContext context,
    SettingProvider provider,
    BluetoothCharacteristic characteristic,
  ) {
    try {
      provider.writeCharacteristic(characteristic, 'o'.codeUnits);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ส่งคำสั่ง "o" แล้ว'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำสั่งล้มเหลว: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _sendQuickCommand(
    BuildContext context,
    SettingProvider provider,
    BluetoothCharacteristic characteristic,
    String command,
  ) {
    try {
      provider.writeCharacteristic(characteristic, command.codeUnits);

      String message;
      Color color;

      switch (command) {
        case 'start':
          message = 'เริ่มการชั่งน้ำหนัก';
          color = Colors.green;
          break;
        case 'stop':
          message = 'หยุดการชั่งน้ำหนัก';
          color = Colors.red;
          break;
        case 'zero':
          message = 'ตั้งค่า Zero';
          color = Colors.blue;
          break;
        case 'tare':
          message = 'ทำ Tare';
          color = Colors.orange;
          break;
        case 'status':
          message = 'ขอสถานะ';
          color = Colors.purple;
          break;
        default:
          message = 'ส่งคำสั่ง "$command"';
          color = Colors.blue;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ส่งคำสั่งล้มเหลว: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showWriteDialog(
    BuildContext context,
    SettingProvider provider,
    BluetoothCharacteristic characteristic,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Write to Characteristic'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Value (text)',
                hintText: 'e.g., Hello, start, stop, o',
              ),
            ),
            const SizedBox(height: 16),
            // Quick buttons
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => controller.text = 'o',
                  child: const Text('o'),
                ),
                ElevatedButton(
                  onPressed: () => controller.text = 'start',
                  child: const Text('start'),
                ),
                ElevatedButton(
                  onPressed: () => controller.text = 'stop',
                  child: const Text('stop'),
                ),
                ElevatedButton(
                  onPressed: () => controller.text = 'status',
                  child: const Text('status'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final input = controller.text.trim();
              if (input.isNotEmpty) {
                try {
                  provider.writeCharacteristic(characteristic, input.codeUnits);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ส่งคำสั่ง "$input" แล้ว'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('ส่งคำสั่งล้มเหลว: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Write'),
          ),
        ],
      ),
    );
  }

  String _formatUUID(String uuid) {
    try {
      if (uuid.isEmpty) return 'Unknown UUID';
      String cleanUuid = uuid.replaceAll('-', '').replaceAll(' ', '');
      if (cleanUuid.length >= 8) {
        return '${cleanUuid.substring(0, 8)}...';
      } else if (cleanUuid.length >= 4) {
        return '${cleanUuid.substring(0, 4)}...';
      } else {
        return cleanUuid;
      }
    } catch (e) {
      return 'Invalid UUID';
    }
  }

  String _getBluetoothStatusText(BluetoothAdapterState state) {
    switch (state) {
      case BluetoothAdapterState.on:
        return 'On';
      case BluetoothAdapterState.off:
        return 'Off';
      case BluetoothAdapterState.turningOn:
        return 'Turning On...';
      case BluetoothAdapterState.turningOff:
        return 'Turning Off...';
      case BluetoothAdapterState.unavailable:
        return 'Unavailable';
      case BluetoothAdapterState.unauthorized:
        return 'Unauthorized';
      default:
        return 'Unknown';
    }
  }
}