import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';
import 'package:try_bluetooth/providers/GenericCRUDProvider.dart';

class FormulaWidget extends StatefulWidget {
  @override
  State<FormulaWidget> createState() => _FormulaWidgetState();
}

class _FormulaWidgetState extends State<FormulaWidget> {
  @override
  void initState() {
    super.initState();

    print("536987");

    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      provider.initialize(context).then((_) {
        // หลังจาก initialize เสร็จแล้ว ค่อยเรียก getFormulaTableNames
        print("✅ FormulaProvider initialized");
        final formulaTableNames = provider.getFormulaTableNames();
        print("📝 Formula table names: $formulaTableNames");
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200, // เป็นเหมือนพื้นหลังในรูป
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (!provider.isInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: const Color(0xFF2D3E50)),
                  SizedBox(height: 16),
                  Text(
                    'กำลังเตรียม Formula Database...',
                    style: TextStyle(fontSize: 16, color: const Color(0xFF2D3E50)),
                  ),
                ],
              ),
            );
          }

          // Error state
          if (provider.lastError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text(
                    'เกิดข้อผิดพลาด: ${provider.lastError}',
                    style: TextStyle(color: Colors.red),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.retryInitialization(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D3E50),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('ลองใหม่'),
                  ),
                ],
              ),
            );
          }

          // Main content
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Debug info - แสดงจำนวน formulas
                Card(
                  color: const Color(0xFF7FB8C4).withOpacity(0.3), // สีฟ้าอ่อนเหมือนในรูป
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'Debug: จำนวน Formulas = ${provider.formulas.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3E50),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8),
                
                // Print All Tables Button
                ElevatedButton(
                  onPressed: () async {
                    final provider = Provider.of<FormulaProvider>(
                      context,
                      listen: false,
                    );
                    await provider.printAllTables(); // ดูใน Debug Console
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3E50), // สีเข้มเหมือนในรูป
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Print All Tables'),
                ),
                
                SizedBox(height: 16),
                
                // Main buttons - แสดง formulas ที่สร้างไว้ + ปุ่ม Add
                Expanded(
                  flex: 3,
                  child: provider.formulas.isEmpty
                      ? _buildEmptyFormulaGrid(provider) // ถ้าไม่มี formulas
                      : GridView.builder(
                          // ถ้ามี formulas
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 1.0,
                          ),
                          itemCount: provider.formulas.length + 1, // +1 สำหรับปุ่ม Add
                          itemBuilder: (context, index) {
                            // ปุ่มสุดท้ายเป็นปุ่ม Add
                            if (index == provider.formulas.length) {
                              return _buildMainButton(
                                title: '',
                                icon: Icons.add,
                                color: const Color(0xFF5A9B9E), // สีเขียวอมฟ้าเหมือนในรูป
                                iconSize: 48,
                                onTap: () => _showCreateFormulaDialog(provider),
                              );
                            }

                            // ปุ่มสำหรับ formula ที่สร้างไว้
                            final formula = provider.formulas[index];
                            return _buildFormulaButton(
                              formula: formula,
                              onTap: () => _navigateToFormulaData(formula),
                            );
                          },
                        ),
                ),

                SizedBox(height: 16),

                // Database info card
                Expanded(
                  flex: 1,
                  child: Card(
                    elevation: 4,
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF7FB8C4).withOpacity(0.3),
                            const Color(0xFF7FB8C4).withOpacity(0.5),
                          ], // สีฟ้าอ่อนเหมือนในรูป
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.storage, size: 32, color: const Color(0xFF2D3E50)),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Formula Database',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF2D3E50),
                                  ),
                                ),
                                Text(
                                  'จำนวน: ${provider.formulas.length} formulas',
                                  style: TextStyle(color: const Color(0xFF2D3E50)),
                                ),
                                Text(
                                  'Tables: ${provider.databaseTables.length} tables',
                                  style: TextStyle(color: const Color(0xFF2D3E50)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showDatabaseViewer(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2D3E50),
                              foregroundColor: Colors.white,
                            ),
                            child: Text('ส่งออก Excel'),
                          ),
                        ],
                      ),
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

  Widget _buildEmptyFormulaGrid(FormulaProvider provider) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.0,
      children: [
        // ปุ่ม + สำหรับสร้าง formula ใหม่
        _buildMainButton(
          title: 'สร้าง Formula',
          icon: Icons.add,
          color: const Color(0xFF5A9B9E), // สีเขียวอมฟ้าเหมือนในรูป
          iconSize: 32,
          onTap: () => _showCreateFormulaDialog(provider),
        ),

        // ปุ่ม Refresh
        _buildMainButton(
          title: 'รีเฟรช',
          icon: Icons.refresh,
          color: const Color(0xFF2D3E50), // สีเข้มเหมือนในรูป
          iconSize: 32,
          onTap: () => provider.refreshFormulas(),
        ),

        // ปุ่ม Database Viewer
        _buildMainButton(
          title: 'ดู Database',
          icon: Icons.storage,
          color: const Color(0xFF7FB8C4), // สีฟ้าอ่อนเหมือนในรูป
          iconSize: 32,
          onTap: () => _showDatabaseViewer(provider),
        ),

        // ปุ่มว่าง
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 2),
            color: Colors.grey.shade100,
          ),
          child: Center(
            child: Text(
              'ไม่มี Formula\nกดปุ่ม + เพื่อสร้าง',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaButton({
    required Map<String, dynamic> formula,
    required VoidCallback onTap,
  }) {
    final formulaName = formula.formulaName;
    final columnCount = formula.columnCount;

    return Card(
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2D3E50), // สีเข้มเหมือนในรูป
                const Color(0xFF2D3E50).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.table_chart, size: 32, color: Colors.white),
                SizedBox(height: 8),
                Text(
                  formulaName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4),
                Text(
                  '$columnCount คอลัมน์',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double iconSize = 32,
  }) {
    return Card(
      elevation: 8,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: color, // ใช้สีเดียวแทน gradient
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: iconSize, color: Colors.white),
              if (title.isNotEmpty) ...[
                SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========== NAVIGATION METHODS ==========

  void _navigateToFormulaData(Map<String, dynamic> formula) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaDetailsPage(formula: formula),
      ),
    );
  }

  void _navigateToFormulaList(FormulaProvider provider, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDataPage(category: category),
      ),
    );
  }

  void _showDatabaseViewer(FormulaProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DatabaseViewerPage()),
    );
  }

  // ========== DIALOG METHODS ==========

  Future<void> _showCreateFormulaDialog(FormulaProvider provider) async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    int columnCount = 3;
    List<TextEditingController> columnControllers = [];

    // Initialize column controllers
    for (int i = 0; i < 10; i++) {
      columnControllers.add(TextEditingController());
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.add_circle, color: const Color(0xFF5A9B9E)),
              SizedBox(width: 8),
              Text(
                'สร้าง Formula ใหม่',
                style: TextStyle(color: const Color(0xFF2D3E50)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Container(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Formula name
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ Formula *',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF5A9B9E)),
                      ),
                      prefixIcon: Icon(Icons.title, color: const Color(0xFF5A9B9E)),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Description
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(
                      labelText: 'คำอธิบาย',
                      border: OutlineInputBorder(),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: const Color(0xFF5A9B9E)),
                      ),
                      prefixIcon: Icon(Icons.description, color: const Color(0xFF5A9B9E)),
                    ),
                    maxLines: 2,
                  ),
                  SizedBox(height: 16),

                  // Column count
                  Row(
                    children: [
                      Icon(Icons.view_column, color: const Color(0xFF2D3E50)),
                      SizedBox(width: 8),
                      Text(
                        'จำนวน Column:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF2D3E50),
                        ),
                      ),
                      SizedBox(width: 16),
                      DropdownButton<int>(
                        value: columnCount,
                        dropdownColor: Colors.white,
                        items: List.generate(10, (index) => index + 1)
                            .map(
                              (count) => DropdownMenuItem(
                                value: count,
                                child: Text(
                                  '$count column${count > 1 ? 's' : ''}',
                                  style: TextStyle(color: const Color(0xFF2D3E50)),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            columnCount = value!;
                          });
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  // Column names
                  Text(
                    'ชื่อ Columns:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3E50),
                    ),
                  ),
                  SizedBox(height: 8),
                  ...List.generate(
                    columnCount,
                    (index) => Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: columnControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Column ${index + 1} *',
                          border: OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: const Color(0xFF5A9B9E)),
                          ),
                          prefixIcon: Icon(Icons.label_outline, color: const Color(0xFF5A9B9E)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                // Validation
                if (nameController.text.trim().isEmpty) {
                  _showMessage('กรุณาใส่ชื่อ Formula');
                  return;
                }

                bool hasEmptyColumn = false;
                for (int i = 0; i < columnCount; i++) {
                  if (columnControllers[i].text.trim().isEmpty) {
                    hasEmptyColumn = true;
                    break;
                  }
                }

                if (hasEmptyColumn) {
                  _showMessage('กรุณาใส่ชื่อ Column ให้ครบทุกช่อง');
                  return;
                }

                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A9B9E),
                foregroundColor: Colors.white,
              ),
              child: Text('สร้าง Formula'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final columnNames = columnControllers
          .take(columnCount)
          .map((controller) => controller.text.trim())
          .toList();

      final success = await provider.createFormula(
        formulaName: nameController.text.trim(),
        columnCount: columnCount,
        columnNames: columnNames,
        description: descriptionController.text.trim(),
      );

      if (success) {
        _showMessage('✅ Formula สร้างสำเร็จแล้ว!');
        // รีเฟรชข้อมูลทันทีหลังสร้าง formula สำเร็จ
        await provider.refreshFormulas();
      } else {
        _showMessage('❌ ไม่สามารถสร้าง Formula ได้: ${provider.lastError}');
      }
    }

    // Dispose controllers
    for (final controller in columnControllers) {
      controller.dispose();
    }
    nameController.dispose();
    descriptionController.dispose();
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2D3E50),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}

// เพิ่ม placeholder classes เพื่อไม่ให้ error
class CategoryDataPage extends StatelessWidget {
  final String category;
  const CategoryDataPage({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(category)),
      body: Center(child: Text('Category Data Page for $category')),
    );
  }
}

class FormulaDetailsPage extends StatelessWidget {
  final Map<String, dynamic> formula;
  const FormulaDetailsPage({Key? key, required this.formula}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Formula Details')),
      body: Center(child: Text('Formula Details Page')),
    );
  }
}

class DatabaseViewerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Database Viewer')),
      body: Center(child: Text('Database Viewer Page')),
    );
  }
}