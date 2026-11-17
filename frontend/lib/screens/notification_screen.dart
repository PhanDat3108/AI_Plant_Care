import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/notification_model.dart';
import '../services/mock_data_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final MockDataService _dataService = MockDataService();
  
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // --- Xử lý dữ liệu & Bắt lỗi ---
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await _dataService.getNotifications();
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // --- Xử lý Logic Tương tác ---
  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
  }

  void _setFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
  }

  // Lọc danh sách trước khi hiển thị
  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'Chưa đọc') {
      return _notifications.where((n) => !n.isRead).toList();
    } else if (_selectedFilter == 'Kết quả AI') {
      return _notifications.where((n) => n.type == NotificationType.aiResult).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(
            child: _buildBodyContent(),
          ),
        ],
      ),
    );
  }

  // Bộ định tuyến Trạng thái (Loading / Error / Empty / Data) 
  Widget _buildBodyContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 64, color: AppTheme.sickBadgeText),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.subTextColor, fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final displayList = _filteredNotifications;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_paused_rounded, size: 64, color: AppTheme.appBarColor),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'Tất cả' 
                  ? 'Bạn chưa có thông báo nào.' 
                  : 'Không có thông báo phù hợp bộ lọc.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.subTextColor, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        return _buildNotificationCard(displayList[index]);
      },
    );
  }

  Widget _buildHeader() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

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
          if (unreadCount > 0) // Chỉ hiện nút khi có thông báo chưa đọc
            InkWell(
              onTap: _markAllAsRead,
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
                onTap: () => _setFilter(filter),
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

  Widget _buildNotificationCard(AppNotification notification) {
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
      onDismissed: (direction) {
        _deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thông báo'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Card(
        color: notification.isRead ? AppTheme.cardColor : bgColor,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: InkWell(
          onTap: () {
            // Click vào để đánh dấu đã đọc
            if (!notification.isRead) {
              setState(() {
                final index = _notifications.indexWhere((n) => n.id == notification.id);
                if (index != -1) {
                  _notifications[index] = _notifications[index].copyWith(isRead: true);
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(16),
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
                      // Tạm mô phỏng thời gian tương đối
                      Text(
                        'Vừa xong',
                        style: TextStyle(color: AppTheme.subTextColor.withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
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
      ),
    );
  }
}