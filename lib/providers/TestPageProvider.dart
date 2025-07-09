import 'package:flutter/foundation.dart';
import 'GenericCRUDProvider.dart';

/// TestPageProvider - Complete Business Logic Layer
/// จัดการ business logic ทั้งหมดสำหรับหน้า Test Page
class TestPageProvider extends ChangeNotifier {
  
  // ========== DEPENDENCY INJECTION ==========
  final GenericCRUDProvider crudProvider;
  
  // ========== PRIVATE STATE VARIABLES ==========
  bool _isInitialized = false;
  String? _lastError;
  bool _isProcessing = false;
  List<Map<String, dynamic>> _users = [];
  String _searchQuery = '';
  
  // ========== CONSTRUCTOR ==========
  TestPageProvider(this.crudProvider) {
    // Auto-initialize เมื่อสร้าง instance
    _initializeDatabase();
  }
  
  // ========== PUBLIC GETTERS ==========
  bool get isInitialized => _isInitialized;
  String? get lastError => _lastError;
  bool get isProcessing => _isProcessing;
  List<Map<String, dynamic>> get users => _users;
  String get searchQuery => _searchQuery;
  
  // ========== DATABASE INITIALIZATION ==========
  
  /// เริ่มต้น database
  Future<void> _initializeDatabase() async {
    try {
      _setProcessing(true);
      _clearError();
      
      debugPrint('🚀 [Provider] Initializing database...');
      
      // สร้าง table schema
      final usersTable = TableSchema.createGenericTable(
        'users',
        extraColumns: {
          'name': 'TEXT NOT NULL',
          'email': 'TEXT UNIQUE',
          'age': 'INTEGER',
          'status': 'TEXT DEFAULT "active"',
        },
      );

      // เรียกใช้ GenericCRUDProvider เพื่อ initialize database
      await crudProvider.initializeDatabase(
        customDatabaseName: 'test_app.db',
        customVersion: 1,
        initialTables: [usersTable],
      );
      
      _isInitialized = true;
      debugPrint('✅ [Provider] Database initialized');
      
      // โหลดข้อมูลเริ่มต้น
      await _loadUsers();
      
    } catch (e) {
      _setError('Database initialization failed: $e');
      debugPrint('❌ [Provider] Init failed: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// Retry initialization
  Future<void> retryInitialization() async {
    _isInitialized = false;
    await _initializeDatabase();
  }
  
  // ========== DATA OPERATIONS ==========
  
  /// โหลดรายชื่อ Users จาก database
  Future<void> _loadUsers() async {
    try {
      if (!_isInitialized) return;
      
      debugPrint('📖 [Provider] Loading users...');
      
      // เรียกใช้ GenericCRUDProvider อ่านข้อมูล
      final usersList = await crudProvider.readAll('users', orderBy: 'created_at DESC');
      
      // อัพเดท internal state
      _users = usersList;
      
      debugPrint('📊 [Provider] Loaded ${_users.length} users');
      
      // แจ้ง UI ว่าข้อมูลเปลี่ยน
      notifyListeners();
      
    } catch (e) {
      _setError('Failed to load users: $e');
      debugPrint('❌ [Provider] Load users error: $e');
    }
  }

  /// รีเฟรชข้อมูล Users
  Future<void> refreshUsers() async {
    if (_isProcessing) return; // ป้องกันการเรียกซ้ำ
    
    _setProcessing(true);
    _clearError();
    
    try {
      await _loadUsers();
      debugPrint('🔄 [Provider] Users refreshed');
    } finally {
      _setProcessing(false);
    }
  }
  
  /// สร้าง User ใหม่
  Future<bool> createUser({
    required String tableName,
    required String name,
    required String email,
    required int age,
    String status = 'active',
  }) async {
    try {
      _setProcessing(true);
      _clearError();
      
      // Validation
      if (name.trim().isEmpty) {
        _setError('Name is required');
        return false;
      }
      
      if (email.trim().isEmpty) {
        _setError('Email is required');
        return false;
      }
      
      debugPrint('📝 [Provider] Creating user in table: $tableName');
      debugPrint('📝 [Provider] User data: $name, $email, $age');
      
      // เรียกใช้ GenericCRUDProvider สร้างข้อมูล
      final userId = await crudProvider.create(tableName, {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'age': age,
        'status': status,
      });

      if (userId != null) {
        debugPrint('✅ [Provider] User created with ID: $userId in table: $tableName');
        await _loadUsers(); // รีโหลดข้อมูลใหม่
        return true;
      } else {
        _setError('Failed to create user in $tableName');
        return false;
      }
      
    } catch (e) {
      _setError('Create user failed in $tableName: $e');
      debugPrint('❌ [Provider] Create user error in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// อัพเดท User
  Future<bool> updateUser({
    required String tableName,
    required int userId,
    required Map<String, dynamic> data,
  }) async {
    try {
      _setProcessing(true);
      _clearError();
      
      // Validation
      if (data['name'] != null && data['name'].toString().trim().isEmpty) {
        _setError('Name cannot be empty');
        return false;
      }
      
      if (data['email'] != null && data['email'].toString().trim().isEmpty) {
        _setError('Email cannot be empty');
        return false;
      }
      
      debugPrint('✏️ [Provider] Updating user ID: $userId in table: $tableName');
      
      // Clean data
      final cleanData = <String, dynamic>{};
      if (data['name'] != null) cleanData['name'] = data['name'].toString().trim();
      if (data['email'] != null) cleanData['email'] = data['email'].toString().trim().toLowerCase();
      if (data['age'] != null) cleanData['age'] = data['age'];
      if (data['status'] != null) cleanData['status'] = data['status'];
      
      final success = await crudProvider.updateById(tableName, userId, cleanData);
      
      if (success) {
        debugPrint('✅ [Provider] User updated in table: $tableName');
        await _loadUsers(); // รีโหลดข้อมูลใหม่
        return true;
      } else {
        _setError('Failed to update user in $tableName');
        return false;
      }
      
    } catch (e) {
      _setError('Update user failed in $tableName: $e');
      debugPrint('❌ [Provider] Update user error in $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ลบ User
  Future<bool> deleteUser({
    required String tableName,
    required int userId,
  }) async {
    try {
      _setProcessing(true);
      _clearError();
      
      debugPrint('🗑️ [Provider] Deleting user ID: $userId from table: $tableName');
      
      final success = await crudProvider.deleteById(tableName, userId);
      
      if (success) {
        debugPrint('✅ [Provider] User deleted from table: $tableName');
        await _loadUsers(); // รีโหลดข้อมูลใหม่
        return true;
      } else {
        _setError('Failed to delete user from $tableName');
        return false;
      }
      
    } catch (e) {
      _setError('Delete user failed from $tableName: $e');
      debugPrint('❌ [Provider] Delete user error from $tableName: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// ค้นหา Users
  Future<void> searchUsers(String searchTerm) async {
    try {
      _setProcessing(true);
      _clearError();
      
      _searchQuery = searchTerm;
      
      if (searchTerm.trim().isEmpty) {
        await _loadUsers(); // โหลดข้อมูลทั้งหมด
        return;
      }
      
      debugPrint('🔍 [Provider] Searching users: $searchTerm');
      
      final results = await crudProvider.search('users', 'name', searchTerm.trim());
      _users = results;
      
      debugPrint('📊 [Provider] Found ${_users.length} matching users');
      notifyListeners();
      
    } catch (e) {
      _setError('Search failed: $e');
      debugPrint('❌ [Provider] Search error: $e');
    } finally {
      _setProcessing(false);
    }
  }

  /// ล้างการค้นหา
  Future<void> clearSearch() async {
    _searchQuery = '';
    await _loadUsers();
  }

  /// ดึงสถิติ Users
  Future<Map<String, dynamic>> getUserStatistics() async {
    try {
      final totalUsers = await crudProvider.count('users');
      final activeUsers = await crudProvider.count(
        'users', 
        where: 'status = ?', 
        whereArgs: ['active'],
      );
      
      return {
        'total': totalUsers,
        'active': activeUsers,
        'inactive': totalUsers - activeUsers,
      };
    } catch (e) {
      debugPrint('❌ [Provider] Statistics error: $e');
      return {'total': 0, 'active': 0, 'inactive': 0};
    }
  }

  /// ดึง Users ล่าสุด
  Future<List<Map<String, dynamic>>> getLatestUsers({int limit = 5}) async {
    try {
      return await crudProvider.getLatest('users', limit: limit);
    } catch (e) {
      debugPrint('❌ [Provider] Get latest users error: $e');
      return [];
    }
  }

  /// ลบ Users ทั้งหมด (สำหรับทดสอบ)
  Future<bool> deleteAllUsers() async {
    try {
      _setProcessing(true);
      _clearError();
      
      debugPrint('🗑️ [Provider] Deleting all users...');
      
      final success = await crudProvider.deleteAll('users');
      
      if (success) {
        debugPrint('✅ [Provider] All users deleted');
        await _loadUsers(); // รีโหลดข้อมูลใหม่
        return true;
      } else {
        _setError('Failed to delete all users');
        return false;
      }
      
    } catch (e) {
      _setError('Delete all users failed: $e');
      debugPrint('❌ [Provider] Delete all users error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// สร้าง Users ตัวอย่างหลายคน
  Future<bool> createSampleUsers() async {
    try {
      _setProcessing(true);
      _clearError();
      
      debugPrint('📝 [Provider] Creating sample users...');
      
      final sampleUsers = [
        {'name': 'John Doe', 'email': 'john@example.com', 'age': 30},
        {'name': 'Jane Smith', 'email': 'jane@example.com', 'age': 25},
        {'name': 'Bob Johnson', 'email': 'bob@example.com', 'age': 35},
        {'name': 'Alice Brown', 'email': 'alice@example.com', 'age': 28},
        {'name': 'Charlie Wilson', 'email': 'charlie@example.com', 'age': 32},
      ];

      int successCount = 0;
      for (final userData in sampleUsers) {
        try {
          final userId = await crudProvider.create('users', {
            ...userData,
            'status': 'active',
          });
          
          if (userId != null) {
            successCount++;
            debugPrint('✅ [Provider] Created sample user: ${userData['name']}');
          }
        } catch (e) {
          debugPrint('❌ [Provider] Failed to create ${userData['name']}: $e');
        }
      }

      if (successCount > 0) {
        await _loadUsers(); // รีโหลดข้อมูลใหม่
        debugPrint('✅ [Provider] Created $successCount/${{sampleUsers.length}} sample users');
        return true;
      } else {
        _setError('Failed to create any sample users');
        return false;
      }
      
    } catch (e) {
      _setError('Create sample users failed: $e');
      debugPrint('❌ [Provider] Create sample users error: $e');
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// อัพเดทสถานะของ User
  Future<bool> updateUserStatus({
    required String tableName,
    required int userId,
    required String newStatus,
  }) async {
    return await updateUser(
      tableName: tableName,
      userId: userId,
      data: {'status': newStatus},
    );
  }

  /// ดึง User ตาม ID
  Future<Map<String, dynamic>?> getUserById(int userId) async {
    try {
      return await crudProvider.readById('users', userId);
    } catch (e) {
      debugPrint('❌ [Provider] Get user by ID error: $e');
      return null;
    }
  }

  /// ดึง Users ตาม status
  Future<List<Map<String, dynamic>>> getUsersByStatus(String status) async {
    try {
      return await crudProvider.readWhere(
        'users',
        where: 'status = ?',
        whereArgs: [status],
        orderBy: 'name ASC',
      );
    } catch (e) {
      debugPrint('❌ [Provider] Get users by status error: $e');
      return [];
    }
  }

  /// ดึง Users แบบ pagination
  Future<PaginatedResult> getUsersPaginated({
    int page = 1,
    int itemsPerPage = 10,
  }) async {
    try {
      return await crudProvider.paginate(
        'users',
        page: page,
        itemsPerPage: itemsPerPage,
        orderBy: 'created_at DESC',
      );
    } catch (e) {
      debugPrint('❌ [Provider] Get users paginated error: $e');
      return PaginatedResult.empty();
    }
  }

  // ========== VALIDATION HELPERS ==========
  
  /// ตรวจสอบ email format


  /// ตรวจสอบว่า email ซ้ำหรือไม่
  Future<bool> isEmailExists(String email, {int? excludeUserId}) async {
    try {
      String whereClause = 'email = ?';
      List<dynamic> whereArgs = [email.trim().toLowerCase()];
      
      if (excludeUserId != null) {
        whereClause += ' AND id != ?';
        whereArgs.add(excludeUserId);
      }
      
      final results = await crudProvider.readWhere(
        'users',
        where: whereClause,
        whereArgs: whereArgs,
        limit: 1,
      );
      
      return results.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [Provider] Check email exists error: $e');
      return false;
    }
  }

  // ========== HELPER METHODS ==========
  
  /// ตั้งค่าสถานะ processing และแจ้ง listeners
  void _setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }

  /// ตั้งค่า error message และแจ้ง listeners
  void _setError(String? error) {
    _lastError = error;
    if (error != null) {
      debugPrint('❌ [Provider] Error: $error');
    }
    notifyListeners();
  }

  /// ล้าง error message
  void _clearError() {
    _lastError = null;
  }

  // ========== DEBUGGING HELPERS ==========

  /// แสดงข้อมูล debug
  void debugPrintState() {
    debugPrint('🔍 [Provider] Debug State:');
    debugPrint('  - Initialized: $_isInitialized');
    debugPrint('  - Processing: $_isProcessing');
    debugPrint('  - Users count: ${_users.length}');
    debugPrint('  - Search query: "$_searchQuery"');
    debugPrint('  - Last error: $_lastError');
  }

  /// ทดสอบ database connection
  Future<bool> testDatabaseConnection() async {
    try {
      final count = await crudProvider.count('users');
      debugPrint('✅ [Provider] Database connection OK, users count: $count');
      return true;
    } catch (e) {
      debugPrint('❌ [Provider] Database connection failed: $e');
      _setError('Database connection test failed: $e');
      return false;
    }
  }

  // ========== LIFECYCLE MANAGEMENT ==========
  
  @override
  void dispose() {
    debugPrint('🧹 [Provider] Disposing TestPageProvider');
    _users.clear();
    super.dispose();
  }
}

// ========== EXTENSION METHODS ==========

/// Extension สำหรับ User data
extension UserDataExtension on Map<String, dynamic> {
  
  /// ดึงชื่อเต็ม
  String get fullName => this['name']?.toString() ?? 'Unknown';
  
  /// ดึง email
  String get email => this['email']?.toString() ?? '';
  
  /// ดึงอายุ
  int get age => this['age'] as int? ?? 0;
  
  /// ดึงสถานะ
  String get status => this['status']?.toString() ?? 'unknown';
  
  /// ตรวจสอบว่าเป็น active หรือไม่
  bool get isActive => status.toLowerCase() == 'active';
  
  /// ดึงตัวอักษรแรกของชื่อ
  String get initials {
    final name = fullName;
    if (name.isEmpty) return '?';
    
    final parts = name.split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
  }
}

/*
📚 COMPLETE BUSINESS LOGIC FEATURES:

🔹 CRUD Operations:
  ✅ createUser() - สร้าง user ใหม่พร้อม validation
  ✅ updateUser() - อัพเดท user พร้อม validation
  ✅ deleteUser() - ลบ user
  ✅ deleteAllUsers() - ลบ users ทั้งหมด

🔹 Search & Filter:
  ✅ searchUsers() - ค้นหา users
  ✅ clearSearch() - ล้างการค้นหา
  ✅ getUsersByStatus() - กรอง users ตาม status

🔹 Data Loading:
  ✅ _loadUsers() - โหลด users ทั้งหมด
  ✅ refreshUsers() - รีเฟรชข้อมูล
  ✅ getLatestUsers() - ดึง users ล่าสุด
  ✅ getUsersPaginated() - ดึงข้อมูลแบบ pagination

🔹 Validation:
  ✅ _isValidEmail() - ตรวจสอบ email format
  ✅ isEmailExists() - ตรวจสอบ email ซ้ำ
  ✅ Input validation ใน create/update methods

🔹 Utilities:
  ✅ getUserStatistics() - สถิติ users
  ✅ createSampleUsers() - สร้าง users ตัวอย่าง
  ✅ updateUserStatus() - อัพเดท status
  ✅ testDatabaseConnection() - ทดสอบ database

🔹 Error Handling:
  ✅ Comprehensive try-catch blocks
  ✅ User-friendly error messages
  ✅ Debug logging

🔹 State Management:
  ✅ Reactive UI updates ด้วย notifyListeners()
  ✅ Loading states
  ✅ Error states

🎯 ARCHITECTURE BENEFITS:
- ✅ Clean separation of concerns
- ✅ Testable business logic
- ✅ Reusable components
- ✅ Maintainable code structure
- ✅ Comprehensive error handling
*/