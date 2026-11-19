/// Cấu hình địa chỉ backend. CHỈ SỬA Ở ĐÂY khi đổi địa chỉ API.
///
/// - Máy ảo Android + backend chạy trên CÙNG máy tính: dùng 10.0.2.2 (không dùng localhost).
/// - Điện thoại thật: thay bằng IP máy chạy backend (ví dụ http://192.168.1.10:3100/api/v1)
///   hoặc địa chỉ server đã triển khai.
///
/// Có thể đổi khi chạy mà không sửa code:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3100/api/v1
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3100/api/v1',
  );
}
