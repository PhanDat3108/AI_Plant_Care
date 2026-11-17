import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

// --- Thẻ Hướng dẫn chăm sóc ---
class InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const InfoCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
        subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
      ),
    );
  }
}

// --- Thẻ Toggle nhắc nhở ---
class ToggleReminderCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleReminderCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }
}

// --- Thẻ Nhật ký chăm sóc ---
class LogCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String action;
  final String date;
  final String note;

  const LogCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.action,
    required this.date,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(action, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.titleTextColor)),
                      Text(date, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(note, style: const TextStyle(color: AppTheme.subTextColor, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
