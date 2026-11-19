import 'package:flutter/material.dart';
import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

/// Thẻ ảnh + tên cây + badge trạng thái (phần đầu trang kết quả)
class AiResultHeader extends StatelessWidget {
  final PlantModel plant;
  final bool isSick;

  const AiResultHeader({super.key, required this.plant, required this.isSick});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Cụm Ảnh & Điểm chính xác
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppTheme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.park_rounded,
                      size: 100,
                      color: isSick
                          ? AppTheme.sickBadgeText.withValues(alpha: 0.5)
                          : AppTheme.primaryColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.appBarColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '94% chính xác',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tên cây
            Text(
              plant.commonName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 24),
            ),
            Text(
              plant.scientificName,
              style: const TextStyle(
                color: AppTheme.subTextColor,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),

            // Badge Trạng thái
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSick ? AppTheme.sickBadgeBg : AppTheme.healthyBadgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                isSick ? 'Phát hiện bệnh: ${plant.diseaseName}' : 'Khỏe mạnh',
                style: TextStyle(
                  color: isSick ? AppTheme.sickBadgeText : AppTheme.healthyBadgeText,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
