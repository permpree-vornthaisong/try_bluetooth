import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/WeightCalibrationPage.dart';
import 'package:try_bluetooth/providers/DeviceConnectionProvider.dart';
import 'package:try_bluetooth/providers/ScanProvider.dart';

class DeviceConnectionPage extends StatefulWidget {
  final BluetoothDeviceInfo deviceInfo;

  const DeviceConnectionPage({Key? key, required this.deviceInfo})
    : super(key: key);

  @override
  State<DeviceConnectionPage> createState() => _DeviceConnectionPageState();
}

class _DeviceConnectionPageState extends State<DeviceConnectionPage> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _hexController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // เชื่อมต่อกับอุปกรณ์เมื่อเปิดหน้า
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<DeviceConnectionProvider>();
      if (!provider.isConnected) {
        provider.connectToDevice(widget.deviceInfo.bleDevice!);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _hexController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.deviceInfo.name),
        actions: [
          Consumer<DeviceConnectionProvider>(
            builder: (context, provider, child) {
              return IconButton(
                icon: Icon(
                  provider.isConnected
                      ? Icons.bluetooth_connected
                      : Icons.bluetooth_disabled,
                  color: provider.isConnected ? Colors.green : Colors.red,
                ),
                onPressed:
                    provider.isConnected
                        ? () => provider.disconnect()
                        : () => provider.connectToDevice(
                          widget.deviceInfo.bleDevice!,
                        ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.scale),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WeightCalibrationPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Consumer<DeviceConnectionProvider>(
        builder: (context, provider, child) {
          if (provider.isConnecting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!provider.isConnected) {
            return const Center(child: Text('กรุณาเชื่อมต่อกับอุปกรณ์'));
          }

          return Column(
            children: [
              // Status Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                color:
                    provider.isConnected
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          provider.isConnected
                              ? Icons.check_circle
                              : provider.isConnecting
                              ? Icons.sync
                              : Icons.error_outline,
                          color:
                              provider.isConnected
                                  ? Colors.green
                                  : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          provider.statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Address: ${widget.deviceInfo.address}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Send Z Button
              if (provider.isConnected)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ElevatedButton.icon(
                    onPressed: () => provider.sendData('z'),
                    icon: const Icon(Icons.send),
                    label: const Text('ส่งตัว Z'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ),

              // Received Data Section
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[50],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ข้อมูลที่ได้รับ (Raw Bytes):',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () => provider.clearReceivedData(),
                            child: const Text('ล้างข้อมูล'),
                          ),
                        ],
                      ),
                      const Divider(),
                      Expanded(
                        child: Consumer<DeviceConnectionProvider>(
                          builder: (context, provider, child) {
                            return provider.receivedData.isEmpty
                                ? const Center(
                                    child: Text(
                                      'ยังไม่มีข้อมูล',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: provider.receivedData.length,
                                    itemBuilder: (context, index) {
                                      final rawData = provider.receivedData[index];
                                      final asciiData = String.fromCharCodes(rawData);
                                      return ListTile(
                                        title: Text('Received: $asciiData'),
                                      );
                                    },
                                  );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Send Custom Data Section
              if (provider.isConnected)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Send as Text
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _messageController,
                              decoration: InputDecoration(
                                hintText: 'ส่งข้อความ...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (_messageController.text.isNotEmpty) {
                                provider.sendData(_messageController.text);
                                _messageController.clear();
                              }
                            },
                            icon: const Icon(Icons.send),
                            color: Colors.blue,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Send as Hex
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _hexController,
                              decoration: InputDecoration(
                                hintText:
                                    'ส่ง HEX (เช่น 7A หรือ 48 65 6C 6C 6F)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9A-Fa-f\s]'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () {
                              if (_hexController.text.isNotEmpty) {
                                try {
                                  final hexString = _hexController.text
                                      .replaceAll(' ', '');
                                  final bytes = <int>[];

                                  for (
                                    int i = 0;
                                    i < hexString.length;
                                    i += 2
                                  ) {
                                    final hex = hexString.substring(
                                      i,
                                      i + 2 <= hexString.length
                                          ? i + 2
                                          : hexString.length,
                                    );
                                    bytes.add(int.parse(hex, radix: 16));
                                  }

                                  provider.sendBytes(bytes);
                                  _hexController.clear();
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'รูปแบบ HEX ไม่ถูกต้อง: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.code),
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
