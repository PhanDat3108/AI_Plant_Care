/// Thông tin người dùng hiển thị ở màn Hồ sơ.
/// Sau này map từ response của GET /me.
class UserModel {
  final String fullName;
  final String email;
  final String? avatarUrl; // null -> dùng ảnh mặc định
  final int totalPlants; // Tổng số cây đang chăm sóc
  final int totalAiScans; // Tổng số lần quét AI

  const UserModel({
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.totalPlants,
    required this.totalAiScans,
  });
}
