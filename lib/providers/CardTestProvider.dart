import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'FormulaProvider.dart';

/// Provider สำหรับจัดการข้อมูลใน CardTest
class CardTestProvider extends ChangeNotifier {
  FormulaProvider? _formulaProvider;

  /// เริ่มต้น provider
  void initialize(BuildContext context) {
    _formulaProvider = Provider.of<FormulaProvider>(context, listen: false);
    debugPrint('✅ [CardTestProvider] Initialized');
  }

  /// ฟังก์ชันสำหรับกดที่ card แล้วปริ้นข้อมูล formula นั้นๆ
  Future<void> onCardTapped(Map<String, dynamic> formula) async {
    if (_formulaProvider == null) {
      debugPrint('❌ FormulaProvider is null');
      return;
    }

    try {
      final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
      final formulaId = formula['id']?.toString() ?? '';
      
      debugPrint('🎯 Card tapped: $formulaName');
      debugPrint('=== PRINTING ${formulaName.toUpperCase()} DATA ===');

      // สร้าง table name จาก formula name หรือ id
      String tableName;
      if (formulaName.toLowerCase() != 'unknown') {
        // ใช้ formula_name เป็น table name
        tableName = 'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';
      } else {
        // ใช้ id แทน
        tableName = 'formula_$formulaId';
      }

      debugPrint('📋 Table name: $tableName');

      // ดึงข้อมูลจาก table
      final tableData = await _formulaProvider!.getTableData(tableName);
      final columns = await _formulaProvider!.getTableColumns(tableName);

      debugPrint(
        '📊 Found ${tableData.length} records with ${columns.length} columns',
      );
      debugPrint('');

      // ปริ้นข้อมูลทั้งหมด
      if (tableData.isEmpty) {
        debugPrint('📝 No data found');
      } else {
        // ปริ้นแบบรายการก่อน
        for (int i = 0; i < tableData.length; i++) {
          final record = tableData[i];
          debugPrint('Record ${i + 1}:');

          for (final column in columns) {
            debugPrint('  $column: ${record[column]}');
          }
          debugPrint('');
        }

        // แล้วปริ้นแบบตาราง
        debugPrint('=== TABLE FORMAT ===');
        _printTable(tableData, columns);
      }

      debugPrint('✅ Finished printing $formulaName data');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error in onCardTapped: $e');
    }
  }

  /// ปริ้นตารางสวยๆ
  void _printTable(List<Map<String, dynamic>> tableData, List<String> columns) {
    if (tableData.isEmpty) return;

    // กำหนดความกว้างสูงสุดของแต่ละ column
    const int maxWidth = 20;
    Map<String, int> columnWidths = {};

    // คำนวณความกว้างที่เหมาะสม
    for (String column in columns) {
      int maxLength = column.length;

      for (var record in tableData) {
        String value = record[column]?.toString() ?? '';
        if (value.length > maxLength) {
          maxLength = value.length;
        }
      }

      // จำกัดความกว้างไม่เกิน maxWidth
      columnWidths[column] = maxLength > maxWidth ? maxWidth : maxLength;
    }

    // สร้าง header
    String header = '| ';
    for (String column in columns) {
      int width = columnWidths[column]!;
      String displayColumn =
          column.length > width
              ? '${column.substring(0, width - 3)}...'
              : column;
      header += '${displayColumn.padRight(width)} | ';
    }
    debugPrint(header);

    // สร้างเส้นแบ่ง
    String separator = '|';
    for (String column in columns) {
      int width = columnWidths[column]!;
      separator += '${'─' * (width + 2)}|';
    }
    debugPrint(separator);

    // แสดงข้อมูลแต่ละแถว
    for (int i = 0; i < tableData.length; i++) {
      var record = tableData[i];
      String row = '| ';

      for (String column in columns) {
        int width = columnWidths[column]!;
        String value = record[column]?.toString() ?? '';

        String displayValue;
        if (value.length > width) {
          displayValue = '${value.substring(0, width - 3)}...';
        } else {
          displayValue = value;
        }

        row += '${displayValue.padRight(width)} | ';
      }
      debugPrint(row);
    }

    // ปิดตาราง
    debugPrint(separator);
    debugPrint('📊 Total records: ${tableData.length}');
  }
}