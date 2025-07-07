import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/PopupProvider.dart';
import '../providers/SettingProvider.dart';
import '../providers/CalibrationProvider.dart';
import '../providers/DisplayProvider.dart';

class PopupWidget extends StatelessWidget {
  final VoidCallback? onTarePressed;
  final VoidCallback? onZeroPressed;
  final VoidCallback? onCalibrationPressed;

  const PopupWidget({
    super.key,
    this.onTarePressed,
    this.onZeroPressed,
    this.onCalibrationPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การควบคุมเครื่องชั่ง'),
        backgroundColor: Colors.grey.shade100,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Header Tabs
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade100),
              child: Row(
                children: [
                  // ปุ่มกำหนด
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'ปุ่มกำหนด',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // ปรับโรงงาน
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text(
                        'ปรับโรงงาน',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // สถานะการเชื่อมต่อ - ใช้ PopupProvider
                  Expanded(
                    child: Consumer<PopupProvider>(
                      builder: (context, popupProvider, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color:
                                popupProvider.isConnected
                                    ? Colors.green.shade50
                                    : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  popupProvider.isConnected
                                      ? Colors.green.shade300
                                      : Colors.red.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                popupProvider.isConnected
                                    ? Icons.bluetooth_connected
                                    : Icons.bluetooth_disabled,
                                color:
                                    popupProvider.isConnected
                                        ? Colors.green
                                        : Colors.red,
                                size: 16,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                popupProvider.isConnected
                                    ? 'เชื่อมต่อ'
                                    : 'ไม่เชื่อมต่อ',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      popupProvider.isConnected
                                          ? Colors.green.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Left Side - Control Buttons
                    SizedBox(
                      width: 120,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Set Tare Button - ใช้ค่าปัจจุบันเพื่อ Tare
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return ElevatedButton(
                                  onPressed:
                                      popupProvider.isProcessing
                                          ? null
                                          : onTarePressed ??
                                              () async {
                                                popupProvider.sendCustomCommand(
                                                  'TARE',
                                                );
                                                print("TARE button pressed");
                                                // final result =
                                                //     await popupProvider
                                                //         .performTare();

                                                // if (context.mounted) {
                                                //   ScaffoldMessenger.of(
                                                //     context,
                                                //   ).showSnackBar(
                                                //     SnackBar(
                                                //       content: Text(
                                                //         result.message,
                                                //       ),
                                                //       backgroundColor:
                                                //           result.success
                                                //               ? Colors.blue
                                                //               : Colors.red,
                                                //       duration: const Duration(
                                                //         seconds: 2,
                                                //       ),
                                                //     ),
                                                //   );
                                                // }
                                              },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue.shade100,
                                    foregroundColor: Colors.blue.shade800,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child:
                                      popupProvider.isProcessing &&
                                              popupProvider.lastOperation ==
                                                  'TARE'
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text(
                                            'Set Tare',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Clear Tare Button - ล้างค่า Tare
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return ElevatedButton(
                                  onPressed:
                                      popupProvider.isProcessing
                                          ? null
                                          : () async {
                                            final result =
                                                await popupProvider.clearTare();

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
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        popupProvider.hasTareOffset
                                            ? Colors.orange.shade100
                                            : Colors.grey.shade200,
                                    foregroundColor:
                                        popupProvider.hasTareOffset
                                            ? Colors.orange.shade800
                                            : Colors.grey.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child:
                                      popupProvider.isProcessing &&
                                              popupProvider.lastOperation ==
                                                  'CLEAR_TARE'
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Text(
                                            popupProvider.hasTareOffset
                                                ? 'Clear Tare'
                                                : 'No Tare',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Zero Button - ส่งคำสั่งไป ESP32
                          SizedBox(
                            width: double.infinity,
                            child: Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return ElevatedButton(
                                  onPressed:
                                      popupProvider.isProcessing
                                          ? null
                                          : onZeroPressed ??
                                              () async {
                                                final result =
                                                    await popupProvider
                                                        .sendZeroCommand();

                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        result.message,
                                                      ),
                                                      backgroundColor:
                                                          result.success
                                                              ? Colors.orange
                                                              : Colors.red,
                                                      duration: const Duration(
                                                        seconds: 2,
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        popupProvider.isConnected
                                            ? Colors.orange.shade100
                                            : Colors.grey.shade200,
                                    foregroundColor:
                                        popupProvider.isConnected
                                            ? Colors.orange.shade800
                                            : Colors.grey.shade600,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child:
                                      popupProvider.isProcessing &&
                                              popupProvider.lastOperation ==
                                                  'ZERO'
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Text(
                                            'Zero\n(ESP32)',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                );
                              },
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Settings Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed:
                                  onCalibrationPressed ??
                                  () {
                                    Navigator.pushNamed(context, '/settings');
                                  },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade100,
                                foregroundColor: Colors.grey.shade800,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Settings\n& BLE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right Side - Weight Display
                    Expanded(
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Weight Icon
                            Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return Icon(
                                  Icons.scale,
                                  size: 48,
                                  color:
                                      popupProvider.isConnected
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade600,
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Weight Value - ใช้ PopupProvider
                            Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return Text(
                                  popupProvider.formattedWeight,
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        popupProvider.currentRawValue != null
                                            ? Colors.blue.shade800
                                            : Colors.grey.shade800,
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 8),

                            // kg Unit
                            Text(
                              'kg',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Status Container - ใช้ PopupProvider
                            Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'น้ำหนักปัจจุบัน: ${popupProvider.formattedWeight} kg',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      if (popupProvider.hasTareOffset) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Tare Offset: ${popupProvider.tareOffset.toStringAsFixed(1)} kg',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.orange.shade600,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                      if (popupProvider.isProcessing) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'กำลังดำเนินการ: ${popupProvider.lastOperation}...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.blue.shade600,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // Additional Weight Information
                            Consumer<PopupProvider>(
                              builder: (context, popupProvider, child) {
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.blue.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      // Raw Weight
                                      // Row(
                                      //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      //   children: [
                                      //     Text(
                                      //       'Raw Weight:',
                                      //       style: TextStyle(
                                      //         fontSize: 12,
                                      //         color: Colors.blue.shade700,
                                      //         fontWeight: FontWeight.w500,
                                      //       ),
                                      //     ),
                                      //     Text(
                                      //       '${popupProvider.rawWeightWithoutTare?.toStringAsFixed(1) ?? "-.--"} kg',
                                      //       style: TextStyle(
                                      //         fontSize: 12,
                                      //         color: Colors.blue.shade800,
                                      //         fontWeight: FontWeight.bold,
                                      //       ),
                                      //     ),
                                      //   ],
                                      // ),

                                      // Tare Offset
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Tare Offset:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            '${popupProvider.tareOffset.toStringAsFixed(1)} kg',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Net Weight
                                      const SizedBox(height: 4),
                                      // Row(
                                      //   mainAxisAlignment:
                                      //       MainAxisAlignment.spaceBetween,
                                      //   children: [
                                      //     Text(
                                      //       'Net Weight:',
                                      //       style: TextStyle(
                                      //         fontSize: 12,
                                      //         color: Colors.green.shade700,
                                      //         fontWeight: FontWeight.w500,
                                      //       ),
                                      //     ),
                                      //     Text(
                                      //       '${popupProvider.netWeight?.toStringAsFixed(1) ?? "-.--"} kg',
                                      //       style: TextStyle(
                                      //         fontSize: 12,
                                      //         color: Colors.green.shade800,
                                      //         fontWeight: FontWeight.bold,
                                      //       ),
                                      //     ),
                                      //   ],
                                      // ),

                                      // Connection and Operations Statistics
                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          Column(
                                            children: [
                                              Text(
                                                '${popupProvider.tareOperations}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.blue.shade700,
                                                ),
                                              ),
                                              Text(
                                                'Tare',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.blue.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Text(
                                                '${popupProvider.zeroOperations}',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange.shade700,
                                                ),
                                              ),
                                              Text(
                                                'Zero',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.orange.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Column(
                                            children: [
                                              Icon(
                                                popupProvider.isConnected
                                                    ? Icons.link
                                                    : Icons.link_off,
                                                color:
                                                    popupProvider.isConnected
                                                        ? Colors.green
                                                        : Colors.red,
                                                size: 16,
                                              ),
                                              Text(
                                                popupProvider.isConnected
                                                    ? 'Connected'
                                                    : 'Offline',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color:
                                                      popupProvider.isConnected
                                                          ? Colors
                                                              .green
                                                              .shade600
                                                          : Colors.red.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function สำหรับแสดงสถานะการเชื่อมต่อ (ใช้ PopupProvider)
Widget buildConnectionStatus(BuildContext context) {
  return Consumer<PopupProvider>(
    builder: (context, popupProvider, child) {
      return Card(
        margin: const EdgeInsets.all(8),
        color:
            popupProvider.isConnected
                ? Colors.green.shade50
                : Colors.red.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Connection Status
              Icon(
                popupProvider.isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: popupProvider.isConnected ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      popupProvider.isConnected
                          ? 'เชื่อมต่อ: ${popupProvider.deviceName}'
                          : 'ยังไม่ได้เชื่อมต่อ Bluetooth',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color:
                            popupProvider.isConnected
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                    ),
                    if (popupProvider.isConnected)
                      Text(
                        'Status: ${popupProvider.connectionStatus}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
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

// ตัวอย่างการใช้งาน
class ExampleUsage extends StatelessWidget {
  const ExampleUsage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Main Page')),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PopupWidget()),
            );
          },
          child: const Text('Go to Control Page'),
        ),
      ),
    );
  }
}
