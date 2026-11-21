import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

/// Thẻ ảnh + tên cây + badge trạng thái (phần đầu trang kết quả)
class AiResultHeader extends StatelessWidget {
  final PlantModel plant;
  final bool isSick;
  final double? confidence;
  final String? localImagePath;
  final String? healthStatusRaw;
  final bool isMock;

  const AiResultHeader({
    super.key,
    required this.plant,
    required this.isSick,
    this.confidence,
    this.localImagePath,
    this.healthStatusRaw,
    this.isMock = false,
  });

  Widget _buildImagePreview() {
    final fallback = Center(
      child: Icon(
        Icons.park_rounded,
        size: 100,
        color: isSick
            ? AppTheme.sickBadgeText.withValues(alpha: 0.5)
            : AppTheme.primaryColor.withValues(alpha: 0.5),
      ),
    );

    final localPath = localImagePath?.trim() ?? '';
    final url = plant.imageUrl.trim();
    final isNetworkUrl =
        url.startsWith('https://') || url.startsWith('http://');

    Widget child = fallback;
    if (localPath.isNotEmpty) {
      child = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (isNetworkUrl) {
      child = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  String? _confidenceText() {
    if (confidence == null) return null;
    final percent =
        confidence! <= 1 ? (confidence! * 100).round() : confidence!.round();
    return '$percent% chính xác';
  }

  @override
  Widget build(BuildContext context) {
    final confidenceLabel = _confidenceText();
    final isNotAssessed =
        healthStatusRaw == 'unknown' || healthStatusRaw == 'not_assessed';

    final String statusText;
    final Color badgeBg;
    final Color badgeText;
    if (isSick) {
      statusText = 'Phát hiện bệnh: ${plant.diseaseName ?? 'Cần kiểm tra'}';
      badgeBg = AppTheme.sickBadgeBg;
      badgeText = AppTheme.sickBadgeText;
    } else if (isNotAssessed) {
      statusText = 'Đã nhận diện loài';
      badgeBg = AppTheme.appBarColor;
      badgeText = AppTheme.primaryColor;
    } else {
      statusText = 'Khỏe mạnh';
      badgeBg = AppTheme.healthyBadgeBg;
      badgeText = AppTheme.healthyBadgeText;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Stack(
              children: [
                _buildImagePreview(),
                if (confidenceLabel != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.appBarColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        confidenceLabel,
                        style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                if (isMock)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Chế độ demo',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              plant.commonName.isNotEmpty ? plant.commonName : plant.nickname,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontSize: 24),
            ),
            if (plant.scientificName.trim().isNotEmpty &&
                plant.scientificName.trim() != plant.commonName.trim())
              Text(
                plant.scientificName,
                style: const TextStyle(
                  color: AppTheme.subTextColor,
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: badgeBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: badgeText,
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