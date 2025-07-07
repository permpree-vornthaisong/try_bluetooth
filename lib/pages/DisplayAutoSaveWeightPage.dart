import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/DisplayMainProvider.dart';
import '../providers/CRUD_Services_Providers.dart';

class DisplayAutoSaveWeightPage extends StatefulWidget {
  const DisplayAutoSaveWeightPage({super.key});

  @override
  State<DisplayAutoSaveWeightPage> createState() => _DisplayAutoSaveWeightPageState();
}

class _DisplayAutoSaveWeightPageState extends State<DisplayAutoSaveWeightPage> {
  final String _tableName = 'auto_saved_weights';
  List<Map<String, dynamic>> _savedRecords = [];
  bool _isLoading = false;
  String? _error;
  
  // Auto Save State
  bool _isAutoSaveActive = false;
  double? _currentWeight;
  int _stableCount = 0;
  int _stableCountThreshold = 10;
  double _weightTolerance = 0.1;
  bool _waitingForZeroWeight = false; // รอให้น้ำหนักเป็น 0 ก่อนบันทึกครั้งต่อไป
  double _zeroWeightThreshold = 0.5; // ถือว่าเป็น 0 ถ้าน้ำหนักต่ำกว่า 0.5 kg
  
  // Filters
  String _sortOrder = 'DESC';
  String _filterBy = 'all';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    // Delay initialization to allow context to be ready
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('🚀 Starting auto save page initialization...');
      await _initializeAutoSaveTable();
      await _loadSavedRecords();
      _startAutoSaveMonitoring();
      debugPrint('✅ Auto save page initialization completed');
    });
  }

  @override
  void dispose() {
    _stopAutoSaveMonitoring();
    super.dispose();
  }

  // ========== AUTO SAVE TABLE INITIALIZATION ==========
  
  Future<void> _initializeAutoSaveTable() async {
    try {
      final crudServices = Provider.of<CRUDServicesProvider>(context, listen: false);
      
      // Wait for database to be ready with multiple attempts
      int attempts = 0;
      while (!crudServices.isDatabaseReady && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 500));
        attempts++;
        debugPrint('⏳ Waiting for database to be ready... attempt $attempts');
      }
      
      if (!crudServices.isDatabaseReady) {
        setState(() {
          _error = 'Database initialization timeout. Please restart the app.';
        });
        return;
      }
      
      debugPrint('🔍 Checking if table $_tableName exists...');
      final tableExists = await crudServices.doesTableExist(_tableName);
      debugPrint('📋 Table $_tableName exists: $tableExists');
      
      if (!tableExists) {
        debugPrint('🔨 Creating table $_tableName...');
        
        // Try using raw SQL query instead
        try {
          final createTableSQL = '''
            CREATE TABLE IF NOT EXISTS $_tableName (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              weight REAL NOT NULL,
              raw_weight REAL,
              tare_offset REAL,
              device_name TEXT,
              timestamp TEXT NOT NULL,
              auto_save_session INTEGER,
              notes TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            )
          ''';
          
          debugPrint('📝 Executing SQL: $createTableSQL');
          await crudServices.executeCustomQuery(createTableSQL);
          
          // Verify table creation
          final verifyExists = await crudServices.doesTableExist(_tableName);
          debugPrint('✅ Table verification after custom query: $_tableName exists = $verifyExists');
          
          if (verifyExists) {
            debugPrint('✅ Auto save table created successfully via custom query');
          } else {
            setState(() {
              _error = 'Failed to create auto save table via custom query';
            });
            debugPrint('❌ Failed to create table $_tableName via custom query');
          }
        } catch (e) {
          debugPrint('❌ Custom query failed, trying createTable method...');
          
          // Fallback to original method with just column definitions
          final schema = '''
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              weight REAL NOT NULL,
              raw_weight REAL,
              tare_offset REAL,
              device_name TEXT,
              timestamp TEXT NOT NULL,
              auto_save_session INTEGER,
              notes TEXT,
              created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          ''';
          
          final success = await crudServices.createTable(_tableName, schema);
          
          if (success) {
            debugPrint('✅ Auto save table created successfully via createTable method');
            // Verify table creation
            final verifyExists = await crudServices.doesTableExist(_tableName);
            debugPrint('✅ Table verification: $_tableName exists = $verifyExists');
          } else {
            setState(() {
              _error = 'Failed to create auto save table';
            });
            debugPrint('❌ Failed to create table $_tableName');
          }
        }
      } else {
        debugPrint('✅ Auto save table already exists');
      }
      
      // Get all table names for debugging
      final allTables = await crudServices.getAllTableNames();
      debugPrint('📋 All tables in database: $allTables');
      
    } catch (e) {
      setState(() {
        _error = 'Error initializing table: $e';
      });
      debugPrint('❌ Error initializing auto save table: $e');
    }
  }

  // ========== AUTO SAVE MONITORING ==========
  
  void _startAutoSaveMonitoring() {
    _isAutoSaveActive = true;
    // Start monitoring weight changes
    _monitorWeightChanges();
  }
  
  void _stopAutoSaveMonitoring() {
    _isAutoSaveActive = false;
  }
  
  void _monitorWeightChanges() {
    if (!_isAutoSaveActive || !mounted) return;
    
    try {
      final displayProvider = Provider.of<DisplayMainProvider>(context, listen: false);
      final currentWeight = displayProvider.netWeight;
      
      if (currentWeight != null) {
        // ตรวจสอบว่าน้ำหนักเป็น 0 หรือไม่
        if (currentWeight <= _zeroWeightThreshold) {
          // น้ำหนักเป็น 0 แล้ว สามารถเริ่มบันทึกใหม่ได้
          if (_waitingForZeroWeight) {
            setState(() {
              _waitingForZeroWeight = false;
            });
            debugPrint('✅ Weight returned to zero, ready for next auto save');
          }
          _resetStableTracking();
        } else if (!_waitingForZeroWeight && currentWeight > 0) {
          // มีน้ำหนักและไม่ได้รออยู่ ให้ตรวจสอบความนิ่ง
          if (_isWeightStable(currentWeight)) {
            setState(() {
              _stableCount++;
            });
            if (_stableCount >= _stableCountThreshold) {
              _triggerAutoSave(currentWeight);
            }
          } else {
            setState(() {
              _currentWeight = currentWeight;
              _stableCount = 1;
            });
          }
        } else if (_waitingForZeroWeight) {
          // กำลังรอให้น้ำหนักเป็น 0 ไม่ต้องทำอะไร
          debugPrint('⏳ Waiting for weight to return to zero... Current: ${currentWeight.toStringAsFixed(1)} kg');
        }
      } else {
        _resetStableTracking();
      }
    } catch (e) {
      debugPrint('❌ Error monitoring weight: $e');
    }
    
    // Continue monitoring
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _isAutoSaveActive) {
        _monitorWeightChanges();
      }
    });
  }
  
  bool _isWeightStable(double newWeight) {
    if (_currentWeight == null) {
      _currentWeight = newWeight;
      return true;
    }
    
    final difference = (newWeight - _currentWeight!).abs();
    return difference <= _weightTolerance;
  }
  
  void _resetStableTracking() {
    setState(() {
      _currentWeight = null;
      _stableCount = 0;
    });
  }
  
  Future<void> _triggerAutoSave(double stableWeight) async {
    try {
      final crudServices = Provider.of<CRUDServicesProvider>(context, listen: false);
      final displayProvider = Provider.of<DisplayMainProvider>(context, listen: false);
      
      // Check if database is ready
      if (!crudServices.isDatabaseReady) {
        setState(() {
          _error = 'Database not ready for auto save';
        });
        debugPrint('❌ Database not ready for auto save');
        return;
      }
      
      // Double check if table exists before inserting
      final tableExists = await crudServices.doesTableExist(_tableName);
      if (!tableExists) {
        debugPrint('❌ Table $_tableName does not exist, attempting to create...');
        await _initializeAutoSaveTable();
        
        // Check again after initialization
        final tableExistsAfterInit = await crudServices.doesTableExist(_tableName);
        if (!tableExistsAfterInit) {
          setState(() {
            _error = 'Cannot create required table for auto save';
          });
          return;
        }
      }
      
      debugPrint('💾 Starting auto save for weight: ${stableWeight.toStringAsFixed(1)} kg');
      
      final saveData = {
        'weight': stableWeight,
        'raw_weight': displayProvider.rawWeightWithoutTare ?? 0.0,
        'tare_offset': displayProvider.tareOffset,
        'device_name': displayProvider.deviceName,
        'timestamp': DateTime.now().toIso8601String(),
        'auto_save_session': DateTime.now().millisecondsSinceEpoch,
        'notes': 'Auto saved after $_stableCountThreshold stable readings',
      };
      
      debugPrint('📝 Save data prepared: $saveData');
      
      final success = await crudServices.insertRecord(_tableName, saveData);
      
      if (success) {
        // Set flag to wait for zero weight before next save
        setState(() {
          _waitingForZeroWeight = true;
        });
        
        // Auto reset after save
        await displayProvider.sendCustomCommand('CLEAR_TARE');
        
        // Reload records
        _loadSavedRecords();
        
        // Reset tracking
        _resetStableTracking();
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Auto saved: ${stableWeight.toStringAsFixed(1)} kg'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        debugPrint('✅ Auto saved: ${stableWeight.toStringAsFixed(1)} kg - Waiting for zero weight');
      } else {
        setState(() {
          _error = 'Failed to auto save weight to database';
        });
        debugPrint('❌ Failed to auto save weight');
      }
    } catch (e) {
      setState(() {
        _error = 'Auto save failed: $e';
      });
      debugPrint('❌ Auto save error: $e');
    }
  }

  // ========== DATA LOADING ==========
  
  Future<void> _loadSavedRecords() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final crudServices = Provider.of<CRUDServicesProvider>(context, listen: false);
      
      // Check if database is ready
      if (!crudServices.isDatabaseReady) {
        setState(() {
          _error = 'Database not ready. Please check CRUD Services initialization.';
          _isLoading = false;
        });
        return;
      }
      
      List<Map<String, dynamic>> records;
      
      if (_filterBy == 'today') {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        records = await crudServices.getRecordsWhere(
          _tableName,
          where: 'timestamp BETWEEN ? AND ?',
          whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
          orderBy: 'timestamp $_sortOrder',
        );
      } else if (_filterBy == 'date_range' && _filterStartDate != null && _filterEndDate != null) {
        records = await crudServices.getRecordsWhere(
          _tableName,
          where: 'timestamp BETWEEN ? AND ?',
          whereArgs: [_filterStartDate!.toIso8601String(), _filterEndDate!.toIso8601String()],
          orderBy: 'timestamp $_sortOrder',
        );
      } else {
        records = await crudServices.getAllRecords(
          _tableName,
          orderBy: 'timestamp $_sortOrder',
        );
      }
      
      if (mounted) {
        setState(() {
          _savedRecords = records;
          _isLoading = false;
        });
        
        debugPrint('✅ Loaded ${records.length} records');
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading records: $e';
          _isLoading = false;
        });
      }
      debugPrint('❌ Error loading records: $e');
    }
  }

  // ========== MANUAL ACTIONS ==========
  
  Future<void> _manualSave() async {
    try {
      final displayProvider = Provider.of<DisplayMainProvider>(context, listen: false);
      final crudServices = Provider.of<CRUDServicesProvider>(context, listen: false);
      
      // Check if database is ready
      if (!crudServices.isDatabaseReady) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database not ready'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final currentWeight = displayProvider.netWeight;
      if (currentWeight == null || currentWeight <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No valid weight to save'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final saveData = {
        'weight': currentWeight,
        'raw_weight': displayProvider.rawWeightWithoutTare ?? 0.0,
        'tare_offset': displayProvider.tareOffset,
        'device_name': displayProvider.deviceName,
        'timestamp': DateTime.now().toIso8601String(),
        'auto_save_session': DateTime.now().millisecondsSinceEpoch,
        'notes': 'Manual save',
      };
      
      final success = await crudServices.insertRecord(_tableName, saveData);
      
      if (success) {
        _loadSavedRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Manually saved: ${currentWeight.toStringAsFixed(1)} kg'),
            backgroundColor: Colors.blue,
          ),
        );
        debugPrint('✅ Manual save: ${currentWeight.toStringAsFixed(1)} kg');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Save failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Save failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      debugPrint('❌ Manual save error: $e');
    }
  }
  
  Future<void> _deleteRecord(int id) async {
    final crudServices = context.read<CRUDServicesProvider>();
    
    try {
      final success = await crudServices.deleteRecordById(_tableName, id);
      
      if (success) {
        _loadSavedRecords();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Record deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _clearAllRecords() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete all saved records?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      final crudServices = context.read<CRUDServicesProvider>();
      
      try {
        final success = await crudServices.deleteAllRecords(_tableName);
        
        if (success) {
          _loadSavedRecords();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All records deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Clear failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ========== UTILITY METHODS ==========
  
  /// Format DateTime to readable string
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays == 0) {
      // Today - show time only
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      // Yesterday
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      // Other days - show full date
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }

  // ========== UI BUILDERS ==========
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('การชั่งอัตโนมัติ'),
        backgroundColor: Colors.blue.shade100,
        actions: [
          IconButton(
            icon: Icon(_isAutoSaveActive ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                if (_isAutoSaveActive) {
                  _stopAutoSaveMonitoring();
                } else {
                  _startAutoSaveMonitoring();
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSavedRecords,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clear_all':
                  _clearAllRecords();
                  break;
                case 'settings':
                  _showSettingsDialog();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Weight Display & Controls
          _buildWeightDisplaySection(),
          
          // Filters
          _buildFiltersSection(),
          
          // Records List
          Expanded(
            child: _buildRecordsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _manualSave,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.save),
      ),
    );
  }
  
  Widget _buildWeightDisplaySection() {
    return Consumer<DisplayMainProvider>(
      builder: (context, displayProvider, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(bottom: BorderSide(color: Colors.blue.shade200)),
          ),
          child: Column(
            children: [
              // Current Weight Display
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildWeightCard(
                    'น้ำหนักปัจจุบัน',
                    displayProvider.formattedWeight,
                    Colors.blue,
                    Icons.scale,
                  ),
                  _buildWeightCard(
                    'Raw Weight',
                    displayProvider.rawWeightWithoutTare?.toStringAsFixed(1) ?? '-.--',
                    Colors.green,
                    Icons.straighten,
                  ),
                  _buildWeightCard(
                    'Tare Offset',
                    displayProvider.tareOffset.toStringAsFixed(1),
                    Colors.orange,
                    Icons.remove_circle_outline,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
            TextFormField(
              initialValue: _zeroWeightThreshold.toString(),
              decoration: const InputDecoration(
                labelText: 'Zero Weight Threshold (kg)',
                helperText: 'น้ำหนักที่ถือว่าเป็น 0',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final threshold = double.tryParse(value);
                if (threshold != null && threshold >= 0) {
                  setState(() {
                    _zeroWeightThreshold = threshold;
                  });
                }
              },
            ),
              
              // Auto Save Status
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAutoSaveActive ? Colors.green.shade100 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isAutoSaveActive ? Colors.green.shade300 : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAutoSaveActive ? Icons.auto_mode : Icons.pause_circle,
                      color: _isAutoSaveActive ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAutoSaveActive ? 'Auto Save: Active' : 'Auto Save: Paused',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _isAutoSaveActive ? Colors.green.shade800 : Colors.grey.shade800,
                            ),
                          ),
                          if (_isAutoSaveActive) ...[
                            Text(
                              _waitingForZeroWeight 
                                ? 'รอให้น้ำหนักเป็น 0 ก่อนบันทึกครั้งต่อไป'
                                : 'Stable: $_stableCount/$_stableCountThreshold readings',
                              style: TextStyle(
                                fontSize: 12,
                                color: _waitingForZeroWeight 
                                  ? Colors.orange.shade600 
                                  : Colors.green.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Text(
                      'Total: ${_savedRecords.length}',
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
        );
      },
    );
  }
  
  Widget _buildWeightCard(String title, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '$value kg',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Filter by
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _filterBy,
              decoration: const InputDecoration(
                labelText: 'Filter',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Records')),
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: 'date_range', child: Text('Date Range')),
              ],
              onChanged: (value) {
                setState(() {
                  _filterBy = value!;
                });
                _loadSavedRecords();
              },
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Sort order
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _sortOrder,
              decoration: const InputDecoration(
                labelText: 'Sort',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem(value: 'DESC', child: Text('Newest First')),
                DropdownMenuItem(value: 'ASC', child: Text('Oldest First')),
              ],
              onChanged: (value) {
                setState(() {
                  _sortOrder = value!;
                });
                _loadSavedRecords();
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 48, color: Colors.red.shade400),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadSavedRecords,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_savedRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No saved records',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _savedRecords.length,
      itemBuilder: (context, index) {
        final record = _savedRecords[index];
        return _buildRecordCard(record, index);
      },
    );
  }
  
  Widget _buildRecordCard(Map<String, dynamic> record, int index) {
    final timestamp = DateTime.parse(record['timestamp']);
    final weight = record['weight']?.toDouble() ?? 0.0;
    final rawWeight = record['raw_weight']?.toDouble() ?? 0.0;
    final tareOffset = record['tare_offset']?.toDouble() ?? 0.0;
    final notes = record['notes'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                Text(
                  _formatDateTime(timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteRecord(record['id']),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Weight information
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('น้ำหนัก', '${weight.toStringAsFixed(1)} kg', Colors.blue),
                ),
                Expanded(
                  child: _buildInfoItem('Raw', '${rawWeight.toStringAsFixed(1)} kg', Colors.green),
                ),
                Expanded(
                  child: _buildInfoItem('Tare', '${tareOffset.toStringAsFixed(1)} kg', Colors.orange),
                ),
              ],
            ),
            
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        notes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
  
  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Auto Save Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              initialValue: _stableCountThreshold.toString(),
              decoration: const InputDecoration(
                labelText: 'Stable Count Threshold',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final threshold = int.tryParse(value);
                if (threshold != null && threshold > 0) {
                  setState(() {
                    _stableCountThreshold = threshold;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _weightTolerance.toString(),
              decoration: const InputDecoration(
                labelText: 'Weight Tolerance (kg)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final tolerance = double.tryParse(value);
                if (tolerance != null && tolerance >= 0) {
                  setState(() {
                    _weightTolerance = tolerance;
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Settings updated'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}