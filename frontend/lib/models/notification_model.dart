enum NotificationType { reminder, aiResult, alert }

class AppNotification {
  final String id;
  final String title;             // Tiêu đề
  final String body;              // Mô tả
  final DateTime time;
  final bool isRead;              // lọc trạng thái "Chưa đọc" hay "Đã đọc"
  final NotificationType type;    // Để render icon tương ứng
  final String? kind;             // Giá trị gốc từ backend: water / fertilize / system

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    required this.type,
    this.kind,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString();
    final createdAt =
        DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();

    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      time: createdAt,
      isRead: json['read_at'] != null,
      type: _mapKindToType(kind),
      kind: kind,
    );
  }

  static NotificationType _mapKindToType(String? kind) {
    switch (kind) {
      case 'water':
      case 'fertilize':
        return NotificationType.reminder;
      case 'ai_result':
        return NotificationType.aiResult;
      case 'system':
      default:
        return NotificationType.alert;
    }
  }

  // Xử lý sự kiện trạng thái đã đọc hay chưa
  AppNotification copyWith({
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      time: time,
      isRead: isRead ?? this.isRead,
      type: type,
      kind: kind,
    );
  }
}