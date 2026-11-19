import 'api_client.dart';

class CareTaskService {
  static Future<Map<String,dynamic>> getCareTasks({
    String? date,
    String? state,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (date != null && date.isNotEmpty) 'date': date,
      if (state != null && state.isNotEmpty) 'state': state,
    };

    return ApiClient.get('/care-tasks', queryParameters: params);
  }
}