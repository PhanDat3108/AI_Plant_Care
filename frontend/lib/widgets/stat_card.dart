import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Thẻ thống kê nhanh: icon + con số lớn, nhãn bên dưới.
/// Ví dụ: (icon cây) 12 — "Cây đang chăm".
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.healthyBadgeBg,
                  ),
                  child: Icon(icon, color: AppTheme.primaryColor, size: 26),
                ),
                const SizedBox(width: 10),
                Text(
                  '$value',
                  style: const TextStyle(
                    color: AppTheme.titleTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.titleTextColor,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
