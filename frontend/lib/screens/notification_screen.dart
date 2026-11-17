import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/notification_model.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  // Dữ liệu tĩnh tạm thời (Bước 1: UI)
  final List<AppNotification> _mockNotifications = [
    AppNotification(id: 'n1', title: 'Đến giờ tưới cây rồi!', body: 'Bé Kim Tiền đang chờ được tưới nước sáng nay.', time: DateTime.now(), type: NotificationType.reminder, isRead: false),
    AppNotification(id: 'n2', title: 'Phân tích AI hoàn tất', body: 'Bàng Singapore có dấu hiệu đốm lá (94% chính xác).', time: DateTime.now(), type: NotificationType.aiResult, isRead: false),
    AppNotification(id: 'n3', title: 'Cảnh báo độ ẩm cao', body: 'Độ ẩm trên 85%, lưu ý phòng nấm cho cây.', time: DateTime.now(), type: NotificationType.alert, isRead: true),
  ];

  String _selectedFilter = 'Tất cả'; // Trạng thái tĩnh của Filter

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80), 
              itemCount: _mockNotifications.length,
              itemBuilder: (context, index) {
                return _buildNotificationCard(_mockNotifications[index]);
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. Header & Nút "Đọc tất cả" ---
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 60, left: 24, right: 24, bottom: 16),
      decoration: const BoxDecoration(color: AppTheme.appBarColor),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Thông báo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 28),
          ),
          InkWell(
            onTap: () {}, 
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Text('Đọc tất cả', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                  SizedBox(width: 4),
                  Icon(Icons.check_circle_outline, size: 18, color: AppTheme.primaryColor),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 2. Thanh Filter (Chip) ---
  Widget _buildFilterChips() {
    final filters = ['Tất cả', 'Chưa đọc', 'Kết quả AI'];

    return Container(
      color: AppTheme.appBarColor,
      width: double.infinity,
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isActive = filter == _selectedFilter;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primaryColor : AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isActive ? [] : [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isActive ? Colors.white : AppTheme.subTextColor,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- 3. Card Thông báo (Có tính năng Vuốt để xóa) ---
  Widget _buildNotificationCard(AppNotification notification) {
    // Tùy chỉnh màu sắc, icon theo loại thông báo
    Color bgColor = AppTheme.cardColor;
    IconData iconData = Icons.notifications;
    Color iconColor = AppTheme.subTextColor;
    
    if (notification.type == NotificationType.reminder) {
      bgColor = const Color(0xFFE0F7FA); 
      iconData = Icons.water_drop_rounded;
      iconColor = const Color(0xFF0277BD);
    } else if (notification.type == NotificationType.aiResult) {
      bgColor = AppTheme.healthyBadgeBg;
      iconData = Icons.document_scanner_rounded;
      iconColor = AppTheme.primaryColor;
    }

    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.sickBadgeText, 
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 32),
      ),
      onDismissed: (direction) {}, 
      child: Card(
        color: notification.isRead ? AppTheme.cardColor : bgColor,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: notification.isRead ? AppTheme.scaffoldBackgroundColor : Colors.white.withOpacity(0.6),
                child: Icon(iconData, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 16,
                        color: notification.isRead ? AppTheme.subTextColor : AppTheme.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Vừa xong', // Mock text thời gian
                      style: TextStyle(color: AppTheme.subTextColor.withOpacity(0.7), fontSize: 12),
                    ),
                  ],
                ),
              ),
              // Chấm chỉ thị chưa đọc
              if (!notification.isRead)
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4, left: 8),
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}