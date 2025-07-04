import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class SavedObjectWeight {
  final String id;
  final String objectName;
  final String objectCategory; // เพิ่มหมวดหมู่สิ่งของ
  final double weight;
  final DateTime timestamp;
  final String? notes; // เพิ่มหมายเหตุ

  SavedObjectWeight({
    required this.id,
    required this.objectName,
    required this.objectCategory,
    required this.weight,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'object_name': objectName,
      'object_category': objectCategory,
      'weight': weight,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory SavedObjectWeight.fromMap(Map<String, dynamic> map) {
    return SavedObjectWeight(
      id: map['id'],
      objectName: map['object_name'],
      objectCategory: map['object_category'] ?? 'อื่นๆ',
      weight: map['weight'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      notes: map['notes'],
    );
  }
}

class SaveObjectProvider extends ChangeNotifier {
  Database? _database;
  final Uuid _uuid = const Uuid();
  List<SavedObjectWeight> _savedWeights = [];
  bool _isLoading = false;

  List<SavedObjectWeight> get savedWeights => _savedWeights;
  bool get isLoading => _isLoading;

  // รายการหมวดหมู่สิ่งของ
  static const List<String> objectCategories = [
    'เครื่องใช้ไฟฟ้า',
    'เฟอร์นิเจอร์',
    'อุปกรณ์กีฬา',
    'เครื่องมือ',
    'เครื่องครัว',
    'อุปกรณ์สำนักงาน',
    'ของเล่น',
    'อุปกรณ์การเกษตร',
    'วัสดุก่อสร้าง',
    'เครื่องประดับ',
    'เสื้อผ้า',
    'กระเป่า/กล่อง',
    'อุปกรณ์อิเล็กทรอนิกส์',
    'หนังสือ/เอกสาร',
    'อาหาร/เครื่องดื่ม',
    'อื่นๆ',
  ];

  // Initialize database
  Future<void> initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'weight_app.db');

      _database = await openDatabase(
        path,
        version: 2, // เพิ่ม version เพื่อ update schema
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE Table_saveObject (
              id TEXT PRIMARY KEY,
              object_name TEXT NOT NULL,
              object_category TEXT NOT NULL,
              weight REAL NOT NULL,
              timestamp INTEGER NOT NULL,
              notes TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // แก้ไขชื่อ column ที่ผิด
            try {
              await db.execute('ALTER TABLE Table_saveObject RENAME COLUMN Object_name TO object_name');
            } catch (e) {
              debugPrint('Column rename failed or not needed: $e');
            }
            
            // เพิ่ม object_category column
            try {
              await db.execute('ALTER TABLE Table_saveObject ADD COLUMN object_category TEXT DEFAULT "อื่นๆ"');
            } catch (e) {
              debugPrint('Category column already exists: $e');
            }
            
            // เพิ่ม notes column
            try {
              await db.execute('ALTER TABLE Table_saveObject ADD COLUMN notes TEXT');
            } catch (e) {
              debugPrint('Notes column already exists: $e');
            }
          }
        },
      );

      await loadSavedWeights();
    } catch (e) {
      debugPrint('Error initializing object database: $e');
    }
  }

  // Save object weight data
  Future<bool> saveObjectWeight({
    required String objectName,
    required String objectCategory,
    required double weight,
    String? notes,
  }) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final savedWeight = SavedObjectWeight(
        id: _uuid.v4(),
        objectName: objectName.trim(),
        objectCategory: objectCategory,
        weight: weight,
        timestamp: DateTime.now(),
        notes: notes?.trim(),
      );

      await _database!.insert(
        'Table_saveObject',
        savedWeight.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _savedWeights.insert(0, savedWeight); // Add to beginning of list
      _isLoading = false;
      notifyListeners();

      debugPrint('Object weight saved successfully: ${savedWeight.objectName} (${savedWeight.objectCategory}) - ${savedWeight.weight}kg');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error saving object weight: $e');
      return false;
    }
  }

  // Backward compatibility - keep old method name
  Future<bool> saveWeight({
    required String personName,
    required double weight,
  }) async {
    return await saveObjectWeight(
      objectName: personName,
      objectCategory: 'อื่นๆ',
      weight: weight,
    );
  }

  // Load all saved weights
  Future<void> loadSavedWeights() async {
    if (_database == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final List<Map<String, dynamic>> maps = await _database!.query(
        'Table_saveObject',
        orderBy: 'timestamp DESC',
      );

      _savedWeights = maps.map((map) => SavedObjectWeight.fromMap(map)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading saved object weights: $e');
    }
  }

  // Delete saved weight
  Future<bool> deleteWeight(String id) async {
    if (_database == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _database!.delete(
        'Table_saveObject',
        where: 'id = ?',
        whereArgs: [id],
      );

      _savedWeights.removeWhere((weight) => weight.id == id);
      _isLoading = false;
      notifyListeners();

      debugPrint('Object weight deleted successfully: $id');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error deleting object weight: $e');
      return false;
    }
  }

  // Get weights by object name
  List<SavedObjectWeight> getWeightsByObject(String objectName) {
    return _savedWeights
        .where((weight) => weight.objectName.toLowerCase() == objectName.toLowerCase())
        .toList();
  }

  // Backward compatibility
  List<SavedObjectWeight> getWeightsByPerson(String personName) {
    return getWeightsByObject(personName);
  }

  // Get weights by category
  List<SavedObjectWeight> getWeightsByCategory(String category) {
    return _savedWeights
        .where((weight) => weight.objectCategory == category)
        .toList();
  }

  // Get latest weight for an object
  SavedObjectWeight? getLatestWeightForObject(String objectName) {
    final weights = getWeightsByObject(objectName);
    return weights.isNotEmpty ? weights.first : null;
  }

  // Backward compatibility
  SavedObjectWeight? getLatestWeightForPerson(String personName) {
    return getLatestWeightForObject(personName);
  }

  // Get weights within date range
  List<SavedObjectWeight> getWeightsInRange(DateTime startDate, DateTime endDate) {
    return _savedWeights.where((weight) {
      return weight.timestamp.isAfter(startDate) && weight.timestamp.isBefore(endDate);
    }).toList();
  }

  // Get unique object names
  List<String> getUniqueObjectNames() {
    return _savedWeights.map((w) => w.objectName).toSet().toList()..sort();
  }

  // Get category statistics
  Map<String, int> getCategoryStats() {
    final categoryCount = <String, int>{};
    for (final weight in _savedWeights) {
      categoryCount[weight.objectCategory] = (categoryCount[weight.objectCategory] ?? 0) + 1;
    }
    return categoryCount;
  }

  // Export data as CSV string
  String exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Object Name,Category,Weight (kg),Date,Time,Notes');

    for (final weight in _savedWeights) {
      final date = weight.timestamp.toLocal();
      buffer.writeln(
        '${weight.id},"${weight.objectName}","${weight.objectCategory}",${weight.weight},'
        '${date.day}/${date.month}/${date.year},'
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')},'
        '"${weight.notes ?? ''}"',
      );
    }

    return buffer.toString();
  }

  // Clear all data
  Future<bool> clearAllData() async {
    if (_database == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _database!.delete('Table_saveObject');
      _savedWeights.clear();
      _isLoading = false;
      notifyListeners();

      debugPrint('All object weight data cleared');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error clearing object data: $e');
      return false;
    }
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    if (_savedWeights.isEmpty) {
      return {
        'totalRecords': 0,
        'uniqueObjects': 0,
        'uniqueCategories': 0,
        'averageWeight': 0.0,
        'minWeight': 0.0,
        'maxWeight': 0.0,
        'latestRecord': null,
        'categoryStats': <String, int>{},
      };
    }

    final weights = _savedWeights.map((w) => w.weight).toList();
    final uniqueObjects = _savedWeights.map((w) => w.objectName).toSet().length;
    final uniqueCategories = _savedWeights.map((w) => w.objectCategory).toSet().length;
    final categoryStats = getCategoryStats();
    
    return {
      'totalRecords': _savedWeights.length,
      'uniqueObjects': uniqueObjects,
      'uniqueCategories': uniqueCategories,
      'averageWeight': weights.reduce((a, b) => a + b) / weights.length,
      'minWeight': weights.reduce((a, b) => a < b ? a : b),
      'maxWeight': weights.reduce((a, b) => a > b ? a : b),
      'latestRecord': _savedWeights.first,
      'categoryStats': categoryStats,
      // Backward compatibility
      'uniquePeople': uniqueObjects,
    };
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}