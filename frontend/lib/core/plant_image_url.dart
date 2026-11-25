/// Storage keys are identifiers, not URLs. Prefer the signed display URL.
String plantImageUrl(Map<String, dynamic> plant) {
  final reference = plant['reference_images'] ?? plant['referenceImage'];
  for (final candidate in [
    plant['cover_image_url'],
    plant['cover_image_key'], // Supports legacy records containing a full URL.
    if (reference is Map) reference['image_url'],
  ]) {
    final value = candidate?.toString().trim() ?? '';
    final uri = Uri.tryParse(value);
    if (uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.isNotEmpty) {
      return value;
    }
  }
  return '';
}
