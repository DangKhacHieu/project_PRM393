import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder.dart';
import '../models/user_model.dart';

class DBHelper {
  static Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await initDb();
    return _db!;
  }

  initDb() async {
    // Đổi tên file để SQLite thực hiện onCreate tạo lại cấu trúc có user_id
    String path = join(await getDatabasesPath(), 'reminders_v4_final.db');

    return await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          // 1. Bảng Users (Xác thực)
          await db.execute('''
            CREATE TABLE users(
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              email TEXT UNIQUE, 
              password TEXT
            )
          ''');

          // 2. Bảng Reminders (CRUD) - Có liên kết user_id
          await db.execute('''
            CREATE TABLE reminders(
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              user_id INTEGER, 
              title TEXT, 
              content TEXT, 
              time TEXT, 
              isDone INTEGER DEFAULT 0, 
              priority TEXT DEFAULT 'Medium',
              category TEXT,
              isDeleted INTEGER DEFAULT 0,
              FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            )
          ''');

          // 3. Bảng Categories (Dữ liệu động)
          await db.execute('''
            CREATE TABLE categories(
              id INTEGER PRIMARY KEY AUTOINCREMENT, 
              name TEXT UNIQUE
            )
          ''');

          // Dữ liệu mẫu ban đầu
          await db.execute('INSERT INTO categories(name) VALUES("Học tập")');
          await db.execute('INSERT INTO categories(name) VALUES("Công việc")');
        }
    );
  }

  // --- HÀM TRỢ GIÚP LẤY ID NGƯỜI DÙNG ĐANG ĐĂNG NHẬP ---
  Future<int?> _getCurrentUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  // ==========================================
  // --- CHỨC NĂNG AUTHENTICATION (XÁC THỰC) ---
  // ==========================================

  // Đăng ký tài khoản mới
  Future<int> register(UserModel user) async {
    var dbClient = await db;
    try {
      return await dbClient.insert('users', user.toMap());
    } catch (e) {
      return -1; // Trả về -1 nếu Email đã tồn tại (UNIQUE)
    }
  }

  // Đăng nhập và quản lý phiên
  Future<bool> login(String email, String password) async {
    var dbClient = await db;
    List<Map<String, dynamic>> res = await dbClient.query(
      'users',
      where: 'email = ? AND password = ?',
      whereArgs: [email, password],
    );

    if (res.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setInt('userId', res.first['id']); // Lưu ID để lọc dữ liệu riêng
      await prefs.setString('userEmail', email);
      return true;
    }
    return false;
  }

  // Đăng xuất
  Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', false);
    await prefs.remove('userId');
    await prefs.remove('userEmail');
  }

  // Kiểm tra trạng thái phiên
  Future<bool> isUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isLoggedIn') ?? false;
  }

  // ==========================================
  // --- QUẢN LÝ LỜI NHẮC (CRUD THEO USER) ---
  // ==========================================

  // Create: Thêm mới lời nhắc và tự động gắn user_id
  Future<int> insert(Reminder reminder) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    Map<String, dynamic> row = reminder.toMap();
    row['user_id'] = userId; // Gắn quyền sở hữu cho người dùng hiện tại

    return await dbClient.insert('reminders', row);
  }

  // Read: Lấy danh sách chưa xóa của RIÊNG người dùng hiện tại
  Future<List<Reminder>> getReminders() async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    List<Map<String, dynamic>> maps = await dbClient.query(
        'reminders',
        where: 'isDeleted = 0 AND user_id = ?',
        whereArgs: [userId],
        orderBy: 'id DESC'
    );
    return maps.map((e) => Reminder.fromMap(e)).toList();
  }

  // Update: Sửa lời nhắc (Chỉ cho phép nếu thuộc về User và chưa xong)
  Future<int> updateReminder(Reminder reminder) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    return await dbClient.update(
        'reminders',
        reminder.toMap(),
        where: 'id = ? AND user_id = ? AND isDone = 0',
        whereArgs: [reminder.id, userId]
    );
  }

  // Update: Đánh dấu hoàn thành
  Future<int> updateStatus(int id, int status) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    return await dbClient.update(
        'reminders',
        {'isDone': status},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId]
    );
  }

  // Delete (Tạm thời): Chuyển vào thùng rác
  Future<int> moveToTrash(int id) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    return await dbClient.update(
        'reminders',
        {'isDeleted': 1},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId]
    );
  }

  // ==========================================
  // --- THÙNG RÁC RIÊNG BIỆT ---
  // ==========================================

  // Lấy danh sách trong thùng rác của riêng User
  Future<List<Reminder>> getTrashedReminders() async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    List<Map<String, dynamic>> maps = await dbClient.query(
        'reminders',
        where: 'isDeleted = 1 AND user_id = ?',
        whereArgs: [userId],
        orderBy: 'id DESC'
    );
    return maps.map((e) => Reminder.fromMap(e)).toList();
  }

  // Khôi phục
  Future<int> restoreReminder(int id) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    return await dbClient.update(
        'reminders',
        {'isDeleted': 0},
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId]
    );
  }

  // Xóa vĩnh viễn
  Future<int> deletePermanently(int id) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    return await dbClient.delete(
        'reminders',
        where: 'id = ? AND user_id = ?',
        whereArgs: [id, userId]
    );
  }

  // ==========================================
  // --- QUẢN LÝ CATEGORY & CALENDAR ---
  // ==========================================

  Future<List<String>> getCategories() async {
    var dbClient = await db;
    List<Map<String, dynamic>> res = await dbClient.query("categories");
    return res.map((e) => e['name'] as String).toList();
  }

  Future<int> insertCategory(String name) async {
    var dbClient = await db;
    return await dbClient.insert("categories", {'name': name}, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Lấy nhắc nhở theo ngày của riêng User
  Future<List<Reminder>> getRemindersByDate(String date) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    List<Map<String, dynamic>> maps = await dbClient.query(
        'reminders',
        where: "date(time) = date(?) AND isDeleted = 0 AND user_id = ?",
        whereArgs: [date, userId],
        orderBy: 'id DESC'
    );
    return maps.map((e) => Reminder.fromMap(e)).toList();
  }

  // Lấy toàn bộ sự kiện cho Lịch của riêng User
  Future<Map<String, List<Reminder>>> getAllEventsForCalendar() async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    List<Map<String, dynamic>> maps = await dbClient.query(
        'reminders',
        where: 'isDeleted = 0 AND user_id = ?',
        whereArgs: [userId]
    );

    Map<String, List<Reminder>> eventMap = {};
    for (var item in maps) {
      Reminder reminder = Reminder.fromMap(item);
      String dateKey = reminder.time.substring(0, 10);
      if (eventMap[dateKey] == null) eventMap[dateKey] = [];
      eventMap[dateKey]!.add(reminder);
    }
    return eventMap;
  }

  // Thêm hàm này vào class DBHelper của bạn
  Future<Map<String, int>> getReminderStatistics() async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();

    // Đếm số lượng nhắc nhở chưa xóa của User hiện tại
    // 1. Lấy số lượng Đang chờ (Pending)
    var pendingRes = await dbClient.rawQuery(
        'SELECT COUNT(*) as count FROM reminders WHERE user_id = ? AND isDone = 0 AND isDeleted = 0',
        [userId]
    );

    // 2. Lấy số lượng Đã hoàn thành (Completed)
    var completedRes = await dbClient.rawQuery(
        'SELECT COUNT(*) as count FROM reminders WHERE user_id = ? AND isDone = 1 AND isDeleted = 0',
        [userId]
    );

    return {
      'pending': Sqflite.firstIntValue(pendingRes) ?? 0,
      'completed': Sqflite.firstIntValue(completedRes) ?? 0,
    };
  }

  Future<Map<String, dynamic>> getAdvancedStatistics() async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId();
    String now = DateTime.now().toIso8601String();

    // 1. Thống kê Trạng thái (Hoàn thành, Quá hạn, Đang chờ)
    var statusRes = await dbClient.rawQuery('''
    SELECT 
      SUM(CASE WHEN isDone = 1 THEN 1 ELSE 0 END) as completed,
      SUM(CASE WHEN isDone = 0 AND datetime(time) < datetime(?) THEN 1 ELSE 0 END) as overdue,
      SUM(CASE WHEN isDone = 0 AND datetime(time) >= datetime(?) THEN 1 ELSE 0 END) as pending
    FROM reminders 
    WHERE user_id = ? AND isDeleted = 0
  ''', [now, now, userId]);

    // 2. Thống kê theo Category (Danh mục)
    var categoryRes = await dbClient.rawQuery('''
    SELECT category, COUNT(*) as count 
    FROM reminders 
    WHERE user_id = ? AND isDeleted = 0
    GROUP BY category
  ''', [userId]);

    return {
      'status': statusRes.first,
      'categories': categoryRes,
    };
  }

  // Thêm vào trong class DBHelper
  Future<Map<String, dynamic>> getMonthlyStatistics(int month, int year) async {
    var dbClient = await db;
    int? userId = await _getCurrentUserId(); // Lấy từ SharedPreferences [cite: 4]

    // Định dạng tháng thành 'YYYY-MM' để khớp với cột 'time' [cite: 7]
    String monthStr = "$year-${month.toString().padLeft(2, '0')}";
    String now = DateTime.now().toIso8601String();

    // 1. Thống kê trạng thái (Logic tối ưu cho UX) [cite: 9, 35]
    var statusRes = await dbClient.rawQuery('''
    SELECT 
      -- Hoàn thành: Tính tất cả (kể cả đã xóa vào thùng rác) để ghi nhận năng suất [cite: 17, 25]
      SUM(CASE WHEN isDone = 1 THEN 1 ELSE 0 END) as completed,
      
      -- Quá hạn: Chỉ tính nếu CHƯA XONG và CHƯA BỊ XÓA [cite: 9, 11]
      SUM(CASE WHEN isDone = 0 AND isDeleted = 0 AND datetime(time) < datetime(?) THEN 1 ELSE 0 END) as overdue,
      
      -- Đang chờ: Chỉ tính nếu CHƯA XONG và CHƯA BỊ XÓA [cite: 9, 11]
      SUM(CASE WHEN isDone = 0 AND isDeleted = 0 AND datetime(time) >= datetime(?) THEN 1 ELSE 0 END) as pending
    FROM reminders 
    WHERE user_id = ? 
      AND strftime('%Y-%m', time) = ?
  ''', [now, now, userId, monthStr]);

    // 2. Thống kê theo danh mục (Category) [cite: 33, 34]
    // Lưu ý: Chỉ thống kê các Category của những việc thực sự tồn tại (chưa xóa) hoặc đã xong
    var categoryRes = await dbClient.rawQuery('''
    SELECT category, COUNT(*) as count 
    FROM reminders 
    WHERE user_id = ? 
      AND strftime('%Y-%m', time) = ?
      AND (isDeleted = 0 OR isDone = 1) 
    GROUP BY category
  ''', [userId, monthStr]);

    return {
      'status': statusRes.first,
      'categories': categoryRes,
    };
  }
}