import '../models/plant_model.dart';
import 'dio_client.dart';

class CareLogService {
  static Future<List<CareLog>> listByPlant(
    String plantId, {
    String? kind,
    int? limit,
  }) async {
    final params = <String, dynamic>{
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (limit != null && limit > 0) 'limit': limit,
    };

    final data = await DioClient.instance.get(
      '/plants/$plantId/care-logs',
      queryParameters: params.isEmpty ? null : params,
    );

    if (data is! List) return [];

    return data
        .whereType()
        .map((item) => CareLog.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  static Future<CareLog> createCareLog({
    required String plantId,
    required String kind, // water | fertilize | treat | note
    String? note,
    DateTime? performedAt,
    String? requestId,
    String? taskId,
  }) async {
    final trimmedNote = note?.trim();
    final data = await DioClient.instance.post(
      '/plants/$plantId/care-logs',
      body: {
        'kind': kind,
        if (trimmedNote != null && trimmedNote.isNotEmpty) 'note': trimmedNote,
        if (performedAt != null)
          'performed_at': performedAt.toUtc().toIso8601String(),
        if (requestId != null && requestId.isNotEmpty) 'request_id': requestId,
        if (taskId != null && taskId.isNotEmpty) 'task_id': taskId,
      },
    );

    return CareLog.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<CareLog> updateCareLog(
    String logId, {
    String? kind,
    String? note,
    DateTime? performedAt,
  }) async {
    final body = <String, dynamic>{
      if (kind != null && kind.isNotEmpty) 'kind': kind,
      if (note != null) 'note': note.trim(),
      if (performedAt != null)
        'performed_at': performedAt.toUtc().toIso8601String(),
    };

    final data = await DioClient.instance.patch(
      '/care-logs/$logId',
      body: body,
    );

    return CareLog.fromJson(Map<String, dynamic>.from(data as Map));
  }

  static Future<void> deleteCareLog(String logId) async {
    await DioClient.instance.delete('/care-logs/$logId');
  }
}