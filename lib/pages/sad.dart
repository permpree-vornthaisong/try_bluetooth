// SizedBox(
//   width: 120,
//   child: Column(
//     mainAxisAlignment: MainAxisAlignment.center,
//     children: [
//       // Set Tare Button - ใช้ค่าปัจจุบันเพื่อ Tare
//       SizedBox(
//         width: double.infinity,
//         child: Consumer<PopupProvider>(
//           builder: (context, popupProvider, child) {
//             return ElevatedButton(
//               onPressed: popupProvider.isProcessing
//                   ? null
//                   : onTarePressed ??
//                       () async {
//                         final result = await popupProvider.performTare();

//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(result.message),
//                               backgroundColor: result.success
//                                   ? Colors.blue
//                                   : Colors.red,
//                               duration: const Duration(seconds: 2),
//                             ),
//                           );
//                         }
//                       },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: Colors.blue.shade100,
//                 foregroundColor: Colors.blue.shade800,
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: popupProvider.isProcessing &&
//                       popupProvider.lastOperation == 'TARE'
//                   ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     )
//                   : const Text(
//                       'Set Tare',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             );
//           },
//         ),
//       ),

//       const SizedBox(height: 8),

//       // Clear Tare Button - ล้างค่า Tare
//       SizedBox(
//         width: double.infinity,
//         child: Consumer<PopupProvider>(
//           builder: (context, popupProvider, child) {
//             return ElevatedButton(
//               onPressed: popupProvider.isProcessing
//                   ? null
//                   : () async {
//                       final result = await popupProvider.clearTare();

//                       if (context.mounted) {
//                         ScaffoldMessenger.of(context).showSnackBar(
//                           SnackBar(
//                             content: Text(result.message),
//                             backgroundColor: result.success
//                                 ? Colors.orange
//                                 : Colors.red,
//                             duration: const Duration(seconds: 2),
//                           ),
//                         );
//                       }
//                     },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: popupProvider.hasTareOffset
//                     ? Colors.orange.shade100
//                     : Colors.grey.shade200,
//                 foregroundColor: popupProvider.hasTareOffset
//                     ? Colors.orange.shade800
//                     : Colors.grey.shade600,
//                 padding: const EdgeInsets.symmetric(vertical: 12),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: popupProvider.isProcessing &&
//                       popupProvider.lastOperation == 'CLEAR_TARE'
//                   ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     )
//                   : Text(
//                       popupProvider.hasTareOffset ? 'Clear Tare' : 'No Tare',
//                       textAlign: TextAlign.center,
//                       style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             );
//           },
//         ),
//       ),

//       const SizedBox(height: 12),

//       // Zero Button - ส่งคำสั่งไป ESP32
//       SizedBox(
//         width: double.infinity,
//         child: Consumer<PopupProvider>(
//           builder: (context, popupProvider, child) {
//             return ElevatedButton(
//               onPressed: popupProvider.isProcessing
//                   ? null
//                   : onZeroPressed ??
//                       () async {
//                         final result = await popupProvider.sendZeroCommand();

//                         if (context.mounted) {
//                           ScaffoldMessenger.of(context).showSnackBar(
//                             SnackBar(
//                               content: Text(result.message),
//                               backgroundColor: result.success
//                                   ? Colors.orange
//                                   : Colors.red,
//                               duration: const Duration(seconds: 2),
//                             ),
//                           );
//                         }
//                       },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: popupProvider.isConnected
//                     ? Colors.orange.shade100
//                     : Colors.grey.shade200,
//                 foregroundColor: popupProvider.isConnected
//                     ? Colors.orange.shade800
//                     : Colors.grey.shade600,
//                 padding: const EdgeInsets.symmetric(vertical: 16),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//               ),
//               child: popupProvider.isProcessing &&
//                       popupProvider.lastOperation == 'ZERO'
//                   ? const SizedBox(
//                       width: 16,
//                       height: 16,
//                       child: CircularProgressIndicator(strokeWidth: 2),
//                     )
//                   : const Text(
//                       'Zero\n(ESP32)',
//                       textAlign: TextAlign.center,
//                       style: TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                       ),
//                     ),
//             );
//           },
//         ),
//       ),

//       const SizedBox(height: 12),

//       // Settings Button
//       SizedBox(
//         width: double.infinity,
//         child: ElevatedButton(
//           onPressed: onCalibrationPressed ??
//               () {
//                 Navigator.pushNamed(context, '/settings');
//               },
//           style: ElevatedButton.styleFrom(
//             backgroundColor: Colors.grey.shade100,
//             foregroundColor: Colors.grey.shade800,
//             padding: const EdgeInsets.symmetric(vertical: 16),
//             shape: RoundedRectangleBorder(
//               borderRadius: BorderRadius.circular(8),
//             ),
//           ),
//           child: const Text(
//             'Settings\n& BLE',
//             textAlign: TextAlign.center,
//             style: TextStyle(
//               fontSize: 14,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),
//       ),
//     ],
//   ),
// )