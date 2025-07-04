import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

class SavedWeight {
  final String id;
  final String personName;
  final double weight;
  final DateTime timestamp;

  SavedWeight({
    required this.id,
    required this.personName,
    required this.weight,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'person_name': personName,
      'weight': weight,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  factory SavedWeight.fromMap(Map<String, dynamic> map) {
    return SavedWeight(
      id: map['id'],
      personName: map['person_name'],
      weight: map['weight'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
    );
  }
}

class SaveHumanProvider extends ChangeNotifier {
  Database? _database;
  final Uuid _uuid = const Uuid();
  List<SavedWeight> _savedWeights = [];
  bool _isLoading = false;

  List<SavedWeight> get savedWeights => _savedWeights;
  bool get isLoading => _isLoading;

  // Initialize database
  Future<void> initDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'weight_app.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE Table_saveHuman (
              id TEXT PRIMARY KEY,
              person_name TEXT NOT NULL,
              weight REAL NOT NULL,
              timestamp INTEGER NOT NULL
            )
          ''');
        },
      );

      await loadSavedWeights();
    } catch (e) {
      debugPrint('Error initializing database: $e');
    }
  }

  // Save weight data
  Future<bool> saveWeight({
    required String personName,
    required double weight,
  }) async {
    if (_database == null) {
      debugPrint('Database not initialized');
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final savedWeight = SavedWeight(
        id: _uuid.v4(),
        personName: personName.trim(),
        weight: weight,
        timestamp: DateTime.now(),
      );

      await _database!.insert(
        'Table_saveHuman',
        savedWeight.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _savedWeights.insert(0, savedWeight); // Add to beginning of list
      _isLoading = false;
      notifyListeners();

      debugPrint('Weight saved successfully: ${savedWeight.personName} - ${savedWeight.weight}kg');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error saving weight: $e');
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
        'Table_saveHuman',
        orderBy: 'timestamp DESC',
      );

      _savedWeights = maps.map((map) => SavedWeight.fromMap(map)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading saved weights: $e');
    }
  }

  // Delete saved weight
  Future<bool> deleteWeight(String id) async {
    if (_database == null) return false;

    try {
      _isLoading = true;
      notifyListeners();

      await _database!.delete(
        'Table_saveHuman',
        where: 'id = ?',
        whereArgs: [id],
      );

      _savedWeights.removeWhere((weight) => weight.id == id);
      _isLoading = false;
      notifyListeners();

      debugPrint('Weight deleted successfully: $id');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error deleting weight: $e');
      return false;
    }
  }

  // Get weights by person name
  List<SavedWeight> getWeightsByPerson(String personName) {
    return _savedWeights
        .where((weight) => weight.personName.toLowerCase() == personName.toLowerCase())
        .toList();
  }

  // Get latest weight for a person
  SavedWeight? getLatestWeightForPerson(String personName) {
    final weights = getWeightsByPerson(personName);
    return weights.isNotEmpty ? weights.first : null;
  }

  // Get weights within date range
  List<SavedWeight> getWeightsInRange(DateTime startDate, DateTime endDate) {
    return _savedWeights.where((weight) {
      return weight.timestamp.isAfter(startDate) && weight.timestamp.isBefore(endDate);
    }).toList();
  }

  // Export data as CSV string
  String exportToCSV() {
    final buffer = StringBuffer();
    buffer.writeln('ID,Person Name,Weight (kg),Date,Time');

    for (final weight in _savedWeights) {
      final date = weight.timestamp.toLocal();
      buffer.writeln(
        '${weight.id},"${weight.personName}",${weight.weight},'
        '${date.day}/${date.month}/${date.year},'
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second.toString().padLeft(2, '0')}',
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

      await _database!.delete('Table_saveHuman');
      _savedWeights.clear();
      _isLoading = false;
      notifyListeners();

      debugPrint('All weight data cleared');
      return true;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error clearing data: $e');
      return false;
    }
  }

  // Get statistics
  Map<String, dynamic> getStatistics() {
    if (_savedWeights.isEmpty) {
      return {
        'totalRecords': 0,
        'uniquePeople': 0,
        'averageWeight': 0.0,
        'minWeight': 0.0,
        'maxWeight': 0.0,
        'latestRecord': null,
      };
    }

    final weights = _savedWeights.map((w) => w.weight).toList();
    final uniquePeople = _savedWeights.map((w) => w.personName).toSet().length;
    
    return {
      'totalRecords': _savedWeights.length,
      'uniquePeople': uniquePeople,
      'averageWeight': weights.reduce((a, b) => a + b) / weights.length,
      'minWeight': weights.reduce((a, b) => a < b ? a : b),
      'maxWeight': weights.reduce((a, b) => a > b ? a : b),
      'latestRecord': _savedWeights.first,
    };
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}