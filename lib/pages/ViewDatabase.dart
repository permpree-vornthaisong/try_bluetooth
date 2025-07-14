import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';

class ViewDatabase extends StatelessWidget {
  final Map<String, dynamic> formula;

  const ViewDatabase({Key? key, required this.formula}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
    final iconPath = formula['icon_path']?.toString() ?? 'assets/icons/cat.ico';
    final tableName =
        'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Image.asset(
                iconPath,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.storage, color: Colors.blue, size: 20);
                },
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formulaName,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Database View',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              // รีเฟรชข้อมูลผ่าน Provider
              Provider.of<FormulaProvider>(
                context,
                listen: false,
              ).refreshFormulas();
            },
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<FormulaProvider>(
        builder: (context, provider, child) {
          return FutureBuilder<DatabaseViewData>(
            future: _loadDatabaseData(provider, tableName),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingView();
              }

              if (snapshot.hasError) {
                return _buildErrorView(snapshot.error.toString(), context);
              }

              if (!snapshot.hasData) {
                return _buildErrorView('No data available', context);
              }

              final data = snapshot.data!;
              return _buildDatabaseView(context, data, provider);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context),
        backgroundColor: Colors.blue,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 16),
          Text('Loading data...'),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error: $error', textAlign: TextAlign.center),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseView(
    BuildContext context,
    DatabaseViewData data,
    FormulaProvider provider,
  ) {
    if (data.records.isEmpty) {
      return _buildEmptyView(context);
    }

    return Column(
      children: [
        // Stats header
        Container(
          margin: EdgeInsets.all(16),
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.storage, color: Colors.blue, size: 24),
                    SizedBox(height: 8),
                    Text(
                      '${data.records.length}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text('Records', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[300]),
              Expanded(
                child: Column(
                  children: [
                    Icon(Icons.view_column, color: Colors.green, size: 24),
                    SizedBox(height: 8),
                    Text(
                      '${data.columns.length}',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text('Columns', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Data table
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        child: Text(
                          '#',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      ...data.columns.map(
                        (column) => Expanded(
                          child: Text(
                            _formatColumnName(column),
                            style: TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Container(
                        width: 60,
                        child: Text(
                          'Actions',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),

                // Table data
                Expanded(
                  child: ListView.separated(
                    itemCount: data.records.length,
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = data.records[index];
                      return Container(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              child: Text(
                                '${index + 1}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            ...data.columns.map(
                              (column) => Expanded(
                                child: Text(
                                  _formatValue(record[column]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            Container(
                              width: 60,
                              child: PopupMenuButton<String>(
                                onSelected:
                                    (action) => _handleAction(
                                      context,
                                      action,
                                      record,
                                      index,
                                      provider,
                                    ),
                                icon: Icon(Icons.more_horiz, size: 18),
                                itemBuilder:
                                    (context) => [
                                      PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                            SizedBox(width: 8),
                                            Text('Edit'),
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
                                            Text('Delete'),
                                          ],
                                        ),
                                      ),
                                    ],
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
        ),
        SizedBox(height: 16),
      ],
    );
  }

  Widget _buildEmptyView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No Data Available',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('This table doesn\'t have any records yet.'),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: Icon(Icons.add),
            label: Text('Add First Record'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<DatabaseViewData> _loadDatabaseData(
    FormulaProvider provider,
    String tableName,
  ) async {
    try {
      final columns = await provider.getTableColumns(tableName);
      final records = await provider.getTableData(tableName);

      // Filter out system columns
      final displayColumns =
          columns
              .where((col) => !['id', 'created_at', 'updated_at'].contains(col))
              .toList();

      return DatabaseViewData(
        tableName: tableName,
        columns: displayColumns,
        records: records,
      );
    } catch (e) {
      throw Exception('Failed to load database data: $e');
    }
  }

  String _formatColumnName(String column) {
    return column
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';
    if (value is String && value.isEmpty) return '-';
    if (value is String && value.length > 30) {
      return '${value.substring(0, 27)}...';
    }
    return value.toString();
  }

  void _handleAction(
    BuildContext context,
    String action,
    Map<String, dynamic> record,
    int index,
    FormulaProvider provider,
  ) {
    switch (action) {
      case 'edit':
        _showEditDialog(context, record, provider);
        break;
      case 'delete':
        _showDeleteDialog(context, record, provider);
        break;
    }
  }

  void _showAddDialog(BuildContext context) {
    final columnNames = formula['column_names']?.toString().split('|') ?? [];
    final controllers = <String, TextEditingController>{};

    for (String column in columnNames) {
      controllers[column] = TextEditingController();
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Add New Record'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      columnNames.map((column) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: controllers[column],
                            decoration: InputDecoration(
                              labelText: _formatColumnName(column),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (var controller in controllers.values) {
                    controller.dispose();
                  }
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _saveRecord(context, controllers);
                  for (var controller in controllers.values) {
                    controller.dispose();
                  }
                  Navigator.pop(context);
                },
                child: Text('Add'),
              ),
            ],
          ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    Map<String, dynamic> record,
    FormulaProvider provider,
  ) {
    final columnNames = formula['column_names']?.toString().split('|') ?? [];
    final controllers = <String, TextEditingController>{};

    for (String column in columnNames) {
      controllers[column] = TextEditingController(
        text: record[column]?.toString() ?? '',
      );
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Edit Record'),
            content: Container(
              width: double.maxFinite,
              constraints: BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children:
                      columnNames.map((column) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 16),
                          child: TextField(
                            controller: controllers[column],
                            decoration: InputDecoration(
                              labelText: _formatColumnName(column),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  for (var controller in controllers.values) {
                    controller.dispose();
                  }
                  Navigator.pop(context);
                },
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _updateRecord(context, record['id'], controllers);
                  for (var controller in controllers.values) {
                    controller.dispose();
                  }
                  Navigator.pop(context);
                },
                child: Text('Update'),
              ),
            ],
          ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Map<String, dynamic> record,
    FormulaProvider provider,
  ) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Record'),
            content: Text('Are you sure you want to delete this record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _deleteRecord(context, record['id']);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
    );
  }

  Future<void> _saveRecord(
    BuildContext context,
    Map<String, TextEditingController> controllers,
  ) async {
    try {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
      final tableName =
          'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';
      final columnNames = formula['column_names']?.toString().split('|') ?? [];

      final data = <String, dynamic>{};
      for (String column in columnNames) {
        data[column] = controllers[column]!.text.trim();
      }

      final success = await provider.createRecord(
        tableName: tableName,
        data: data,
      );

      if (success) {
        _showMessage(context, 'Record added successfully!', Colors.green);
        // รีเฟรชข้อมูลผ่าน Provider
        provider.refreshFormulas();
      } else {
        _showMessage(context, 'Failed to add record', Colors.red);
      }
    } catch (e) {
      _showMessage(context, 'Error: $e', Colors.red);
    }
  }

  Future<void> _updateRecord(
    BuildContext context,
    int recordId,
    Map<String, TextEditingController> controllers,
  ) async {
    try {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
      final tableName =
          'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';
      final columnNames = formula['column_names']?.toString().split('|') ?? [];

      final data = <String, dynamic>{};
      for (String column in columnNames) {
        data[column] = controllers[column]!.text.trim();
      }

      final success = await provider.updateRecord(
        tableName: tableName,
        recordId: recordId,
        data: data,
      );

      if (success) {
        _showMessage(context, 'Record updated successfully!', Colors.green);
        // รีเฟรชข้อมูลผ่าน Provider
        provider.refreshFormulas();
      } else {
        _showMessage(context, 'Failed to update record', Colors.red);
      }
    } catch (e) {
      _showMessage(context, 'Error: $e', Colors.red);
    }
  }

  Future<void> _deleteRecord(BuildContext context, int recordId) async {
    try {
      final provider = Provider.of<FormulaProvider>(context, listen: false);
      final formulaName = formula['formula_name']?.toString() ?? 'Unknown';
      final tableName =
          'formula_${formulaName.toLowerCase().replaceAll(' ', '_')}';

      final success = await provider.deleteRecord(
        tableName: tableName,
        recordId: recordId,
      );

      if (success) {
        _showMessage(context, 'Record deleted successfully!', Colors.green);
        // รีเฟรชข้อมูลผ่าน Provider
        provider.refreshFormulas();
      } else {
        _showMessage(context, 'Failed to delete record', Colors.red);
      }
    } catch (e) {
      _showMessage(context, 'Error: $e', Colors.red);
    }
  }

  void _showMessage(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Data class สำหรับเก็บข้อมูล database
class DatabaseViewData {
  final String tableName;
  final List<String> columns;
  final List<Map<String, dynamic>> records;

  DatabaseViewData({
    required this.tableName,
    required this.columns,
    required this.records,
  });
}
