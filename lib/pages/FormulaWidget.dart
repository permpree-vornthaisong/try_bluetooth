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
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF2D3E50),
                    ),
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
                // Debug info card
                // Card(
                //   elevation: 2,
                //   child: Container(
                //     padding: EdgeInsets.all(12),
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(8),
                //       color: const Color(0xFF7FB8C4).withOpacity(0.3),
                //     ),
                //     child: Row(
                //       children: [
                //         Icon(
                //           Icons.info_outline,
                //           color: const Color(0xFF2D3E50),
                //           size: 20,
                //         ),
                //         SizedBox(width: 8),
                //         Text(
                //           'Debug: จำนวน Formulas = ${provider.formulas.length}',
                //           style: TextStyle(
                //             fontSize: 12,
                //             fontWeight: FontWeight.bold,
                //             color: const Color(0xFF2D3E50),
                //           ),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
                SizedBox(height: 8),

                // Print All Tables Button Card
                // Card(
                //   elevation: 2,
                //   child: InkWell(
                //     onTap: () async {
                //       final provider = Provider.of<FormulaProvider>(
                //         context,
                //         listen: false,
                //       );
                //       await provider.printAllTables();
                //     },
                //     borderRadius: BorderRadius.circular(8),
                //     child: Container(
                //       padding: EdgeInsets.all(16),
                //       decoration: BoxDecoration(
                //         borderRadius: BorderRadius.circular(8),
                //         color: const Color(0xFF2D3E50),
                //       ),
                //       child: Row(
                //         children: [
                //           Icon(
                //             Icons.print,
                //             color: Colors.white,
                //             size: 24,
                //           ),
                //           SizedBox(width: 12),
                //           Text(
                //             'Print All Tables',
                //             style: TextStyle(
                //               color: Colors.white,
                //               fontSize: 16,
                //               fontWeight: FontWeight.w600,
                //             ),
                //           ),
                //           Spacer(),
                //           Icon(
                //             Icons.arrow_forward_ios,
                //             color: Colors.white,
                //             size: 16,
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
                // ),
                SizedBox(height: 16),

                // Main action cards
                Expanded(
                  flex: 3,
                  child:
                      provider.formulas.isEmpty
                          ? _buildEmptyFormulaCards(provider)
                          : _buildFormulaCards(provider),
                ),

                SizedBox(height: 16),

                // Database info card
                // Card(
                //   elevation: 4,
                //   child: Container(
                //     padding: EdgeInsets.all(20),
                //     decoration: BoxDecoration(
                //       borderRadius: BorderRadius.circular(8),
                //       gradient: LinearGradient(
                //         colors: [
                //           const Color(0xFF7FB8C4).withOpacity(0.3),
                //           const Color(0xFF7FB8C4).withOpacity(0.5),
                //         ],
                //         begin: Alignment.topLeft,
                //         end: Alignment.bottomRight,
                //       ),
                //     ),
                //     child: Row(
                //       children: [
                //         Icon(
                //           Icons.storage,
                //           size: 32,
                //           color: const Color(0xFF2D3E50),
                //         ),
                //         SizedBox(width: 16),
                //         Expanded(
                //           child: Column(
                //             crossAxisAlignment: CrossAxisAlignment.start,
                //             mainAxisAlignment: MainAxisAlignment.center,
                //             children: [
                //               Text(
                //                 'Formula Database',
                //                 style: TextStyle(
                //                   fontSize: 18,
                //                   fontWeight: FontWeight.bold,
                //                   color: const Color(0xFF2D3E50),
                //                 ),
                //               ),
                //               Text(
                //                 'จำนวน: ${provider.formulas.length} formulas',
                //                 style: TextStyle(
                //                   color: const Color(0xFF2D3E50),
                //                 ),
                //               ),
                //               Text(
                //                 'Tables: ${provider.databaseTables.length} tables',
                //                 style: TextStyle(
                //                   color: const Color(0xFF2D3E50),
                //                 ),
                //               ),
                //             ],
                //           ),
                //         ),
                //         ElevatedButton(
                //           onPressed: () => _showDatabaseViewer(provider),
                //           style: ElevatedButton.styleFrom(
                //             backgroundColor: const Color(0xFF2D3E50),
                //             foregroundColor: Colors.white,
                //           ),
                //           child: Text('ส่งออก Excel'),
                //         ),
                //       ],
                //     ),
                //   ),
                // ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyFormulaCards(FormulaProvider provider) {
    return ListView(
      children: [
        // สร้าง Formula Card
        Card(
          elevation: 4,
          child: InkWell(
            onTap: () => _showCreateFormulaDialog(provider),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF5A9B9E),
                    const Color(0xFF5A9B9E).withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.add_circle,
                      size: 28,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'สร้าง Formula ใหม่',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'เริ่มต้นสร้างสูตรคำนวณของคุณ',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),

        // รีเฟรช Card
        Card(
          elevation: 2,
          child: InkWell(
            onTap: () => provider.refreshFormulas(),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF2D3E50),
              ),
              child: Row(
                children: [
                  Icon(Icons.refresh, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'รีเฟรช',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'อัพเดทข้อมูล Formula',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),

        // ดู Database Card
        Card(
          elevation: 2,
          child: InkWell(
            onTap: () => _showDatabaseViewer(provider),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF7FB8C4),
              ),
              child: Row(
                children: [
                  Icon(Icons.storage, color: Colors.white, size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ดู Database',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'จัดการข้อมูลทั้งหมด',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 12),

        // Empty state card
        Card(
          elevation: 1,
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                SizedBox(height: 12),
                Text(
                  'ไม่มี Formula',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'กดปุ่มด้านบนเพื่อสร้าง Formula แรกของคุณ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormulaCards(FormulaProvider provider) {
    return ListView.builder(
      itemCount: provider.formulas.length + 1, // +1 สำหรับปุ่ม Add
      itemBuilder: (context, index) {
        // ปุ่มแรกเป็นปุ่ม Add Formula
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 4,
              child: InkWell(
                onTap: () => _showCreateFormulaDialog(provider),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF5A9B9E),
                        const Color(0xFF5A9B9E).withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.add_circle,
                          size: 28,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สร้าง Formula ใหม่',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'เพิ่มสูตรคำนวณใหม่',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Formula cards
        final formula = provider.formulas[index - 1];
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: _buildFormulaCard(
            formula: formula,
            onTap: () => _navigateToFormulaData(formula),
          ),
        );
      },
    );
  }

  Widget _buildFormulaCard({
    required Map<String, dynamic> formula,
    required VoidCallback onTap,
  }) {
    final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
    final columnCount = formula['column_count'] ?? 0;
    final description = formula['description']?.toString() ?? '';

    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2D3E50),
                const Color(0xFF2D3E50).withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.table_chart, size: 28, color: Colors.white),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formulaName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5A9B9E).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '$columnCount คอลัมน์',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              description,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
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
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setState) => AlertDialog(
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
                                borderSide: BorderSide(
                                  color: const Color(0xFF5A9B9E),
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.title,
                                color: const Color(0xFF5A9B9E),
                              ),
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
                                borderSide: BorderSide(
                                  color: const Color(0xFF5A9B9E),
                                ),
                              ),
                              prefixIcon: Icon(
                                Icons.description,
                                color: const Color(0xFF5A9B9E),
                              ),
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: 16),

                          // Column count
                          Row(
                            children: [
                              Icon(
                                Icons.view_column,
                                color: const Color(0xFF2D3E50),
                              ),
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
                                items:
                                    List.generate(10, (index) => index + 1)
                                        .map(
                                          (count) => DropdownMenuItem(
                                            value: count,
                                            child: Text(
                                              '$count column${count > 1 ? 's' : ''}',
                                              style: TextStyle(
                                                color: const Color(0xFF2D3E50),
                                              ),
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
                                    borderSide: BorderSide(
                                      color: const Color(0xFF5A9B9E),
                                    ),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.label_outline,
                                    color: const Color(0xFF5A9B9E),
                                  ),
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
      final columnNames =
          columnControllers
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

class FormulaDetailsPage extends StatefulWidget {
  final Map<String, dynamic> formula;

  const FormulaDetailsPage({Key? key, required this.formula}) : super(key: key);

  @override
  State<FormulaDetailsPage> createState() => _FormulaDetailsPageState();
}

class _FormulaDetailsPageState extends State<FormulaDetailsPage> {
  List<Map<String, dynamic>> _tableData = [];
  List<String> _tableColumns = [];
  bool _isLoading = true;
  String _tableName = '';

  @override
  void initState() {
    super.initState();
    _tableName =
        'formula_${widget.formula['formula_name']?.toString().toLowerCase().replaceAll(' ', '_') ?? 'unknown'}';
    _loadTableData();
  }

  Future<void> _loadTableData() async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);

    try {
      setState(() => _isLoading = true);

      // ตรวจสอบว่า table มีอยู่หรือไม่
      final tableExists = await provider.tableExists(_tableName);
      if (!tableExists) {
        setState(() {
          _isLoading = false;
          _tableData = [];
          _tableColumns = [];
        });
        return;
      }

      // โหลดข้อมูลและ columns
      final data = await provider.getTableData(_tableName);
      final columns = await provider.getTableColumns(_tableName);

      setState(() {
        _tableData = data;
        _tableColumns = columns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('ไม่สามารถโหลดข้อมูลได้: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final formulaName =
        widget.formula['formula_name']?.toString() ?? 'Unknown Formula';
    final columnCount = widget.formula['column_count'] ?? 0;
    final description = widget.formula['description']?.toString() ?? '';
    final columnNames =
        widget.formula['column_names']?.toString().split('|') ?? [];

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
          '📊 $formulaName',
          style: TextStyle(color: const Color(0xFF2D3E50)),
        ),
        backgroundColor: const Color(0xFF7FB8C4),
        iconTheme: IconThemeData(color: const Color(0xFF2D3E50)),
        actions: [
          IconButton(
            onPressed: () => _addNewRecord(),
            icon: Icon(Icons.add),
            tooltip: 'เพิ่มข้อมูล',
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(
                          Icons.refresh,
                          size: 16,
                          color: const Color(0xFF2D3E50),
                        ),
                        SizedBox(width: 8),
                        Text('รีเฟรช'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(
                          Icons.file_download,
                          size: 16,
                          color: const Color(0xFF5A9B9E),
                        ),
                        SizedBox(width: 8),
                        Text('ส่งออก Excel'),
                      ],
                    ),
                  ),
                  if (_tableData.isNotEmpty)
                    PopupMenuItem(
                      value: 'deleteAll',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_sweep,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'ลบข้อมูลทั้งหมด',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'deleteFormula',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, size: 16, color: Colors.red),
                        SizedBox(width: 8),
                        Text('ลบ Formula', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: const Color(0xFF2D3E50)),
                    SizedBox(height: 16),
                    Text(
                      'กำลังโหลดข้อมูล...',
                      style: TextStyle(color: const Color(0xFF2D3E50)),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formula Info Card
                    Card(
                      elevation: 4,
                      child: Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF7FB8C4).withOpacity(0.3),
                              const Color(0xFF7FB8C4).withOpacity(0.5),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2D3E50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.table_chart,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    formulaName,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF2D3E50),
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildInfoChip(
                                        Icons.view_column,
                                        '$columnCount คอลัมน์',
                                      ),
                                      SizedBox(width: 8),
                                      _buildInfoChip(
                                        Icons.storage,
                                        '${_tableData.length} รายการ',
                                      ),
                                    ],
                                  ),
                                  if (description.isNotEmpty) ...[
                                    SizedBox(height: 8),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: const Color(
                                          0xFF2D3E50,
                                        ).withOpacity(0.7),
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: 8),
                                  Text(
                                    'Columns: ${columnNames.join(", ")}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(
                                        0xFF2D3E50,
                                      ).withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Data Table Section
                    Text(
                      'ข้อมูลใน Formula',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF2D3E50),
                      ),
                    ),
                    SizedBox(height: 12),

                    Expanded(
                      child:
                          _tableData.isEmpty
                              ? _buildEmptyState()
                              : _buildDataTable(),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D3E50).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2D3E50)),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3E50),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.table_chart,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          SizedBox(height: 24),
          Text(
            'ยังไม่มีข้อมูล',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'เริ่มต้นด้วยการเพิ่มข้อมูลแรกของคุณ',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _addNewRecord(),
            icon: Icon(Icons.add),
            label: Text('เพิ่มข้อมูล'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5A9B9E),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable() {
    return Card(
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                children: [
                  Icon(Icons.table_rows, color: Colors.grey.shade600),
                  SizedBox(width: 8),
                  Text(
                    'ข้อมูลทั้งหมด (${_tableData.length} รายการ)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),

            // Table content
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      const Color(0xFF7FB8C4).withOpacity(0.3),
                    ),
                    headingTextStyle: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3E50),
                    ),
                    columns: [
                      ..._tableColumns.map(
                        (column) => DataColumn(label: Text(column)),
                      ),
                      DataColumn(label: Text('การดำเนินการ')),
                    ],
                    rows:
                        _tableData.map((row) {
                          return DataRow(
                            cells: [
                              ..._tableColumns.map(
                                (column) => DataCell(
                                  Container(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      row[column]?.toString() ?? '',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit,
                                        size: 18,
                                        color: const Color(0xFF5A9B9E),
                                      ),
                                      onPressed: () => _editRecord(row),
                                      tooltip: 'แก้ไข',
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _confirmDeleteRecord(row),
                                      tooltip: 'ลบ',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CRUD Operations
  void _addNewRecord() async {
    final columnNames =
        widget.formula['column_names']?.toString().split('|') ?? [];
    final controllers = <String, TextEditingController>{};

    for (final column in columnNames) {
      controllers[column] = TextEditingController();
    }

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.add_circle, color: const Color(0xFF5A9B9E)),
                SizedBox(width: 8),
                Text('เพิ่มข้อมูลใหม่'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    controllers.entries
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: entry.key,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: const Color(0xFF5A9B9E),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A9B9E),
                ),
                child: Text('เพิ่มข้อมูล'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _saveNewRecord(controllers);
    }

    controllers.values.forEach((controller) => controller.dispose());
  }

  Future<void> _saveNewRecord(
    Map<String, TextEditingController> controllers,
  ) async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);

    try {
      final recordData = <String, dynamic>{};

      controllers.forEach((column, controller) {
        final columnKey = column.toLowerCase().replaceAll(' ', '_');
        recordData[columnKey] = controller.text.trim();
      });

      final success = await provider.createRecord(
        tableName: _tableName,
        data: recordData,
      );

      if (success) {
        _showMessage('✅ เพิ่มข้อมูลสำเร็จ!');
        await _loadTableData();
      } else {
        _showMessage('❌ ไม่สามารถเพิ่มข้อมูลได้');
      }
    } catch (e) {
      _showMessage('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  void _editRecord(Map<String, dynamic> record) async {
    final columnNames =
        widget.formula['column_names']?.toString().split('|') ?? [];
    final controllers = <String, TextEditingController>{};

    for (final column in columnNames) {
      final columnKey = column.toLowerCase().replaceAll(' ', '_');
      controllers[column] = TextEditingController(
        text: record[columnKey]?.toString() ?? '',
      );
    }

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.edit, color: const Color(0xFF5A9B9E)),
                SizedBox(width: 8),
                Text('แก้ไขข้อมูล'),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    controllers.entries
                        .map(
                          (entry) => Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: TextField(
                              controller: entry.value,
                              decoration: InputDecoration(
                                labelText: entry.key,
                                border: OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: const Color(0xFF5A9B9E),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5A9B9E),
                ),
                child: Text('บันทึก'),
              ),
            ],
          ),
    );

    if (result == true) {
      await _saveEditRecord(record, controllers);
    }

    controllers.values.forEach((controller) => controller.dispose());
  }

  Future<void> _saveEditRecord(
    Map<String, dynamic> record,
    Map<String, TextEditingController> controllers,
  ) async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);
    final recordId = record['id'];

    try {
      final recordData = <String, dynamic>{};

      controllers.forEach((column, controller) {
        final columnKey = column.toLowerCase().replaceAll(' ', '_');
        recordData[columnKey] = controller.text.trim();
      });

      final success = await provider.updateRecord(
        tableName: _tableName,
        recordId: recordId,
        data: recordData,
      );

      if (success) {
        _showMessage('✅ แก้ไขข้อมูลสำเร็จ!');
        await _loadTableData();
      } else {
        _showMessage('❌ ไม่สามารถแก้ไขข้อมูลได้');
      }
    } catch (e) {
      _showMessage('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  Future<void> _confirmDeleteRecord(Map<String, dynamic> record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('ยืนยันการลบ'),
              ],
            ),
            content: Text('คุณแน่ใจหรือไม่ที่จะลบข้อมูลนี้?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('ลบ'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteRecord(record);
    }
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);
    final recordId = record['id'];

    try {
      final success = await provider.deleteRecord(
        tableName: _tableName,
        recordId: recordId,
      );

      if (success) {
        _showMessage('✅ ลบข้อมูลสำเร็จ!');
        await _loadTableData();
      } else {
        _showMessage('❌ ไม่สามารถลบข้อมูลได้');
      }
    } catch (e) {
      _showMessage('❌ เกิดข้อผิดพลาด: $e');
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _loadTableData();
        break;
      case 'export':
        _showMessage('ส่งออก Excel (ฟีเจอร์นี้จะพัฒนาต่อ)');
        break;
      case 'deleteAll':
        _confirmDeleteAllRecords();
        break;
      case 'deleteFormula':
        _confirmDeleteFormula();
        break;
    }
  }

  Future<void> _confirmDeleteAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('ยืนยันการลบข้อมูลทั้งหมด'),
              ],
            ),
            content: Text(
              'คุณแน่ใจหรือไม่ที่จะลบข้อมูลทั้งหมด ${_tableData.length} รายการ?\n\nการดำเนินการนี้ไม่สามารถย้อนกลับได้!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('ลบทั้งหมด'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      try {
        final success = await provider.deleteAllRecords(_tableName);
        if (success) {
          _showMessage('✅ ลบข้อมูลทั้งหมดสำเร็จ!');
          await _loadTableData();
        } else {
          _showMessage('❌ ไม่สามารถลบข้อมูลทั้งหมดได้');
        }
      } catch (e) {
        _showMessage('❌ เกิดข้อผิดพลาด: $e');
      }
    }
  }

  Future<void> _confirmDeleteFormula() async {
    final formulaName = widget.formula['formula_name']?.toString() ?? 'Unknown';

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.dangerous, color: Colors.red),
                SizedBox(width: 8),
                Text('ยืนยันการลบ Formula'),
              ],
            ),
            content: Text(
              'คุณแน่ใจหรือไม่ที่จะลบ Formula "$formulaName" ทั้งหมด?\n\nการดำเนินการนี้จะลบทั้ง Formula และข้อมูลทั้งหมด และไม่สามารถย้อนกลับได้!',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('ลบ Formula'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      try {
        final success = await provider.deleteFormula(
          widget.formula['id'] ?? 0,
          formulaName,
        );
        if (success) {
          _showMessage('✅ ลบ Formula สำเร็จ!');
          Navigator.pop(context); // กลับไปหน้าแรก
        } else {
          _showMessage('❌ ไม่สามารถลบ Formula ได้');
        }
      } catch (e) {
        _showMessage('❌ เกิดข้อผิดพลาด: $e');
      }
    }
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

class DatabaseViewerPage extends StatefulWidget {
  @override
  State<DatabaseViewerPage> createState() => _DatabaseViewerPageState();
}

class _DatabaseViewerPageState extends State<DatabaseViewerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Text(
          '🗃️ Database Viewer',
          style: TextStyle(color: const Color(0xFF2D3E50)),
        ),
        backgroundColor: const Color(0xFF7FB8C4),
        iconTheme: IconThemeData(color: const Color(0xFF2D3E50)),
        actions: [
          IconButton(
            onPressed: () => _refreshTables(),
            icon: Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ),
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: const Color(0xFF2D3E50)),
                  SizedBox(height: 16),
                  Text(
                    'กำลังโหลดข้อมูล Database...',
                    style: TextStyle(color: const Color(0xFF2D3E50)),
                  ),
                ],
              ),
            );
          }

          if (provider.databaseTables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.storage,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    'ไม่มี Tables ใน Database',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'สร้าง Formula เพื่อเริ่มต้นใช้งาน',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                  ),
                  SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.add),
                    label: Text('กลับไปสร้าง Formula'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5A9B9E),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Card(
                  elevation: 4,
                  child: Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF7FB8C4).withOpacity(0.3),
                          const Color(0xFF7FB8C4).withOpacity(0.5),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2D3E50),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.storage,
                            size: 32,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Database Overview',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFF2D3E50),
                                ),
                              ),
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildInfoChip(
                                    Icons.table_chart,
                                    '${provider.databaseTables.length} Tables',
                                  ),
                                  SizedBox(width: 8),
                                  _buildInfoChip(
                                    Icons.functions,
                                    '${provider.formulas.length} Formulas',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // Tables List Header
                Text(
                  'Tables ทั้งหมด',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2D3E50),
                  ),
                ),
                SizedBox(height: 12),

                // Tables List - แสดงเป็น Card แบบ List
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.databaseTables.length,
                    itemBuilder: (context, index) {
                      final table = provider.databaseTables[index];
                      final tableName = table['table_name'] as String;
                      final isFormulaTable = table['is_formula_table'] as bool;
                      final recordCount = table['record_count'] as int;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: Card(
                          elevation: 2,
                          child: InkWell(
                            onTap: () => _viewTableData(tableName, provider),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Icon
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          isFormulaTable
                                              ? const Color(0xFF5A9B9E)
                                              : const Color(0xFF2D3E50),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      isFormulaTable
                                          ? Icons.functions
                                          : Icons.table_chart,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),

                                  // Content
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                tableName,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(
                                                    0xFF2D3E50,
                                                  ),
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                            if (isFormulaTable)
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF5A9B9E,
                                                  ).withOpacity(0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  'Formula',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: const Color(
                                                      0xFF5A9B9E,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          '$recordCount records',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Menu Button
                                  PopupMenuButton<String>(
                                    onSelected:
                                        (value) => _handleTableAction(
                                          value,
                                          tableName,
                                          provider,
                                        ),
                                    icon: Icon(
                                      Icons.more_vert,
                                      color: Colors.grey.shade600,
                                    ),
                                    itemBuilder:
                                        (context) => [
                                          PopupMenuItem(
                                            value: 'view',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.visibility,
                                                  size: 16,
                                                  color: const Color(
                                                    0xFF2D3E50,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text('ดูข้อมูล'),
                                              ],
                                            ),
                                          ),
                                          PopupMenuItem(
                                            value: 'export',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.file_download,
                                                  size: 16,
                                                  color: const Color(
                                                    0xFF5A9B9E,
                                                  ),
                                                ),
                                                SizedBox(width: 8),
                                                Text('ส่งออก'),
                                              ],
                                            ),
                                          ),
                                          if (recordCount > 0)
                                            PopupMenuItem(
                                              value: 'clear',
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.clear_all,
                                                    size: 16,
                                                    color: Colors.orange,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Text(
                                                    'ล้างข้อมูล',
                                                    style: TextStyle(
                                                      color: Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
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
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D3E50).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF2D3E50)),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF2D3E50),
            ),
          ),
        ],
      ),
    );
  }

  void _refreshTables() async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);
    await provider.refreshFormulas();
    _showMessage('รีเฟรชข้อมูลเรียบร้อย');
  }

  void _handleTableAction(
    String action,
    String tableName,
    FormulaProvider provider,
  ) {
    switch (action) {
      case 'view':
        _viewTableData(tableName, provider);
        break;
      case 'export':
        _exportTable(tableName);
        break;
      case 'clear':
        _confirmClearTable(tableName, provider);
        break;
    }
  }

  void _viewTableData(String tableName, FormulaProvider provider) async {
    try {
      // ดึงข้อมูลจาก table
      final data = await provider.getTableData(tableName);
      final columns = await provider.getTableColumns(tableName);

      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.table_chart, color: const Color(0xFF2D3E50)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tableName,
                      style: TextStyle(color: const Color(0xFF2D3E50)),
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                height: 400,
                child:
                    data.isEmpty
                        ? Center(
                          child: Text(
                            'ไม่มีข้อมูลใน Table นี้',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                        : SingleChildScrollView(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(
                                const Color(0xFF7FB8C4).withOpacity(0.3),
                              ),
                              columns:
                                  columns
                                      .map(
                                        (col) => DataColumn(label: Text(col)),
                                      )
                                      .toList(),
                              rows:
                                  data
                                      .take(50) // แสดงแค่ 50 records แรก
                                      .map(
                                        (row) => DataRow(
                                          cells:
                                              columns
                                                  .map(
                                                    (col) => DataCell(
                                                      Text(
                                                        row[col]?.toString() ??
                                                            '',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                  .toList(),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                        ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ปิด'),
                ),
              ],
            ),
      );
    } catch (e) {
      _showMessage('ไม่สามารถโหลดข้อมูลได้: $e');
    }
  }

  void _exportTable(String tableName) {
    _showMessage('ส่งออก $tableName (ฟีเจอร์นี้จะพัฒนาต่อ)');
  }

  void _confirmClearTable(String tableName, FormulaProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('ยืนยันการล้างข้อมูล'),
              ],
            ),
            content: Text(
              'คุณแน่ใจหรือไม่ที่จะล้างข้อมูลทั้งหมดใน table "$tableName"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                child: Text('ล้างข้อมูล'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        final success = await provider.deleteAllRecords(tableName);
        if (success) {
          _showMessage('ล้างข้อมูลใน $tableName เรียบร้อย');
          await provider.refreshFormulas(); // รีเฟรชข้อมูล
        } else {
          _showMessage('ไม่สามารถล้างข้อมูลได้');
        }
      } catch (e) {
        _showMessage('เกิดข้อผิดพลาด: $e');
      }
    }
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
