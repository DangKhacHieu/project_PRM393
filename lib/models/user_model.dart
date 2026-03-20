class UserModel {
  final int? id;
  final String email;
  final String password;

  UserModel({
    this.id,
    required this.email,
    required this.password,
  });

  // Chuyển từ Model sang Map để lưu vào SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'password': password,
    };
  }

  // Chuyển từ Map (SQLite) ngược lại thành Model để sử dụng trong App
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      email: map['email'],
      password: map['password'],
    );
  }
}