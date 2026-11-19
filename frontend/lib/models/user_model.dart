/// Thống kê chăm sóc, nằm trong `care_stats` của GET /me.
class CareStats {
  const CareStats({
    this.totalActions = 0,
    this.wateringCount = 0,
    this.fertilizingCount = 0,
    this.treatmentCount = 0,
    this.lastCaredAt,
  });

  final int totalActions;
  final int wateringCount;
  final int fertilizingCount;
  final int treatmentCount;
  final DateTime? lastCaredAt; // null nếu chưa chăm sóc lần nào

  factory CareStats.fromJson(Map<String, dynamic> json) {
    return CareStats(
      totalActions: _asInt(json['total_actions']),
      wateringCount: _asInt(json['watering_count']),
      fertilizingCount: _asInt(json['fertilizing_count']),
      treatmentCount: _asInt(json['treatment_count']),
      lastCaredAt: DateTime.tryParse('${json['last_cared_at'] ?? ''}'),
    );
  }
}

/// Thông tin người dùng ở màn Hồ sơ, đọc từ GET /me.
class UserModel {
  const UserModel({
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.totalPlants,
    required this.totalAiScans,
    this.timezone = 'Asia/Ho_Chi_Minh',
    this.careStats = const CareStats(),
  });

  final String fullName; // = display_name
  final String email;
  final String? avatarUrl; // null -> dùng ảnh mặc định
  final int totalPlants; // Tổng số cây đang chăm sóc
  final int totalAiScans; // Tổng số lần quét AI
  final String timezone; // mã IANA, ví dụ Asia/Ho_Chi_Minh
  final CareStats careStats;

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final avatar = json['avatar_url'];
    final stats = json['care_stats'];
    return UserModel(
      fullName: '${json['display_name'] ?? ''}'.trim(),
      email: '${json['email'] ?? ''}',
      avatarUrl: (avatar is String && avatar.isNotEmpty) ? avatar : null,
      totalPlants: _asInt(json['total_plants']),
      totalAiScans: _asInt(json['total_ai_scans']),
      timezone: (json['timezone'] is String &&
              (json['timezone'] as String).isNotEmpty)
          ? json['timezone'] as String
          : 'Asia/Ho_Chi_Minh',
      careStats: stats is Map
          ? CareStats.fromJson(Map<String, dynamic>.from(stats))
          : const CareStats(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? 0;
}
