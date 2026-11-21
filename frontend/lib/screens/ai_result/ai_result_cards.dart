import 'package:flutter/material.dart';
import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';

/// Bộ 3 chip tóm tắt thông số chăm sóc (Ánh sáng / Nước / Nhiệt độ)
class AiResultCareSummary extends StatelessWidget {
  final PlantModel plant;

  const AiResultCareSummary({super.key, required this.plant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CareChip(icon: Icons.wb_sunny_rounded, iconColor: Colors.orange, label: plant.sunlightInfo),
          _CareChip(icon: Icons.water_drop_rounded, iconColor: Colors.blue, label: plant.waterInfo),
          _CareChip(icon: Icons.thermostat_rounded, iconColor: Colors.redAccent, label: plant.temperatureInfo),
        ],
      ),
    );
  }
}

/// 1 chip thông số chăm sóc (widget nội bộ)
class _CareChip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _CareChip({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.titleTextColor,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ Triệu chứng & Cách xử lý (chỉ hiện khi cây bị bệnh)
class AiResultDiseaseCard extends StatelessWidget {
  final PlantModel plant;
  final bool isSick;

  const AiResultDiseaseCard({
    super.key,
    required this.plant,
    this.isSick = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSick ? 'Triệu chứng & Cách xử lý' : 'Nhận xét & Gợi ý chăm sóc',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (plant.symptoms != null)
              ...plant.symptoms!.map((symptom) => _BulletPoint(text: symptom)),
            if (plant.treatmentSteps != null)
              ...plant.treatmentSteps!.map((step) => _BulletPoint(text: step)),
          ],
        ),
      ),
    );
  }
}

/// 1 dòng bullet point (widget nội bộ)
class _BulletPoint extends StatelessWidget {
  final String text;

  const _BulletPoint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6, right: 8),
            child: Icon(Icons.circle, size: 8, color: AppTheme.primaryColor),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppTheme.titleTextColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút nổi "Thêm vào Vườn của tôi"
class AiResultAddButton extends StatelessWidget {
  final bool isAdding;
  final VoidCallback onAdd;

  const AiResultAddButton({super.key, required this.isAdding, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ElevatedButton(
        onPressed: isAdding ? null : onAdd,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: isAdding
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Thêm vào Vườn của tôi', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Icon(Icons.eco_rounded, size: 20),
                ],
              ),
      ),
    );
  }
}
