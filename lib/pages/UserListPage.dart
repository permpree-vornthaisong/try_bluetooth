import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:try_bluetooth/providers/CRUDSQLiteProvider.dart';

class UserListPage extends StatefulWidget {
  @override
  State<UserListPage> createState() => _UserListPageState();
}

class _UserListPageState extends State<UserListPage> {
  bool _isTableCreated = false;
  bool _isCreatingTable = false;

  @override
  void initState() {
    super.initState();
    _initializeTable();
  }

  // ✅ สร้าง table users เมื่อหน้าโหลดครั้งแรก
  Future<void> _initializeTable() async {
    if (_isTableCreated || _isCreatingTable) return;

    setState(() {
      _isCreatingTable = true;
    });

    try {
      final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
      
      // ตรวจสอบว่า table มีอยู่หรือไม่
      final tableExists = await crudProvider.tableExists('users');
      
      if (!tableExists) {
        // สร้าง table users
        final success = await crudProvider.createTable(
          'users',
          '''
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          email TEXT,
          age INTEGER,
          created_at INTEGER
          '''
        );

        if (success) {
          print('✅ Table users created successfully');
          
          // เพิ่มข้อมูลตัวอย่าง
          
        } else {
          print('❌ Failed to create table users');
        }
      } else {
        print('✅ Table users already exists');
      }

      setState(() {
        _isTableCreated = true;
        _isCreatingTable = false;
      });
    } catch (e) {
      print('❌ Error initializing table: $e');
      setState(() {
        _isCreatingTable = false;
      });
    }
  }

  // เพิ่มข้อมูลตัวอย่าง
  Future<void> _addSampleData(CRUDSQLiteProvider crudProvider) async {
    final sampleUsers = [
      {
        'name': 'สมชาย ใจดี',
        'email': 'somchai@example.com',
        'age': 25,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'name': 'สมหญิง สวยงาม',
        'email': 'somying@example.com',
        'age': 23,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      {
        'name': 'สมศักดิ์ มีสุข',
        'email': 'somsak@example.com',
        'age': 30,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
    ];

    for (final user in sampleUsers) {
      await crudProvider.insert('users', user);
    }
    
    print('✅ Sample data added');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User List (CRUD Demo)'),
        backgroundColor: Colors.blue.withOpacity(0.1),
        actions: [
          IconButton(
            onPressed: _refreshData,
            icon: Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            onPressed: _showTableInfo,
            icon: Icon(Icons.info),
            tooltip: 'Table Info',
          ),
        ],
      ),
      body: Consumer<CRUDSQLiteProvider>(
        builder: (context, crudProvider, child) {
          if (_isCreatingTable) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating table...'),
                ],
              ),
            );
          }

          if (!_isTableCreated) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  SizedBox(height: 16),
                  Text('Failed to create table'),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeTable,
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // Status Card
              Card(
                margin: EdgeInsets.all(8),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.storage, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CRUD SQLite Demo',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text('Table: users | Status: Ready'),
                          ],
                        ),
                      ),
                      if (crudProvider.isLoading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ),

              // User List
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: crudProvider.safeSelectAll('users', orderBy: 'name ASC'),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error, size: 64, color: Colors.red),
                            SizedBox(height: 16),
                            Text(
                              'Error: ${snapshot.error}',
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () => setState(() {}),
                              child: Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final users = snapshot.data ?? [];

                    if (users.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No users found',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _addSampleUser,
                              icon: Icon(Icons.add),
                              label: Text('Add Sample User'),
                            ),
                          ],
                        ),
                      );
                    }

                    return RefreshIndicator(
                      onRefresh: _refreshData,
                      child: ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          final createdAt = DateTime.fromMillisecondsSinceEpoch(
                            user['created_at'] ?? 0,
                          );

                          return Card(
                            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.withOpacity(0.2),
                                child: Icon(Icons.person, color: Colors.blue),
                              ),
                              title: Text(
                                user['name'] ?? 'No name',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user['email'] ?? 'No email'),
                                  Text(
                                    'Age: ${user['age'] ?? 'Unknown'} | Created: ${createdAt.day}/${createdAt.month}/${createdAt.year}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editUser(user),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteUser(user),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewUser,
        child: Icon(Icons.add),
        tooltip: 'Add New User',
      ),
    );
  }

  // เพิ่มผู้ใช้ใหม่
  Future<void> _addNewUser() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final ageController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New User'),
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
            SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
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
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop(true);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
      
      final success = await crudProvider.insert('users', {
        'name': nameController.text.trim(),
        'email': emailController.text.trim(),
        'age': int.tryParse(ageController.text.trim()) ?? 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {}); // Refresh the list
      }
    }
  }

  // เพิ่มผู้ใช้ตัวอย่าง
  Future<void> _addSampleUser() async {
    final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
    
    final success = await crudProvider.insert('users', {
      'name': 'ผู้ใช้ใหม่ ${DateTime.now().millisecond}',
      'email': 'user${DateTime.now().millisecond}@example.com',
      'age': 20 + (DateTime.now().millisecond % 30),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sample user added!')),
      );
      setState(() {});
    }
  }

  // แก้ไขผู้ใช้
  Future<void> _editUser(Map<String, dynamic> user) async {
    final nameController = TextEditingController(text: user['name']);
    final emailController = TextEditingController(text: user['email']);
    final ageController = TextEditingController(text: user['age'].toString());

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit User'),
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
            SizedBox(height: 8),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 8),
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
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Update'),
          ),
        ],
      ),
    );

    if (result == true) {
      final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
      
      final success = await crudProvider.update(
        'users',
        {
          'name': nameController.text.trim(),
          'email': emailController.text.trim(),
          'age': int.tryParse(ageController.text.trim()) ?? 0,
        },
        where: 'id = ?',
        whereArgs: [user['id']],
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {});
      }
    }
  }

  // ลบผู้ใช้
  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete User'),
        content: Text('Are you sure you want to delete ${user['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
      
      final success = await crudProvider.delete(
        'users',
        where: 'id = ?',
        whereArgs: [user['id']],
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User deleted successfully!'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {});
      }
    }
  }

  // รีเฟรชข้อมูล
  Future<void> _refreshData() async {
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data refreshed')),
    );
  }

  // แสดงข้อมูล table
  Future<void> _showTableInfo() async {
    final crudProvider = Provider.of<CRUDSQLiteProvider>(context, listen: false);
    
    final tableNames = await crudProvider.getAllTableNames();
    final userCount = await crudProvider.count('users');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Database Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tables: ${tableNames.join(', ')}'),
            SizedBox(height: 8),
            Text('Users count: $userCount'),
            SizedBox(height: 8),
            Text('Database initialized: ${crudProvider.isInitialized}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }
}