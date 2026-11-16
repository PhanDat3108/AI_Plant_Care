enum NotificationType { reminder, aiResult, alert } 

class AppNotification {
  final String id;
  final String title;             // Tiêu đề
  final String body;              // Mô tả
  final DateTime time;
  final bool isRead;              // lọc trạng thái "Chưa đọc" hay "Đã đọc"
  final NotificationType type;    // Để render icon tương ứng 

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    required this.type,
  });

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
    );
  }
}