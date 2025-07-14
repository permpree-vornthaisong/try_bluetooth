import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/pages/ViewDatabase.dart'; // เพิ่ม import ViewDatabase
import 'package:try_bluetooth/pages/showCreateCustomerDialog.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';

class Cardtest extends StatelessWidget {
  Cardtest({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Data Base'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            onPressed: () => showCreateCustomerDialog(context),
            icon: const Icon(Icons.add),
            tooltip: 'Create New Formula',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon(Icons.functions, size: 100, color: Colors.blue),
            // SizedBox(height: 20),
            // Text(
            //   'Formula Page',
            //   style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            // ),
            SizedBox(height: 10),
            // Text(
            //   'This is the formula testing page',
            //   style: TextStyle(fontSize: 16, color: Colors.grey),
            // ),
            Expanded(child: buildTapCardList()),
            // ElevatedButton.icon(
            //   onPressed: () => _showIconDialog(context),
            //   icon: const Icon(Icons.category),
            //   label: const Text('Show Icon Categories'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.blue,
            //     foregroundColor: Colors.white,
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 20,
            //       vertical: 10,
            //     ),
            //   ),
            // ),
            // ElevatedButton.icon(
            //   onPressed: () => showCreateCustomerDialog(context),
            //   icon: const Icon(Icons.add),
            //   label: const Text('Create New Formula'),
            //   style: ElevatedButton.styleFrom(
            //     backgroundColor: Colors.green,
            //     foregroundColor: Colors.white,
            //     padding: const EdgeInsets.symmetric(
            //       horizontal: 20,
            //       vertical: 10,
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget buildTapCardList() {
    return Consumer<FormulaProvider>(
      builder: (context, formulaProvider, child) {
        // ตรวจสอบสถานะ initialization
        if (!formulaProvider.isInitialized) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing formulas...'),
              ],
            ),
          );
        }

        // ตรวจสอบสถานะ processing
        if (formulaProvider.isProcessing) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading formulas...'),
              ],
            ),
          );
        }

        // ตรวจสอบ error
        if (formulaProvider.lastError != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text(
                  'Error: ${formulaProvider.lastError}',
                  style: TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => formulaProvider.refreshFormulas(),
                  child: Text('Retry'),
                ),
              ],
            ),
          );
        }

        // ดึงจำนวน formulas
        final formulas = formulaProvider.formulas;
        final formulaCount = formulas.length;

        // ถ้าไม่มี formulas
        if (formulaCount == 0) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.functions, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No formulas created yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'Create your first formula to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => showCreateCustomerDialog(context),
                  icon: Icon(Icons.add),
                  label: Text('Create Formula'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // แสดง ListView ของ formulas
        return ListView.builder(
          padding: EdgeInsets.all(8),
          itemCount: formulaCount,
          itemBuilder: (context, index) {
            final formula = formulas[index];

            // ดึงข้อมูลจาก Map
            final formulaName =
                formula['formula_name']?.toString() ?? 'Unknown';
            final columnCount = formula['column_count'] ?? 0;
            final description = formula['description']?.toString() ?? '';
            final iconPath =
                formula['icon_path']?.toString() ?? 'assets/icons/cat.ico';
            final status = formula['status']?.toString() ?? 'active';

            return Card(
              clipBehavior: Clip.hardEdge,
              margin: EdgeInsets.symmetric(vertical: 8),
              elevation: 3,
              child: InkWell(
                splashColor: Colors.blue.withAlpha(30),
                onTap: () async {
                  debugPrint('Formula "$formulaName" tapped.');

                  // 🎯 เพิ่มการปริ้นข้อมูลทุกอย่างใน Formula
                  await _printFormulaData(formulaProvider, formula);

                  // 🚀 นำทางไปยัง ViewDatabase
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewDatabase(formula: formula),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Formula Icon - แสดง icon ที่เลือก
                        Container(
                          width: 60,
                          height: 60,
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.asset(
                              iconPath,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.functions,
                                  size: 30,
                                  color: Colors.blue,
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(width: 16),

                        // Formula info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      formulaName,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade800,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // เพิ่ม hint ว่าแตะเพื่อดูข้อมูล
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.green.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.touch_app,
                                          size: 12,
                                          color: Colors.green.shade700,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'TAP TO VIEW',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.view_column,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '$columnCount columns',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              if (description.isNotEmpty) ...[
                                SizedBox(height: 4),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),

                        // Status indicator และ menu
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    status == 'active'
                                        ? Colors.green
                                        : Colors.grey,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(height: 8),
                            PopupMenuButton<String>(
                              onSelected:
                                  (value) => _handleFormulaAction(
                                    context,
                                    value,
                                    formula,
                                  ),
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.grey[600],
                              ),
                              itemBuilder:
                                  (context) => [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.storage,
                                            size: 16,
                                            color: Colors.blue,
                                          ),
                                          SizedBox(width: 8),
                                          Text('View Database'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'details',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.info,
                                            size: 16,
                                            color: Colors.green,
                                          ),
                                          SizedBox(width: 8),
                                          Text('View Details'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'print',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.print,
                                            size: 16,
                                            color: Colors.orange,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Print Data'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete,
                                            size: 16,
                                            color: Colors.red,
                                          ),
                                          SizedBox(width: 8),
                                          Text('Delete Formula'),
                                        ],
                                      ),
                                    ),
                                  ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // 🎯 ฟังก์ชันปริ้นข้อมูลทุกอย่างใน Formula
  Future<void> _printFormulaData(
    FormulaProvider provider,
    Map<String, dynamic> formula,
  ) async {
    try {
      final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
      final tableName =
          'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';

      debugPrint('🎯 Card tapped: $formulaName');
      debugPrint('=== PRINTING ${formulaName.toUpperCase()} DATA ===');

      // ดึงข้อมูลจาก table
      final tableData = await provider.getTableData(tableName);
      final columns = await provider.getTableColumns(tableName);

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
      debugPrint('❌ Error printing formula data: $e');
    }
  }

  // ฟังก์ชันปริ้นตารางสวยๆ
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

  // แสดงรายละเอียด Formula
  void _showFormulaDetails(BuildContext context, Map<String, dynamic> formula) {
    final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
    final columnCount = formula['column_count'] ?? 0;
    final description = formula['description']?.toString() ?? '';
    final iconPath = formula['icon_path']?.toString() ?? 'assets/icons/cat.ico';
    final columnNames = formula['column_names']?.toString().split('|') ?? [];

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  padding: EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.functions, color: Colors.blue);
                    },
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    formulaName,
                    style: TextStyle(fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty) ...[
                  Text(
                    'Description:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(description),
                  SizedBox(height: 12),
                ],
                Text(
                  'Columns ($columnCount):',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children:
                      columnNames
                          .map(
                            (column) => Chip(
                              label: Text(
                                column,
                                style: TextStyle(fontSize: 12),
                              ),
                              backgroundColor: Colors.blue.shade50,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // นำทางไปยัง ViewDatabase
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ViewDatabase(formula: formula),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: Text('View Database'),
              ),
            ],
          ),
    );
  }

  // จัดการ action menu
  void _handleFormulaAction(
    BuildContext context,
    String action,
    Map<String, dynamic> formula,
  ) {
    final formulaName = formula['formula_name']?.toString() ?? 'Unknown';

    switch (action) {
      case 'view':
        // นำทางไปยัง ViewDatabase
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ViewDatabase(formula: formula),
          ),
        );
        break;
      case 'details':
        _showFormulaDetails(context, formula);
        break;
      case 'print':
        // ปริ้นข้อมูลใน console
        final provider = Provider.of<FormulaProvider>(context, listen: false);
        _printFormulaData(provider, formula);
        _showMessage(context, 'Data printed to console (check debug output)');
        break;
      case 'delete':
        _confirmDeleteFormula(context, formula);
        break;
    }
  }

  // ยืนยันการลบ Formula
  void _confirmDeleteFormula(
    BuildContext context,
    Map<String, dynamic> formula,
  ) {
    final formulaName = formula['formula_name']?.toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete Formula'),
              ],
            ),
            content: Text(
              'Are you sure you want to delete formula "$formulaName"?\n\nThis action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  final provider = Provider.of<FormulaProvider>(
                    context,
                    listen: false,
                  );
                  final success = await provider.deleteFormula(
                    formula['id'] ?? 0,
                    formulaName,
                  );

                  if (success) {
                    _showMessage(
                      context,
                      'Formula "$formulaName" deleted successfully!',
                    );
                  } else {
                    _showMessage(
                      context,
                      'Failed to delete formula: ${provider.lastError}',
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  // แสดงข้อความ
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue.shade700,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showIconDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 400,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              minHeight: 300,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  child: const Text(
                    'Choose Animal Icon',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Animals Category
                        const Text(
                          'Animals',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Animal icons from your .ico files
                        GridView.count(
                          crossAxisCount: 4,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.0,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                          children: [
                            _buildAnimalIcon('assets/icons/cat.ico', 'Cat'),
                            _buildAnimalIcon('assets/icons/dog.ico', 'Dog'),
                            _buildAnimalIcon('assets/icons/cow.ico', 'Cow'),
                            _buildAnimalIcon('assets/icons/horse.ico', 'Horse'),
                            _buildAnimalIcon('assets/icons/lion.ico', 'Lion'),
                            _buildAnimalIcon('assets/icons/tiger.ico', 'Tiger'),
                            _buildAnimalIcon(
                              'assets/icons/buffalo.ico',
                              'Buffalo',
                            ),
                            _buildAnimalIcon(
                              'assets/icons/chicken.ico',
                              'Chicken',
                            ),
                            _buildAnimalIcon('assets/icons/fish.ico', 'Fish'),
                            _buildAnimalIcon(
                              'assets/icons/giraffe.ico',
                              'Giraffe',
                            ),
                            _buildAnimalIcon('assets/icons/goat.ico', 'Goat'),
                            _buildAnimalIcon(
                              'assets/icons/monkey.ico',
                              'Monkey',
                            ),
                            _buildAnimalIcon(
                              'assets/icons/shrimp.ico',
                              'Shrimp',
                            ),
                            _buildAnimalIcon('assets/icons/zebra.ico', 'Zebra'),
                            _buildAnimalIcon(
                              'assets/icons/pawprint.ico',
                              'Paw',
                            ),
                            _buildAnimalIcon('assets/icons/1998617.ico', '1'),
                            _buildAnimalIcon('assets/icons/1998620.ico', '2'),
                            _buildAnimalIcon('assets/icons/1998642.ico', '3'),
                            _buildAnimalIcon('assets/icons/1998728.ico', '4'),
                            _buildAnimalIcon('assets/icons/1998773.ico', '5'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper function for animal icons (using .ico files) - ปรับปรุงแล้ว
  Widget _buildAnimalIcon(String iconPath, String label) {
    return GestureDetector(
      onTap: () {
        debugPrint('$label animal icon selected: $iconPath');
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    iconPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.pets,
                        size: 35,
                        color: Colors.grey,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
