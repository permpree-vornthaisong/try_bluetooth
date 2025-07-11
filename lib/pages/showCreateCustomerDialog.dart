import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/FormulaProvider.dart';

/// ฟังก์ชันสำหรับแสดง Dialog สร้าง Formula
void showCreateCustomerDialog(BuildContext context) {
  showDialog(context: context, builder: (context) => CreateCustomerDialog());
}

/// Dialog สำหรับสร้าง Formula ใหม่
class CreateCustomerDialog extends StatefulWidget {
  @override
  State<CreateCustomerDialog> createState() => _CreateCustomerDialogState();
}

class _CreateCustomerDialogState extends State<CreateCustomerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _formulaNameController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _columnCount = 3; // เริ่มต้น 3 columns
  List<TextEditingController> _columnControllers = [];
  bool _isLoading = false;

  // เพิ่มตัวแปรสำหรับ icon selection
  String _selectedIconPath = 'assets/icons/cat.ico';
  String _selectedIconLabel = 'Cat';

  @override
  void initState() {
    super.initState();
    // ตั้งค่าเริ่มต้น
    _formulaNameController.text = 'customer';
    _updateColumnControllers();
  }

  void _updateColumnControllers() {
    // ล้าง controllers เก่า
    for (var controller in _columnControllers) {
      controller.dispose();
    }
    _columnControllers.clear();

    // สร้าง controllers ใหม่ตามจำนวน columns
    for (int i = 0; i < _columnCount; i++) {
      _columnControllers.add(TextEditingController());
    }

    // ตั้งค่าเริ่มต้นสำหรับ customer
    if (_columnCount >= 1) _columnControllers[0].text = 'name';
    if (_columnCount >= 2) _columnControllers[1].text = 'email';
    if (_columnCount >= 3) _columnControllers[2].text = 'phone';
    if (_columnCount >= 4) _columnControllers[3].text = 'address';
    if (_columnCount >= 5) _columnControllers[4].text = 'company';
    if (_columnCount >= 6) _columnControllers[5].text = 'department';
    if (_columnCount >= 7) _columnControllers[6].text = 'position';
    if (_columnCount >= 8) _columnControllers[7].text = 'salary';
    if (_columnCount >= 9) _columnControllers[8].text = 'age';
    if (_columnCount >= 10) _columnControllers[9].text = 'notes';

    setState(() {});
  }

  @override
  void dispose() {
    _formulaNameController.dispose();
    _descriptionController.dispose();
    for (var controller in _columnControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.add_business, color: Colors.blue),
          SizedBox(width: 8),
          Text('Create New Formula'),
        ],
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(maxHeight: 600), // เพิ่มความสูงเล็กน้อย
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Formula Name
                TextFormField(
                  controller: _formulaNameController,
                  decoration: InputDecoration(
                    labelText: 'Formula Name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label),
                    hintText: 'e.g. customer, employee, product',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Formula name is required';
                    }
                    if (value.trim().contains(' ')) {
                      return 'Formula name cannot contain spaces';
                    }
                    return null;
                  },
                ),

                SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.description),
                    hintText: 'Describe what this formula is for',
                  ),
                  maxLines: 2,
                ),

                SizedBox(height: 16),

                // Icon Selection Section
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Formula Icon:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),

                      // Current selected icon display
                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.white,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                _selectedIconPath,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.pets,
                                    size: 30,
                                    color: Colors.grey,
                                  );
                                },
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selected: $_selectedIconLabel',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                                SizedBox(height: 4),
                                ElevatedButton.icon(
                                  onPressed: () => _showIconSelectionDialog(),
                                  icon: Icon(Icons.image, size: 16),
                                  label: Text('Choose Icon'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade100,
                                    foregroundColor: Colors.blue,
                                    elevation: 0,
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Column Count Selector
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Number of Columns:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        value: _columnCount,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items:
                            List.generate(10, (index) => index + 1)
                                .map(
                                  (count) => DropdownMenuItem(
                                    value: count,
                                    child: Text('$count columns'),
                                  ),
                                )
                                .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            _columnCount = value;
                            _updateColumnControllers();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 16),

                // Column Names
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Column Names:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),

                      ...List.generate(_columnCount, (index) {
                        return Padding(
                          padding: EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: _columnControllers[index],
                            decoration: InputDecoration(
                              labelText: 'Column ${index + 1}',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.view_column),
                              hintText: 'Enter column name',
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Column name is required';
                              }
                              if (value.trim().contains(' ')) {
                                return 'Column name cannot contain spaces';
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                SizedBox(height: 8),

                // Helper text
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Column names will be used as field names in the database. Use lowercase without spaces.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _createFormula,
          icon:
              _isLoading
                  ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : Icon(Icons.save),
          label: Text(_isLoading ? 'Creating...' : 'Create Formula'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  // ฟังก์ชันแสดง Dialog เลือก icon
  void _showIconSelectionDialog() {
    String tempSelectedIconPath = _selectedIconPath;
    String tempSelectedIconLabel = _selectedIconLabel;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          // เพิ่ม StatefulBuilder!
          builder:
              (context, setDialogState) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Container(
                  width: 400,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.7,
                    minHeight: 300,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: const Text(
                          'Choose Formula Icon',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Animals Category
                              const Text(
                                'Animals & Icons',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Animal icons grid
                              GridView.count(
                                crossAxisCount: 4,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                childAspectRatio: 1.0,
                                crossAxisSpacing: 4,
                                mainAxisSpacing: 4,
                                children: _buildIconGridWithCallback(
                                  tempSelectedIconPath,
                                  (iconPath, iconLabel) {
                                    setDialogState(() {
                                      // ใช้ setDialogState แทน setState
                                      tempSelectedIconPath = iconPath;
                                      tempSelectedIconLabel = iconLabel;
                                    });
                                    debugPrint(
                                      'Selected icon: $iconLabel at $iconPath',
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel'),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                // อัพเดท state หลัก
                                setState(() {
                                  _selectedIconPath = tempSelectedIconPath;
                                  _selectedIconLabel = tempSelectedIconLabel;
                                });
                                Navigator.of(context).pop();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Done'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        );
      },
    );
  }

  List<Widget> _buildIconGridWithCallback(
    String selectedIconPath,
    Function(String, String) onIconSelected,
  ) {
    final iconData = [
      {'path': 'assets/icons/cat.ico', 'label': 'Cat'},
      {'path': 'assets/icons/dog.ico', 'label': 'Dog'},
      {'path': 'assets/icons/cow.ico', 'label': 'Cow'},
      {'path': 'assets/icons/horse.ico', 'label': 'Horse'},
      {'path': 'assets/icons/lion.ico', 'label': 'Lion'},
      {'path': 'assets/icons/tiger.ico', 'label': 'Tiger'},
      {'path': 'assets/icons/buffalo.ico', 'label': 'Buffalo'},
      {'path': 'assets/icons/chicken.ico', 'label': 'Chicken'},
      {'path': 'assets/icons/fish.ico', 'label': 'Fish'},
      {'path': 'assets/icons/giraffe.ico', 'label': 'Giraffe'},
      {'path': 'assets/icons/goat.ico', 'label': 'Goat'},
      {'path': 'assets/icons/monkey.ico', 'label': 'Monkey'},
      {'path': 'assets/icons/shrimp.ico', 'label': 'Shrimp'},
      {'path': 'assets/icons/zebra.ico', 'label': 'Zebra'},
      {'path': 'assets/icons/pawprint.ico', 'label': 'Paw'},
      {'path': 'assets/icons/1998617.ico', 'label': 'Icon 1'},
      {'path': 'assets/icons/1998620.ico', 'label': 'Icon 2'},
      {'path': 'assets/icons/1998642.ico', 'label': 'Icon 3'},
      {'path': 'assets/icons/1998728.ico', 'label': 'Icon 4'},
      {'path': 'assets/icons/1998773.ico', 'label': 'Icon 5'},
    ];

    return iconData
        .map(
          (icon) => _buildSelectableIconWithCallback(
            icon['path']!,
            icon['label']!,
            selectedIconPath,
            onIconSelected,
          ),
        )
        .toList();
  }

  // สร้าง icon ที่เลือกได้ พร้อม callback
  Widget _buildSelectableIconWithCallback(
    String iconPath,
    String label,
    String selectedIconPath,
    Function(String, String) onIconSelected,
  ) {
    final isSelected = selectedIconPath == iconPath;

    return GestureDetector(
      onTap: () => onIconSelected(iconPath, label),
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          iconPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.pets,
                              size: 35,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // สร้าง grid ของ icons
  List<Widget> _buildIconGrid() {
    final iconData = [
      {'path': 'assets/icons/cat.ico', 'label': 'Cat'},
      {'path': 'assets/icons/dog.ico', 'label': 'Dog'},
      {'path': 'assets/icons/cow.ico', 'label': 'Cow'},
      {'path': 'assets/icons/horse.ico', 'label': 'Horse'},
      {'path': 'assets/icons/lion.ico', 'label': 'Lion'},
      {'path': 'assets/icons/tiger.ico', 'label': 'Tiger'},
      {'path': 'assets/icons/buffalo.ico', 'label': 'Buffalo'},
      {'path': 'assets/icons/chicken.ico', 'label': 'Chicken'},
      {'path': 'assets/icons/fish.ico', 'label': 'Fish'},
      {'path': 'assets/icons/giraffe.ico', 'label': 'Giraffe'},
      {'path': 'assets/icons/goat.ico', 'label': 'Goat'},
      {'path': 'assets/icons/monkey.ico', 'label': 'Monkey'},
      {'path': 'assets/icons/shrimp.ico', 'label': 'Shrimp'},
      {'path': 'assets/icons/zebra.ico', 'label': 'Zebra'},
      {'path': 'assets/icons/pawprint.ico', 'label': 'Paw'},
      {'path': 'assets/icons/1998617.ico', 'label': 'Icon 1'},
      {'path': 'assets/icons/1998620.ico', 'label': 'Icon 2'},
      {'path': 'assets/icons/1998642.ico', 'label': 'Icon 3'},
      {'path': 'assets/icons/1998728.ico', 'label': 'Icon 4'},
      {'path': 'assets/icons/1998773.ico', 'label': 'Icon 5'},
    ];

    return iconData
        .map((icon) => _buildSelectableIcon(icon['path']!, icon['label']!))
        .toList();
  }

  // สร้าง icon ที่เลือกได้
  Widget _buildSelectableIcon(String iconPath, String label) {
    final isSelected = _selectedIconPath == iconPath;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIconPath = iconPath;
          _selectedIconLabel = label;
        });
        debugPrint('Selected icon: $label at $iconPath');
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? Colors.blue.shade50 : Colors.white,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.asset(
                          iconPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.pets,
                              size: 35,
                              color: Colors.grey,
                            );
                          },
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check,
                              size: 12,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.blue : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createFormula() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final formulaProvider = Provider.of<FormulaProvider>(
        context,
        listen: false,
      );

      // เก็บชื่อ columns
      final columnNames = _columnControllers.map((c) => c.text.trim()).toList();

      // ตรวจสอบชื่อ column ซ้ำ
      final uniqueColumns = columnNames.toSet();
      if (uniqueColumns.length != columnNames.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Column names must be unique!'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      debugPrint('🚀 Creating formula: ${_formulaNameController.text}');
      debugPrint('🎨 Selected icon: $_selectedIconLabel ($_selectedIconPath)');
      debugPrint('📊 Columns: ${columnNames.join(', ')}');

      // สร้าง formula พร้อม icon path
      final success = await formulaProvider.createFormula(
        formulaName: _formulaNameController.text.trim(),
        columnCount: _columnCount,
        columnNames: columnNames,
        description: _descriptionController.text.trim(),
        iconPath: _selectedIconPath, // ส่ง icon path ไปด้วย
      );

      if (success) {
        // แสดงข้อความสำเร็จ
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Formula "${_formulaNameController.text}" created successfully!',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // ปิด dialog
        Navigator.of(context).pop();

        debugPrint('✅ Formula created successfully!');
        debugPrint('📋 Table created: formula_${_formulaNameController.text}');
      } else {
        // แสดงข้อความ error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Failed to create formula: ${formulaProvider.lastError ?? 'Unknown error'}',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error creating formula: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Error: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
