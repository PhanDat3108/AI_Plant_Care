import 'plant_model.dart';

/// Giá trị `CareLog.actionType` dùng cho lần tưới nước.
const String kWaterActionType = 'water';

/// PlantModel chưa có trường "ngày tưới tiếp theo", nên tính từ nhật ký:
/// ngày tưới gần nhất + tần suất tưới (wateringFrequencyDays).
extension PlantWateringSchedule on PlantModel {
  /// Ngày tưới gần nhất, null nếu chưa có log tưới nào.
  DateTime? get lastWateredAt {
    DateTime? latest;
    for (final log in logs) {
      if (log.actionType != kWaterActionType) continue;
      if (latest == null || log.actionDate.isAfter(latest)) {
        latest = log.actionDate;
      }
    }
    return latest;
  }

  /// Số ngày còn lại đến lần tưới tiếp theo.
  /// 0 = hôm nay, số âm = quá hạn, null = chưa có dữ liệu.
  int? get daysUntilWatering {
    final last = lastWateredAt;
    if (last == null) return null;

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final lastDay = DateTime.utc(last.year, last.month, last.day);
    final next = lastDay.add(Duration(days: wateringFrequencyDays));
    return next.difference(today).inDays;
  }

  /// Chuỗi hiển thị trên thẻ cây, ví dụ "Tưới sau 2 ngày".
  String get wateringCountdownText {
    final days = daysUntilWatering;
    if (days == null) return 'Chưa có lịch tưới';
    if (days < 0) return 'Quá hạn ${-days} ngày';
    if (days == 0) return 'Tưới hôm nay';
    return 'Tưới sau $days ngày';
  }
}
