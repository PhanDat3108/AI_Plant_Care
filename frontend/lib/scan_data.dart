import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';

class Prediction {
  final String name;
  final double probability;
  Prediction.fromJson(Json json)
    : name = json['name'] as String,
      probability = (json['probability'] as num).toDouble();
  String get label => '$name • ${(probability * 100).round()}%';
}

class ScanResult {
  final bool isMock;
  final Prediction species;
  final List<Prediction> diseases;
  final String care;
  final String? possibleCause;
  ScanResult.fromJson(Json json)
    : isMock = json['isMock'] as bool,
      species = Prediction.fromJson(json['species'] as Json),
      diseases = (json['diseases'] as List)
          .cast<Json>()
          .map(Prediction.fromJson)
          .toList(),
      care = json['care'] as String,
      possibleCause = json['possibleCause'] as String?;
}

Future<ScanResult> analyzePhoto(Dio api, XFile image) async {
  if (await image.length() > 5 * 1024 * 1024) {
    throw const FormatException('Ảnh vượt quá 5 MiB.');
  }
  final bytes = await image.readAsBytes();
  final png = bytes.length >= 8 && bytes[0] == 137 && bytes[1] == 80;
  final jpg = bytes.length >= 3 && bytes[0] == 255 && bytes[1] == 216;
  if (!png && !jpg) throw const FormatException('Hãy chọn ảnh JPEG hoặc PNG.');
  final part = MultipartFile.fromBytes(
    bytes,
    filename: png ? 'plant.png' : 'plant.jpg',
    contentType: DioMediaType('image', png ? 'png' : 'jpeg'),
  );
  final response = await api.post<Json>(
    '/scans/analyze',
    data: FormData.fromMap({'image': part}),
  );
  return ScanResult.fromJson(response.data!['data'] as Json);
}
