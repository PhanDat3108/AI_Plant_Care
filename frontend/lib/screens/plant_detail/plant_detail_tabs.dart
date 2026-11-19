import 'package:flutter/material.dart';

import '../../models/plant_model.dart';
import '../../theme/app_theme.dart';
import 'plant_detail_cards.dart';

/// Tab 1: Hướng dẫn chăm sóc (dữ liệu từ loài & Gemini AI)
class PlantInstructionTab extends StatelessWidget {
  final PlantModel plant;
  final String? careDataNotice;
  final bool isEnrichingCare;
  final bool isMutatingPlant;
  final Future<void> Function() onRefresh;
  final VoidCallback onEnrichCare;
  final VoidCallback onDeletePlant;

  const PlantInstructionTab({
    super.key,
    required this.plant,
    required this.careDataNotice,
    required this.isEnrichingCare,
    required this.isMutatingPlant,
    required this.onRefresh,
    required this.onEnrichCare,
    required this.onDeletePlant,
  });

  String _careStatusLabel(String? status) {
    switch (status) {
      case 'verified':
        return 'Dữ liệu đã kiểm duyệt';
      case 'ai_suggested':
        return 'Đề xuất chăm sóc bởi AI (Gemini)';
      case 'draft':
        return 'Bản đề xuất nháp';
      default:
        return 'Chưa có dữ liệu chăm sóc chuẩn';
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          if (careDataNotice != null)
            Card(
              color: const Color(0xFFFFF8E1),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        careDataNotice!,
                        style: const TextStyle(
                          color: AppTheme.titleTextColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _careStatusLabel(plant.careStatus),
                  style: const TextStyle(
                    color: AppTheme.subTextColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: isEnrichingCare ? null : onEnrichCare,
                icon: isEnrichingCare
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('Bổ sung AI'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          InfoCard(
            icon: Icons.wb_sunny_rounded,
            iconColor: Colors.orange,
            title: 'Ánh sáng',
            subtitle: plant.sunlightInfo,
          ),
          InfoCard(
            icon: Icons.water_drop_rounded,
            iconColor: Colors.blue,
            title: 'Lượng nước',
            subtitle: plant.waterInfo,
          ),
          InfoCard(
            icon: Icons.thermostat_rounded,
            iconColor: Colors.redAccent,
            title: 'Nhiệt độ',
            subtitle: plant.temperatureInfo,
          ),
          if (plant.soilInfo != null && plant.soilInfo!.trim().isNotEmpty)
            InfoCard(
              icon: Icons.eco_rounded,
              iconColor: Colors.brown,
              title: 'Loại đất',
              subtitle: plant.soilInfo!,
            ),
          if (plant.fertilizerInfo != null &&
              plant.fertilizerInfo!.trim().isNotEmpty)
            InfoCard(
              icon: Icons.science_rounded,
              iconColor: AppTheme.primaryColor,
              title: 'Bón phân',
              subtitle: plant.fertilizerInfo!,
            ),
          _DeletePlantButton(
            disabled: isMutatingPlant,
            onPressed: onDeletePlant,
          ),
        ],
      ),
    );
  }
}

/// Tab 2: Lịch nhắc nhở & đồng bộ thời tiết Open-Meteo
class PlantReminderTab extends StatelessWidget {
  final PlantModel plant;
  final bool isSavingSchedule;
  final bool isSyncingPlan;
  final bool isMutatingPlant;
  final List<String> syncWarnings;
  final Future<void> Function() onRefresh;
  final ValueChanged<bool> onToggleWater;
  final ValueChanged<bool> onToggleFertilize;
  final VoidCallback onEditWater;
  final VoidCallback onEditFertilize;
  final VoidCallback onSyncPlan;
  final VoidCallback onDeletePlant;

  const PlantReminderTab({
    super.key,
    required this.plant,
    required this.isSavingSchedule,
    required this.isSyncingPlan,
    required this.isMutatingPlant,
    required this.syncWarnings,
    required this.onRefresh,
    required this.onToggleWater,
    required this.onToggleFertilize,
    required this.onEditWater,
    required this.onEditFertilize,
    required this.onSyncPlan,
    required this.onDeletePlant,
  });

  String _warningLabel(String code) {
    switch (code) {
      case 'CARE_DATA_REVIEW_REQUIRED':
        return 'Loài cây chưa có dữ liệu chăm sóc đã duyệt để tự tạo lịch mặc định.';
      case 'LOCATION_REQUIRED_FOR_WEATHER':
        return 'Cây chưa có tọa độ vị trí nên dùng lịch nền (chưa điều chỉnh theo thời tiết).';
      case 'ENVIRONMENT_UNKNOWN_BASELINE_ONLY':
        return 'Chưa rõ cây trong nhà hay ngoài trời nên giữ lịch nền.';
      case 'WEATHER_UNAVAILABLE_KEEP_EXISTING_DUE':
        return 'Tạm thời không đọc được dữ liệu thời tiết, giữ nguyên hạn hiện tại.';
      case 'MISSING_WATER_INTERVAL':
        return 'Loài cây thiếu chu kỳ tưới nước mặc định.';
      case 'MISSING_FERTILIZE_INTERVAL':
        return 'Loài cây thiếu chu kỳ bón phân mặc định.';
      default:
        return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          ToggleReminderCard(
            icon: Icons.water_drop_rounded,
            iconColor: Colors.blue,
            title: 'Tưới nước',
            subtitle:
                'Mỗi ${plant.wateringFrequencyDays} ngày, lúc ${plant.effectiveWaterTime}',
            value: plant.isWateringReminderOn,
            onEdit: isSavingSchedule ? null : onEditWater,
            onChanged: isSavingSchedule ? null : onToggleWater,
          ),
          ToggleReminderCard(
            icon: Icons.science_rounded,
            iconColor: Colors.orange,
            title: 'Bón phân',
            subtitle:
                'Mỗi ${plant.fertilizingFrequencyDays} ngày, lúc ${plant.effectiveFertilizeTime}',
            value: plant.isFertilizingReminderOn,
            onEdit: isSavingSchedule ? null : onEditFertilize,
            onChanged: isSavingSchedule ? null : onToggleFertilize,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: isSyncingPlan ? null : onSyncPlan,
            icon: isSyncingPlan
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_sync_rounded),
            label: const Text('Đồng bộ lịch theo thời tiết (Open-Meteo)'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (syncWarnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Card(
              color: const Color(0xFFFFF8E1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: syncWarnings
                      .map(
                        (code) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '• ${_warningLabel(code)}',
                            style: const TextStyle(
                              color: AppTheme.titleTextColor,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
          _DeletePlantButton(
            disabled: isMutatingPlant,
            onPressed: onDeletePlant,
          ),
        ],
      ),
    );
  }
}

/// Tab 3: Nhật ký chăm sóc (thêm, sửa, xóa)
class PlantHistoryTab extends StatelessWidget {
  final List<CareLog> logs;
  final bool isMutatingLog;
  final bool isMutatingPlant;
  final Future<void> Function() onRefresh;
  final VoidCallback onAddLog;
  final ValueChanged<CareLog> onEditLog;
  final ValueChanged<CareLog> onDeleteLog;
  final VoidCallback onDeletePlant;

  const PlantHistoryTab({
    super.key,
    required this.logs,
    required this.isMutatingLog,
    required this.isMutatingPlant,
    required this.onRefresh,
    required this.onAddLog,
    required this.onEditLog,
    required this.onDeleteLog,
    required this.onDeletePlant,
  });

  String _formatLogDate(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year} $hh:$min';
  }

  ({IconData icon, Color color}) _styleForLog(CareLog log) {
    final lowerAction = log.actionType.toLowerCase();
    if (log.kind == 'water' || lowerAction.contains('tưới')) {
      return (icon: Icons.water_drop_rounded, color: Colors.blue);
    }
    if (log.kind == 'fertilize' || lowerAction.contains('bón')) {
      return (icon: Icons.science_rounded, color: Colors.orange);
    }
    if (log.kind == 'treat' ||
        lowerAction.contains('phun') ||
        lowerAction.contains('chẩn')) {
      return (icon: Icons.sanitizer_rounded, color: const Color(0xFF6A1B9A));
    }
    return (icon: Icons.notes_rounded, color: AppTheme.primaryColor);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.primaryColor,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          ElevatedButton.icon(
            onPressed: isMutatingLog ? null : onAddLog,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm ghi chép chăm sóc'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty) ...[
            const SizedBox(height: 24),
            const Icon(
              Icons.history_rounded,
              size: 48,
              color: AppTheme.appBarColor,
            ),
            const SizedBox(height: 12),
            const Text(
              'Chưa có ghi chép chăm sóc nào.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.subTextColor),
            ),
          ] else
            ...logs.map((log) {
              final style = _styleForLog(log);
              return LogCard(
                icon: style.icon,
                iconColor: style.color,
                action: log.actionType,
                date: _formatLogDate(log.actionDate),
                note: log.note,
                onEdit: isMutatingLog ? null : () => onEditLog(log),
                onDelete: isMutatingLog ? null : () => onDeleteLog(log),
              );
            }),
          _DeletePlantButton(
            disabled: isMutatingPlant,
            onPressed: onDeletePlant,
          ),
        ],
      ),
    );
  }
}

/// Nút xóa cây dùng chung ở cuối 3 tab
class _DeletePlantButton extends StatelessWidget {
  final bool disabled;
  final VoidCallback onPressed;

  const _DeletePlantButton({
    required this.disabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: OutlinedButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppTheme.sickBadgeText,
        ),
        label: const Text(
          'Xóa cây khỏi vườn',
          style: TextStyle(color: AppTheme.sickBadgeText),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: const BorderSide(color: AppTheme.sickBadgeText),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}