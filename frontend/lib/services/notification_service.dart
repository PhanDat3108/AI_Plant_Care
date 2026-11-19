import 'api_client.dart';

class NotificationService {
  static Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    String? cursor,
    bool? unreadOnly,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (unreadOnly == true) 'unread': 'true',
    };

    final data = await ApiClient.get('/notifications', queryParameters: params);
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<int> getUnreadCount() async {
    final data = await ApiClient.get('/notifications/unread-count');
    if (data['unread_count'] != null) {
      return (data['unread_count'] as num).toInt();
    }
    return 0;
  }

  static Future<void> markAsRead(String notificationId) async {
    await ApiClient.patch('/notifications/$notificationId/read');
  }
}