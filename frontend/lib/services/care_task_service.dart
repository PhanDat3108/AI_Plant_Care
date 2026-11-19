import 'dio_client.dart';

class CareTaskService {
  static Future<dynamic> getCareTasks({
    String? date,
    String? state,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
      if (date != null && date.isNotEmpty) 'date': date,
      if (state != null && state.isNotEmpty) 'state': state,
    };

    return DioClient.instance.get(
      '/care-tasks',
      queryParameters: params,
    );
  }
}