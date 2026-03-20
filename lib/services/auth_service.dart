import 'package:shared_preferences/shared_preferences.dart';
import '../services/db_helper.dart';
import '../models/user_model.dart';

class AuthService {
  // Khởi tạo DBHelper để gọi các hàm xử lý Database
  final DBHelper _dbHelper = DBHelper();

  // 1. Chức năng Đăng ký
  Future<String?> registerUser(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      return "Vui lòng nhập đầy đủ thông tin";
    }

    // Tạo đối tượng Model để truyền vào DB
    UserModel newUser = UserModel(email: email, password: password);

    int result = await _dbHelper.register(newUser);

    if (result == -1) {
      return "Email này đã được đăng ký!";
    } else if (result > 0) {
      return null; // Trả về null nghĩa là đăng ký thành công
    } else {
      return "Có lỗi xảy ra, vui lòng thử lại";
    }
  }

  // 2. Chức năng Đăng nhập
  Future<bool> loginUser(String email, String password) async {
    // Gọi hàm login từ DBHelper để kiểm tra trong SQLite
    bool isSuccess = await _dbHelper.login(email, password);

    if (isSuccess) {
      // Nếu đăng nhập đúng, DBHelper đã tự động lưu session vào SharedPreferences
      return true;
    }
    return false;
  }

  // 3. Chức năng Đăng xuất (Logout)
  Future<void> logoutUser() async {
    await _dbHelper.logout();
  }

  // 4. Kiểm tra trạng thái phiên đăng nhập khi mở App
  // Hàm này dùng ở main.dart để quyết định hiện màn hình Login hay Home
  Future<bool> isLoggedIn() async {
    return await _dbHelper.isUserLoggedIn();
  }

  // 5. Lấy Email người dùng hiện tại để hiển thị trên Header
  Future<String?> getCurrentUserEmail() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('userEmail');
  }
}