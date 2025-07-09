import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/GenericTestPageProvider.dart';

class TestEntityCar extends StatefulWidget {
  @override
  State<TestEntityCar> createState() => _TestEntityCarState();
}

class _TestEntityCarState extends State<TestEntityCar> {
  @override
  void initState() {
    super.initState();
    
    // Configure provider สำหรับรถ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<GenericTestPageProvider>(context, listen: false);
      _configureForCars(provider);
    });
  }

  // 🚗 กำหนดค่าสำหรับรถ
  Future<void> _configureForCars(GenericTestPageProvider provider) async {
    await provider.configure(
      context: context,
      primaryTableName: 'cars',
      entityDisplayName: 'Cars',
      entitySingularName: 'Car',
      tableSchema: {
        'brand': 'TEXT NOT NULL',
        'model': 'TEXT NOT NULL',
        'year': 'INTEGER',
        'license_plate': 'TEXT UNIQUE',
        'color': 'TEXT',
        'engine_type': 'TEXT',
        'status': 'TEXT DEFAULT "active"',
      },
      defaultValues: {
        'status': 'active',
        'engine_type': 'gasoline',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🚗 Car Management'),
        backgroundColor: Colors.blue.shade100,
      ),
      body: Consumer<GenericTestPageProvider>(
        builder: (context, provider, child) {
          // Loading state
          if (!provider.isInitialized) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Initializing cars database...'),
                ],
              ),
            );
          }

          // Error state
          if (provider.lastError != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, color: Colors.red, size: 64),
                  SizedBox(height: 16),
                  Text('Error: ${provider.lastError}', style: TextStyle(color: Colors.red)),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.retryInitialization(),
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Main content
          return Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.directions_car, size: 48, color: Colors.blue),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '🚗 Cars Management',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                              Text('Total Cars: ${provider.records.length}'),
                              Text('Table: ${provider.currentTableName}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddCarDialog(provider),
                        icon: Icon(Icons.add),
                        label: Text('Add Car'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _createSampleCars(provider),
                      icon: Icon(Icons.auto_fix_high),
                      label: Text('Sample'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 16),

                // Cars List
                Expanded(
                  child: provider.records.isEmpty
                      ? _buildEmptyState()
                      : _buildCarsList(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No cars found', style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Add your first car to get started', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildCarsList(GenericTestPageProvider provider) {
    return ListView.builder(
      itemCount: provider.records.length,
      itemBuilder: (context, index) {
        final car = provider.records[index];
        return Card(
          margin: EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue,
              child: Icon(Icons.directions_car, color: Colors.white),
            ),
            title: Text('${car['brand']} ${car['model']}'),
            subtitle: Text(
              '${car['year']} • ${car['color']} • ${car['license_plate']}\n'
              'Engine: ${car['engine_type']} • Status: ${car['status']}',
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditCarDialog(provider, car);
                } else if (value == 'delete') {
                  _confirmDeleteCar(provider, car);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }

  // ========== Dialog Methods ==========

  Future<void> _showAddCarDialog(GenericTestPageProvider provider) async {
    final brandController = TextEditingController();
    final modelController = TextEditingController();
    final yearController = TextEditingController();
    final licensePlateController = TextEditingController();
    final colorController = TextEditingController();
    String engineType = 'gasoline';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add New Car'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: brandController,
                  decoration: InputDecoration(labelText: 'Brand *', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: 'Model *', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: yearController,
                  decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: licensePlateController,
                  decoration: InputDecoration(labelText: 'License Plate', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: colorController,
                  decoration: InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: engineType,
                  decoration: InputDecoration(labelText: 'Engine Type', border: OutlineInputBorder()),
                  items: ['gasoline', 'diesel', 'electric', 'hybrid'].map((type) => 
                    DropdownMenuItem(value: type, child: Text(type.toUpperCase()))
                  ).toList(),
                  onChanged: (value) => setState(() => engineType = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Add Car'),
            ),
          ],
        ),
      ),
    );

    if (result == true && brandController.text.isNotEmpty && modelController.text.isNotEmpty) {
      final success = await provider.createRecord(
        tableName: 'cars',
        data: {
          'brand': brandController.text,
          'model': modelController.text,
          'year': int.tryParse(yearController.text) ?? 2024,
          'license_plate': licensePlateController.text.isEmpty ? null : licensePlateController.text,
          'color': colorController.text.isEmpty ? 'Unknown' : colorController.text,
          'engine_type': engineType,
        },
      );

      if (success) {
        _showMessage('✅ Car added successfully!');
      } else {
        _showMessage('❌ Failed to add car: ${provider.lastError}');
      }
    }
  }

  Future<void> _showEditCarDialog(GenericTestPageProvider provider, Map<String, dynamic> car) async {
    final brandController = TextEditingController(text: car['brand']);
    final modelController = TextEditingController(text: car['model']);
    final yearController = TextEditingController(text: car['year'].toString());
    final licensePlateController = TextEditingController(text: car['license_plate'] ?? '');
    final colorController = TextEditingController(text: car['color'] ?? '');
    String engineType = car['engine_type'] ?? 'gasoline';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Car'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: brandController,
                  decoration: InputDecoration(labelText: 'Brand', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: yearController,
                  decoration: InputDecoration(labelText: 'Year', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 8),
                TextField(
                  controller: licensePlateController,
                  decoration: InputDecoration(labelText: 'License Plate', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: colorController,
                  decoration: InputDecoration(labelText: 'Color', border: OutlineInputBorder()),
                ),
                SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: engineType,
                  decoration: InputDecoration(labelText: 'Engine Type', border: OutlineInputBorder()),
                  items: ['gasoline', 'diesel', 'electric', 'hybrid'].map((type) => 
                    DropdownMenuItem(value: type, child: Text(type.toUpperCase()))
                  ).toList(),
                  onChanged: (value) => setState(() => engineType = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Update'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final success = await provider.updateRecord(
        tableName: 'cars',
        recordId: car['id'],
        data: {
          'brand': brandController.text,
          'model': modelController.text,
          'year': int.tryParse(yearController.text) ?? 2024,
          'license_plate': licensePlateController.text,
          'color': colorController.text,
          'engine_type': engineType,
        },
      );

      if (success) {
        _showMessage('✅ Car updated successfully!');
      } else {
        _showMessage('❌ Failed to update car: ${provider.lastError}');
      }
    }
  }

  Future<void> _confirmDeleteCar(GenericTestPageProvider provider, Map<String, dynamic> car) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Car'),
        content: Text('Are you sure you want to delete\n${car['brand']} ${car['model']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await provider.deleteRecord(
        tableName: 'cars',
        recordId: car['id'],
      );

      if (success) {
        _showMessage('✅ Car deleted successfully!');
      } else {
        _showMessage('❌ Failed to delete car: ${provider.lastError}');
      }
    }
  }

  // ========== Sample Data ==========

  Future<void> _createSampleCars(GenericTestPageProvider provider) async {
    final sampleCars = [
      {
        'brand': 'Toyota',
        'model': 'Camry',
        'year': 2023,
        'license_plate': 'กข-1234',
        'color': 'White',
        'engine_type': 'hybrid',
      },
      {
        'brand': 'Honda',
        'model': 'Civic',
        'year': 2022,
        'license_plate': 'คง-5678',
        'color': 'Black',
        'engine_type': 'gasoline',
      },
      {
        'brand': 'Tesla',
        'model': 'Model 3',
        'year': 2024,
        'license_plate': 'จฉ-9999',
        'color': 'Blue',
        'engine_type': 'electric',
      },
    ];

    final success = await provider.createSampleRecords(
      tableName: 'cars',
      sampleData: sampleCars,
    );

    if (success) {
      _showMessage('✅ Sample cars created successfully!');
    } else {
      _showMessage('❌ Failed to create sample cars: ${provider.lastError}');
    }
  }

  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }
}