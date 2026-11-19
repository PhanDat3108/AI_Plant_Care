enum HealthStatus {
  // Tình trạng sức khỏe
  healthy,
  sick,
}

// Nhật ký chăm sóc
class CareLog {
  final String id;
  final String? plantId;
  final String? taskId;
  final String? kind; // water | fertilize | treat | note
  final DateTime actionDate;
  final String actionType;
  final String note; // Ghi chú

  CareLog({
    required this.id,
    this.plantId,
    this.taskId,
    this.kind,
    required this.actionDate,
    required this.actionType,
    required this.note,
  });

  factory CareLog.fromJson(Map<String, dynamic> json) {
    final kind = json['kind']?.toString();
    final performedAt =
        DateTime.tryParse(json['performed_at']?.toString() ?? '')?.toLocal() ??
            DateTime.now();

    return CareLog(
      id: json['id']?.toString() ?? '',
      plantId: json['plant_id']?.toString(),
      taskId: json['task_id']?.toString(),
      kind: kind,
      actionDate: performedAt,
      actionType: kindToLabel(kind),
      note: json['note']?.toString() ?? '',
    );
  }

  static String kindToLabel(String? kind) {
    switch (kind) {
      case 'water':
        return 'Đã tưới nước';
      case 'fertilize':
        return 'Đã bón phân';
      case 'treat':
        return 'Phun thuốc / Điều trị';
      case 'note':
        return 'Ghi chú chăm sóc';
      default:
        return 'Hoạt động chăm sóc';
    }
  }
}

// Cây
class PlantModel {
  final String id;
  final String? speciesId;
  final String environment; // indoor / outdoor / unknown
  final String nickname; // Biệt danh người dùng đặt
  final String scientificName; // Tên khoa học
  final String commonName; // Tên phổ thông
  final String imageUrl;
  final HealthStatus healthStatus; // Tình trạng sức khỏe

  // Thông tin bệnh
  final String? diseaseName; // Tên bệnh
  final List<String>? symptoms; // Triệu chứng
  final List<String>? treatmentSteps; // Các bước xử lý

  // Hướng dẫn chăm sóc
  final String sunlightInfo; // Ánh sáng
  final String waterInfo; // Tưới nước
  final String temperatureInfo; // Nhiệt độ
  final String? soilInfo; // Loại đất
  final String? fertilizerInfo; // Bón phân
  final String? careStatus; // verified / ai_suggested / draft / missing

  // Lịch nhắc nhở
  final int wateringFrequencyDays; // Tần suất tưới (ngày)
  final int fertilizingFrequencyDays; // Tần suất bón phân (ngày)
  final String reminderTime; // Giờ nhắc chung (giữ tương thích dữ liệu cũ)
  final String? waterReminderTime; // Giờ nhắc tưới (HH:mm)
  final String? fertilizeReminderTime; // Giờ nhắc bón phân (HH:mm)
  final bool isWateringReminderOn;
  final bool isFertilizingReminderOn;

  // Nhật ký
  final List<CareLog> logs;

  PlantModel({
    required this.id,
    this.speciesId,
    this.environment = 'unknown',
    required this.nickname,
    required this.scientificName,
    required this.commonName,
    required this.imageUrl,
    required this.healthStatus,
    this.diseaseName,
    this.symptoms,
    this.treatmentSteps,
    required this.sunlightInfo,
    required this.waterInfo,
    required this.temperatureInfo,
    this.soilInfo,
    this.fertilizerInfo,
    this.careStatus,
    required this.wateringFrequencyDays,
    required this.fertilizingFrequencyDays,
    required this.reminderTime,
    this.waterReminderTime,
    this.fertilizeReminderTime,
    this.isWateringReminderOn = true,
    this.isFertilizingReminderOn = true,
    this.logs = const [],
  });

  String get effectiveWaterTime => waterReminderTime ?? reminderTime;
  String get effectiveFertilizeTime => fertilizeReminderTime ?? reminderTime;

  PlantModel copyWith({
    String? speciesId,
    String? environment,
    String? nickname,
    String? scientificName,
    String? commonName,
    String? imageUrl,
    HealthStatus? healthStatus,
    String? sunlightInfo,
    String? waterInfo,
    String? temperatureInfo,
    String? soilInfo,
    String? fertilizerInfo,
    String? careStatus,
    int? wateringFrequencyDays,
    int? fertilizingFrequencyDays,
    String? reminderTime,
    String? waterReminderTime,
    String? fertilizeReminderTime,
    bool? isWateringReminderOn,
    bool? isFertilizingReminderOn,
    List<CareLog>? logs,
  }) {
    return PlantModel(
      id: id,
      speciesId: speciesId ?? this.speciesId,
      environment: environment ?? this.environment,
      nickname: nickname ?? this.nickname,
      scientificName: scientificName ?? this.scientificName,
      commonName: commonName ?? this.commonName,
      imageUrl: imageUrl ?? this.imageUrl,
      healthStatus: healthStatus ?? this.healthStatus,
      diseaseName: diseaseName,
      symptoms: symptoms,
      treatmentSteps: treatmentSteps,
      sunlightInfo: sunlightInfo ?? this.sunlightInfo,
      waterInfo: waterInfo ?? this.waterInfo,
      temperatureInfo: temperatureInfo ?? this.temperatureInfo,
      soilInfo: soilInfo ?? this.soilInfo,
      fertilizerInfo: fertilizerInfo ?? this.fertilizerInfo,
      careStatus: careStatus ?? this.careStatus,
      wateringFrequencyDays:
          wateringFrequencyDays ?? this.wateringFrequencyDays,
      fertilizingFrequencyDays:
          fertilizingFrequencyDays ?? this.fertilizingFrequencyDays,
      reminderTime: reminderTime ?? this.reminderTime,
      waterReminderTime: waterReminderTime ?? this.waterReminderTime,
      fertilizeReminderTime:
          fertilizeReminderTime ?? this.fertilizeReminderTime,
      isWateringReminderOn: isWateringReminderOn ?? this.isWateringReminderOn,
      isFertilizingReminderOn:
          isFertilizingReminderOn ?? this.isFertilizingReminderOn,
      logs: logs ?? this.logs,
    );
  }
}