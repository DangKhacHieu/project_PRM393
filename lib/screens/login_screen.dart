import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../main.dart';
import 'register_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true; // Thêm biến để ẩn/hiện mật khẩu
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _handleLogin() async {
    setState(() => _isLoading = true);
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showMsg("Vui lòng nhập đầy đủ Email và Mật khẩu");
      setState(() => _isLoading = false);
      return;
    }

    if (!_isValidEmail(email)) {
      _showMsg("Email không đúng định dạng!");
      return;
    }

    bool success = await _authService.loginUser(email, password);
    setState(() => _isLoading = false);

    if (success) {
      if (!mounted) return;

      // Khi đăng nhập thành công, ta điều hướng sang HomeScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            isDarkMode: false, // Ép mặc định Light Mode khi vừa từ trang Login sáng qua
            onThemeChanged: (bool val) async {
              // Logic lưu theme vẫn giữ nguyên để trang Home hoạt động
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isDarkMode', val);

              // Sau đó yêu cầu main.dart nạp lại để trang Home đổi màu
              Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
            },
          ),
        ),
      );
    } else {
      _showMsg("Email hoặc mật khẩu không chính xác!");
    }
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Tạo nền Gradient nhẹ nhàng cho chuyên nghiệp
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.amber.shade200, Colors.white],
          ),
        ),
        child: Center( // ĐƯA TOÀN BỘ VÀO GIỮA MÀN HÌNH
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card( // Dùng Card để tạo khối trắng nổi bật
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min, // Để Card co giãn theo nội dung
                  children: [
                    // Icon Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_person_rounded, size: 50, color: Colors.orange),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "ĐĂNG NHẬP",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 8),
                    const Text("Chào mừng bạn quay trở lại!", style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 32),

                    // Ô nhập Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
                        hintText: "example@mail.com",
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ô nhập Mật khẩu
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 32),


                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("ĐĂNG NHẬP", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Nút chuyển màn hình
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Chưa có tài khoản? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => RegisterScreen()));
                          },
                          child: const Text(
                            "Đăng ký ngay",
                            style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}