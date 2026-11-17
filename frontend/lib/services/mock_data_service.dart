import 'dart:async';
import '../models/plant_model.dart';
import '../models/task_model.dart';
import '../models/notification_model.dart';

class MockDataService {
  // HÀM LÕI: Mô phỏng gọi API
  Future<T> _simulateNetworkCall<T>(FutureOr<T> Function() computation) async {
    try {
      // delay 1.5 giây để test được trạng thái isLoading trên UI
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Bọc timeout 10s 
      return await Future.value(computation()).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Kết nối quá hạn'),
      );
    } on TimeoutException {
      throw Exception('Máy chủ phản hồi quá chậm. Vui lòng kiểm tra lại mạng và thử lại.');
    } catch (e) {
      // Quăng lỗi tiếng Việt thân thiện, tuyệt đối không in lỗi kỹ thuật thô ra màn hình
      throw Exception('Đã xảy ra sự cố kết nối. Vui lòng thử lại sau nhé!');
    }
  }

  // DỮ LIỆU: Việc cần làm (Tasks)
  Future<List<TaskModel>> getTodayTasks() async {
    return _simulateNetworkCall( () {
      return [
        TaskModel(
          id: 't1',
          plantId: 'p1',
          plantNickname: 'Bé Kim Tiền',
          plantAvatar: 'assets/images/kim_tien.png', // Thay bằng asset thật sau
          type: TaskType.water,
          isCompleted: false,
        ),
        TaskModel(
          id: 't2',
          plantId: 'p2',
          plantNickname: 'Trầu Bà Xanh',
          plantAvatar: 'assets/images/trau_ba.png',
          type: TaskType.fertilize,
          isCompleted: false,
        ),
        TaskModel(
          id: 't3',
          plantId: 'p3',
          plantNickname: 'Lưỡi Hổ',
          plantAvatar: 'assets/images/luoi_ho.png',
          type: TaskType.spray,
          isCompleted: true, // Đã tick xong như trong bản thiết kế
        ),
      ];
    });
  }

  // 2. DỮ LIỆU: Thông báo (Notifications)
  Future<List<AppNotification>> getNotifications() async {
    return _simulateNetworkCall(() {
      return [
        AppNotification(
          id: 'n1',
          title: 'Đến giờ tưới cây rồi!',
          body: 'Bé Kim Tiền đang chờ được tưới nước sáng nay.',
          time: DateTime.now().subtract(const Duration(minutes: 10)),
          type: NotificationType.reminder,
          isRead: false,
        ),
        AppNotification(
          id: 'n2',
          title: 'Phân tích AI hoàn tất',
          body: 'Bàng Singapore có dấu hiệu đốm lá (94% chính xác).',
          time: DateTime.now().subtract(const Duration(hours: 2)),
          type: NotificationType.aiResult,
          isRead: false,
        ),
        AppNotification(
          id: 'n3',
          title: 'Cảnh báo độ ẩm cao',
          body: 'Độ ẩm trên 85%, lưu ý phòng nấm cho cây.',
          time: DateTime.now().subtract(const Duration(days: 1)),
          type: NotificationType.alert,
          isRead: true,
        ),
      ];
    });
  }

  // 3. DỮ LIỆU: Chi tiết cây (Plant Detail)
  Future<PlantModel> getPlantDetail(String plantId) async {
    return _simulateNetworkCall(() {
      // Mock tạm một cây để test màn hình chi tiết
      return PlantModel(
        id: plantId,
        nickname: 'Bé Kim Tiền',
        scientificName: 'Zamioculcas zamiifolia',
        commonName: 'Cây Kim Tiền',
        imageUrl: 'assets/images/kim_tien.png',
        healthStatus: HealthStatus.healthy,
        sunlightInfo: 'Nắng nhẹ hoặc bóng râm trong nhà',
        waterInfo: 'Tưới 1 lần/tuần, tránh ngập úng',
        temperatureInfo: 'Đất tơi xốp, thoát nước tốt', // Đang dùng trường nhiệt độ làm thông tin đất tạm
        wateringFrequencyDays: 3,
        fertilizingFrequencyDays: 30,
        reminderTime: '08:00 AM',
        logs: [
          CareLog(
            id: 'l1',
            actionDate: DateTime(2026, 11, 16, 8, 5),
            actionType: 'Đã tưới nước',
            note: 'Tưới đủ ẩm gốc, lá xanh tốt',
          ),
          CareLog(
            id: 'l2',
            actionDate: DateTime(2026, 11, 10, 16, 20),
            actionType: 'Đã chẩn đoán bệnh',
            note: 'AI xác nhận cây khỏe mạnh (96%)',
          ),
        ],
      );
    });
  }

  // 4. DỮ LIỆU: Giả lập gọi AI quét bệnh
  Future<PlantModel> scanAndDiagnose(String imagePath) async {
    return _simulateNetworkCall(() {
      // Mock kết quả quét Bàng Singapore bị đốm lá như trong bản thiết kế
      return PlantModel(
        id: 'ai_result_01',
        nickname: 'Cây mới quét',
        scientificName: 'Ficus lyrata',
        commonName: 'Bàng Singapore',
        imageUrl: imagePath, 
        healthStatus: HealthStatus.sick,
        diseaseName: 'Đốm lá',
        symptoms: [
          'Xuất hiện các đốm nâu, tròn trên lá.',
        ],
        treatmentSteps: [
          'Cắt bỏ các lá bị bệnh, cách ly nguồn nước.',
          'Phun thuốc trị nấm hoặc cách ly tự nhiên.',
        ],
        sunlightInfo: 'Nắng nhẹ',
        waterInfo: '7 ngày/lần',
        temperatureInfo: '18-28°C',
        wateringFrequencyDays: 7,
        fertilizingFrequencyDays: 30,
        reminderTime: '07:00 AM',
      );
    });
  }
}

// 5. DỮ LIỆU: Danh sách vườn cây
