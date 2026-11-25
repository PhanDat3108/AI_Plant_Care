import '../core/api_exception.dart';
import 'dio_client.dart';
import 'token_storage.dart';
import 'push_notification_service.dart';

/// Các thao tác xác thực, gọi đúng API trong hợp đồng backend (tiền tố /api/v1
/// đã nằm trong ApiConfig.baseUrl).
class AuthService {
  AuthService._();

  static final DioClient _api = DioClient.instance;

  /// POST /auth/login {email, password}
  /// Thành công: lưu access_token + refresh_token. Trả về data.user (có thể null).
  static Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final data = await _api.post(
      '/auth/login',
      body: {'email': email, 'password': password},
      auth: false,
    );

    if (data is! Map ||
        data['access_token'] is! String ||
        data['refresh_token'] is! String) {
      throw const ApiException('Phản hồi đăng nhập không hợp lệ.');
    }

    await TokenStorage.save(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
    );

    final user = data['user'];
    return user is Map<String, dynamic> ? user : null;
  }

  /// POST /auth/register {full_name, email, password}
  /// Backend yêu cầu xác nhận email, nên không có token ở bước này.
  static Future<void> register({
    required String fullName,
    required String email,
    required String password,
  }) async {
    await _api.post(
      '/auth/register',
      body: {'full_name': fullName, 'email': email, 'password': password},
      auth: false,
    );
  }

  /// POST /auth/resend-confirmation {email}
  static Future<void> resendConfirmation(String email) async {
    await _api.post(
      '/auth/resend-confirmation',
      body: {'email': email},
      auth: false,
    );
  }

  /// POST /auth/forgot-password {email}
  /// Phản hồi trung tính, backend gửi email nếu hợp lệ.
  static Future<void> forgotPassword(String email) async {
    await _api.post(
      '/auth/forgot-password',
      body: {'email': email},
      auth: false,
    );
  }

  /// POST /auth/logout rồi xóa token trên thiết bị.
  /// Dù gọi API lỗi (mất mạng...) vẫn xóa token để người dùng thoát được.
  static Future<bool> logout() async {
    final pushRemoved = await PushNotificationService.instance.endSession();
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // bỏ qua: vẫn đăng xuất cục bộ
    } finally {
      await TokenStorage.clear();
    }
    return pushRemoved;
  }

  /// Đã có token lưu trên máy hay chưa (dùng để quyết định mở màn nào đầu tiên).
  static Future<bool> hasSession() async {
    final token = await TokenStorage.readAccess();
    return token != null && token.isNotEmpty;
  }
}
