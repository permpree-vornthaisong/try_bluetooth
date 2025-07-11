import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';

class ShowDataBaseFormular extends StatefulWidget {
  final Map<String, dynamic> formula;

  const ShowDataBaseFormular({Key? key, required this.formula})
    : super(key: key);

  @override
  State<ShowDataBaseFormular> createState() => _ShowDataBaseFormularState();
}

class _ShowDataBaseFormularState extends State<ShowDataBaseFormular> {
  List<Map<String, dynamic>> _formulaData = [];
  List<String> _columns = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFormulaData();
  }

  Future<void> _loadFormulaData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final formulaProvider = Provider.of<FormulaProvider>(
        context,
        listen: false,
      );

      // ดึงชื่อ table ที่เกี่ยวข้องกับ formula
      final tableName = widget.formula.tableName;

      debugPrint('🔍 Loading data from table: $tableName');

      // ดึงข้อมูลจาก table
      final data = await formulaProvider.getTableData(tableName);
      final columns = await formulaProvider.getTableColumns(tableName);

      setState(() {
        _formulaData = data;
        _columns = columns;
        _isLoading = false;
      });

      debugPrint(
        '✅ Loaded ${data.length} records with ${columns.length} columns',
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
        _isLoading = false;
      });
      debugPrint('❌ Error loading formula data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.formula.formulaName} Data'),
        backgroundColor: Colors.blue,
        actions: [
          // ปุ่มรีเฟรช
          IconButton(icon: Icon(Icons.refresh), onPressed: _loadFormulaData),
          // ปุ่มเพิ่มข้อมูล
          IconButton(
            icon: Icon(Icons.add),
            onPressed: () => _showAddRecordDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(
                        widget.formula.initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
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
                          Text(
                            'Table: ${widget.formula.tableName}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                            widget.formula.isActive
                                ? Colors.green
                                : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_formulaData.length} Records',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.formula.description.isNotEmpty) ...[
                  SizedBox(height: 8),
                  Text(
                    widget.formula.description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                ],
              ],
            ),
          ),

          // Content area
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading formula data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(onPressed: _loadFormulaData, child: Text('Retry')),
          ],
        ),
      );
    }

    if (_formulaData.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No data found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Add your first record to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showAddRecordDialog(),
              icon: Icon(Icons.add),
              label: Text('Add Record'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return _buildDataTable();
  }

  Widget _buildDataTable() {
    // กรองเอาเฉพาะ columns ที่ไม่ใช่ system columns
    final displayColumns =
        _columns
            .where((col) => !['id', 'created_at', 'updated_at'].contains(col))
            .toList();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateColor.resolveWith(
            (states) => Colors.blue.shade100,
          ),
          columns: [
            // เพิ่ม column สำหรับ actions
            DataColumn(
              label: Text(
                'Actions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // แสดง columns ที่เป็นข้อมูลจริง
            ...displayColumns.map(
              (column) => DataColumn(
                label: Text(
                  _formatColumnName(column),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // เพิ่ม column สำหรับ timestamp
            DataColumn(
              label: Text(
                'Created',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          rows:
              _formulaData.map((record) {
                return DataRow(
                  cells: [
                    // Actions cell
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.blue,
                            ),
                            onPressed: () => _showEditRecordDialog(record),
                            tooltip: 'Edit',
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete,
                              size: 18,
                              color: Colors.red,
                            ),
                            onPressed: () => _showDeleteConfirmDialog(record),
                            tooltip: 'Delete',
                          ),
                        ],
                      ),
                    ),
                    // Data cells
                    ...displayColumns.map(
                      (column) => DataCell(
                        Text(
                          record[column]?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // Created timestamp cell
                    DataCell(
                      Text(
                        _formatDate(record['created_at']),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  String _formatColumnName(String columnName) {
    // แปลง snake_case เป็น Title Case
    return columnName
        .split('_')
        .map(
          (word) =>
              word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
        )
        .join(' ');
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return '';

    try {
      // อาจจะเป็น String หรือ DateTime
      DateTime date;
      if (dateValue is String) {
        date = DateTime.parse(dateValue);
      } else if (dateValue is DateTime) {
        date = dateValue;
      } else {
        return dateValue.toString();
      }

      return '${date.day}/${date.month}/${date.year}\n${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateValue.toString();
    }
  }

  void _showAddRecordDialog() {
    // TODO: Implement add record dialog
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Add record feature coming soon!')));
  }

  void _showEditRecordDialog(Map<String, dynamic> record) {
    // TODO: Implement edit record dialog
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Edit record feature coming soon!')));
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete Record'),
            content: Text('Are you sure you want to delete this record?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => _deleteRecord(record),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text('Delete', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
    );
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    try {
      final formulaProvider = Provider.of<FormulaProvider>(
        context,
        listen: false,
      );

      final success = await formulaProvider.deleteRecord(
        tableName: widget.formula.tableName,
        recordId: record['id'],
      );

      Navigator.of(context).pop(); // ปิด dialog

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Record deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadFormulaData(); // รีโหลดข้อมูล
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete record'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop(); // ปิด dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
