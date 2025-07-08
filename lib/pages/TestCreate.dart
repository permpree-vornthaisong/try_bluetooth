import 'package:flutter/material.dart';
import 'package:try_bluetooth/providers/GenericSaveService.dart';

/// Test class สำหรับทดสอบการสร้างตารางและบันทึกข้อมูล
class TestCreate {
  final GenericSaveService saveService;

  TestCreate(this.saveService);

  // ========== สร้างตารางทดสอบ ==========

  /// สร้างตารางสำหรับข้อมูลคน (Lab Weights Human)
  Future<bool> createLabWeightsHumanTable() async {
    debugPrint('📋 Creating lab_weights_Human table...');

    final success = await saveService.createWeightTable(
      tableName: 'lab_weights_Human',
      extraColumns: {
        'lab_id': 'TEXT',
        'operator': 'TEXT',
        'equipment_id': 'TEXT',
        'temperature': 'REAL',
        'humidity': 'REAL',
        'name': 'TEXT',
        'age': 'INTEGER',
        'gender': 'TEXT',
        'height': 'REAL',
        'medical_condition': 'TEXT',
      },
    );

    if (success) {
      debugPrint('✅ lab_weights_Human table created successfully');
    } else {
      debugPrint(
        '❌ Failed to create lab_weights_Human table: ${saveService.lastError}',
      );
    }
    return success;
  }

  /// สร้างตารางสำหรับข้อมูลสัตว์ (Lab Weights Animal)
  Future<bool> createLabWeightsAnimalTable() async {
    debugPrint('📋 Creating lab_weights_Animal table...');

    final success = await saveService.createWeightTable(
      tableName: 'lab_weights_Animal',
      extraColumns: {
        'lab_id': 'TEXT',
        'operator': 'TEXT',
        'equipment_id': 'TEXT',
        'temperature': 'REAL',
        'humidity': 'REAL',
        'species': 'TEXT',
        'breed': 'TEXT',
        'animal_id': 'TEXT',
        'owner': 'TEXT',
        'vaccination_status': 'TEXT',
      },
    );

    if (success) {
      debugPrint('✅ lab_weights_Animal table created successfully');
    } else {
      debugPrint(
        '❌ Failed to create lab_weights_Animal table: ${saveService.lastError}',
      );
    }
    return success;
  }

  /// สร้างตารางสำหรับข้อมูลสิ่งของ (Lab Weights Object)
  Future<bool> createLabWeightsObjectTable() async {
    debugPrint('📋 Creating lab_weights_Object table...');

    final success = await saveService.createWeightTable(
      tableName: 'lab_weights_Object',
      extraColumns: {
        'lab_id': 'TEXT',
        'operator': 'TEXT',
        'equipment_id': 'TEXT',
        'temperature': 'REAL',
        'humidity': 'REAL',
        'object_name': 'TEXT',
        'category': 'TEXT',
        'barcode': 'TEXT',
        'material': 'TEXT',
        'batch_number': 'TEXT',
      },
    );

    if (success) {
      debugPrint('✅ lab_weights_Object table created successfully');
    } else {
      debugPrint(
        '❌ Failed to create lab_weights_Object table: ${saveService.lastError}',
      );
    }
    return success;
  }

  // ========== ทดสอบบันทึกข้อมูลคน ==========

  /// ทดสอบบันทึกข้อมูลคนแบบ Laboratory
  Future<bool> testSaveHumanWeight() async {
    debugPrint('🧪 Testing save human weight to lab_weights_Human...');

    final success = await saveService.saveWeightToTable(
      tableName: 'lab_weights_Human',
      saveType: 'laboratory',
      customNotes: 'Medical checkup in laboratory',
      additionalData: {
        'lab_id': 'LAB001',
        'operator': 'Dr. Smith',
        'equipment_id': 'SCALE_001',
        'temperature': 25.5,
        'humidity': 60.0,
        'name': 'John Doe',
        'age': 35,
        'gender': 'Male',
        'height': 175.0,
        'medical_condition': 'Healthy',
      },
    );

    if (success) {
      debugPrint('✅ Human weight saved successfully to lab_weights_Human');
    } else {
      debugPrint('❌ Failed to save human weight: ${saveService.lastError}');
    }
    return success;
  }

  /// ทดสอบบันทึกข้อมูลคนหลายๆ คน
  Future<void> testSaveMultipleHumanWeights() async {
    debugPrint('🧪 Testing save multiple human weights...');

    final humans = [
      {
        'name': 'Jane Smith',
        'age': 28,
        'gender': 'Female',
        'height': 165.0,
        'medical_condition': 'Healthy',
      },
      {
        'name': 'Bob Johnson',
        'age': 42,
        'gender': 'Male',
        'height': 180.0,
        'medical_condition': 'Diabetes',
      },
      {
        'name': 'Alice Brown',
        'age': 25,
        'gender': 'Female',
        'height': 160.0,
        'medical_condition': 'Healthy',
      },
    ];

    int successCount = 0;
    for (int i = 0; i < humans.length; i++) {
      final human = humans[i];
      final success = await saveService.saveWeightToTable(
        tableName: 'lab_weights_Human',
        saveType: 'laboratory',
        customNotes: 'Batch testing human ${i + 1}',
        additionalData: {
          'lab_id': 'LAB001',
          'operator': 'Lab Tech ${i + 1}',
          'equipment_id': 'SCALE_00${i + 1}',
          'temperature': 25.0 + (i * 0.5),
          'humidity': 58.0 + (i * 2.0),
          ...human,
        },
      );

      if (success) {
        successCount++;
        debugPrint('✅ Human ${i + 1} (${human['name']}) saved successfully');
      } else {
        debugPrint('❌ Failed to save human ${i + 1}: ${saveService.lastError}');
      }
    }

    debugPrint('📊 Human weights saved: $successCount/${humans.length}');
  }

  // ========== ทดสอบบันทึกข้อมูลสัตว์ ==========

  /// ทดสอบบันทึกข้อมูลสัตว์แบบ Laboratory
  Future<bool> testSaveAnimalWeight() async {
    debugPrint('🧪 Testing save animal weight to lab_weights_Animal...');

    final success = await saveService.saveWeightToTable(
      tableName: 'lab_weights_Animal',
      saveType: 'laboratory',
      customNotes: 'Veterinary checkup in laboratory',
      additionalData: {
        'lab_id': 'LAB002',
        'operator': 'Dr. Wilson',
        'equipment_id': 'SCALE_002',
        'temperature': 24.0,
        'humidity': 65.0,
        'species': 'Dog',
        'breed': 'Golden Retriever',
        'animal_id': 'DOG001',
        'owner': 'Michael Johnson',
        'vaccination_status': 'Up to date',
      },
    );

    if (success) {
      debugPrint('✅ Animal weight saved successfully to lab_weights_Animal');
    } else {
      debugPrint('❌ Failed to save animal weight: ${saveService.lastError}');
    }
    return success;
  }

  /// ทดสอบบันทึกข้อมูลสัตว์หลายตัว
  Future<void> testSaveMultipleAnimalWeights() async {
    debugPrint('🧪 Testing save multiple animal weights...');

    final animals = [
      {
        'species': 'Cat',
        'breed': 'Persian',
        'animal_id': 'CAT001',
        'owner': 'Sarah Lee',
        'vaccination_status': 'Up to date',
      },
      {
        'species': 'Dog',
        'breed': 'Labrador',
        'animal_id': 'DOG002',
        'owner': 'Tom Wilson',
        'vaccination_status': 'Overdue',
      },
      {
        'species': 'Rabbit',
        'breed': 'Holland Lop',
        'animal_id': 'RAB001',
        'owner': 'Emma Davis',
        'vaccination_status': 'Up to date',
      },
    ];

    int successCount = 0;
    for (int i = 0; i < animals.length; i++) {
      final animal = animals[i];
      final success = await saveService.saveWeightToTable(
        tableName: 'lab_weights_Animal',
        saveType: 'laboratory',
        customNotes: 'Batch testing animal ${i + 1}',
        additionalData: {
          'lab_id': 'LAB002',
          'operator': 'Vet Tech ${i + 1}',
          'equipment_id': 'SCALE_00${i + 2}',
          'temperature': 23.5 + (i * 0.3),
          'humidity': 62.0 + (i * 1.5),
          ...animal,
        },
      );

      if (success) {
        successCount++;
        debugPrint(
          '✅ Animal ${i + 1} (${animal['species']}) saved successfully',
        );
      } else {
        debugPrint(
          '❌ Failed to save animal ${i + 1}: ${saveService.lastError}',
        );
      }
    }

    debugPrint('📊 Animal weights saved: $successCount/${animals.length}');
  }

  // ========== ทดสอบบันทึกข้อมูลสิ่งของ ==========

  /// ทดสอบบันทึกข้อมูลสิ่งของแบบ Laboratory
  Future<bool> testSaveObjectWeight() async {
    debugPrint('🧪 Testing save object weight to lab_weights_Object...');

    final success = await saveService.saveWeightToTable(
      tableName: 'lab_weights_Object',
      saveType: 'laboratory',
      customNotes: 'Quality control testing in laboratory',
      additionalData: {
        'lab_id': 'LAB003',
        'operator': 'Lab Tech Johnson',
        'equipment_id': 'SCALE_003',
        'temperature': 26.0,
        'humidity': 55.0,
        'object_name': 'Chemical Sample A',
        'category': 'Chemical',
        'barcode': '1234567890',
        'material': 'Powder',
        'batch_number': 'BATCH001',
      },
    );

    if (success) {
      debugPrint('✅ Object weight saved successfully to lab_weights_Object');
    } else {
      debugPrint('❌ Failed to save object weight: ${saveService.lastError}');
    }
    return success;
  }

  /// ทดสอบบันทึกข้อมูลสิ่งของหลายชิ้น
  Future<void> testSaveMultipleObjectWeights() async {
    debugPrint('🧪 Testing save multiple object weights...');

    final objects = [
      {
        'object_name': 'Metal Rod B',
        'category': 'Metal',
        'barcode': '2345678901',
        'material': 'Steel',
        'batch_number': 'BATCH002',
      },
      {
        'object_name': 'Plastic Component C',
        'category': 'Plastic',
        'barcode': '3456789012',
        'material': 'ABS',
        'batch_number': 'BATCH003',
      },
      {
        'object_name': 'Glass Vial D',
        'category': 'Glass',
        'barcode': '4567890123',
        'material': 'Borosilicate',
        'batch_number': 'BATCH004',
      },
    ];

    int successCount = 0;
    for (int i = 0; i < objects.length; i++) {
      final object = objects[i];
      final success = await saveService.saveWeightToTable(
        tableName: 'lab_weights_Object',
        saveType: 'laboratory',
        customNotes: 'Batch testing object ${i + 1}',
        additionalData: {
          'lab_id': 'LAB003',
          'operator': 'QC Tech ${i + 1}',
          'equipment_id': 'SCALE_00${i + 3}',
          'temperature': 25.8 + (i * 0.2),
          'humidity': 53.0 + (i * 1.0),
          ...object,
        },
      );

      if (success) {
        successCount++;
        debugPrint(
          '✅ Object ${i + 1} (${object['object_name']}) saved successfully',
        );
      } else {
        debugPrint(
          '❌ Failed to save object ${i + 1}: ${saveService.lastError}',
        );
      }
    }

    debugPrint('📊 Object weights saved: $successCount/${objects.length}');
  }

  // ========== ทดสอบการอ่านข้อมูล ==========

  /// ทดสอบอ่านข้อมูลจากตารางต่างๆ
  Future<void> testReadAllData() async {
    debugPrint('📖 Testing read data from all tables...');

    // อ่านข้อมูลคน
    final humanRecords = await saveService.getRecordsFromTable(
      tableName: 'lab_weights_Human',
      orderBy: 'timestamp DESC',
      limit: 10,
    );
    debugPrint('👥 Human records found: ${humanRecords.length}');

    // อ่านข้อมูลสัตว์
    final animalRecords = await saveService.getRecordsFromTable(
      tableName: 'lab_weights_Animal',
      orderBy: 'timestamp DESC',
      limit: 10,
    );
    debugPrint('🐕 Animal records found: ${animalRecords.length}');

    // อ่านข้อมูลสิ่งของ
    final objectRecords = await saveService.getRecordsFromTable(
      tableName: 'lab_weights_Object',
      orderBy: 'timestamp DESC',
      limit: 10,
    );
    debugPrint('📦 Object records found: ${objectRecords.length}');

    // แสดงตัวอย่างข้อมูล
    if (humanRecords.isNotEmpty) {
      debugPrint('👤 Sample human record: ${humanRecords.first}');
    }
    if (animalRecords.isNotEmpty) {
      debugPrint('🐾 Sample animal record: ${animalRecords.first}');
    }
    if (objectRecords.isNotEmpty) {
      debugPrint('📋 Sample object record: ${objectRecords.first}');
    }
  }

  /// ทดสอบการดูสถิติ
  Future<void> testGetStatistics() async {
    debugPrint('📊 Testing get statistics...');

    final tables = [
      'lab_weights_Human',
      'lab_weights_Animal',
      'lab_weights_Object',
    ];

    for (final table in tables) {
      final stats = await saveService.getTableStatistics(table);
      debugPrint('📈 Statistics for $table: $stats');
    }
  }

  // ========== ทดสอบหลัก ==========

  /// รันการทดสอบทั้งหมด
  Future<void> runAllTests() async {
    debugPrint('🚀 Starting all tests...');

    try {
      // สร้างตารางทั้งหมด
      debugPrint('\n=== Creating Tables ===');
      await createLabWeightsHumanTable();
      await createLabWeightsAnimalTable();
      await createLabWeightsObjectTable();

      // ทดสอบบันทึกข้อมูล
      debugPrint('\n=== Testing Single Saves ===');
      await testSaveHumanWeight();
      await testSaveAnimalWeight();
      await testSaveObjectWeight();

      // ทดสอบบันทึกข้อมูลหลายรายการ
      debugPrint('\n=== Testing Multiple Saves ===');
      await testSaveMultipleHumanWeights();
      await testSaveMultipleAnimalWeights();
      await testSaveMultipleObjectWeights();

      // ทดสอบอ่านข้อมูล
      debugPrint('\n=== Testing Data Reading ===');
      await testReadAllData();

      // ทดสอบสถิติ
      debugPrint('\n=== Testing Statistics ===');
      await testGetStatistics();

      debugPrint('\n✅ All tests completed successfully!');
    } catch (e) {
      debugPrint('\n❌ Test failed with error: $e');
    }
  }

  /// ทดสอบเฉพาะการสร้างตารางและบันทึกข้อมูลเดียว
  Future<void> runQuickTest() async {
    debugPrint('⚡ Running quick test...');

    // สร้างตารางคน
    await createLabWeightsHumanTable();

    // บันทึกข้อมูลคนแบบ Laboratory
    await saveService.saveWeightToTable(
      tableName: 'lab_weights_Human',
      saveType: 'laboratory',
      customNotes: 'Quick test save',
      additionalData: {
        'lab_id': 'LAB001',
        'operator': 'Lab Tech',
        'equipment_id': 'SCALE_001',
        'temperature': 25.5,
        'humidity': 60.0,
        'name': 'Test User',
        'age': 30,
        'gender': 'Male',
      },
    );

    debugPrint('⚡ Quick test completed!');
  }
}

// ========== ตัวอย่างการใช้งาน ==========

/// Widget สำหรับทดสอบ
class TestCreateWidget extends StatefulWidget {
  final GenericSaveService saveService;

  const TestCreateWidget({Key? key, required this.saveService})
    : super(key: key);

  @override
  State<TestCreateWidget> createState() => _TestCreateWidgetState();
}

class _TestCreateWidgetState extends State<TestCreateWidget> {
  late TestCreate testCreate;
  bool isRunning = false;

  @override
  void initState() {
    super.initState();
    testCreate = TestCreate(widget.saveService);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Test Create - Lab Weights')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Laboratory Weight Tables',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed:
                  isRunning
                      ? null
                      : () async {
                        setState(() => isRunning = true);
                        await testCreate.runQuickTest();
                        setState(() => isRunning = false);
                      },
              child: const Text('Run Quick Test'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed:
                  isRunning
                      ? null
                      : () async {
                        setState(() => isRunning = true);
                        await testCreate.runAllTests();
                        setState(() => isRunning = false);
                      },
              child: const Text('Run All Tests'),
            ),

            const SizedBox(height: 20),

            if (isRunning)
              const Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text('Running tests...'),
                ],
              ),

            const SizedBox(height: 20),

            if (widget.saveService.lastError != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Error: ${widget.saveService.lastError}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
