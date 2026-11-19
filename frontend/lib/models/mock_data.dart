import 'plant_model.dart';
import 'plant_extensions.dart';
import 'user_model.dart';

// Dữ liệu mẫu để dựng giao diện trước khi có API thật.
// Khi nối backend, thay các biến này bằng dữ liệu từ service.

DateTime _daysAgo(int days) => DateTime.now().subtract(Duration(days: days));

CareLog _waterLog(String id, int daysAgo) => CareLog(
      id: id,
      actionDate: _daysAgo(daysAgo),
      actionType: kWaterActionType,
      note: 'Tưới đẫm nước',
    );

final List<PlantModel> mockPlants = [
  // Tưới sau 2 ngày (tưới 5 ngày trước, chu kỳ 7 ngày)
  PlantModel(
    id: 'p1',
    nickname: 'Bé Kim Tiền',
    scientificName: 'Zamioculcas zamiifolia',
    commonName: 'Cây Kim Tiền',
    imageUrl: '',
    healthStatus: HealthStatus.healthy,
    sunlightInfo: 'Ánh sáng gián tiếp, chịu được bóng râm',
    waterInfo: 'Tưới khi đất khô hoàn toàn, khoảng 1 lần mỗi tuần',
    temperatureInfo: '18–30°C',
    wateringFrequencyDays: 7,
    fertilizingFrequencyDays: 30,
    reminderTime: '07:00',
    logs: [_waterLog('l1', 5)],
  ),

  // Tưới sau 1 ngày (tưới 3 ngày trước, chu kỳ 4 ngày)
  PlantModel(
    id: 'p2',
    nickname: 'Bé Bàng',
    scientificName: 'Ficus lyrata',
    commonName: 'Bàng Singapore',
    imageUrl: '',
    healthStatus: HealthStatus.sick,
    diseaseName: 'Đốm lá do nấm',
    symptoms: [
      'Xuất hiện các đốm nâu trên lá',
      'Mép lá khô và cháy',
    ],
    treatmentSteps: [
      'Cắt bỏ những lá bị bệnh nặng',
      'Phun thuốc trị nấm theo hướng dẫn trên bao bì',
      'Giảm lượng nước tưới, để cây thông thoáng hơn',
    ],
    sunlightInfo: 'Nhiều ánh sáng gián tiếp',
    waterInfo: 'Giữ đất ẩm nhẹ, tránh để úng nước',
    temperatureInfo: '18–28°C',
    wateringFrequencyDays: 4,
    fertilizingFrequencyDays: 21,
    reminderTime: '07:30',
    logs: [_waterLog('l2', 3)],
  ),

  // Tưới sau 5 ngày (tưới 9 ngày trước, chu kỳ 14 ngày)
  PlantModel(
    id: 'p3',
    nickname: 'Bé Lưỡi Hổ',
    scientificName: 'Dracaena trifasciata',
    commonName: 'Cây Lưỡi Hổ',
    imageUrl: '',
    healthStatus: HealthStatus.healthy,
    sunlightInfo: 'Chịu được cả nắng nhẹ lẫn bóng râm',
    waterInfo: 'Khoảng 2 tuần một lần, để đất khô giữa các lần tưới',
    temperatureInfo: '15–32°C',
    wateringFrequencyDays: 14,
    fertilizingFrequencyDays: 60,
    reminderTime: '08:00',
    logs: [_waterLog('l3', 9)],
  ),

  // Tưới hôm nay (tưới 5 ngày trước, chu kỳ 5 ngày)
  PlantModel(
    id: 'p4',
    nickname: 'Bé Trầu Bà',
    scientificName: 'Epipremnum aureum',
    commonName: 'Trầu Bà Xanh',
    imageUrl: '',
    healthStatus: HealthStatus.healthy,
    sunlightInfo: 'Ánh sáng gián tiếp vừa phải',
    waterInfo: 'Tưới khi lớp đất mặt khô',
    temperatureInfo: '18–30°C',
    wateringFrequencyDays: 5,
    fertilizingFrequencyDays: 30,
    reminderTime: '07:00',
    logs: [_waterLog('l4', 5)],
  ),
];

const UserModel mockUser = UserModel(
  fullName: 'Minh Anh',
  email: 'minhanh.plant@gmail.com',
  totalPlants: 12,
  totalAiScans: 28,
);
