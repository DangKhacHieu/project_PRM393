import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController(); // Thêm controller xác nhận

  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _handleRegister() async {
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();
    String confirmPass = _confirmPasswordController.text.trim();

    // 1. Kiểm tra trống
    if (email.isEmpty || password.isEmpty || confirmPass.isEmpty) {
      _showMsg("Vui lòng nhập đầy đủ thông tin ");
      return;
    }

    //2.Kiểm tra định dạng gmail
    if (!_isValidEmail(email)) {
      _showMsg("Định dạng Email không hợp lệ! (Ví dụ: abc@gmail.com)");
      return;
    }

    // 3. Kiểm tra mật khẩu khớp nhau
    if (password != confirmPass) {
      _showMsg("Mật khẩu xác nhận không khớp!");
      return;
    }

    // 4. Kiểm tra độ dài mật khẩu (Ví dụ tối thiểu 6 ký tự)
    if (password.length < 6) {
      _showMsg("Mật khẩu phải có ít nhất 6 ký tự");
      return;
    }

    setState(() => _isLoading = true);

    // Gọi hàm đăng ký từ AuthService
    String? error = await _authService.registerUser(email, password);

    setState(() => _isLoading = false);

    if (error == null) {
      _showMsg("Đăng ký thành công! Hãy đăng nhập.");
      if (mounted) Navigator.pop(context); // Quay lại màn hình Login
    } else {
      _showMsg(error);
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
      // Nền Gradient đồng bộ với trang Login
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
        child: Center( // ĐƯA VÀO GIỮA MÀN HÌNH
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, size: 50, color: Colors.orange),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "ĐĂNG KÝ",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 32),

                    // Ô nhập Email
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: "Email",
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
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Ô nhập lại Mật khẩu
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      decoration: InputDecoration(
                        labelText: "Xác nhận mật khẩu",
                        prefixIcon: const Icon(Icons.lock_reset_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Nút Đăng ký
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 4,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("TẠO TÀI KHOẢN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Nút quay lại Login
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Đã có tài khoản? Đăng nhập",
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                      ),
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