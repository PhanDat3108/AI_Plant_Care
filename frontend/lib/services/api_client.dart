import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  static const _storage = FlutterSecureStorage();
  static const _defaultTimeout = Duration(seconds: 15);

  static String get baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3100/api/v1';
    }
    return 'http://localhost:3100/api/v1';
  }

  static Uri _buildUri(String endpoint, [Map<String, String>? queryParameters]) {
    final uri = Uri.parse('$baseUrl$endpoint');
    if (queryParameters == null || queryParameters.isEmpty) return uri;
    return uri.replace(queryParameters: queryParameters);
  }

  static Future<Map<String,String>> _getHeaders() async {
    final token = await _storage.read(key: 'access_token');
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String,String>> get(
    String endpoint, {
    Map<String, String>? queryParameters,
    Duration timeout = _defaultTimeout,}) async {
    final headers = await _getHeaders();
    return _send(
      () => http
          .get(_buildUri(endpoint, queryParameters), headers: headers)
          .timeout(timeout),
    );
  }

  static Future<Map<String,String>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Duration timeout = _defaultTimeout,
  }) async {
    final headers = await _getHeaders();
    return _send(
      () => http
          .post(
            _buildUri(endpoint),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout),
    );
  }

  static Future<Map<String,String>> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Duration timeout = _defaultTimeout,
  }) async {
    final headers = await _getHeaders();
    return _send(
      () => http
          .put(
            _buildUri(endpoint),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout),
    );
  }

  static Future<Map<String,String>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Duration timeout = _defaultTimeout,
  }) async {
    final headers = await _getHeaders();
    return _send(
      () => http
          .patch(
            _buildUri(endpoint),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout),
    );
  }

  static Future<Map<String,String>> delete(
    String endpoint, {
    Duration timeout = _defaultTimeout,
  }) async {
    final headers = await _getHeaders();
    return _send(
      () => http.delete(_buildUri(endpoint), headers: headers).timeout(timeout),
    );
  }

  static Future<Map<String,String>> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request();
      return _processResponse(response);
    } on SocketException {
      throw Exception('Không thể kết nối máy chủ. Vui lòng kiểm tra mạng!');
    } on TimeoutException {
      throw Exception('Máy chủ phản hồi quá lâu. Vui lòng thử lại!');
    } on FormatException {
      throw Exception('Dữ liệu máy chủ trả về bị lỗi định dạng.');
    }
  }

  static dynamic _processResponse(http.Response response) {
    final decodedBody =
        response.body.isNotEmpty ? jsonDecode(response.body) : <String, dynamic>{};

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decodedBody is Map<String, dynamic> &&
        decodedBody['success'] == true) {
      return decodedBody['data'];
    }

    final errorMessage = (decodedBody is Map<String, dynamic> &&
            decodedBody['message'] != null)
        ? decodedBody['message'].toString()
        : 'Đã xảy ra lỗi hệ thống (${response.statusCode}).';

    if (response.statusCode == 401) {
      throw Exception('Phiên đăng nhập hết hạn. Vui lòng đăng nhập lại.');
    }

    throw Exception(errorMessage);
  }
}