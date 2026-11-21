import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Nền camera trực tiếp (hoặc ảnh vừa chọn khi đang phân tích)
class ScanCameraPreview extends StatelessWidget {
  final CameraController? cameraController;
  final String? previewImagePath;
  final String? cameraError;

  const ScanCameraPreview({
    super.key,
    this.cameraController,
    this.previewImagePath,
    this.cameraError,
  });

  Widget _buildLiveCamera(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasLocalFile =
        previewImagePath != null && previewImagePath!.isNotEmpty;
    final isCameraReady =
        cameraController != null && cameraController!.value.isInitialized;

    Widget content;
    if (hasLocalFile) {
      content = Image.file(
        File(previewImagePath!),
        fit: BoxFit.cover,
      );
    } else if (isCameraReady) {
      content = _buildLiveCamera(cameraController!);
    } else {
      content = Stack(
        fit: StackFit.expand,
        children: [
          const Center(
            child: Icon(
              Icons.eco_rounded,
              size: 200,
              color: Color(0x332E5A36),
            ),
          ),
          if (cameraError != null)
            Align(
              alignment: const Alignment(0, 0.45),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.titleTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xFFC8E6C9),
        child: content,
      ),
    );
  }
}

/// Khung ngắm 4 góc + chú thích hướng dẫn
class ScanViewfinder extends StatelessWidget {
  final bool isAnalyzing;

  const ScanViewfinder({super.key, required this.isAnalyzing});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _ScanCorner(isTop: true, isLeft: true),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _ScanCorner(isTop: true, isLeft: false),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _ScanCorner(isTop: false, isLeft: true),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _ScanCorner(isTop: false, isLeft: false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AnimatedOpacity(
              opacity: isAnalyzing ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Đưa lá cây vào giữa khung hình',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 1 góc khung ngắm (widget nội bộ)
class _ScanCorner extends StatelessWidget {
  final bool isTop;
  final bool isLeft;

  const _ScanCorner({required this.isTop, required this.isLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          left: isLeft
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
          right: !isLeft
              ? const BorderSide(color: Colors.white, width: 4)
              : BorderSide.none,
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(isTop && isLeft ? 24 : 0),
          topRight: Radius.circular(isTop && !isLeft ? 24 : 0),
          bottomLeft: Radius.circular(!isTop && isLeft ? 24 : 0),
          bottomRight: Radius.circular(!isTop && !isLeft ? 24 : 0),
        ),
      ),
    );
  }
}