import '../../../domain/user/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required int id,
    required String fullName,
    required String email,
  }) : super(id: id, fullName: fullName, email: email);

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Đảm bảo các trường đọc ra đúng kiểu dữ liệu
    final id = json['id'] is int
        ? json['id']
        : int.tryParse(json['id'].toString()) ?? 0;
    final name =
        json['fullName']?.toString() ??
        json['name']?.toString() ??
        'Unknown User';
    final email = json['email']?.toString() ?? '';

    return UserModel(id: id, fullName: name, email: email);
  }

  // Chuyển đổi từ Map đọc ra từ database SQLite
  factory UserModel.fromDb(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'],
      fullName: map['fullName'],
      email: map['email'],
    );
  }
}
