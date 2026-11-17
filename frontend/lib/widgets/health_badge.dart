import 'package:flutter/material.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';

/// Nhãn tình trạng sức khỏe: "Khỏe mạnh" (xanh) / "Cần chữa trị" (đỏ nhạt).
class HealthBadge extends StatelessWidget {
  const HealthBadge({super.key, required this.status});

  final HealthStatus status;

  @override
  Widget build(BuildContext context) {
    final isHealthy = status == HealthStatus.healthy;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: isHealthy ? AppTheme.healthyBadgeBg : AppTheme.sickBadgeBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isHealthy ? 'Khỏe mạnh' : 'Cần chữa trị',
        style: TextStyle(
          color: isHealthy ? AppTheme.healthyBadgeText : AppTheme.sickBadgeText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
