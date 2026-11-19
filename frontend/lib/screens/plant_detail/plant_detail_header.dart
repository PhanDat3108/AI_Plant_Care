import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/plant_model.dart';

class PlantDetailHeader extends StatelessWidget {
  final PlantModel plant;
  final VoidCallback onEditNickname;

  const PlantDetailHeader({
    super.key,
    required this.plant,
    required this.onEditNickname,
  });

  Widget _buildPlantAvatar(bool isSick) {
    final url = plant.imageUrl.trim();
    final isNetworkUrl = url.startsWith('https://') || url.startsWith('http://');

    final fallback = Center(
      child: Icon(
        Icons.park_rounded,
        size: 60,
        color: isSick
            ? AppTheme.sickBadgeText.withValues(alpha: 0.5)
            : AppTheme.primaryColor,
      ),
    );

    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackgroundColor,
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: isNetworkUrl
          ? Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            )
          : fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSick = plant.healthStatus == HealthStatus.sick;

    return Stack(
      children: [
        Container(
          height: 80,
          decoration: const BoxDecoration(
            color: AppTheme.appBarColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                _buildPlantAvatar(isSick),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        plant.nickname,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.titleTextColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onEditNickname,
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 20,
                        color: AppTheme.subTextColor,
                      ),
                    ),
                  ],
                ),
                if (plant.scientificName.trim().isNotEmpty)
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSick ? AppTheme.sickBadgeBg : AppTheme.healthyBadgeBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isSick ? 'Phát hiện bệnh' : 'Khỏe mạnh',
                    style: TextStyle(
                      color: isSick ? AppTheme.sickBadgeText : AppTheme.healthyBadgeText,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}