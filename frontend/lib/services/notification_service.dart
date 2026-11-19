import '../models/notification_model.dart';
import 'dio_client.dart';

class NotificationPage {
  final List<AppNotification> items;
  final String? nextCursor;

  const NotificationPage({
    required this.items,
    required this.nextCursor,
  });
}

class NotificationService {
  static Future<NotificationPage> getNotifications({
    int limit = 20,
    String? cursor,
    bool unreadOnly = false,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      if (unreadOnly) 'unread': 'true',
    };

    final data = await DioClient.instance.get(
      '/notifications',
      queryParameters: params,
    );

    if (data is! Map) {
      return const NotificationPage(items: [], nextCursor: null);
    }

    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map(
              (item) => AppNotification.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : <AppNotification>[];

    final nextCursor = data['next_cursor'] is String &&
            (data['next_cursor'] as String).isNotEmpty
        ? data['next_cursor'] as String
        : null;

    return NotificationPage(items: items, nextCursor: nextCursor);
  }

  static Future<int> getUnreadCount() async {
    final data = await DioClient.instance.get('/notifications/unread-count');
    if (data is Map && data['unread_count'] is num) {
      return (data['unread_count'] as num).toInt();
    }
    return 0;
  }

  static Future<void> markAsRead(String notificationId) async {
    await DioClient.instance.patch('/notifications/$notificationId/read');
  }
}