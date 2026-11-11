import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/settings.dart';

typedef Json = Map<String, dynamic>;
final apiProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: Settings.apiUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 55),
    ),
  );
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = Settings.hasAuth
            ? Supabase.instance.client.auth.currentSession?.accessToken
            : null;
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  ref.onDispose(() => dio.close());
  return dio;
});
final resourceProvider = FutureProvider.autoDispose.family<dynamic, String>((
  ref,
  path,
) async {
  final response = await ref.watch(apiProvider).get<Json>(path);
  return response.data!['data'];
});
String explain(Object error) {
  if (error is DioException) {
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return 'Không kết nối được máy chủ. Kiểm tra địa chỉ API và kết nối mạng rồi thử lại.';
  }
  return 'Không thể hoàn tất. Kiểm tra dữ liệu và thử lại.';
}
