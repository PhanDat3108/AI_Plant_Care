import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/notification_model.dart';
import '../../services/mock_data_service.dart';
import 'notification_header.dart';
import 'notification_filter_chips.dart';
import 'notification_card.dart';

class NotificationScreen extends StatefulWidget {
  final ValueChanged<bool>? onUnreadChanged;

// hàm constructor
  const NotificationScreen({super.key, this.onUnreadChanged});

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

// Hàm này đếm xem còn cái nào chưa đọc (!isRead) hay không
  void _notifyUnreadChanged() {
    final hasUnread = _notifications.any((n) => !n.isRead);
    widget.onUnreadChanged?.call(hasUnread);            // báo cho BottomBar
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final data = await _dataService.getNotifications();
      if (!mounted) return;
      setState(() {
        _notifications = data;
        _isLoading = false;
      });
      _notifyUnreadChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }
// người dùng bấm nút "Đọc tất cả"
  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();
    });
    _notifyUnreadChanged();
  }
// người dùng quẹt xóa một thông báo.
  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    _notifyUnreadChanged();
  }

// người dùng click vào từng thẻ thông báo để đọc.
  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = _notifications[index].copyWith(isRead: true);
      }
    });
    _notifyUnreadChanged();
  }

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'Chưa đọc') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    if (_selectedFilter == 'Kết quả AI') {
      return _notifications
          .where((n) => n.type == NotificationType.aiResult)
          .toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      body: Column(
        children: [
          NotificationHeader(
            unreadCount: unreadCount,
            onMarkAllRead: _markAllAsRead,
          ),
          NotificationFilterChips(
            selectedFilter: _selectedFilter,
            onFilterChanged: (f) => setState(() => _selectedFilter = f),
          ),
          Expanded(child: _buildBodyContent()),
        ],
      ),
    );
  }

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
              const Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: AppTheme.sickBadgeText,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.subTextColor,
                  fontSize: 16,
                ),
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
            const Icon(
              Icons.notifications_paused_rounded,
              size: 64,
              color: AppTheme.appBarColor,
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'Tất cả'
                  ? 'Bạn chưa có thông báo nào.'
                  : 'Không có thông báo phù hợp bộ lọc.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: displayList.length,
      itemBuilder: (context, index) => NotificationCard(
        notification: displayList[index],
        onDismissed: () => _deleteNotification(displayList[index].id),
        onTap: () => _markAsRead(displayList[index].id),
      ),
    );
  }
}
