import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback? onDismissed;
  final VoidCallback onTap;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onDismissed,
    required this.onTap,
  });

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';

    final dd = time.day.toString().padLeft(2, '0');
    final mm = time.month.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final min = time.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${time.year} $hh:$min';
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = AppTheme.cardColor;
    IconData iconData = Icons.notifications_rounded;
    Color iconColor = AppTheme.subTextColor;

    if (notification.kind == 'fertilize') {
      bgColor = const Color(0xFFFFF8E1);
      iconData = Icons.eco_rounded;
      iconColor = const Color(0xFFEF6C00);
    } else if (notification.type == NotificationType.reminder) {
      bgColor = const Color(0xFFE0F7FA);
      iconData = Icons.water_drop_rounded;
      iconColor = const Color(0xFF0277BD);
    } else if (notification.type == NotificationType.aiResult) {
      bgColor = AppTheme.healthyBadgeBg;
      iconData = Icons.document_scanner_rounded;
      iconColor = AppTheme.primaryColor;
    }

    final cardWidget = Card(
      color: notification.isRead ? AppTheme.cardColor : bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: notification.isRead
                    ? AppTheme.scaffoldBackgroundColor
                    : Colors.white.withValues(alpha: 0.6),
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
                        color: notification.isRead
                            ? AppTheme.subTextColor
                            : AppTheme.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(notification.time),
                      style: TextStyle(
                        color: AppTheme.subTextColor.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
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
    );

    if (onDismissed == null) {
      return cardWidget;
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
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 32,
        ),
      ),
      onDismissed: (_) {
        onDismissed!.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa thông báo'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: cardWidget,
    );
  }
}