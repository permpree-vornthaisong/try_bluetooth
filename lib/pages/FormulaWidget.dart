import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';

class FormulaWidget extends StatefulWidget {
  @override
  State<FormulaWidget> createState() => _FormulaWidgetState();
}

class _FormulaWidgetState extends State<FormulaWidget> {
  @override
  void initState() {
    super.initState();

    // Initialize provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      provider.initialize(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (!provider.isInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.teal),
                  SizedBox(height: 16),
                  Text(
                    'กำลังเตรียม Formula Database...',
                    style: TextStyle(fontSize: 16, color: Colors.teal),
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
                // Main buttons grid (2x2)
                Expanded(
                  flex: 3,
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      // คน button
                      _buildMainButton(
                        title: 'คน',
                        icon: Icons.person,
                        color: Colors.teal,
                        onTap: () => _navigateToFormulaList(provider, 'คน'),
                      ),

                      // สัตว์ button
                      _buildMainButton(
                        title: 'สัตว์',
                        icon: Icons.pets,
                        color: Colors.orange,
                        onTap: () => _navigateToFormulaList(provider, 'สัตว์'),
                      ),

                      // สิ่งของ button
                      _buildMainButton(
                        title: 'สิ่งของ',
                        icon: Icons.inventory,
                        color: Colors.purple,
                        onTap:
                            () => _navigateToFormulaList(provider, 'สิ่งของ'),
                      ),

                      // + button (สร้าง formula ใหม่)
                      _buildMainButton(
                        title: '',
                        icon: Icons.add,
                        color: Colors.green,
                        iconSize: 48,
                        onTap: () => _showCreateFormulaDialog(provider),
                      ),
                    ],
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
                          colors: [Colors.blue.shade50, Colors.blue.shade100],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.storage, size: 32, color: Colors.blue),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'คน',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade800,
                                  ),
                                ),
                                Text(
                                  'จำนวน: ${provider.formulas.length} formulas',
                                ),
                                Text(
                                  'Tables: ${provider.databaseTables.length} tables',
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => _showDatabaseViewer(provider),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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

  Widget _buildMainButton({
    required String title,
    required IconData icon,
    required MaterialColor color,
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
            gradient: LinearGradient(
              colors: [color.shade300, color.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
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
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ========== NAVIGATION METHODS ==========

  void _navigateToFormulaList(FormulaProvider provider, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaListPage(category: category),
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
                  title: Row(
                    children: [
                      Icon(Icons.add_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text('สร้าง Formula ใหม่'),
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
                              prefixIcon: Icon(Icons.title),
                            ),
                          ),
                          SizedBox(height: 16),

                          // Description
                          TextField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: 'คำอธิบาย',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.description),
                            ),
                            maxLines: 2,
                          ),
                          SizedBox(height: 16),

                          // Column count
                          Row(
                            children: [
                              Icon(Icons.view_column, color: Colors.blue),
                              SizedBox(width: 8),
                              Text(
                                'จำนวน Column:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 16),
                              DropdownButton<int>(
                                value: columnCount,
                                items:
                                    List.generate(10, (index) => index + 1)
                                        .map(
                                          (count) => DropdownMenuItem(
                                            value: count,
                                            child: Text(
                                              '$count column${count > 1 ? 's' : ''}',
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
                            style: TextStyle(fontWeight: FontWeight.bold),
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
                                  prefixIcon: Icon(Icons.label_outline),
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
                      child: Text('ยกเลิก'),
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
                        backgroundColor: Colors.green,
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
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }
}

// ========== FORMULA LIST PAGE ==========

class FormulaListPage extends StatefulWidget {
  final String category;

  const FormulaListPage({Key? key, required this.category}) : super(key: key);

  @override
  State<FormulaListPage> createState() => _FormulaListPageState();
}

class _FormulaListPageState extends State<FormulaListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📋 ${widget.category} Formulas'),
        backgroundColor: Colors.blue[100],
        actions: [
          IconButton(
            onPressed: () => _showCreateFormulaDialog(),
            icon: Icon(Icons.add),
          ),
        ],
      ),
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          if (provider.isProcessing) {
            return Center(child: CircularProgressIndicator());
          }

          final formulas =
              provider.formulas
                  .where(
                    (formula) => _isFormulaInCategory(formula, widget.category),
                  )
                  .toList();

          if (formulas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getCategoryIcon(widget.category),
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'ไม่มี ${widget.category} Formula',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'สร้าง Formula แรกของคุณ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showCreateFormulaDialog(),
                    icon: Icon(Icons.add),
                    label: Text('สร้าง Formula'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: formulas.length,
            itemBuilder: (context, index) {
              final formula = formulas[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                elevation: 2,
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getCategoryColor(widget.category),
                    child: Text(
                      formula.initials,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    formula.formulaName,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Columns: ${formula.columnCount}'),
                      Text('Fields: ${formula.columnNames.join(", ")}'),
                      if (formula.description.isNotEmpty)
                        Text('คำอธิบาย: ${formula.description}'),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') {
                        _showFormulaDetails(formula);
                      } else if (value == 'delete') {
                        _confirmDeleteFormula(provider, formula);
                      }
                    },
                    itemBuilder:
                        (context) => [
                          PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 16),
                                SizedBox(width: 8),
                                Text('ดูข้อมูล'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('ลบ', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                  ),
                  onTap: () => _showFormulaDetails(formula),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCreateFormulaDialog() {
    // Similar to the main create dialog but filtered for this category
    Navigator.pop(context); // Go back to main page
    // The main page will handle the create dialog
  }

  void _showFormulaDetails(Map<String, dynamic> formula) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FormulaDetailsPage(formula: formula),
      ),
    );
  }

  Future<void> _confirmDeleteFormula(
    FormulaProvider provider,
    Map<String, dynamic> formula,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('ลบ Formula'),
            content: Text('คุณแน่ใจหรือไม่ที่จะลบ\n"${formula.formulaName}"?'),
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
      final success = await provider.deleteFormula(
        formula.formulaId,
        formula.formulaName,
      );

      if (success) {
        _showMessage('✅ Formula ถูกลบแล้ว!');
      } else {
        _showMessage('❌ ไม่สามารถลบ Formula ได้: ${provider.lastError}');
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'คน':
        return Colors.teal;
      case 'สัตว์':
        return Colors.orange;
      case 'สิ่งของ':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'คน':
        return Icons.person;
      case 'สัตว์':
        return Icons.pets;
      case 'สิ่งของ':
        return Icons.inventory;
      default:
        return Icons.description;
    }
  }

  bool _isFormulaInCategory(Map<String, dynamic> formula, String category) {
    // This is a simple categorization based on formula name or could be more sophisticated
    final name = formula.formulaName.toLowerCase();
    switch (category) {
      case 'คน':
        return name.contains('คน') ||
            name.contains('person') ||
            name.contains('human') ||
            name.contains('people');
      case 'สัตว์':
        return name.contains('สัตว์') ||
            name.contains('animal') ||
            name.contains('pet');
      case 'สิ่งของ':
        return name.contains('สิ่งของ') ||
            name.contains('object') ||
            name.contains('item') ||
            name.contains('thing');
      default:
        return true;
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }
}

// ========== FORMULA DETAILS PAGE ==========

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

  @override
  void initState() {
    super.initState();
    _loadTableData();
  }

  Future<void> _loadTableData() async {
    final provider = Provider.of<FormulaProvider>(context, listen: false);
    final tableName = widget.formula.tableName;

    try {
      final data = await provider.getTableData(tableName);
      final columns = await provider.getTableColumns(tableName);

      setState(() {
        _tableData = data;
        _tableColumns = columns;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showMessage('ไม่สามารถโหลดข้อมูลได้: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('📊 ${widget.formula.formulaName}'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(onPressed: () => _addNewRecord(), icon: Icon(Icons.add)),
          IconButton(
            onPressed: () => _exportToExcel(),
            icon: Icon(Icons.file_download),
          ),
        ],
      ),
      body:
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Formula info card
                    Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.formula.formulaName,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text('Columns: ${widget.formula.columnCount}'),
                            Text(
                              'Fields: ${widget.formula.columnNames.join(", ")}',
                            ),
                            if (widget.formula.description.isNotEmpty)
                              Text('คำอธิบาย: ${widget.formula.description}'),
                            Text('Records: ${_tableData.length}'),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),

                    // Data table
                    Expanded(
                      child:
                          _tableData.isEmpty
                              ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.table_chart,
                                      size: 64,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'ไม่มีข้อมูล',
                                      style: TextStyle(
                                        fontSize: 18,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'เพิ่มข้อมูลแรกของคุณ',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                    SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () => _addNewRecord(),
                                      icon: Icon(Icons.add),
                                      label: Text('เพิ่มข้อมูล'),
                                    ),
                                  ],
                                ),
                              )
                              : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns:
                                      _tableColumns
                                          .map(
                                            (column) => DataColumn(
                                              label: Text(
                                                column,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                  rows:
                                      _tableData
                                          .map(
                                            (row) => DataRow(
                                              cells:
                                                  _tableColumns
                                                      .map(
                                                        (column) => DataCell(
                                                          Text(
                                                            row[column]
                                                                    ?.toString() ??
                                                                '',
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
                  ],
                ),
              ),
    );
  }

  void _addNewRecord() {
    // Show dialog to add new record
    _showMessage('เพิ่มข้อมูลใหม่ (ฟีเจอร์นี้จะพัฒนาต่อ)');
  }

  void _exportToExcel() {
    // Export data to Excel
    _showMessage('ส่งออก Excel (ฟีเจอร์นี้จะพัฒนาต่อ)');
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }
}

// ========== DATABASE VIEWER PAGE ==========

class DatabaseViewerPage extends StatefulWidget {
  @override
  State<DatabaseViewerPage> createState() => _DatabaseViewerPageState();
}

class _DatabaseViewerPageState extends State<DatabaseViewerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🗃️ Database Viewer'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          if (provider.databaseTables.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.storage, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'ไม่มี Tables ใน Database',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: provider.databaseTables.length,
            itemBuilder: (context, index) {
              final table = provider.databaseTables[index];
              final isFormulaTable = table['is_formula_table'] as bool;

              return Card(
                margin: EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        isFormulaTable ? Colors.green : Colors.blue,
                    child: Icon(
                      isFormulaTable ? Icons.functions : Icons.table_chart,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(table['table_name'] as String),
                  subtitle: Text('Records: ${table['record_count']}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFormulaTable)
                        Chip(
                          label: Text(
                            'Formula',
                            style: TextStyle(fontSize: 10),
                          ),
                          backgroundColor: Colors.green.shade100,
                        ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                  onTap: () => _showTableData(table['table_name'] as String),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showTableData(String tableName) {
    _showMessage('ดูข้อมูล Table: $tableName (ฟีเจอร์นี้จะพัฒนาต่อ)');
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }
}
