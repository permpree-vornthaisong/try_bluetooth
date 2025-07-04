import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:try_bluetooth/providers/SettingProvider.dart';

class CalibrationEasy extends ChangeNotifier {
  // Database
  Database? _database;

  // Calibration data
  double? _zeroPoint; // Raw value สำหรับ 0 kg
  double? _referencePoint; // Raw value สำหรับ x kg
  double? _referenceWeight; // น้ำหนักจริงของ reference point

  // Two-point calibration coefficients
  double? _slope; // m
  double? _intercept; // b

  // Current data collection
  List<double> _currentReadings = [];
  bool _isCollectingZero = false;
  bool _isCollectingReference = false;
  int _targetReadings = 10;
  Timer? _collectionTimer;

  // Data source - เชื่อมต่อกับ SettingProvider โดยตรง
  Function? _getRawValueFunction;

  // Status
  bool _isCalibrated = false;
  String _statusMessage = 'ยังไม่ได้ Calibrate';

  // Getters
  bool get isCalibrated => _isCalibrated;
  String get statusMessage => _statusMessage;
  double? get zeroPoint => _zeroPoint;
  double? get referencePoint => _referencePoint;
  double? get referenceWeight => _referenceWeight;
  double? get slope => _slope;
  double? get intercept => _intercept;
  int get currentReadingsCount => _currentReadings.length;
  int get targetReadings => _targetReadings;
  bool get isCollectingZero => _isCollectingZero;
  bool get isCollectingReference => _isCollectingReference;
  bool get isCollecting => _isCollectingZero || _isCollectingReference;

  // Progress percentage for UI
  double get collectionProgress => _currentReadings.length / _targetReadings;

  // Initialize
  Future<void> initialize() async {
    await _initDatabase();
    await _loadCalibrationData();
    _updateStatus();
  }

  // Database initialization
  Future<void> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'calibration_easy.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (Database db, int version) async {
          await db.execute('''
            CREATE TABLE calibration_data (
              id INTEGER PRIMARY KEY,
              zero_point REAL,
              reference_point REAL,
              reference_weight REAL,
              slope REAL,
              intercept REAL,
              created_at TEXT,
              updated_at TEXT
            )
          ''');

          // Insert default row
          await db.insert('calibration_data', {
            'id': 1,
            'zero_point': null,
            'reference_point': null,
            'reference_weight': null,
            'slope': null,
            'intercept': null,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        },
      );
    } catch (e) {
      print('Database initialization error: $e');
      _statusMessage = 'Database Error: $e';
      notifyListeners();
    }
  }

  // Load calibration data from database
  Future<void> _loadCalibrationData() async {
    if (_database == null) return;

    try {
      final List<Map<String, dynamic>> maps = await _database!.query(
        'calibration_data',
        where: 'id = ?',
        whereArgs: [1],
      );

      if (maps.isNotEmpty) {
        final data = maps.first;
        _zeroPoint = data['zero_point'];
        _referencePoint = data['reference_point'];
        _referenceWeight = data['reference_weight'];
        _slope = data['slope'];
        _intercept = data['intercept'];

        _isCalibrated = _slope != null && _intercept != null;
      }
    } catch (e) {
      print('Load calibration data error: $e');
    }
  }

  // Save calibration data to database
  Future<void> _saveCalibrationData() async {
    if (_database == null) return;

    try {
      await _database!.update(
        'calibration_data',
        {
          'zero_point': _zeroPoint,
          'reference_point': _referencePoint,
          'reference_weight': _referenceWeight,
          'slope': _slope,
          'intercept': _intercept,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [1],
      );
    } catch (e) {
      print('Save calibration data error: $e');
    }
  }

  // Set function to get raw value from SettingProvider
  void setRawValueGetter(double? Function() getRawValue) {
    _getRawValueFunction = getRawValue;
  }

  // ✅ เพิ่ม method ใหม่ - เชื่อมต่อกับ SettingProvider โดยตรง
  void connectToSettingProvider(SettingProvider settingProvider) {
    _getRawValueFunction = () => settingProvider.getRawValueForCalibration();
    print('CalibrationEasy connected to SettingProvider');
  }

  // 1. Calibration First - 0kg
  Future<void> calibrationFirst_0kg() async {
    if (isCollecting) {
      _statusMessage = 'กำลัง Collect ข้อมูลอยู่';
      notifyListeners();
      return;
    }

    if (_getRawValueFunction == null) {
      _statusMessage = 'ยังไม่ได้เชื่อมต่อกับ SettingProvider';
      notifyListeners();
      return;
    }

    // ✅ ตรวจสอบว่ามีข้อมูล raw value หรือไม่
    double? currentRaw = _getRawValueFunction!();
    if (currentRaw == null || currentRaw <= 0) {
      _statusMessage = 'ไม่มีข้อมูล Raw Value จาก Bluetooth';
      notifyListeners();
      return;
    }

    print('Starting 0kg calibration with current raw value: $currentRaw');

    _startCollection(isZeroPoint: true);
    _statusMessage =
        'กำลัง Collect ข้อมูล 0 kg (${_currentReadings.length}/$_targetReadings)';
    notifyListeners();

    // เริ่มการ collect ข้อมูล
    _startAutoCollection();
  }

  // 2. Calibration Last - X kg
  Future<void> calibrationLast_xkg(double weightKg) async {
    if (isCollecting) {
      _statusMessage = 'กำลัง Collect ข้อมูลอยู่';
      notifyListeners();
      return;
    }

    if (_getRawValueFunction == null) {
      _statusMessage = 'ยังไม่ได้เชื่อมต่อกับ SettingProvider';
      notifyListeners();
      return;
    }

    if (_zeroPoint == null) {
      _statusMessage = 'ต้อง Calibrate 0 kg ก่อน';
      notifyListeners();
      return;
    }

    if (weightKg <= 0) {
      _statusMessage = 'น้ำหนักต้องมากกว่า 0';
      notifyListeners();
      return;
    }

    // ✅ ตรวจสอบว่ามีข้อมูล raw value หรือไม่
    double? currentRaw = _getRawValueFunction!();
    if (currentRaw == null || currentRaw <= 0) {
      _statusMessage = 'ไม่มีข้อมูล Raw Value จาก Bluetooth';
      notifyListeners();
      return;
    }

    print(
      'Starting ${weightKg}kg calibration with current raw value: $currentRaw',
    );

    _referenceWeight = weightKg;
    _startCollection(isZeroPoint: false);
    _statusMessage =
        'กำลัง Collect ข้อมูล $weightKg kg (${_currentReadings.length}/$_targetReadings)';
    notifyListeners();

    // เริ่มการ collect ข้อมูล
    _startAutoCollection();
  }

  // เริ่มการ collect ข้อมูลอัตโนมัติ
  void _startAutoCollection() {
    // ตั้ง Timer สำหรับ collect ข้อมูลทุก 200ms
    _collectionTimer = Timer.periodic(Duration(milliseconds: 200), (timer) {
      // Use the getter instead of the undefined _isCollecting
      if (!isCollecting) {
        timer.cancel();
        return;
      }

      // ดึงข้อมูล raw value จาก SettingProvider
      double? rawValue = _getRawValueFunction?.call();

      // ✅ แก้ไขเงื่อนไข - รับค่า raw value ทุกค่าที่ไม่ใช่ null
      if (rawValue != null) {
        _currentReadings.add(rawValue);

        print(
          'Collected raw value: $rawValue (${_currentReadings.length}/$_targetReadings)',
        );

        // อัพเดทสถานะ
        if (_isCollectingZero) {
          _statusMessage =
              'กำลัง Collect ข้อมูล 0 kg (${_currentReadings.length}/$_targetReadings)';
        } else if (_isCollectingReference) {
          _statusMessage =
              'กำลัง Collect ข้อมูล $_referenceWeight kg (${_currentReadings.length}/$_targetReadings)';
        }

        notifyListeners();

        // ตรวจสอบว่าครบจำนวนแล้วหรือยัง
        if (_currentReadings.length >= _targetReadings) {
          timer.cancel();
          _finishCollection();
        }
      } else {
        print('No raw value received from SettingProvider');
      }
    });

    // Safety timeout - หยุดหลัง 30 วินาทีไม่ว่าจะครบหรือไม่
    Timer(Duration(seconds: 30), () {
      if (isCollecting && _currentReadings.isNotEmpty) {
        _collectionTimer?.cancel();
        _finishCollection();
        print(
          'Collection finished by timeout with ${_currentReadings.length} readings',
        );
      } else if (isCollecting && _currentReadings.isEmpty) {
        _collectionTimer?.cancel();
        _statusMessage = 'ไม่ได้รับข้อมูลจาก Bluetooth (Timeout)';
        _stopCollection();
        print('Collection timeout - no data received');
      }
    });
  }

  // Start data collection
  void _startCollection({required bool isZeroPoint}) {
    _currentReadings.clear();
    _isCollectingZero = isZeroPoint;
    _isCollectingReference = !isZeroPoint;
    _collectionTimer?.cancel();
  }

  // Finish data collection and calculate average
  void _finishCollection() {
    _collectionTimer?.cancel();

    if (_currentReadings.isEmpty) {
      _statusMessage = 'ไม่มีข้อมูลสำหรับ Calibrate';
      _stopCollection();
      return;
    }

    // Calculate average
    double average =
        _currentReadings.reduce((a, b) => a + b) / _currentReadings.length;

    if (_isCollectingZero) {
      _zeroPoint = average;
      _statusMessage =
          'Calibrate 0 kg เสร็จ (เฉลี่ย: ${average.toStringAsFixed(2)})';
    } else if (_isCollectingReference) {
      _referencePoint = average;
      _calculateTwoPointCalibration();
      _statusMessage =
          'Calibrate ${_referenceWeight} kg เสร็จ (เฉลี่ย: ${average.toStringAsFixed(2)})';
    }

    _stopCollection();
    _saveCalibrationData();
    _updateStatus();
  }

  // Stop data collection
  void _stopCollection() {
    _isCollectingZero = false;
    _isCollectingReference = false;
    _currentReadings.clear();
    _collectionTimer?.cancel();
    notifyListeners();
  }

  // Calculate two-point calibration
  void _calculateTwoPointCalibration() {
    if (_zeroPoint == null ||
        _referencePoint == null ||
        _referenceWeight == null) {
      return;
    }

    // Two-point calibration formula
    // y = mx + b
    // Point 1: (_zeroPoint, 0)
    // Point 2: (_referencePoint, _referenceWeight)

    double x1 = _zeroPoint!;
    double y1 = 0.0;
    double x2 = _referencePoint!;
    double y2 = _referenceWeight!;

    // Calculate slope (m)
    _slope = (y2 - y1) / (x2 - x1);

    // Calculate intercept (b)
    _intercept = y1 - _slope! * x1;

    _isCalibrated = true;

    print('Calibration completed:');
    print('Zero point: $_zeroPoint');
    print('Reference point: $_referencePoint (${_referenceWeight} kg)');
    print('Slope: $_slope');
    print('Intercept: $_intercept');
    print('Formula: Weight = $_slope × RawValue + $_intercept');
  }

  // 3. Give Weight - แปลง raw value เป็น weight
  double giveWeight(double rawValue) {
    if (!_isCalibrated || _slope == null || _intercept == null) {
      return 0.0; // หรือ throw exception
    }

    double weight = _slope! * rawValue + _intercept!;

    // ป้องกันค่าติดลบ
    return weight < 0 ? 0.0 : weight;
  }

  // Get weight from current raw value (สำหรับแสดงใน UI)
  double getCurrentWeight(double currentRawValue) {
    return giveWeight(currentRawValue);
  }

  // Update status message
  void _updateStatus() {
    if (_isCalibrated) {
      _statusMessage = 'Calibrated ✅ (${_referenceWeight} kg)';
    } else if (_zeroPoint != null && _referencePoint == null) {
      _statusMessage = 'ต้อง Calibrate น้ำหนัก Reference';
    } else if (_zeroPoint == null) {
      _statusMessage = 'ต้อง Calibrate 0 kg ก่อน';
    } else {
      _statusMessage = 'ยังไม่ได้ Calibrate';
    }
    notifyListeners();
  }

  // Reset calibration
  Future<void> resetCalibration() async {
    _zeroPoint = null;
    _referencePoint = null;
    _referenceWeight = null;
    _slope = null;
    _intercept = null;
    _isCalibrated = false;
    _stopCollection();

    await _saveCalibrationData();
    _updateStatus();
  }

  // Get calibration info for display
  Map<String, dynamic> getCalibrationInfo() {
    return {
      'isCalibrated': _isCalibrated,
      'zeroPoint': _zeroPoint,
      'referencePoint': _referencePoint,
      'referenceWeight': _referenceWeight,
      'slope': _slope,
      'intercept': _intercept,
      'formula':
          _isCalibrated
              ? 'Weight = ${_slope?.toStringAsFixed(6)} × Raw + ${_intercept?.toStringAsFixed(3)}'
              : 'Not calibrated',
    };
  }

  // Validate current calibration
  bool validateCalibration(
    double testRawValue,
    double expectedWeight, {
    double tolerance = 0.1,
  }) {
    if (!_isCalibrated) return false;

    double calculatedWeight = giveWeight(testRawValue);
    double error = (calculatedWeight - expectedWeight).abs();

    return error <= tolerance;
  }

  // Set target readings count
  void setTargetReadings(int count) {
    if (count > 0 && count <= 100) {
      _targetReadings = count;
      notifyListeners();
    }
  }

  // Cancel current collection
  void cancelCollection() {
    if (isCollecting) {
      _collectionTimer?.cancel();
      _stopCollection();
      _statusMessage = 'ยกเลิกการ Collect ข้อมูล';
      notifyListeners();
    }
  }

  // Manual add reading (สำหรับทดสอบ)
  void addManualReading(double rawValue) {
    if (isCollecting) {
      _currentReadings.add(rawValue);

      print(
        'Manual reading added: $rawValue (${_currentReadings.length}/$_targetReadings)',
      );

      // อัพเดทสถานะ
      if (_isCollectingZero) {
        _statusMessage =
            'กำลัง Collect ข้อมูล 0 kg (${_currentReadings.length}/$_targetReadings)';
      } else if (_isCollectingReference) {
        _statusMessage =
            'กำลัง Collect ข้อมูล $_referenceWeight kg (${_currentReadings.length}/$_targetReadings)';
      }

      notifyListeners();

      // ตรวจสอบว่าครบจำนวนแล้วหรือยัง
      if (_currentReadings.length >= _targetReadings) {
        _collectionTimer?.cancel();
        _finishCollection();
      }
    }
  }

  @override
  void dispose() {
    _collectionTimer?.cancel();
    _database?.close();
    super.dispose();
  }
}

// Extension สำหรับ formatting
extension CalibrationEasyFormatting on CalibrationEasy {
  String get formattedFormula {
    if (!isCalibrated || slope == null || intercept == null) {
      return 'Not calibrated';
    }

    String slopeStr = slope!.toStringAsFixed(6);
    String interceptStr = intercept!.toStringAsFixed(3);
    String sign = intercept! >= 0 ? '+' : '';

    return 'Weight = $slopeStr × Raw $sign $interceptStr';
  }

  String get calibrationSummary {
    if (!isCalibrated) return 'ยังไม่ได้ Calibrate';

    return '''
Calibration Summary:
• Zero Point: ${zeroPoint?.toStringAsFixed(2)} (0 kg)
• Reference Point: ${referencePoint?.toStringAsFixed(2)} (${referenceWeight} kg)
• Formula: $formattedFormula
• Status: $statusMessage
    ''';
  }
}
