import 'package:flutter/material.dart';

import '../models/plant_extensions.dart';
import '../models/plant_model.dart';
import '../theme/app_theme.dart';
import 'health_badge.dart';

/// Thẻ cây trong lưới "Vườn của tôi":
/// ảnh tròn, tên loài, badge sức khỏe, đếm ngược lần tưới tiếp theo.
class PlantCard extends StatelessWidget {
  const PlantCard({super.key, required this.plant, this.onTap});

  final PlantModel plant;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PlantAvatar(imageUrl: plant.imageUrl, size: 84),
              const SizedBox(height: 10),
              Text(
                plant.commonName.isNotEmpty ? plant.commonName : plant.nickname,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.titleTextColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              HealthBadge(status: plant.healthStatus),
              const SizedBox(height: 8),
              Text(
                plant.wateringCountdownText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.subTextColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ảnh cây hình tròn nền xanh nhạt.
/// - imageUrl rỗng hoặc lỗi tải -> hiện icon cây thay thế.
/// - bắt đầu bằng "http" -> ảnh mạng; còn lại -> ảnh trong assets.
class PlantAvatar extends StatelessWidget {
  const PlantAvatar({super.key, required this.imageUrl, this.size = 84});

  final String imageUrl;
  final double size;

  static const Color _backgroundColor = Color(0xFFDDE9DE);

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(
      Icons.local_florist_rounded,
      size: size * 0.52,
      color: AppTheme.primaryColor,
    );

    Widget content = placeholder;
    if (imageUrl.isNotEmpty) {
      final image = imageUrl.startsWith('http')
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            )
          : Image.asset(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            );
      content = SizedBox(width: size, height: size, child: image);
    }

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _backgroundColor,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: content,
    );
  }
}
