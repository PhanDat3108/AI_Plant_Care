import '../core/plant_image_url.dart';

enum TaskType {
  water, // Tưới nước
  fertilize, // Bón phân
  spray, // Phun thuốc / điều trị
}

class TaskModel {
  final String id;
  final String plantId;
  final String plantNickname;
  final String plantAvatar;
  final TaskType type;
  final bool isCompleted;
  final String state;
  final DateTime? dueAt;
  final DateTime? originalDueAt;
  final String? adjustmentReason;
  final Map<String, dynamic>? weatherSnapshot;

  TaskModel({
    required this.id,
    required this.plantId,
    required this.plantNickname,
    required this.plantAvatar,
    required this.type,
    this.isCompleted = false,
    this.state = 'pending',
    this.dueAt,
    this.originalDueAt,
    this.adjustmentReason,
    this.weatherSnapshot,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final schedule = json['care_schedules'] is Map
        ? Map<String, dynamic>.from(json['care_schedules'] as Map)
        : <String, dynamic>{};
    final plant = schedule['plants'] is Map
        ? Map<String, dynamic>.from(schedule['plants'] as Map)
        : <String, dynamic>{};
    final state = json['state']?.toString() ?? 'pending';
    final kind = json['kind']?.toString() ?? schedule['kind']?.toString();
    final reasonRaw = json['adjustment_reason']?.toString().trim();

    return TaskModel(
      id: json['id']?.toString() ?? '',
      plantId: plant['id']?.toString() ?? json['plant_id']?.toString() ?? '',
      plantNickname: plant['nickname']?.toString() ?? 'Cây chưa đặt tên',
      plantAvatar: plantImageUrl(plant),
      type: _mapKindToType(kind),
      isCompleted: state == 'done',
      state: state,
      dueAt: DateTime.tryParse(json['due_at']?.toString() ?? '')?.toLocal(),
      originalDueAt: DateTime.tryParse(
        json['original_due_at']?.toString() ?? '',
      )?.toLocal(),
      adjustmentReason: (reasonRaw != null && reasonRaw.isNotEmpty)
          ? reasonRaw
          : null,
      weatherSnapshot: json['weather_snapshot'] is Map
          ? Map<String, dynamic>.from(json['weather_snapshot'] as Map)
          : null,
    );
  }

  static TaskType _mapKindToType(String? kind) {
    switch (kind) {
      case 'fertilize':
        return TaskType.fertilize;
      case 'treat':
      case 'spray':
        return TaskType.spray;
      case 'water':
      default:
        return TaskType.water;
    }
  }

  TaskModel copyWith({bool? isCompleted, String? state}) {
    return TaskModel(
      id: id,
      plantId: plantId,
      plantNickname: plantNickname,
      plantAvatar: plantAvatar,
      type: type,
      isCompleted: isCompleted ?? this.isCompleted,
      state: state ?? this.state,
      dueAt: dueAt,
      originalDueAt: originalDueAt,
      adjustmentReason: adjustmentReason,
      weatherSnapshot: weatherSnapshot,
    );
  }
}
