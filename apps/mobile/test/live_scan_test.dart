import 'dart:convert';

import 'package:ai_plant_care/features/plant_scan/data/scan.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  const url = String.fromEnvironment('LIVE_MOCK_API');
  test('Dio gửi ảnh thật qua HTTP tới Express mock', () async {
    final api = Dio(BaseOptions(baseUrl: url));
    addTearDown(() => api.close());
    final photo = XFile.fromData(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=',
      ),
      name: 'leaf.png',
      mimeType: 'image/png',
    );
    final result = await analyzePhoto(api, photo);
    expect(result.isMock, isTrue);
    expect(result.species.label, 'Epipremnum aureum • 94%');
    expect(result.diseases, isNotEmpty);
  }, skip: url.isEmpty);
}
