import 'package:dio/dio.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import 'token_storage.dart';

/// Client gọi API dùng chung cho cả nhóm.
///
/// - Tự gắn `Authorization: Bearer <access_token>` vào mọi yêu cầu
///   (trừ khi gọi với `auth: false`, ví dụ đăng nhập, đăng ký).
/// - Khi gặp 401: tự gọi POST /auth/refresh, lưu lại 2 token mới rồi gọi lại 1 lần.
/// - Đọc response chung `{success, data, error, message}` và trả về phần `data`.
/// - Mọi lỗi được đổi thành [ApiException] với câu báo lỗi đọc được.
///
/// Cách dùng ở màn hình khác:
///   final data = await DioClient.instance.get('/me');
class DioClient {
  DioClient._() {
    final options = BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    );
    _dio = Dio(options);
    _refreshDio = Dio(options); // riêng, để không bị vòng lặp khi refresh

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] != true) {
            final token = await TokenStorage.readAccess();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final isUnauthorized = error.response?.statusCode == 401;
          final canRetry =
              request.extra['skipAuth'] != true &&
              request.extra['retried'] != true;

          if (isUnauthorized && canRetry) {
            final refreshed = await _refreshTokens();
            if (refreshed) {
              request.extra['retried'] = true;
              try {
                final response = await _dio.fetch<dynamic>(request);
                return handler.resolve(response);
              } on DioException catch (e) {
                return handler.next(e);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._();

  late final Dio _dio;
  late final Dio _refreshDio;

  // ---- Các hàm tiện dụng ----

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? receiveTimeout,
  }) => _send(
    'GET',
    path,
    queryParameters: queryParameters,
    auth: auth,
    receiveTimeout: receiveTimeout,
  );

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? receiveTimeout,
  }) => _send(
    'POST',
    path,
    body: body,
    queryParameters: queryParameters,
    auth: auth,
    receiveTimeout: receiveTimeout,
  );

  Future<dynamic> put(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? receiveTimeout,
  }) => _send(
    'PUT',
    path,
    body: body,
    queryParameters: queryParameters,
    auth: auth,
    receiveTimeout: receiveTimeout,
  );

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? receiveTimeout,
  }) => _send(
    'PATCH',
    path,
    body: body,
    queryParameters: queryParameters,
    auth: auth,
    receiveTimeout: receiveTimeout,
  );

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? receiveTimeout,
  }) => _send(
    'DELETE',
    path,
    queryParameters: queryParameters,
    auth: auth,
    receiveTimeout: receiveTimeout,
  );

  // ---- Bên trong ----

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required bool auth,
    Duration? receiveTimeout,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          receiveTimeout: receiveTimeout,
          extra: {'skipAuth': !auth},
        ),
      );
      return _unwrap(response.data, response.statusCode);
    } on DioException catch (e) {
      throw _toApiException(e);
    }
  }

  /// Bóc `{success, data, error, message}`: trả về `data`, hoặc ném lỗi.
  dynamic _unwrap(dynamic body, int? statusCode) {
    if (body is Map) {
      if (body['success'] == false) {
        throw ApiException(
          _messageFrom(body) ?? 'Đã có lỗi xảy ra. Vui lòng thử lại.',
          statusCode: statusCode,
        );
      }
      return body.containsKey('data') ? body['data'] : body;
    }
    return body;
  }

  ApiException _toApiException(DioException e) {
    final response = e.response;
    if (response != null) {
      final message = _messageFrom(response.data);
      if (message != null) {
        return ApiException(message, statusCode: response.statusCode);
      }
      switch (response.statusCode) {
        case 400:
        case 422:
          return ApiException(
            'Dữ liệu không hợp lệ.',
            statusCode: response.statusCode,
          );
        case 401:
          return ApiException(
            'Email hoặc mật khẩu không đúng.',
            statusCode: 401,
          );
        case 403:
          return ApiException(
            'Bạn không có quyền thực hiện thao tác này.',
            statusCode: 403,
          );
        case 404:
          return ApiException('Không tìm thấy dữ liệu.', statusCode: 404);
        case 409:
          return ApiException('Dữ liệu đã tồn tại.', statusCode: 409);
      }
      if ((response.statusCode ?? 0) >= 500) {
        return ApiException(
          'Máy chủ đang gặp sự cố. Vui lòng thử lại sau.',
          statusCode: response.statusCode,
        );
      }
      return ApiException(
        'Đã có lỗi xảy ra. Vui lòng thử lại.',
        statusCode: response.statusCode,
      );
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException('Kết nối quá chậm. Vui lòng thử lại.');
      default:
        return const ApiException(
          'Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.',
        );
    }
  }

  String? _messageFrom(dynamic body) {
    if (body is Map) {
      final error = body['error'];
      if (error is Map && error['message'] is String) {
        final m = error['message'] as String;
        if (m.isNotEmpty) return m;
      }
      if (error is String && error.isNotEmpty) return error;
      final message = body['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return null;
  }

  Future<bool> _refreshTokens() async {
    final refreshToken = await TokenStorage.readRefresh();
    if (refreshToken == null || refreshToken.isEmpty) return false;

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final body = response.data;
      final data = (body is Map && body['data'] is Map) ? body['data'] : body;
      if (data is Map &&
          data['access_token'] is String &&
          data['refresh_token'] is String) {
        await TokenStorage.save(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return true;
      }
      return false;
    } on DioException {
      await TokenStorage.clear();
      return false;
    }
  }
}
