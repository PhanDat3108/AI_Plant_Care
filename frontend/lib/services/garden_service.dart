import '../core/api_exception.dart';
import '../models/plant_model.dart';
import 'dio_client.dart';

/// API vườn cây (theo BACKEND_FEATURE_4.md). Mọi request cần Bearer token.
class GardenService {
  GardenService._();

  static final DioClient _api = DioClient.instance;

  /// GET /garden: danh sách cây của người dùng.
  /// Backend chỉ trả id, nickname, cover_image_key, created_at nên các trường
  /// còn lại của PlantModel dùng giá trị mặc định cho đến khi có API chi tiết.
  static Future<List<PlantModel>> getPlants() async {
    final data = await _api.get('/garden');
    if (data is! List) {
      throw const ApiException('Dữ liệu vườn cây không hợp lệ.');
    }
    return data
        .whereType<Map>()
        .map((e) => _fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// PATCH /garden/:id/nickname
  static Future<void> updateNickname(String id, String nickname) async {
    await _api.patch('/garden/$id/nickname', body: {'nickname': nickname});
  }

  /// DELETE /garden/:id
  static Future<void> deletePlant(String id) async {
    await _api.delete('/garden/$id');
  }

  static PlantModel _fromJson(Map<String, dynamic> j) {
    final cover = (j['cover_image_key'] as String?) ?? '';
    return PlantModel(
      id: (j['id'] ?? '').toString(),
      nickname: (j['nickname'] ?? 'Cây chưa đặt tên').toString(),
      scientificName: '',
      commonName: '',
      // cover_image_key là khóa lưu trữ, chỉ hiển thị khi đã là URL đầy đủ.
      imageUrl: cover.startsWith('http') ? cover : '',
      healthStatus: HealthStatus.healthy,
      sunlightInfo: '',
      waterInfo: '',
      temperatureInfo: '',
      wateringFrequencyDays: 7,
      fertilizingFrequencyDays: 30,
      reminderTime: '07:00',
      logs: const [],
    );
  }
}
