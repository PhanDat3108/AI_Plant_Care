import 'api_client.dart';

class PlantCareService {
  // --- Lịch chăm sóc (Plant Detail) ---
  static Future<Map<String, dynamic>> getSchedules(String plantId) async {
    final data = await ApiClient.get('/plants/$plantId/schedules');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> updateWaterSchedule(
    String plantId, {
    required int intervalDays,
    required String localTime,
    required bool enabled,
  }) async {
    final data = await ApiClient.put(
      '/plants/$plantId/schedules/water',
      body: {
        'interval_days': intervalDays,
        'local_time': localTime,
        'enabled': enabled,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> updateFertilizeSchedule(
    String plantId, {
    required int intervalDays,
    required String localTime,
    required bool enabled,
  }) async {
    final data = await ApiClient.put(
      '/plants/$plantId/schedules/fertilize',
      body: {
        'interval_days': intervalDays,
        'local_time': localTime,
        'enabled': enabled,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> syncCarePlan(String plantId) async {
    final data = await ApiClient.post(
      '/plants/$plantId/care-plan/sync',
      body: {},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  // --- Dữ liệu chăm sóc loài bằng Gemini (Plant Detail / AI Result) ---
  static Future<Map<String, dynamic>> getCareData(String plantId) async {
    final data = await ApiClient.get('/plants/$plantId/care-data');
    return Map<String, dynamic>.from(data as Map);
  }

  static Future<Map<String, dynamic>> enrichCareData(String plantId) async {
    final data = await ApiClient.post(
      '/plants/$plantId/care-data/enrich',
      body: {},
      timeout: const Duration(seconds: 50),
    );
    return Map<String, dynamic>.from(data as Map);
  }

  // --- Lưu cây sau khi quét AI (AI Result) ---
  static Future<Map<String, dynamic>> saveScannedPlant({
    required String nickname,
    String? speciesId,
    String? coverImageKey,
    String environment = 'unknown',
  }) async {
    final data = await ApiClient.post(
      '/garden',
      body: {
        'nickname': nickname,
        'species_id': ?speciesId,
        'cover_image_key': ?coverImageKey,
        'environment': environment,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }
}
