import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/GenericCRUDProvider.dart';
import 'package:try_bluetooth/providers/TestPageProvider.dart';

/// TestPageWidget - UI Layer เท่านั้น
/// Business Logic ทั้งหมดอยู่ใน TestPageProvider
class TestPage extends StatefulWidget {
  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  late TestPageProvider testPageProvider;

  // ========== TABLE CONFIGURATION ==========
  static const String tableName = 'users';
  static const String tableDisplayName = 'Users';

  @override
  void initState() {
    super.initState();

    // ดึง GenericCRUDProvider จาก context
    final crudProvider = Provider.of<GenericCRUDProvider>(
      context,
      listen: false,
    );

    // สร้าง TestPageProvider และส่ง GenericCRUDProvider เข้าไป
    // Business Logic จะทำงานอัตโนมัติใน constructor
    testPageProvider = TestPageProvider(crudProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test CRUD Provider (Clean Architecture)'),
        backgroundColor: Colors.blue.shade100,
      ),

      // WraP TestPageProvider ด้วย ChangeNotifierProvider.value
      body: ChangeNotifierProvider.value(
        value: testPageProvider,
        child: Consumer<TestPageProvider>(
          builder: (context, provider, child) {
            // 🎯 UI เพียงแค่ react ต่อ state จาก provider
            return _buildBody(provider);
          },
        ),
      ),
    );
  }

  /// สร้าง UI ตาม state ของ Provider
  Widget _buildBody(TestPageProvider provider) {
    // Loading State
    if (!provider.isInitialized && provider.isProcessing) {
      return _buildLoadingState();
    }

    // Error State
    if (provider.lastError != null && !provider.isInitialized) {
      return _buildErrorState(provider);
    }

    // Success State - แสดงหน้าจอหลัก
    return _buildMainContent(provider);
  }

  /// Loading State UI
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 16),
          Text('Initializing database...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  /// Error State UI
  Widget _buildErrorState(TestPageProvider provider) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Database Error',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            SizedBox(height: 8),
            Text(
              provider.lastError ?? 'Unknown error',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => provider.retryInitialization(),
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Main Content UI
  Widget _buildMainContent(TestPageProvider provider) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Card
          _buildStatusCard(),

          SizedBox(height: 20),

          // Action Buttons
          _buildActionButtons(provider),

          SizedBox(height: 20),

          // Users List
          _buildUsersSection(provider),
        ],
      ),
    );
  }

  /// Status Card UI
  Widget _buildStatusCard() {
    return Card(
      color: Colors.green.shade100,
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 40),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ Database Ready!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  Text(
                    'All CRUD operations available',
                    style: TextStyle(color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Action Buttons UI
  Widget _buildActionButtons(TestPageProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Test CRUD Operations:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),

        // Create User Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed:
                provider.isProcessing
                    ? null
                    : () => _showCreateUserDialog(provider),
            icon: Icon(Icons.add),
            label: Text('Create $tableDisplayName'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        SizedBox(height: 8),

        // Other Action Buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    provider.isProcessing
                        ? null
                        : () => _testQuickCreate(provider),
                icon: Icon(Icons.flash_on),
                label: Text('Quick Create'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    provider.isProcessing
                        ? null
                        : () => provider.refreshUsers(),
                icon: Icon(Icons.refresh),
                label: Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Users Section UI
  Widget _buildUsersSection(TestPageProvider provider) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Text(
                '$tableDisplayName (${provider.users.length})',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Spacer(),
              if (provider.isProcessing)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),

          SizedBox(height: 12),

          // Users List
          Expanded(child: _buildUsersList(provider)),
        ],
      ),
    );
  }

  /// Users List UI
  Widget _buildUsersList(TestPageProvider provider) {
    final users = provider.users;

    if (users.isEmpty) {
      return _buildEmptyState(provider);
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserCard(user, provider);
      },
    );
  }

  /// Empty State UI
  Widget _buildEmptyState(TestPageProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
          SizedBox(height: 16),
          Text(
            'No $tableName found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          SizedBox(height: 8),
          Text(
            'Create your first ${tableName.toLowerCase()} to get started',
            style: TextStyle(color: Colors.grey.shade500),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateUserDialog(provider),
            icon: Icon(Icons.add),
            label: Text(
              'Create First ${tableDisplayName.substring(0, tableDisplayName.length - 1)}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// User Card UI
  Widget _buildUserCard(Map<String, dynamic> user, TestPageProvider provider) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            user['name'][0].toUpperCase(),
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          user['name'] ?? 'No Name',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${user['email']} • Age: ${user['age']}'),
            SizedBox(height: 4),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    user['status'] == 'active'
                        ? Colors.green.shade100
                        : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user['status'] ?? 'unknown',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      user['status'] == 'active'
                          ? Colors.green.shade800
                          : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleUserAction(value, user, provider),
          itemBuilder:
              (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
        ),
      ),
    );
  }

  // ========== UI ACTIONS (เรียกใช้ Business Logic จาก Provider) ==========

  /// Handle user actions (Edit/Delete)
  void _handleUserAction(
    String action,
    Map<String, dynamic> user,
    TestPageProvider provider,
  ) {
    switch (action) {
      case 'edit':
        _showEditUserDialog(user, provider);
        break;
      case 'delete':
        _confirmDeleteUser(user, provider);
        break;
    }
  }

  /// แสดง Dialog สร้าง User ใหม่
  Future<void> _showCreateUserDialog(TestPageProvider provider) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final ageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Create ${tableDisplayName.substring(0, tableDisplayName.length - 1)}',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Create'),
              ),
            ],
          ),
    );

    if (result == true &&
        nameController.text.isNotEmpty &&
        emailController.text.isNotEmpty) {
      // 🎯 เรียกใช้ Business Logic จาก Provider
      final success = await provider.createUser(
        tableName: tableName,
        name: nameController.text,
        email: emailController.text,
        age: int.tryParse(ageController.text) ?? 0,
      );

      if (success) {
        _showMessage(
          '✅ ${tableDisplayName.substring(0, tableDisplayName.length - 1)} created successfully',
        );
      } else {
        _showMessage(
          '❌ Failed to create ${tableName.toLowerCase()}: ${provider.lastError}',
        );
      }
    }
  }

  /// แสดง Dialog แก้ไข User
  Future<void> _showEditUserDialog(
    Map<String, dynamic> user,
    TestPageProvider provider,
  ) async {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final ageController = TextEditingController(text: user['age'].toString());

    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Edit ${tableDisplayName.substring(0, tableDisplayName.length - 1)}',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(height: 12),
                TextField(
                  controller: ageController,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text('Save'),
              ),
            ],
          ),
    );

    if (result == true) {
      // 🎯 เรียกใช้ Business Logic จาก Provider
      final success = await provider.updateUser(
        tableName: tableName,
        userId: user['id'],
        data: {
          'name': nameController.text,
          'email': emailController.text,
          'age': int.tryParse(ageController.text) ?? 0,
        },
      );

      if (success) {
        _showMessage(
          '✅ ${tableDisplayName.substring(0, tableDisplayName.length - 1)} updated successfully',
        );
      } else {
        _showMessage(
          '❌ Failed to update ${tableName.toLowerCase()}: ${provider.lastError}',
        );
      }
    }
  }

  /// Confirm Delete User
  Future<void> _confirmDeleteUser(
    Map<String, dynamic> user,
    TestPageProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(
              'Delete ${tableDisplayName.substring(0, tableDisplayName.length - 1)}',
            ),
            content: Text('Are you sure you want to delete "${user['name']}"?'),
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
      // 🎯 เรียกใช้ Business Logic จาก Provider
      final success = await provider.deleteUser(
        tableName: tableName,
        userId: user['id'],
      );

      if (success) {
        _showMessage(
          '✅ ${tableDisplayName.substring(0, tableDisplayName.length - 1)} deleted successfully',
        );
      } else {
        _showMessage(
          '❌ Failed to delete ${tableName.toLowerCase()}: ${provider.lastError}',
        );
      }
    }
  }

  /// ทดสอบสร้าง User แบบเร็ว
  Future<void> _testQuickCreate(TestPageProvider provider) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // 🎯 เรียกใช้ Business Logic จาก Provider
    final success = await provider.createUser(
      tableName: tableName,
      name:
          'Quick ${tableDisplayName.substring(0, tableDisplayName.length - 1)} $timestamp',
      email: 'quick$timestamp@test.com',
      age: 25,
    );

    if (success) {
      _showMessage('✅ Quick ${tableName.toLowerCase()} created successfully');
    } else {
      _showMessage(
        '❌ Failed to create quick ${tableName.toLowerCase()}: ${provider.lastError}',
      );
    }
  }

  /// แสดงข้อความ
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: Duration(seconds: 2)),
      );
    }
  }

  @override
  void dispose() {
    testPageProvider.dispose();
    super.dispose();
  }
}
