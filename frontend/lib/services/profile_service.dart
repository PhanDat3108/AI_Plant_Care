import '../core/api_exception.dart';
import '../models/user_model.dart';
import 'dio_client.dart';

/// API hồ sơ (theo PROFILE_API.md). Mọi request cần Bearer token,
/// DioClient tự gắn và tự làm mới token khi gặp 401.
class ProfileService {
  ProfileService._();

  static final DioClient _api = DioClient.instance;

  /// GET /me: hồ sơ + thống kê (total_plants, total_ai_scans, care_stats).
  static Future<UserModel> getMe() async {
    final data = await _api.get('/me');
    if (data is! Map) {
      throw const ApiException('Dữ liệu hồ sơ không hợp lệ.');
    }
    return UserModel.fromJson(Map<String, dynamic>.from(data));
  }

  /// PATCH /me: chỉ gửi display_name và/hoặc timezone.
  /// Không gửi email, id, avatar hay thống kê. Sau khi lưu, gọi [getMe] để nạp lại.
  static Future<void> updateMe({String? displayName, String? timezone}) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['display_name'] = displayName;
    if (timezone != null) body['timezone'] = timezone;
    await _api.patch('/me', body: body);
  }
}
