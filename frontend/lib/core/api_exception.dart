/// Lỗi gọi API đã được chuẩn hóa. `message` là câu tiếng Việt/thông báo
/// của backend, có thể hiện thẳng cho người dùng.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
