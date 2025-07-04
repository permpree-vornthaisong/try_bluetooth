import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class CalibrationData {
  final int? id;
  final double rawValue;
  final double actualWeight;
  final DateTime timestamp;
  final String? notes;

  CalibrationData({
    this.id,
    required this.rawValue,
    required this.actualWeight,
    required this.timestamp,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'raw_value': rawValue,
      'actual_weight': actualWeight,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory CalibrationData.fromMap(Map<String, dynamic> map) {
    return CalibrationData(
      id: map['id'],
      rawValue: map['raw_value'],
      actualWeight: map['actual_weight'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      notes: map['notes'],
    );
  }
}

class CalibrationProvider extends ChangeNotifier {
  // Database
  Database? _database;
  
  // Calibration data
  List<CalibrationData> _calibrationPoints = [];
  double? _slope;
  double? _intercept;
  bool _isCalibrated = false;
  
  // Current calibration process
  bool _isCalibrating = false;
  double? _currentRawValue;
  String _calibrationStep = 'idle'; // 'idle', 'waiting_for_weight', 'enter_actual_weight'
  
  // Quick calibration process
  bool _isQuickCalibrating = false;
  double? _zeroValue; // ค่าเมื่อไม่มีน้ำหนัก
  double? _weightedValue; // ค่าเมื่อมีน้ำหนัก
  double? _knownWeight; // น้ำหนักที่ทราบ
  String _quickCalibrationStep = 'idle'; // 'idle', 'waiting_zero', 'waiting_weight'
  
  // Average calculation for readings
  List<double> _recentReadings = [];
  int _maxReadingsForAverage = 10;
  bool _useAverageForCalibration = true;
  
  // Stats
  double? _averageError;
  double? _maxError;
  int _totalCalibrations = 0;

  // Getters
  List<CalibrationData> get calibrationPoints => _calibrationPoints;
  double? get slope => _slope;
  double? get intercept => _intercept;
  bool get isCalibrated => _isCalibrated;
  bool get isCalibrating => _isCalibrating;
  double? get currentRawValue => _currentRawValue;
  String get calibrationStep => _calibrationStep;
  double? get averageError => _averageError;
  double? get maxError => _maxError;
  int get totalCalibrations => _totalCalibrations;
  
  // Quick calibration getters
  bool get isQuickCalibrating => _isQuickCalibrating;
  String get quickCalibrationStep => _quickCalibrationStep;
  double? get zeroValue => _zeroValue;
  double? get weightedValue => _weightedValue;
  double? get knownWeight => _knownWeight;
  
  // Average calculation getters
  List<double> get recentReadings => List.unmodifiable(_recentReadings);
  int get maxReadingsForAverage => _maxReadingsForAverage;
  bool get useAverageForCalibration => _useAverageForCalibration;
  double? get currentAverageReading => _recentReadings.isEmpty ? null : _recentReadings.reduce((a, b) => a + b) / _recentReadings.length;

  CalibrationProvider() {
    _initializeDatabase();
  }

  // Method to add new reading and maintain running average
  void addReading(double reading) {
    _recentReadings.add(reading);
    
    // Keep only the last N readings for average calculation
    if (_recentReadings.length > _maxReadingsForAverage) {
      _recentReadings.removeAt(0);
    }
    
    notifyListeners();
    
    if (kDebugMode) {
      print('Added reading: $reading, Current average: ${currentAverageReading?.toStringAsFixed(3)}');
    }
  }

  // Method to get the value to use for calibration (average or current)
  double? getValueForCalibration() {
    if (_useAverageForCalibration && _recentReadings.isNotEmpty) {
      return currentAverageReading;
    }
    return _recentReadings.isNotEmpty ? _recentReadings.last : null;
  }

  // Method to set whether to use average for calibration
  void setUseAverageForCalibration(bool useAverage) {
    _useAverageForCalibration = useAverage;
    notifyListeners();
  }

  // Method to set max readings for average
  void setMaxReadingsForAverage(int maxReadings) {
    if (maxReadings > 0) {
      _maxReadingsForAverage = maxReadings;
      
      // Trim existing readings if new max is smaller
      while (_recentReadings.length > _maxReadingsForAverage) {
        _recentReadings.removeAt(0);
      }
      
      notifyListeners();
    }
  }

  // Method to clear recent readings
  void clearRecentReadings() {
    _recentReadings.clear();
    notifyListeners();
  }

  // Method to get statistics of recent readings
  Map<String, double> getReadingStatistics() {
    if (_recentReadings.isEmpty) {
      return {'count': 0, 'average': 0, 'min': 0, 'max': 0, 'standardDeviation': 0};
    }

    double average = currentAverageReading!;
    double min = _recentReadings.reduce((a, b) => a < b ? a : b);
    double max = _recentReadings.reduce((a, b) => a > b ? a : b);
    
    // Calculate standard deviation
    double variance = _recentReadings
        .map((reading) => (reading - average) * (reading - average))
        .reduce((a, b) => a + b) / _recentReadings.length;
    double standardDeviation = variance.isFinite ? variance : 0.0;

    return {
      'count': _recentReadings.length.toDouble(),
      'average': average,
      'min': min,
      'max': max,
      'standardDeviation': standardDeviation,
    };
  }

  Future<void> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'calibration.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE calibration_data('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'raw_value REAL NOT NULL, '
          'actual_weight REAL NOT NULL, '
          'timestamp INTEGER NOT NULL, '
          'notes TEXT'
          ')',
        );
      },
    );

    await _loadCalibrationData();
    _calculateCalibration();
  }

  Future<void> _loadCalibrationData() async {
    if (_database == null) return;

    final List<Map<String, dynamic>> maps = await _database!.query(
      'calibration_data',
      orderBy: 'timestamp DESC',
    );

    _calibrationPoints = maps.map((map) => CalibrationData.fromMap(map)).toList();
    _totalCalibrations = _calibrationPoints.length;
    notifyListeners();
  }

  Future<void> addCalibrationPoint(double rawValue, double actualWeight, {String? notes}) async {
    if (_database == null) return;

    final calibrationData = CalibrationData(
      rawValue: rawValue,
      actualWeight: actualWeight,
      timestamp: DateTime.now(),
      notes: notes,
    );

    final id = await _database!.insert('calibration_data', calibrationData.toMap());
    
    // Add to local list with the generated ID
    final newCalibrationData = CalibrationData(
      id: id,
      rawValue: rawValue,
      actualWeight: actualWeight,
      timestamp: calibrationData.timestamp,
      notes: notes,
    );

    _calibrationPoints.insert(0, newCalibrationData); // Insert at beginning (newest first)
    _totalCalibrations++;
    
    _calculateCalibration();
    _calculateStats();
    notifyListeners();
  }

  Future<void> removeCalibrationPoint(int id) async {
    if (_database == null) return;

    await _database!.delete('calibration_data', where: 'id = ?', whereArgs: [id]);
    _calibrationPoints.removeWhere((point) => point.id == id);
    _totalCalibrations--;
    
    _calculateCalibration();
    _calculateStats();
    notifyListeners();
  }

  Future<void> clearAllCalibrationData() async {
    if (_database == null) return;

    await _database!.delete('calibration_data');
    _calibrationPoints.clear();
    _totalCalibrations = 0;
    _slope = null;
    _intercept = null;
    _isCalibrated = false;
    _averageError = null;
    _maxError = null;
    
    notifyListeners();
  }


  void _calculateCalibration() {
    if (_calibrationPoints.length < 2) {
      _slope = null;
      _intercept = null;
      _isCalibrated = false;
      return;
    }

    // Linear regression: y = mx + b
    // where y = actual weight, x = raw value
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = _calibrationPoints.length;

    for (var point in _calibrationPoints) {
      sumX += point.rawValue;
      sumY += point.actualWeight;
      sumXY += point.rawValue * point.actualWeight;
      sumX2 += point.rawValue * point.rawValue;
    }

    // Calculate slope (m) and intercept (b)
    _slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    _intercept = (sumY - _slope! * sumX) / n;
    _isCalibrated = true;

    if (kDebugMode) {
      print('Calibration calculated: slope = $_slope, intercept = $_intercept');
    }
  }

  void _calculateStats() {
    if (!_isCalibrated || _calibrationPoints.isEmpty) {
      _averageError = null;
      _maxError = null;
      return;
    }

    double totalError = 0;
    double maxErr = 0;

    for (var point in _calibrationPoints) {
      double predictedWeight = convertRawToWeight(point.rawValue);
      double error = (predictedWeight - point.actualWeight).abs();
      totalError += error;
      if (error > maxErr) maxErr = error;
    }

    _averageError = totalError / _calibrationPoints.length;
    _maxError = maxErr;
  }

  double convertRawToWeight(double rawValue) {
    if (!_isCalibrated || _slope == null || _intercept == null) {
      return rawValue; // Return raw value if not calibrated
    }
    return _slope! * rawValue + _intercept!;
  }

  void startCalibration(double rawValue) {
    _isCalibrating = true;
    _currentRawValue = rawValue;
    _calibrationStep = 'enter_actual_weight';
    notifyListeners();
  }

  void cancelCalibration() {
    _isCalibrating = false;
    _currentRawValue = null;
    _calibrationStep = 'idle';
    notifyListeners();
  }

  Future<void> completeCalibration(double actualWeight, {String? notes}) async {
    if (_currentRawValue != null) {
      await addCalibrationPoint(_currentRawValue!, actualWeight, notes: notes);
      _isCalibrating = false;
      _currentRawValue = null;
      _calibrationStep = 'idle';
      notifyListeners();
    }
  }

  void updateCurrentRawValue(double rawValue) {
    _currentRawValue = rawValue;
    if (_calibrationStep == 'idle') {
      _calibrationStep = 'waiting_for_weight';
    }
    notifyListeners();
  }

  // Quick calibration methods
  void startQuickCalibration() {
    _isQuickCalibrating = true;
    _quickCalibrationStep = 'waiting_zero';
    _zeroValue = null;
    _weightedValue = null;
    _knownWeight = null;
    notifyListeners();
  }

  void captureZeroReading(double rawValue) {
    if (_quickCalibrationStep == 'waiting_zero') {
      // Use average if available and enabled
      double valueToUse = _useAverageForCalibration && currentAverageReading != null 
          ? currentAverageReading! 
          : rawValue;
      
      _zeroValue = valueToUse;
      _quickCalibrationStep = 'waiting_weight';
      notifyListeners();
      
      if (kDebugMode) {
        print('Captured zero reading: $valueToUse (from ${_useAverageForCalibration ? 'average' : 'current'})');
      }
    }
  }

  Future<void> captureWeightReading(double rawValue, double knownWeight) async {
    if (_quickCalibrationStep == 'waiting_weight' && _zeroValue != null) {
      // Use average if available and enabled
      double valueToUse = _useAverageForCalibration && currentAverageReading != null 
          ? currentAverageReading! 
          : rawValue;
      
      _weightedValue = valueToUse;
      _knownWeight = knownWeight;
      
      // Add two calibration points automatically
      await addCalibrationPoint(_zeroValue!, 0.0, notes: 'Zero point (Quick Cal - ${_useAverageForCalibration ? 'Average' : 'Single'})');
      await addCalibrationPoint(_weightedValue!, _knownWeight!, notes: 'Weight point (Quick Cal - ${_useAverageForCalibration ? 'Average' : 'Single'})');
      
      // Complete quick calibration
      _isQuickCalibrating = false;
      _quickCalibrationStep = 'idle';
      notifyListeners();
      
      if (kDebugMode) {
        print('Captured weight reading: $valueToUse for $knownWeight kg (from ${_useAverageForCalibration ? 'average' : 'current'})');
      }
    }
  }

  void cancelQuickCalibration() {
    _isQuickCalibrating = false;
    _quickCalibrationStep = 'idle';
    _zeroValue = null;
    _weightedValue = null;
    _knownWeight = null;
    notifyListeners();
  }

  // Get calibration accuracy percentage
  double getCalibrationAccuracy() {
    if (_averageError == null || _calibrationPoints.isEmpty) return 0.0;
    
    double avgActualWeight = _calibrationPoints
        .map((p) => p.actualWeight)
        .reduce((a, b) => a + b) / _calibrationPoints.length;
    
    if (avgActualWeight == 0) return 0.0;
    
    double accuracyPercent = (1.0 - (_averageError! / avgActualWeight)) * 100;
    return accuracyPercent.clamp(0.0, 100.0);
  }

  // Export calibration data
  String exportCalibrationData() {
    StringBuffer buffer = StringBuffer();
    buffer.writeln('Calibration Data Export');
    buffer.writeln('Exported: ${DateTime.now()}');
    buffer.writeln('Total Points: ${_calibrationPoints.length}');
    if (_isCalibrated) {
      buffer.writeln('Slope: $_slope');
      buffer.writeln('Intercept: $_intercept');
      buffer.writeln('Average Error: $_averageError');
      buffer.writeln('Max Error: $_maxError');
      buffer.writeln('Accuracy: ${getCalibrationAccuracy().toStringAsFixed(2)}%');
    }
    buffer.writeln();
    buffer.writeln('Raw Value\tActual Weight\tTimestamp\tNotes');
    
    for (var point in _calibrationPoints) {
      buffer.writeln('${point.rawValue}\t${point.actualWeight}\t${point.timestamp}\t${point.notes ?? ''}');
    }
    
    return buffer.toString();
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }
}