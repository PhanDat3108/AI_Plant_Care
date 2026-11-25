import 'package:flutter_test/flutter_test.dart';
import 'package:ai_plant_care/core/plant_image_url.dart';
import 'package:ai_plant_care/models/task_model.dart';
import 'package:ai_plant_care/services/scan_service.dart';

void main() {
  const url = 'https://example.com/storage/object/sign/plant.jpg?token=test';
  test('prefers signed cover URL and never treats storage key as URL', () {
    expect(
      plantImageUrl({
        'cover_image_url': url,
        'cover_image_key': 'scans/user/photo.jpg',
      }),
      url,
    );
    expect(plantImageUrl({'cover_image_key': 'scans/user/photo.jpg'}), '');
    expect(
      plantImageUrl({'cover_image_key': 'https://example.com/old.jpg'}),
      'https://example.com/old.jpg',
    );
  });
  test('task images use the cover URL ahead of reference images', () {
    final task = TaskModel.fromJson({
      'care_schedules': {
        'plants': {
          'cover_image_url': url,
          'cover_image_key': 'scans/user/photo.jpg',
          'reference_images': {
            'image_url': 'https://example.com/reference.jpg',
          },
        },
      },
    });
    expect(task.plantAvatar, url);
  });
  test('scan keeps storage key for saving and URL for display separate', () {
    final scan = ScanResponse.fromJson({
      'image_key': 'scans/user/photo.jpg',
      'image_url': url,
    });
    expect(scan.imageKey, 'scans/user/photo.jpg');
    expect(scan.toPlantModel().imageUrl, url);
  });
}
