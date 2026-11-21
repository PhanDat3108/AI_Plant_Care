import 'dio_client.dart';

class CareScheduleItem {
  final String id;
  final String kind; // water | fertilize
  final int intervalDays;
  final String localTime; // HH:mm
  final bool enabled;

  const CareScheduleItem({
    required this.id,
    required this.kind,
    required this.intervalDays,
    required this.localTime,
    required this.enabled,
  });

  factory CareScheduleItem.fromJson(Map<String, dynamic> json) {
    return CareScheduleItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      intervalDays: (json['interval_days'] as num?)?.toInt() ?? 7,
      localTime: json['local_time']?.toString() ?? '08:00',
      enabled: json['enabled'] == true,
    );
  }
}

class CareSchedulesResult {
  final String timezone;
  final List<CareScheduleItem> items;

  const CareSchedulesResult({
    required this.timezone,
    required this.items,
  });

  CareScheduleItem? findByKind(String kind) {
    for (final item in items) {
      if (item.kind == kind) return item;
    }
    return null;
  }
}

class PlantCareDataResult {
  final String? scientificName;
  final String? commonName;
  final String? careStatus; // verified | ai_suggested | draft | missing
  final int? wateringDays;
  final int? fertilizingDays;
  final String? waterGuide;
  final String? lightGuide;
  final String? soilGuide;
  final String? temperatureGuide;
  final String? fertilizerGuide;
  final String? draftStatus; // generating | draft | approved | rejected | failed
  final bool isMockDraft;

  const PlantCareDataResult({
    this.scientificName,
    this.commonName,
    this.careStatus,
    this.wateringDays,
    this.fertilizingDays,
    this.waterGuide,
    this.lightGuide,
    this.soilGuide,
    this.temperatureGuide,
    this.fertilizerGuide,
    this.draftStatus,
    this.isMockDraft = false,
  });

  factory PlantCareDataResult.fromJson(Map<String, dynamic> json) {
    final species = json['species'] is Map
        ? Map<String, dynamic>.from(json['species'] as Map)
        : <String, dynamic>{};
    final draft = json['draft'] is Map
        ? Map<String, dynamic>.from(json['draft'] as Map)
        : null;
    final draftData = (draft?['data'] is Map)
        ? Map<String, dynamic>.from(draft!['data'] as Map)
        : null;
    final draftCare = (draftData?['care'] is Map)
        ? Map<String, dynamic>.from(draftData!['care'] as Map)
        : null;

    String? pickGuide(String key) {
      final primary = species[key]?.toString().trim();
      if (primary != null && primary.isNotEmpty) return primary;
      final fallback = draftCare?[key]?.toString().trim();
      if (fallback != null && fallback.isNotEmpty) return fallback;
      return null;
    }

    int? pickDays(String key) {
      final primary = species[key];
      if (primary is num) return primary.toInt();
      final fallback = draftCare?[key];
      if (fallback is num) return fallback.toInt();
      return null;
    }

    return PlantCareDataResult(
      scientificName: species['scientific_name']?.toString(),
      commonName: species['common_name']?.toString(),
      careStatus: species['care_status']?.toString(),
      wateringDays: pickDays('watering_days'),
      fertilizingDays: pickDays('fertilizing_days'),
      waterGuide: pickGuide('water_guide'),
      lightGuide: pickGuide('light_guide'),
      soilGuide: pickGuide('soil_guide'),
      temperatureGuide: pickGuide('temperature_guide'),
      fertilizerGuide: pickGuide('fertilizer_guide'),
      draftStatus: draft?['status']?.toString(),
      isMockDraft: draft?['is_mock'] == true,
    );
  }
}

class CarePlanSyncResult {
  final List<String> warnings;
  final int notificationsCreated;
  final String? weatherSource;

  const CarePlanSyncResult({
    required this.warnings,
    required this.notificationsCreated,
    this.weatherSource,
  });

  factory CarePlanSyncResult.fromJson(Map<String, dynamic> json) {
    final rawWarnings = json['warnings'];
    final warnings = rawWarnings is List
        ? rawWarnings.map((w) => w.toString()).toList()
        : <String>[];

    return CarePlanSyncResult(
      warnings: warnings,
      notificationsCreated: (json['notifications_created'] as num?)?.toInt() ?? 0,
      weatherSource: json['weather_source']?.toString(),
    );
  }
}

class PlantCareService {
  // --- Thông tin cây từ Vườn (theo BACKEND_FEATURE_4.md) ---
  static Future<Map<String, dynamic>?> getGardenPlantById(String plantId) async {
  final data = await DioClient.instance.get('/garden/$plantId');
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  return null;
}

  static Future<Map<String, dynamic>> updatePlantNickname(
    String plantId,
    String nickname,
  ) async {
    final data = await DioClient.instance.patch(
      '/garden/$plantId/nickname',
      body: {'nickname': nickname.trim()},
    );
    return data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
  }

  static Future<void> deletePlant(String plantId) async {
    await DioClient.instance.delete('/garden/$plantId');
  }

  // --- Lịch chăm sóc (Plant Detail) ---
  static Future<CareSchedulesResult> getSchedules(String plantId) async {
    final data = await DioClient.instance.get('/plants/$plantId/schedules');
    if (data is! Map) {
      return const CareSchedulesResult(
        timezone: 'Asia/Ho_Chi_Minh',
        items: [],
      );
    }

    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems
            .whereType()
            .map(
              (item) =>
                  CareScheduleItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList()
        : <CareScheduleItem>[];

    return CareSchedulesResult(
      timezone: data['timezone']?.toString() ?? 'Asia/Ho_Chi_Minh',
      items: items,
    );
  }

  static Future<CareScheduleItem> updateWaterSchedule(
    String plantId, {
    required int intervalDays,
    required String localTime,
    required bool enabled,
  }) async {
    final data = await DioClient.instance.put(
      '/plants/$plantId/schedules/water',
      body: {
        'interval_days': intervalDays,
        'local_time': localTime,
        'enabled': enabled,
      },
    );
    return CareScheduleItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<CareScheduleItem> updateFertilizeSchedule(
    String plantId, {
    required int intervalDays,
    required String localTime,
    required bool enabled,
  }) async {
    final data = await DioClient.instance.put(
      '/plants/$plantId/schedules/fertilize',
      body: {
        'interval_days': intervalDays,
        'local_time': localTime,
        'enabled': enabled,
      },
    );
    return CareScheduleItem.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<CarePlanSyncResult> syncCarePlan(String plantId) async {
    final data = await DioClient.instance.post(
      '/plants/$plantId/care-plan/sync',
      body: {},
    );
    return CarePlanSyncResult.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  // --- Dữ liệu chăm sóc loài bằng Gemini (Plant Detail / AI Result) ---
  static Future<PlantCareDataResult> getCareData(String plantId) async {
    final data = await DioClient.instance.get('/plants/$plantId/care-data');
    return PlantCareDataResult.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  static Future<PlantCareDataResult> enrichCareData(String plantId) async {
    final data = await DioClient.instance.post(
      '/plants/$plantId/care-data/enrich',
      body: {},
      receiveTimeout: const Duration(seconds: 50),
    );
    return PlantCareDataResult.fromJson(
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
    );
  }

  // --- Lưu cây sau khi quét AI (AI Result) ---
  static Future<Map<String, dynamic>> saveScannedPlant({
    required String nickname,
    String? speciesId,
    String? coverImageKey,
    String environment = 'unknown',
    double? latitude,
    double? longitude,
  }) async {
    final data = await DioClient.instance.post(
      '/garden',
      body: {
        'nickname': nickname.trim(),
        if (speciesId != null && speciesId.isNotEmpty) 'species_id': speciesId,
        if (coverImageKey != null && coverImageKey.isNotEmpty)
          'cover_image_key': coverImageKey,
        'environment': environment,
        'latitude': ?latitude,
        'longitude': ?longitude,
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }
}