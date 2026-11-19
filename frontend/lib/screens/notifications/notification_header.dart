import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NotificationHeader extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onMarkAllRead;

  const NotificationHeader({
    super.key,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
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
          if (unreadCount > 0)
            InkWell(
              onTap: onMarkAllRead,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
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
}
