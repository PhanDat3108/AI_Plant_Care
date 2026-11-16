enum HealthStatus {     //tình trạng sức khỏe
  healthy, 
  sick 
}   

// Nhật kí chăm sóc
class CareLog {
  final String id;
  final DateTime actionDate;
  final String actionType;      
  final String note;            // Ghi chú

  CareLog({
    required this.id,
    required this.actionDate,
    required this.actionType,
    required this.note,
  });
}

// Cây
class PlantModel {
  final String id;
  final String nickname;           // Biệt danh người dùng đặt 
  final String scientificName;     // Tên khoa học 
  final String commonName;         // Tên phổ thông 
  final String imageUrl;           
  final HealthStatus healthStatus;  // Tình trạng sức khỏe
  
  // Thông tin bệnh 
  final String? diseaseName;              //Tên bệnh
  final List<String>? symptoms;           //Triệu chứng
  final List<String>? treatmentSteps;     //Các bước xử lí 

  // Hướng dẫn chăm sóc
  final String sunlightInfo;       // Cần ánh sáng như nào
  final String waterInfo;          // Cách tưới nước 
  final String temperatureInfo;    // Nhiệt độ phù hợp

  // Lịch nhắc nhở
  final int wateringFrequencyDays;      // Tần suất tưới (ngày)
  final int fertilizingFrequencyDays;   // Tần suất bón phân (ngày)
  final String reminderTime;            // Thời gian lịch báo 
  final bool isWateringReminderOn;
  final bool isFertilizingReminderOn;

  // Nhật ký
  final List<CareLog> logs;

  PlantModel({
    required this.id,
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
    required this.wateringFrequencyDays,
    required this.fertilizingFrequencyDays,
    required this.reminderTime,
    this.isWateringReminderOn = true,
    this.isFertilizingReminderOn = true,
    this.logs = const [],
  });


  PlantModel copyWith({
    String? nickname,
    HealthStatus? healthStatus,
    bool? isWateringReminderOn,
    bool? isFertilizingReminderOn,
    List<CareLog>? logs,
  }) {
    return PlantModel(
      id: id,
      nickname: nickname ?? this.nickname,
      scientificName: scientificName,
      commonName: commonName,
      imageUrl: imageUrl,
      healthStatus: healthStatus ?? this.healthStatus,
      diseaseName: diseaseName,
      symptoms: symptoms,
      treatmentSteps: treatmentSteps,
      sunlightInfo: sunlightInfo,
      waterInfo: waterInfo,
      temperatureInfo: temperatureInfo,
      wateringFrequencyDays: wateringFrequencyDays,
      fertilizingFrequencyDays: fertilizingFrequencyDays,
      reminderTime: reminderTime,
      isWateringReminderOn: isWateringReminderOn ?? this.isWateringReminderOn,
      isFertilizingReminderOn: isFertilizingReminderOn ?? this.isFertilizingReminderOn,
      logs: logs ?? this.logs,
    );
  }
}