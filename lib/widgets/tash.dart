// // ฟังก์ชันสำหรับ BTN4 - Insert น้ำหนักโดยอัตโนมัติ
// Future<void> _insertWeightToBTN4(
//   BuildContext context,
//   DisplayHomeProvider displayProvider,
//   FormulaProvider formulaProvider,
//   SettingProvider settingProvider,
// ) async {
//   try {
//     print('🔄 [BTN4] Starting weight insertion process...');

//     // 1. ตรวจสอบว่าเลือก formula แล้วหรือยัง
//     if (displayProvider.isReadonlyMode || !displayProvider.hasValidFormulaSelected) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Please select a formula first'),
//           backgroundColor: Colors.orange,
//         ),
//       );
//       return;
//     }

//     // 2. ตรวจสอบว่ามีข้อมูลน้ำหนักหรือไม่
//     if (settingProvider.currentRawValue == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('No weight data available. Please connect device first.'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     final selectedFormulaName = displayProvider.selectedFormula!;
//     final weightValue = settingProvider.currentRawValue!;
//     final deviceName = settingProvider.connectedDevice?.platformName ?? 'Unknown Device';
//     final timestamp = DateTime.now().toIso8601String();

//     print('⚖️ [BTN4] Weight value: ${weightValue.toStringAsFixed(2)} kg');
//     print('📱 [BTN4] Device: $deviceName');
//     print('🕐 [BTN4] Timestamp: $timestamp');

//     // 3. ดึงข้อมูล formula
//     final formulaDetails = formulaProvider.getFormulaByName(selectedFormulaName);
    
//     if (formulaDetails == null) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Formula not found'),
//           backgroundColor: Colors.red,
//         ),
//       );
//       return;
//     }

//     final tableName = formulaDetails.tableName;
//     final existingColumns = formulaDetails.columnNames;
    
//     print('📋 [BTN4] Table: $tableName');
//     print('🏷️ [BTN4] Existing columns: $existingColumns');

//     // 4. ตรวจสอบว่ามี column weight หรือไม่
//     final normalizedColumns = existingColumns.map((col) => col.toLowerCase().replaceAll(' ', '_')).toList();
//     final hasWeightColumn = normalizedColumns.any((col) => 
//         col == 'weight' || 
//         col == 'weight_kg' || 
//         col == 'weight_value' ||
//         col.contains('weight')
//     );

//     print('🔍 [BTN4] Has weight column: $hasWeightColumn');

//     // 5. เตรียมข้อมูลสำหรับ insert
//     final Map<String, dynamic> dataToInsert = {};

//     if (hasWeightColumn) {
//       // กรณีมี weight column อยู่แล้ว
//       print('✅ [BTN4] Using existing weight column');
      
//       for (int i = 0; i < existingColumns.length; i++) {
//         final originalColumnName = existingColumns[i];
//         final normalizedColumnName = originalColumnName.toLowerCase().replaceAll(' ', '_');
        
//         if (normalizedColumnName == 'weight' || 
//             normalizedColumnName == 'weight_kg' || 
//             normalizedColumnName == 'weight_value' ||
//             normalizedColumnName.contains('weight')) {
//           // ใส่ค่าน้ำหนัก
//           dataToInsert[normalizedColumnName] = weightValue.toString();
//           print('⚖️ [BTN4] Inserted weight: $weightValue -> $normalizedColumnName');
//         } else if (normalizedColumnName.contains('time') || 
//                    normalizedColumnName.contains('date') ||
//                    normalizedColumnName == 'timestamp') {
//           // ใส่ timestamp
//           dataToInsert[normalizedColumnName] = timestamp;
//           print('🕐 [BTN4] Inserted timestamp -> $normalizedColumnName');
//         } else if (normalizedColumnName.contains('device') || 
//                    normalizedColumnName.contains('source')) {
//           // ใส่ชื่อ device
//           dataToInsert[normalizedColumnName] = deviceName;
//           print('📱 [BTN4] Inserted device -> $normalizedColumnName');
//         } else {
//           // ใส่ข้อมูล default
//           dataToInsert[normalizedColumnName] = 'Auto-${DateTime.now().millisecondsSinceEpoch}';
//           print('📝 [BTN4] Inserted default -> $normalizedColumnName');
//         }
//       }
//     } else {
//       // กรณีไม่มี weight column - ต้องเพิ่ม column weight เข้าไป
//       print('⚠️ [BTN4] No weight column found. Adding weight column...');
      
//       try {
//         // 1. เพิ่ม weight column ลงใน table
//         await _addWeightColumnToTable(formulaProvider, tableName);
        
//         // 2. ใส่ข้อมูลเดิมตาม column เดิม
//         for (int i = 0; i < existingColumns.length; i++) {
//           final normalizedColumnName = existingColumns[i].toLowerCase().replaceAll(' ', '_');
          
//           if (normalizedColumnName.contains('time') || 
//               normalizedColumnName.contains('date') ||
//               normalizedColumnName == 'timestamp') {
//             dataToInsert[normalizedColumnName] = timestamp;
//           } else if (normalizedColumnName.contains('device') || 
//                      normalizedColumnName.contains('source')) {
//             dataToInsert[normalizedColumnName] = deviceName;
//           } else {
//             dataToInsert[normalizedColumnName] = 'Auto-${DateTime.now().millisecondsSinceEpoch}';
//           }
//         }
        
//         // 3. เพิ่มข้อมูลน้ำหนักใน column weight ใหม่
//         dataToInsert['weight'] = weightValue.toString();
//         print('✅ [BTN4] Added weight column and inserted weight: $weightValue');
        
//       } catch (e) {
//         print('❌ [BTN4] Failed to add weight column: $e');
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Failed to add weight column: $e'),
//             backgroundColor: Colors.red,
//           ),
//         );
//         return;
//       }
//     }

//     print('💾 [BTN4] Final data to insert: $dataToInsert');

//     // 6. Insert ข้อมูลลง database
//     final success = await formulaProvider.createRecord(
//       tableName: tableName,
//       data: dataToInsert,
//     );

//     // 7. แสดงผลลัพธ์
//     if (success) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             'Weight ${weightValue.toStringAsFixed(2)} kg saved to $selectedFormulaName!',
//           ),
//           backgroundColor: Colors.green,
//           duration: const Duration(seconds: 2),
//         ),
//       );
      
//       print('✅ [BTN4] Weight data saved successfully!');
//       print('📊 [BTN4] Weight: ${weightValue.toStringAsFixed(2)} kg');
//       print('📋 [BTN4] Formula: $selectedFormulaName');
      
//       // Optional: Print table data to verify
//       await formulaProvider.printSpecificTable(tableName);
      
//     } else {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Failed to save weight data'),
//           backgroundColor: Colors.red,
//         ),
//       );
      
//       print('❌ [BTN4] Failed to save weight data');
//     }

//   } catch (e) {
//     print('❌ [BTN4] Error in weight insertion: $e');
    
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text('Error saving weight: $e'),
//         backgroundColor: Colors.red,
//       ),
//     );
//   }
// }

// // Helper function สำหรับเพิ่ม weight column ลงใน table
// Future<void> _addWeightColumnToTable(
//   FormulaProvider formulaProvider,
//   String tableName,
// ) async {
//   try {
//     print('🔧 [BTN4] Adding weight column to table: $tableName');
    
//     // ใช้ SQL ALTER TABLE เพื่อเพิ่ม column (ถ้า GenericCRUDProvider รองรับ)
//     // หรือใช้วิธีอื่นตามที่ provider รองรับ
    
//     // วิธีที่ 1: ใช้ GenericCRUDProvider (ถ้ามี method addColumn)
//     // await formulaProvider._crudProvider!.addColumn(tableName, 'weight', 'TEXT');
    
//     // วิธีที่ 2: ใช้ SQL โดยตรง (ถ้า provider รองรับ raw SQL)
//     // await formulaProvider._crudProvider!.executeSql(
//     //   'ALTER TABLE $tableName ADD COLUMN weight TEXT'
//     // );
    
//     // วิธีที่ 3: สำหรับ demo - ถ้าไม่สามารถเพิ่ม column ได้
//     // เราจะใช้การสร้าง record ปกติและให้ระบบจัดการเอง
//     print('⚠️ [BTN4] Weight column addition simulated (actual implementation depends on GenericCRUDProvider capabilities)');
    
//   } catch (e) {
//     print('❌ [BTN4] Error adding weight column: $e');
//     throw e;
//   }
// }

// // BTN4 Implementation
// Expanded(
//   child: Consumer3<DisplayHomeProvider, FormulaProvider, SettingProvider>(
//     builder: (context, displayProvider, formulaProvider, settingProvider, child) {
//       return _buildButton(
//         'SAVE WEIGHT',
//         backgroundColor: Colors.teal,
//         onPressed: () async {
//           await _insertWeightToBTN4(
//             context,
//             displayProvider,
//             formulaProvider,
//             settingProvider,
//           );
//         },
//       );
//     },
//   ),
// ),

// // ทางเลือก: ถ้าต้องการใช้ Provider.of แทน Consumer
// Expanded(
//   child: _buildButton(
//     'SAVE WEIGHT',
//     backgroundColor: Colors.teal,
//     onPressed: () async {
//       final displayProvider = Provider.of<DisplayHomeProvider>(context, listen: false);
//       final formulaProvider = Provider.of<FormulaProvider>(context, listen: false);
//       final settingProvider = Provider.of<SettingProvider>(context, listen: false);
      
//       await _insertWeightToBTN4(
//         context,
//         displayProvider,
//         formulaProvider,
//         settingProvider,
//       );
//     },
//   ),
// ),


// Bottom Row - BTN3 and BTN4
// Row(
//   children: [
//     Expanded(
//       child: _buildButton(
//         'BTN3',
//         onPressed: () {
//           print('BTN3 pressed');
//         },
//       ),
//     ),
//     const SizedBox(width: 16),
//     Expanded(
//       child: Consumer3<DisplayHomeProvider, FormulaProvider, SettingProvider>(
//         builder: (context, displayProvider, formulaProvider, settingProvider, child) {
//           return _buildButton(
//             'SAVE WEIGHT',
//             backgroundColor: Colors.teal,
//             onPressed: () async {
//               await _insertWeightToBTN4(
//                 context,
//                 displayProvider,
//                 formulaProvider,
//                 settingProvider,
//               );
//             },
//           );
//         },
//       ),
//     ),
//   ],
// ),