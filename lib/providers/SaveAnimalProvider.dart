import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class SavedAnimalWeight {
  final String id;
  final String animalName;
  final String animalType; // เพิ่มประเภทสัตว์
  final double weight;
  final DateTime timestamp;
  final String? notes; // เพิ่มหมายเหตุ

  SavedAnimalWeight({
    required this.id,
    required this.animalName,
    required this.animalType,
    required this.weight,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'animal_name': animalName,
      'animal_type': animalType,
      'weight': weight,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory SavedAnimalWeight.fromMap(Map<String, dynamic> map) {
    return SavedAnimalWeight(
      id: map['id'],
      animalName: map['animal_name'],
      animalType: map['animal_type'],
      weight: map['weight'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      notes: map['notes'],
    );
  }
}

class SaveAnimalProvider extends ChangeNotifier {
  Database? _database;
  final Uuid _uuid = const Uuid();
  List<SavedAnimalWeight> _savedWeights = [];
  bool _isLoading = false;

  List<SavedAnimalWeight> get savedWeights => _savedWeights;
  bool get isLoading => _isLoading;

  // รายการประเภทสัตว์ที่นิยม
  static const List<String> animalTypes = [
    'หมา',
    'แมว', 
    'วัว',
    'หมู',
    'ไก่',
    'เป็ด',
    'แพะ',
    'แกะ',
    'ม้า',
    'กบ',
    'ปลา',
    'นก',
    'กิ้งก่า',
    'งู',
    'เต่า',
    'สัตว์อื่นๆ',
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
            CREATE TABLE Table_saveAnimal (
              id TEXT PRIMARY KEY,
              animal_name TEXT NOT NULL,
              animal_type TEXT NOT NULL,
              weight REAL NOT NULL,
              timestamp INTEGER NOT NULL,
              notes TEXT
            )
          ''');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            // ถ้าตารางเก่าไม่มี animal_type และ notes
            await db.execute('ALTER TABLE Table_saveAnimal ADD COLUMN animal_type TEXT');
            await db.execute('ALTER TABLE Table_saveAnimal ADD COLUMN notes TEXT');
            
            // อัปเดต animal_type เป็นค่าเริ่มต้น
            await db.execute("UPDATE Table_saveAnimal SET animal_type = 'สัตว์อื่นๆ' WHERE animal_type IS NULL");
            
            // เปลี่ยนชื่อ column person_name เป็น animal_name (ถ้ามี)
            await db.execute('ALTER TABLE Table_saveAnimal RENAME COLUMN person_name TO animal_name');
          }
        },
      );

      await loadSavedWeights();
    } catch (e) {
      debugPrint('Error initializing animal database: $e');
    }
  }

  // Save animal weight data
  Future<bool> saveAnimalWeight({
    required String animalName,
    required String animalType,
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

      final savedWeight = SavedAnimalWeight(
        id: _uuid.v4(),
        animalName: animalName.trim(),
        animalType: animalType,
        weight: weight,
        timestamp: DateTime.now(),
        notes: notes?.trim(),
      );

      await _database!.insert(
        'Table_saveAnimal',
        savedWeight.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _savedWeights.insert(0, savedWeight); // Add to beginning of list
      _isLoading = false;
      notifyListeners();

      debugPrint('Animal weight saved successfully: ${savedWeight.animalName} (${savedWeight.animalType}) - ${savedWeight.weight}kg');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error saving animal weight: $e');
      return false;
    }
  }

  // Load all saved weights
  Future<void> loadSavedWeights() async {
    if (_database == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final List<Map<String, dynamic>> maps = await _database!.query(
        'Table_saveAnimal',
        orderBy: 'timestamp DESC',
      );

      _savedWeights = maps.map((map) => SavedAnimalWeight.fromMap(map)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading saved animal weights: $e');
    }
  }

  // Delete saved weight
  Future<bool> deleteWeight(String id) async {
    if (_database == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _database!.delete(
        'Table_saveAnimal',
        where: 'id = ?',
        whereArgs: [id],
      );

      _savedWeights.removeWhere((weight) => weight.id == id);
      _isLoading = false;
      notifyListeners();

      debugPrint('Animal weight deleted successfully: $id');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error deleting animal weight: $e');
      return false;
    }
  }

  // Get weights by animal name
  List<SavedAnimalWeight> getWeightsByAnimal(String animalName) {
    return _savedWeights
        .where((weight) => weight.animalName.toLowerCase() == animalName.toLowerCase())
        .toList();
  }

  // Get weights by animal type
  List<SavedAnimalWeight> getWeightsByType(String animalType) {
    return _savedWeights
        .where((weight) => weight.animalType == animalType)
        .toList();
  }

  // Get latest weight for an animal
  SavedAnimalWeight? getLatestWeightForAnimal(String animalName) {
    final weights = getWeightsByAnimal(animalName);
    return weights.isNotEmpty ? weights.first : null;
  }

  // Get weights within date range
  List<SavedAnimalWeight> getWeightsInRange(DateTime startDate, DateTime endDate) {
    return _savedWeights.where((weight) {
      return weight.timestamp.isAfter(startDate) && weight.timestamp.isBefore(endDate);
    }).toList();
  }

  // Get unique animal names
  List<String> getUniqueAnimalNames() {
    return _savedWeights.map((w) => w.animalName).toSet().toList()..sort();
  }

  // Get animal type statistics
  Map<String, int> getAnimalTypeStats() {
    final typeCount = <String, int>{};
    for (final weight in _savedWeights) {
      typeCount[weight.animalType] = (typeCount[weight.animalType] ?? 0) + 1;
    }
    return typeCount;
  }

  // Export data as CSV string
  String exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Animal Name,Animal Type,Weight (kg),Date,Time,Notes');

    for (final weight in _savedWeights) {
      final date = weight.timestamp.toLocal();
      buffer.writeln(
        '${weight.id},"${weight.animalName}","${weight.animalType}",${weight.weight},'
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

      await _database!.delete('Table_saveAnimal');
      _savedWeights.clear();
      _isLoading = false;
      notifyListeners();

      debugPrint('All animal weight data cleared');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error clearing animal data: $e');
      return false;
    }
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    if (_savedWeights.isEmpty) {
      return {
        'totalRecords': 0,
        'uniqueAnimals': 0,
        'uniqueTypes': 0,
        'averageWeight': 0.0,
        'minWeight': 0.0,
        'maxWeight': 0.0,
        'latestRecord': null,
        'typeStats': <String, int>{},
      };
    }

    final weights = _savedWeights.map((w) => w.weight).toList();
    final uniqueAnimals = _savedWeights.map((w) => w.animalName).toSet().length;
    final uniqueTypes = _savedWeights.map((w) => w.animalType).toSet().length;
    final typeStats = getAnimalTypeStats();
    
    return {
      'totalRecords': _savedWeights.length,
      'uniqueAnimals': uniqueAnimals,
      'uniqueTypes': uniqueTypes,
      'averageWeight': weights.reduce((a, b) => a + b) / weights.length,
      'minWeight': weights.reduce((a, b) => a < b ? a : b),
      'maxWeight': weights.reduce((a, b) => a > b ? a : b),
      'latestRecord': _savedWeights.first,
      'typeStats': typeStats,
    };
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}