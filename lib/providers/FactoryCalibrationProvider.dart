import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class FactoryCalibrationData {
  final String name;
  final String description;
  final List<CalibrationPoint> points;
  final DateTime createdAt;
  final String version;

  FactoryCalibrationData({
    required this.name,
    required this.description,
    required this.points,
    required this.createdAt,
    required this.version,
  });

  factory FactoryCalibrationData.fromJson(Map<String, dynamic> json) {
    return FactoryCalibrationData(
      name: json['name'],
      description: json['description'],
      points: (json['points'] as List)
          .map((point) => CalibrationPoint.fromJson(point))
          .toList(),
      createdAt: DateTime.parse(json['created_at']),
      version: json['version'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'points': points.map((point) => point.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'version': version,
    };
  }
}

class CalibrationPoint {
  final double rawValue;
  final double actualWeight;
  final String notes;

  CalibrationPoint({
    required this.rawValue,
    required this.actualWeight,
    required this.notes,
  });

  factory CalibrationPoint.fromJson(Map<String, dynamic> json) {
    return CalibrationPoint(
      rawValue: json['raw_value'].toDouble(),
      actualWeight: json['actual_weight'].toDouble(),
      notes: json['notes'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'raw_value': rawValue,
      'actual_weight': actualWeight,
      'notes': notes,
    };
  }
}

class FactoryCalibrationProvider extends ChangeNotifier {
  Database? _database;
  List<FactoryCalibrationData> _factoryCalibrations = [];
  bool _isApplying = false;
  String _lastAppliedCalibration = '';

  // Getters
  List<FactoryCalibrationData> get factoryCalibrations => _factoryCalibrations;
  bool get isApplying => _isApplying;
  String get lastAppliedCalibration => _lastAppliedCalibration;

  // Predefined factory calibrations
  static const String _defaultCalibrationsJson = '''
{
  "calibrations": [
    {
      "name": "Standard Scale v1.0",
      "description": "มาตรฐานสำหรับเครื่องชั่งทั่วไป 0-10kg",
      "version": "1.0",
      "created_at": "2024-01-01T00:00:00.000Z",
      "points": [
        {"raw_value": 0.0, "actual_weight": 0.0, "notes": "Zero point - Factory"},
        {"raw_value": 1000.0, "actual_weight": 1.0, "notes": "1kg - Factory"},
        {"raw_value": 5000.0, "actual_weight": 5.0, "notes": "5kg - Factory"},
        {"raw_value": 10000.0, "actual_weight": 10.0, "notes": "10kg - Factory"}
      ]
    },
    {
      "name": "Precision Scale v2.0",
      "description": "มาตรฐานสำหรับเครื่องชั่งความละเอียดสูง 0-5kg",
      "version": "2.0",
      "created_at": "2024-02-01T00:00:00.000Z",
      "points": [
        {"raw_value": 0.0, "actual_weight": 0.0, "notes": "Zero point - Precision"},
        {"raw_value": 500.0, "actual_weight": 0.5, "notes": "500g - Precision"},
        {"raw_value": 1000.0, "actual_weight": 1.0, "notes": "1kg - Precision"},
        {"raw_value": 2500.0, "actual_weight": 2.5, "notes": "2.5kg - Precision"},
        {"raw_value": 5000.0, "actual_weight": 5.0, "notes": "5kg - Precision"}
      ]
    },
    {
      "name": "Heavy Duty Scale v1.5",
      "description": "มาตรฐานสำหรับเครื่องชั่งหนัก 0-50kg",
      "version": "1.5",
      "created_at": "2024-03-01T00:00:00.000Z",
      "points": [
        {"raw_value": 0.0, "actual_weight": 0.0, "notes": "Zero point - Heavy Duty"},
        {"raw_value": 2000.0, "actual_weight": 2.0, "notes": "2kg - Heavy Duty"},
        {"raw_value": 10000.0, "actual_weight": 10.0, "notes": "10kg - Heavy Duty"},
        {"raw_value": 25000.0, "actual_weight": 25.0, "notes": "25kg - Heavy Duty"},
        {"raw_value": 50000.0, "actual_weight": 50.0, "notes": "50kg - Heavy Duty"}
      ]
    },
    {
      "name": "Laboratory Scale v3.0",
      "description": "มาตรฐานสำหรับเครื่องชั่งห้องปฏิบัติการ 0-2kg",
      "version": "3.0",
      "created_at": "2024-04-01T00:00:00.000Z",
      "points": [
        {"raw_value": 0.0, "actual_weight": 0.0, "notes": "Zero point - Lab"},
        {"raw_value": 100.0, "actual_weight": 0.1, "notes": "100g - Lab"},
        {"raw_value": 500.0, "actual_weight": 0.5, "notes": "500g - Lab"},
        {"raw_value": 1000.0, "actual_weight": 1.0, "notes": "1kg - Lab"},
        {"raw_value": 2000.0, "actual_weight": 2.0, "notes": "2kg - Lab"}
      ]
    }
  ]
}''';

  FactoryCalibrationProvider() {
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'factory_calibration.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE factory_calibrations('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'name TEXT NOT NULL, '
          'description TEXT NOT NULL, '
          'calibration_data TEXT NOT NULL, '
          'applied_at INTEGER, '
          'version TEXT NOT NULL'
          ')',
        );
      },
    );

    await _loadPredefinedCalibrations();
    await _loadFactoryCalibrations();
  }

  Future<void> _loadPredefinedCalibrations() async {
    try {
      final Map<String, dynamic> data = json.decode(_defaultCalibrationsJson);
      final List<dynamic> calibrations = data['calibrations'];

      _factoryCalibrations = calibrations
          .map((cal) => FactoryCalibrationData.fromJson(cal))
          .toList();

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading predefined calibrations: $e');
      }
    }
  }

  Future<void> _loadFactoryCalibrations() async {
    if (_database == null) return;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'factory_calibrations',
        orderBy: 'applied_at DESC',
      );

      // Get the last applied calibration
      if (maps.isNotEmpty) {
        _lastAppliedCalibration = maps.first['name'];
      }

      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('Error loading factory calibrations: $e');
      }
    }
  }

  Future<bool> applyFactoryCalibration(
    FactoryCalibrationData factoryCalibration,
    Function(CalibrationPoint, String) addCalibrationPoint,
    Function() clearAllCalibrationData,
  ) async {
    if (_isApplying) return false;

    try {
      _isApplying = true;
      notifyListeners();

      // Clear existing calibration data
      await clearAllCalibrationData();
      
      // Add factory calibration points
      for (CalibrationPoint point in factoryCalibration.points) {
        await addCalibrationPoint(
          point,
          'Factory Calibration: ${factoryCalibration.name}',
        );
        
        // Small delay to show progress
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // Save to database
      await _saveAppliedCalibration(factoryCalibration);
      
      _lastAppliedCalibration = factoryCalibration.name;
      
      if (kDebugMode) {
        print('Applied factory calibration: ${factoryCalibration.name}');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error applying factory calibration: $e');
      }
      return false;
    } finally {
      _isApplying = false;
      notifyListeners();
    }
  }

  Future<void> _saveAppliedCalibration(FactoryCalibrationData calibration) async {
    if (_database == null) return;

    await _database!.insert('factory_calibrations', {
      'name': calibration.name,
      'description': calibration.description,
      'calibration_data': json.encode(calibration.toJson()),
      'applied_at': DateTime.now().millisecondsSinceEpoch,
      'version': calibration.version,
    });
  }

  Future<List<Map<String, dynamic>>> getCalibrationHistory() async {
    if (_database == null) return [];

    return await _database!.query(
      'factory_calibrations',
      orderBy: 'applied_at DESC',
      limit: 10,
    );
  }

  Future<void> clearCalibrationHistory() async {
    if (_database == null) return;

    await _database!.delete('factory_calibrations');
    _lastAppliedCalibration = '';
    notifyListeners();
  }

  // Add custom factory calibration from JSON
  Future<bool> addCustomFactoryCalibration(String jsonString) async {
    try {
      final Map<String, dynamic> data = json.decode(jsonString);
      final FactoryCalibrationData customCalibration = FactoryCalibrationData.fromJson(data);
      
      _factoryCalibrations.add(customCalibration);
      notifyListeners();
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding custom factory calibration: $e');
      }
      return false;
    }
  }

  // Export factory calibration as JSON
  String exportFactoryCalibration(FactoryCalibrationData calibration) {
    return json.encode(calibration.toJson());
  }

  // Get calibration info
  String getCalibrationInfo(FactoryCalibrationData calibration) {
    StringBuffer info = StringBuffer();
    info.writeln('Name: ${calibration.name}');
    info.writeln('Description: ${calibration.description}');
    info.writeln('Version: ${calibration.version}');
    info.writeln('Points: ${calibration.points.length}');
    info.writeln('Created: ${calibration.createdAt.toString().substring(0, 19)}');
    
    info.writeln('\nCalibration Points:');
    for (int i = 0; i < calibration.points.length; i++) {
      final point = calibration.points[i];
      info.writeln('${i + 1}. Raw: ${point.rawValue} → Weight: ${point.actualWeight} kg');
    }
    
    return info.toString();
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}