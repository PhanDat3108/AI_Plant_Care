import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  static const _storage = FlutterSecureStorage();

  // Tự động nhận diện thiết bị để cấu hình Base URL chuẩn
  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3100/api/v1';     // Android 
    } else {
      return 'http://localhost:3100/api/v1';    // iOS 
    }
  }

  // Tự động lấy token và cấu hình Header cho mọi Request
  static Future<Map<String, String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

// --- Hàm PUT dùng chung ---
  static Future<Map<String, dynamic>> put(String endpoint, {Map<String, dynamic>? body,}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      if (e is FormatException) {
        throw Exception('Dữ liệu máy chủ trả về bị lỗi định dạng.');
      }
      throw Exception('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng!');
    }
  }

  // Hàm POST dùng chung
  static Future<Map<String, dynamic>> post(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      if (e is FormatException) throw Exception('Dữ liệu máy chủ trả về bị lỗi định dạng.');
      throw Exception('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng!');
    }
  }

  // Hàm GET dùng chung
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      if (e is FormatException) throw Exception('Dữ liệu máy chủ trả về bị lỗi định dạng.');
      throw Exception('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng!');
    }
  }

  // Hàm PATCH dùng chung
  static Future<Map<String, dynamic>> patch(String endpoint, {Map<String, dynamic>? body}) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final headers = await _getHeaders();

    try {
      final response = await http.patch(
        url,
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ).timeout(const Duration(seconds: 10));

      return _processResponse(response);
    } catch (e) {
      throw Exception('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng!');
    }
  }

  // Xử lý dữ liệu trả về theo chuẩn Backend
  static Map<String, dynamic> _processResponse(http.Response response) {
    final decodedBody = jsonDecode(response.body);

    // Kiểm tra HTTP status và cờ "success" từ backend
    if (response.statusCode >= 200 && response.statusCode < 300 && decodedBody['success'] == true) {
      // Backend bọc dữ liệu trong field "data", ta bóc ra luôn ở đây
      return decodedBody['data'] ?? {};
    } else {
      // Bắt các mã lỗi như 400, 401, 404, 500
      final errorMessage = decodedBody['message'] ?? 'Đã xảy ra lỗi hệ thống.';

      // Nếu mã lỗi là 401 (Hết hạn Token), ta có thể kích hoạt luồng Refresh Token ở đây sau
      if (response.statusCode == 401) {
        throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
      }

      throw Exception(errorMessage);
    }
  }
}
