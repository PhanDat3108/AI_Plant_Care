import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_exception.dart';
import 'dio_client.dart';
import 'token_storage.dart';

/// Đăng nhập Google qua trình duyệt hệ thống (OAuth + PKCE),
/// theo GOOGLE_MOBILE_SETUP.md. Không lưu/ghi log code hay token.
class GoogleAuthService {
  GoogleAuthService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _verifierKey = 'google_pkce_verifier';
  static const String _createdKey = 'google_pkce_created_at';
  static const Duration _maxAge = Duration(minutes: 10);

  // Địa chỉ quay về app, phải trùng AndroidManifest và Supabase Redirect URLs.
  static const String callbackScheme = 'vn.aiplantcare.app';
  static const String callbackHost = 'auth';
  static const String callbackPath = '/callback';

  // Chống xử lý trùng cùng một callback.
  static String? _lastHandledCode;

  static bool isCallback(Uri uri) =>
      uri.scheme == callbackScheme &&
      uri.host == callbackHost &&
      uri.path == callbackPath;

  /// Bước 1: tạo PKCE, xin URL đăng nhập Google và mở bằng trình duyệt.
  static Future<void> start() async {
    final verifier = _generateVerifier();
    final challenge = _challengeOf(verifier);

    await _storage.write(key: _verifierKey, value: verifier);
    await _storage.write(
      key: _createdKey,
      value: DateTime.now().millisecondsSinceEpoch.toString(),
    );

    try {
      final data = await DioClient.instance.post(
        '/auth/google',
        body: {'code_challenge': challenge},
        auth: false,
      );
      final url = data is Map ? data['url'] : null;
      final uri = url is String ? Uri.tryParse(url) : null;
      if (uri == null || uri.scheme != 'https') {
        throw const ApiException('Không lấy được đường dẫn đăng nhập Google.');
      }
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) {
        throw const ApiException('Không mở được trình duyệt để đăng nhập.');
      }
    } catch (_) {
      await _clearPending();
      rethrow;
    }
  }

  /// Bước 2: xử lý link quay về app.
  /// Trả true nếu đã đăng nhập xong (token đã lưu), false nếu link không liên quan
  /// hoặc là callback trùng. Ném [ApiException] khi hủy/thất bại.
  static Future<bool> handleCallback(Uri uri) async {
    if (!isCallback(uri)) return false;

    final params = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      try {
        params.addAll(Uri.splitQueryString(uri.fragment));
      } catch (_) {}
    }

    if (params['error'] != null) {
      await _clearPending();
      throw const ApiException('Đăng nhập Google đã bị hủy hoặc thất bại.');
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const ApiException('Phản hồi đăng nhập Google không hợp lệ.');
    }
    if (code == _lastHandledCode) return false;

    final verifier = await _storage.read(key: _verifierKey);
    final created = int.tryParse(await _storage.read(key: _createdKey) ?? '');
    final expired = created == null ||
        DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(created)) >
            _maxAge;
    if (verifier == null || verifier.isEmpty || expired) {
      await _clearPending();
      throw const ApiException(
        'Phiên đăng nhập Google đã hết hạn. Vui lòng thử lại.',
      );
    }

    _lastHandledCode = code;
    try {
      final data = await DioClient.instance.post(
        '/auth/exchange-code',
        body: {'auth_code': code, 'code_verifier': verifier},
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
      return true;
    } finally {
      await _clearPending();
    }
  }

  static Future<void> _clearPending() async {
    await _storage.delete(key: _verifierKey);
    await _storage.delete(key: _createdKey);
  }

  // 32 byte ngẫu nhiên -> base64url bỏ padding (43 ký tự, đúng chuẩn PKCE).
  static String _generateVerifier() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  static String _challengeOf(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
