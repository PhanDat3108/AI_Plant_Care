/// Các hàm kiểm tra dữ liệu nhập, dùng cho `validator:` của TextFormField.
/// Trả về null nếu hợp lệ, trả về câu báo lỗi nếu sai.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const int passwordMinLength = 8; // theo hợp đồng API: 8–256 ký tự
  static const int passwordMaxLength = 256;

  static String? email(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return 'Vui lòng nhập email';
    if (!_emailRegex.hasMatch(v)) return 'Email không hợp lệ';
    return null;
  }

  /// Dùng cho ô mật khẩu ở màn Đăng nhập: chỉ cần không để trống.
  static String? requiredPassword(String? value) {
    if ((value ?? '').isEmpty) return 'Vui lòng nhập mật khẩu';
    return null;
  }

  /// Dùng cho ô mật khẩu ở màn Đăng ký / đặt mật khẩu mới.
  static String? newPassword(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < passwordMinLength) {
      return 'Mật khẩu tối thiểu $passwordMinLength ký tự';
    }
    if (v.length > passwordMaxLength) {
      return 'Mật khẩu tối đa $passwordMaxLength ký tự';
    }
    return null;
  }

  static String? fullName(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Vui lòng nhập họ và tên';
    return null;
  }

  /// Ô nhập lại mật khẩu: chỉ kiểm tra ở frontend, không gửi lên backend.
  static String? Function(String?) confirmPassword(String Function() original) {
    return (String? value) {
      if ((value ?? '').isEmpty) return 'Vui lòng nhập lại mật khẩu';
      if (value != original()) return 'Mật khẩu nhập lại không khớp';
      return null;
    };
  }
}
