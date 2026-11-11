import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'page.dart';
import 'scan_data.dart';

class Scan extends ConsumerStatefulWidget {
  const Scan({super.key});
  @override
  ConsumerState<Scan> createState() => _ScanState();
}

class _ScanState extends ConsumerState<Scan> {
  XFile? photo;
  bool busy = false;
  String? error;
  Future<void> pick(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (mounted && picked != null) {
        setState(() {
          photo = picked;
          error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error =
              'Không mở được ảnh. Hãy kiểm tra quyền camera hoặc thư viện.',
        );
      }
    }
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await analyzePhoto(ref.read(apiProvider), photo!);
      if (mounted) context.push('/result', extra: result);
    } catch (e) {
      if (mounted) {
        setState(() => error = e is FormatException ? e.message : explain(e));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PlantPage('Quét ảnh cây', [
    if (photo != null)
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.file(
          File(photo!.path),
          height: 220,
          fit: BoxFit.cover,
          errorBuilder: (_, e, s) => const Text('Không xem trước được ảnh.'),
        ),
      ),
    const Text(
      'Chọn ảnh rõ nét của lá hoặc toàn bộ cây. JPEG hoặc PNG, tối đa 5 MiB.',
    ),
    Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: busy ? null : () => pick(ImageSource.camera),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Chụp ảnh'),
        ),
        OutlinedButton.icon(
          onPressed: busy ? null : () => pick(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Chọn từ thư viện'),
        ),
      ],
    ),
    FilledButton(
      onPressed: busy || photo == null ? null : submit,
      child: Text(busy ? 'Đang phân tích…' : 'Phân tích ảnh'),
    ),
    if (error != null)
      Text(
        error!,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
  ]);
}
