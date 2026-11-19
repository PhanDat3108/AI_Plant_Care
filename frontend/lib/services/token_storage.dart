import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Lưu access_token và refresh_token an toàn trên thiết bị.
/// Đăng xuất xong phải gọi [clear] (theo hợp đồng API).
class TokenStorage {
  TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  static Future<String?> readAccess() => _storage.read(key: _accessKey);

  static Future<String?> readRefresh() => _storage.read(key: _refreshKey);

  static Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }
}
