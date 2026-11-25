import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/plant_model.dart';
import 'dio_client.dart';

double? _parseDouble(dynamic val) {
  if (val == null) return null;
  if (val is num) return val.toDouble();
  if (val is String) return double.tryParse(val);
  return null;
}

class ScanFindingItem {
  final String reportedName;
  final double? confidence;
  final String? symptoms;
  final String? possibleCause;
  final List<String> treatmentSteps;

  const ScanFindingItem({
    required this.reportedName,
    this.confidence,
    this.symptoms,
    this.possibleCause,
    this.treatmentSteps = const [],
  });

  factory ScanFindingItem.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['treatment_steps'];
    final steps = rawSteps is List
        ? rawSteps
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    return ScanFindingItem(
      reportedName: json['reported_name']?.toString().trim() ?? '',
      confidence: _parseDouble(json['confidence']),
      symptoms: json['symptoms']?.toString().trim(),
      possibleCause: json['possible_cause']?.toString().trim(),
      treatmentSteps: steps,
    );
  }
}

class ScanResponse {
  final String id;
  final String mode;
  final String source;
  final bool isMock;
  final String imageKey;
  final String imageUrl;
  final String? speciesId;
  final String? reportedSpeciesName;
  final double? speciesConfidence;
  final String healthStatus; // healthy | suspected | unknown | not_assessed
  final List<ScanFindingItem> findings;

  const ScanResponse({
    required this.id,
    required this.mode,
    required this.source,
    required this.isMock,
    required this.imageKey,
    this.imageUrl = '',
    this.speciesId,
    this.reportedSpeciesName,
    this.speciesConfidence,
    required this.healthStatus,
    this.findings = const [],
  });

  factory ScanResponse.fromJson(Map<String, dynamic> json) {
    final rawFindings = json['scan_findings'];
    final findings = rawFindings is List
        ? rawFindings
              .whereType()
              .map(
                (m) => ScanFindingItem.fromJson(Map<String, dynamic>.from(m)),
              )
              .toList()
        : <ScanFindingItem>[];

    return ScanResponse(
      id: json['id']?.toString() ?? '',
      mode: json['mode']?.toString() ?? 'identify',
      source: json['source']?.toString() ?? '',
      isMock: json['is_mock'] == true,
      imageKey: json['image_key']?.toString() ?? '',
      imageUrl: json['image_url']?.toString() ?? '',
      speciesId: json['species_id']?.toString(),
      reportedSpeciesName: json['reported_species_name']?.toString().trim(),
      speciesConfidence: _parseDouble(json['species_confidence']),
      healthStatus: json['health_status']?.toString() ?? 'unknown',
      findings: findings,
    );
  }

  /// Độ tin cậy ưu tiên theo loài; nếu chỉ chẩn đoán thì lấy theo finding đầu tiên
  double? get displayConfidence {
    if (speciesConfidence != null) return speciesConfidence;
    if (findings.isNotEmpty) return findings.first.confidence;
    return null;
  }

  PlantModel toPlantModel() {
    final firstFinding = findings.isNotEmpty ? findings.first : null;
    final isSick = healthStatus == 'suspected';

    final scientific = reportedSpeciesName ?? '';
    final displayName = scientific.isNotEmpty ? scientific : 'Cây mới quét';

    final symptomList = <String>[];
    final treatmentList = <String>[];
    for (final f in findings) {
      if (f.symptoms != null && f.symptoms!.isNotEmpty) {
        symptomList.add(f.symptoms!);
      }
      if (f.possibleCause != null && f.possibleCause!.isNotEmpty) {
        symptomList.add('Nguyên nhân: ${f.possibleCause!}');
      }
      treatmentList.addAll(f.treatmentSteps);
    }

    return PlantModel(
      id: id,
      speciesId: speciesId,
      environment: 'unknown',
      nickname: displayName,
      scientificName: scientific,
      commonName: displayName,
      imageUrl: imageUrl,
      healthStatus: isSick ? HealthStatus.sick : HealthStatus.healthy,
      diseaseName:
          isSick && firstFinding != null && firstFinding.reportedName.isNotEmpty
          ? firstFinding.reportedName
          : null,
      symptoms: symptomList.isEmpty ? null : symptomList,
      treatmentSteps: treatmentList.isEmpty ? null : treatmentList,
      sunlightInfo: 'Lưu cây để xem',
      waterInfo: 'Tự tạo lịch',
      temperatureInfo: 'Theo loài',
      wateringFrequencyDays: 3,
      fertilizingFrequencyDays: 14,
      reminderTime: '08:00',
    );
  }
}

class ScanService {
  /// Gửi ảnh lên POST /scans (hỗ trợ mode: identify | diagnose | both)
  static Future<ScanResponse> createScan({
    required Uint8List imageBytes,
    required String fileName,
    required String mode,
    String organ = 'auto',
    String? plantId,
  }) async {
    final lower = fileName.toLowerCase();
    final String subtype;
    final String safeName;
    if (lower.endsWith('.png')) {
      subtype = 'png';
      safeName = fileName;
    } else if (lower.endsWith('.webp')) {
      subtype = 'webp';
      safeName = fileName;
    } else {
      subtype = 'jpeg';
      safeName = (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
          ? fileName
          : 'scan.jpg';
    }

    final map = <String, dynamic>{
      'image': MultipartFile.fromBytes(
        imageBytes,
        filename: safeName,
        contentType: DioMediaType('image', subtype),
      ),
      'mode': mode,
      'organ': organ,
    };
    if (plantId != null && plantId.isNotEmpty) {
      map['plant_id'] = plantId;
    }

    final data = await DioClient.instance.post(
      '/scans',
      body: FormData.fromMap(map),
      receiveTimeout: const Duration(seconds: 60),
    );

    if (data is Map) {
      return ScanResponse.fromJson(Map<String, dynamic>.from(data));
    }
    throw Exception('Phản hồi từ máy chủ không đúng định dạng.');
  }
}
