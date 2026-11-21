import 'package:flutter/material.dart';

import '../../core/api_exception.dart';
import '../../models/notification_model.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import 'notification_card.dart';
import 'notification_filter_chips.dart';
import 'notification_header.dart';

class NotificationScreen extends StatefulWidget {
  final ValueChanged<bool>? onUnreadChanged;

  const NotificationScreen({super.key, this.onUnreadChanged});

  @override
  State<NotificationScreen> createState() => NotificationScreenState();
}

class NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _notifications = [];
  String? _nextCursor;
  int _unreadCount = 0;
  
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isMarkingAll = false;
  String? _errorMessage;
  String _selectedFilter = 'Tất cả';

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  void _notifyUnreadChanged() {
    widget.onUnreadChanged?.call(_unreadCount > 0);
  }

  String _formatError(Object e) {
    if (e is ApiException) return e.message;
    return e.toString().replaceAll('Exception: ', '');
  }

  Future<void> loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait<dynamic>([
        NotificationService.getNotifications(
          limit: 20,
          unreadOnly: _selectedFilter == 'Chưa đọc',
        ),
        NotificationService.getUnreadCount(),
      ]);

      if (!mounted) return;
      final page = results[0] as NotificationPage;
      final unreadCount = results[1] as int;

      setState(() {
        _notifications = page.items;
        _nextCursor = page.nextCursor;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
      _notifyUnreadChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _formatError(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || _nextCursor == null) return;

    setState(() => _isLoadingMore = true);
    try {
      final page = await NotificationService.getNotifications(
        limit: 20,
        cursor: _nextCursor,
        unreadOnly: _selectedFilter == 'Chưa đọc',
      );
      if (!mounted) return;

      final existingIds = _notifications.map((n) => n.id).toSet();
      final newItems =
          page.items.where((n) => !existingIds.contains(n.id)).toList();

      setState(() {
        _notifications = [..._notifications, ...newItems];
        _nextCursor = page.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    final needsReload =
        filter == 'Chưa đọc' || _selectedFilter == 'Chưa đọc';
    setState(() => _selectedFilter = filter);
    if (needsReload) {
      loadNotifications();
    }
  }

  Future<void> _markAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1 || _notifications[index].isRead) return;

    try {
      await NotificationService.markAsRead(id);
      if (!mounted) return;

      setState(() {
        if (_selectedFilter == 'Chưa đọc') {
          _notifications.removeAt(index);
        } else {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        }
        if (_unreadCount > 0) _unreadCount--;
      });
      _notifyUnreadChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    if (_isMarkingAll) return;
    final unreadItems = _notifications.where((n) => !n.isRead).toList();
    if (unreadItems.isEmpty) return;

    setState(() => _isMarkingAll = true);
    try {
      await Future.wait(
        unreadItems.map((n) => NotificationService.markAsRead(n.id)),
      );
      final latestUnreadCount = await NotificationService.getUnreadCount();
      if (!mounted) return;

      setState(() {
        if (_selectedFilter == 'Chưa đọc') {
          _notifications = [];
        } else {
          _notifications =
              _notifications.map((n) => n.copyWith(isRead: true)).toList();
        }
        _unreadCount = latestUnreadCount;
        _isMarkingAll = false;
      });
      _notifyUnreadChanged();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMarkingAll = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'Chưa đọc') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          NotificationHeader(
            unreadCount: _unreadCount,
            onMarkAllRead: _markAllAsRead,
          ),
          NotificationFilterChips(
            selectedFilter: _selectedFilter,
            onFilterChanged: _onFilterChanged,
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
                onPressed: loadNotifications,
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
      return RefreshIndicator(
        onRefresh: loadNotifications,
        color: AppTheme.primaryColor,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(height: MediaQuery.of(context).size.height * 0.22),
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

    final showLoadMore = _nextCursor != null;

    return RefreshIndicator(
      onRefresh: loadNotifications,
      color: AppTheme.primaryColor,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        itemCount: displayList.length + (showLoadMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (showLoadMore && index == displayList.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              child: OutlinedButton(
                onPressed: _isLoadingMore ? null : _loadMoreNotifications,
                child: _isLoadingMore
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Tải thêm thông báo'),
              ),
            );
          }

          final item = displayList[index];
          return NotificationCard(
            notification: item,
            onTap: () => _markAsRead(item.id),
          );
        },
      ),
    );
  }

  void reload() {}
}